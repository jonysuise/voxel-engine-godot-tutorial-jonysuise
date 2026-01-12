extends MeshInstance3D

var chunk_manager : Node
var chunk_offset := Vector3i(0, 0, 0)
var chunk_color = Color.WHITE
var key := Vector2i(0, 0)
var _triangles = 0
var _chunk_data = []
var _tiles_per_row := 2
var _tile_size := 1.0 / _tiles_per_row

signal mesh_updated(chunk, triangle_count)
signal border_update_requested(neighbor_key: Vector2i)


func is_air(ix: int, iy: int, iz: int) -> bool:
	
	if ix >= 0 and ix < chunk_manager.chunk_size \
		and iy >= 0 and iy < chunk_manager.chunk_size \
		and iz >= 0 and iz < chunk_manager.chunk_size:
			return _chunk_data[ix][iz][iy] == BlockDefinitions.BlockType.AIR
	
	# outside -> ask chunk manager using world coordinates
	var wx = ix + chunk_offset.x
	var wy = iy + chunk_offset.y
	var wz = iz + chunk_offset.z
	
	return chunk_manager.is_air_world(wx, wy, wz)


func _add_face(
	st: SurfaceTool,
	v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3,
	normal: Vector3,
	color: Color,
	block_type: BlockDefinitions.BlockType,
	face: BlockDefinitions.Face,
	u_repeat: float = 1.0,
	v_repeat: float = 1.0
) -> void:
	st.set_normal(normal)
	st.set_color(color)


	# --- Atlas tile origin (goes into UV2) ---
	var tile_index: int = BlockDefinitions.BLOCK_TILES[block_type][face]
	var col: int = tile_index % _tiles_per_row
	var row: int = tile_index / _tiles_per_row 
	var base_uv := Vector2(col * _tile_size, row * _tile_size)

	# UV = local tiling UVs (can exceed 1.0)
	# UV2 = atlas tile origin (base_uv)
	# Triangle 1: v1, v2, v3
	st.set_uv2(base_uv)
	st.set_uv(Vector2(0.0, v_repeat))
	st.add_vertex(v1)

	st.set_uv2(base_uv)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(v2)

	st.set_uv2(base_uv)
	st.set_uv(Vector2(u_repeat, 0.0))
	st.add_vertex(v3)

	# Triangle 2: v1, v3, v4
	st.set_uv2(base_uv)
	st.set_uv(Vector2(0.0, v_repeat))
	st.add_vertex(v1)

	st.set_uv2(base_uv)
	st.set_uv(Vector2(u_repeat, 0.0))
	st.add_vertex(v3)

	st.set_uv2(base_uv)
	st.set_uv(Vector2(u_repeat, v_repeat))
	st.add_vertex(v4)

	_triangles += 2


func init_mesh(sn : FastNoiseLite) -> void:
	
	for x in range(chunk_manager.chunk_size):
		_chunk_data.append([])
		for z in range(chunk_manager.chunk_size):
			_chunk_data[x].append([])
			
			var xf = (x + chunk_offset.x) * chunk_manager.noise_scale
			var zf = (z + chunk_offset.z) * chunk_manager.noise_scale

			var height = snapped((sn.get_noise_2d(xf, zf) + 1) * 0.5 * chunk_manager.max_height, 1)

			for y in range(chunk_manager.chunk_size):
				if y > height:
					_chunk_data[x][z].append(BlockDefinitions.BlockType.AIR)
				elif y == height:
					if y > 15:
						_chunk_data[x][z].append(BlockDefinitions.BlockType.STONE)
					else:
						_chunk_data[x][z].append(BlockDefinitions.BlockType.GRASS)
				else:
					_chunk_data[x][z].append(BlockDefinitions.BlockType.DIRT)


func build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_triangles = 0

	# ---------- POSITIVE Z ----------
	for z in range(chunk_manager.chunk_size):
		_greedy_xy_on_z_slice(st, z, BlockDefinitions.Face.POS_Z, 0, 0, 1)

	# ---------- NEGATIVE Z ----------
	for z in range(chunk_manager.chunk_size):
		_greedy_xy_on_z_slice(st, z, BlockDefinitions.Face.NEG_Z, 0, 0, -1)
	
	# ---------- POSITIVE X ----------
	for x in range(chunk_manager.chunk_size):
		_greedy_zy_on_x_slice(st, x, BlockDefinitions.Face.POS_X, 1, 0, 0)

	# ---------- NEGATIVE X ----------
	for x in range(chunk_manager.chunk_size):
		_greedy_zy_on_x_slice(st, x, BlockDefinitions.Face.NEG_X, -1, 0, 0)

	# ---------- POSITIVE Y ----------
	for y in range(chunk_manager.chunk_size):
		_greedy_xz_on_y_slice(st, y, BlockDefinitions.Face.POS_Y, 0, 1, 0)

	# ---------- NEGATIVE Y ----------
	for y in range(chunk_manager.chunk_size):
		_greedy_xz_on_y_slice(st, y, BlockDefinitions.Face.NEG_Y, 0, -1, 0)

	mesh = st.commit()
	_build_collider()
	emit_signal("mesh_updated", self, _triangles)


func _greedy_xy_on_z_slice(st, z: int, face, dx: int, dy: int, dz: int) -> void:
	var active := {}
	var next_active := {}

	for y in range(chunk_manager.chunk_size):
		next_active.clear()

		# --- scan this row and produce X-runs ---
		var run_start_x := 0
		var run_tile := -1

		for x in range(chunk_manager.chunk_size):
			var tile := -1
			var block = _chunk_data[x][z][y]
			if block != BlockDefinitions.BlockType.AIR and is_air(x + dx, y + dy, z + dz):
				tile = BlockDefinitions.BLOCK_TILES[block][face]


			if x == 0:
				run_tile = tile
				run_start_x = 0
				continue

			if tile != run_tile:
				# close previous run
				if run_tile >= 0:
					var x0 := run_start_x
					var x1 := x - 1
					var key := "%d:%d:%d" % [x0, x1, run_tile]

					if active.has(key):
						# extend rect
						var r = active[key]
						r.y1 = y
						next_active[key] = r
					else:
						# new rect
						next_active[key] = {"x0": x0, "x1": x1, "y0": y, "y1": y, "tile": run_tile}

				# start new run
				run_tile = tile
				run_start_x = x

		# close last run in row
		if run_tile >= 0:
			var x0 := run_start_x
			var x1 = chunk_manager.chunk_size - 1
			var key := "%d:%d:%d" % [x0, x1, run_tile]

			if active.has(key):
				var r = active[key]
				r.y1 = y
				next_active[key] = r
			else:
				next_active[key] = {"x0": x0, "x1": x1, "y0": y, "y1": y, "tile": run_tile}

		# flush rects that did not continue
		for key in active:
			if not next_active.has(key):
				var r = active[key]
				_flush_x_run_2d(st, r.x0, r.x1, r.y0, r.y1, z, r.tile, face)

		# swap (no allocation)
		var tmp = active
		active = next_active
		next_active = tmp

	# flush remaining
	for key in active:
		var r = active[key]
		_flush_x_run_2d(st, r.x0, r.x1, r.y0, r.y1, z, r.tile, face)


func _flush_x_run_2d(st, x0, x1, y0, y1, z, tile, face):
	if tile < 0:
		return

	var size_x = x1 - x0 + 1
	var size_y = y1 - y0 + 1

	var z_off := 0.5 if face == BlockDefinitions.Face.POS_Z else -0.5
	var normal := Vector3(0, 0, 1) if face == BlockDefinitions.Face.POS_Z else Vector3(0, 0, -1)

	var x_start = x0 + chunk_offset.x
	var x_end   = x1 + chunk_offset.x
	var y_start = y0 + chunk_offset.y
	var y_end   = y1 + chunk_offset.y
	var wz      = z  + chunk_offset.z

	var v1: Vector3
	var v2: Vector3
	var v3: Vector3
	var v4: Vector3

	if face == BlockDefinitions.Face.POS_Z:
		v1 = Vector3(x_start - 0.5, y_start - 0.5, wz + z_off)
		v2 = Vector3(x_start - 0.5, y_end   + 0.5, wz + z_off)
		v3 = Vector3(x_end   + 0.5, y_end   + 0.5, wz + z_off)
		v4 = Vector3(x_end   + 0.5, y_start - 0.5, wz + z_off)
	else:
		v1 = Vector3(x_end   + 0.5, y_start - 0.5, wz + z_off)
		v2 = Vector3(x_end   + 0.5, y_end   + 0.5, wz + z_off)
		v3 = Vector3(x_start - 0.5, y_end   + 0.5, wz + z_off)
		v4 = Vector3(x_start - 0.5, y_start - 0.5, wz + z_off)

	var block_type = _chunk_data[x0][z][y0]

	_add_face(
		st,
		v1, v2, v3, v4,
		normal,
		chunk_color,
		block_type,
		face,
		size_x,   # u_repeat
		size_y    # v_repeat
	)


func _greedy_zy_on_x_slice(st, x: int, face, dx: int, dy: int, dz: int) -> void:
	var active := {}
	var next_active := {}

	for y in range(chunk_manager.chunk_size):
		next_active.clear()

		var run_start_z := 0
		var run_tile := -1

		for z in range(chunk_manager.chunk_size):
			var tile := -1
			var block = _chunk_data[x][z][y]
			if block != BlockDefinitions.BlockType.AIR and is_air(x + dx, y + dy, z + dz):
				tile = BlockDefinitions.BLOCK_TILES[block][face]

			if z == 0:
				run_tile = tile
				run_start_z = 0
				continue

			if tile != run_tile:
				if run_tile >= 0:
					var z0 := run_start_z
					var z1 := z - 1
					var key := "%d:%d:%d" % [z0, z1, run_tile]

					if active.has(key):
						var r = active[key]
						r.y1 = y
						next_active[key] = r
					else:
						next_active[key] = {"z0": z0, "z1": z1, "y0": y, "y1": y, "tile": run_tile}

				run_tile = tile
				run_start_z = z

		if run_tile >= 0:
			var z0 := run_start_z
			var z1 = chunk_manager.chunk_size - 1
			var key := "%d:%d:%d" % [z0, z1, run_tile]

			if active.has(key):
				var r = active[key]
				r.y1 = y
				next_active[key] = r
			else:
				next_active[key] = {"z0": z0, "z1": z1, "y0": y, "y1": y, "tile": run_tile}

		for key in active:
			if not next_active.has(key):
				var r = active[key]
				_flush_z_run_2d(st, r.z0, r.z1, r.y0, r.y1, x, r.tile, face)

		# swap (no allocation)
		var tmp = active
		active = next_active
		next_active = tmp

	for key in active:
		var r = active[key]
		_flush_z_run_2d(st, r.z0, r.z1, r.y0, r.y1, x, r.tile, face)


func _flush_z_run_2d(st, z0, z1, y0, y1, x, tile, face):
	if tile < 0:
		return

	var size_z = z1 - z0 + 1
	var size_y = y1 - y0 + 1

	var x_off := 0.5 if face == BlockDefinitions.Face.POS_X else -0.5
	var normal := Vector3(1, 0, 0) if face == BlockDefinitions.Face.POS_X else Vector3(-1, 0, 0)

	var z_start = z0 + chunk_offset.z
	var z_end   = z1 + chunk_offset.z
	var y_start = y0 + chunk_offset.y
	var y_end   = y1 + chunk_offset.y
	var wx      = x  + chunk_offset.x

	var v1: Vector3
	var v2: Vector3
	var v3: Vector3
	var v4: Vector3

	if face == BlockDefinitions.Face.NEG_X:
		v1 = Vector3(wx + x_off, y_start - 0.5, z_start - 0.5)
		v2 = Vector3(wx + x_off, y_end   + 0.5, z_start - 0.5)
		v3 = Vector3(wx + x_off, y_end   + 0.5, z_end   + 0.5)
		v4 = Vector3(wx + x_off, y_start - 0.5, z_end   + 0.5)
	else:
		v1 = Vector3(wx + x_off, y_start - 0.5, z_end   + 0.5)
		v2 = Vector3(wx + x_off, y_end   + 0.5, z_end   + 0.5)
		v3 = Vector3(wx + x_off, y_end   + 0.5, z_start - 0.5)
		v4 = Vector3(wx + x_off, y_start - 0.5, z_start - 0.5)

	var block_type = _chunk_data[x][z0][y0]

	_add_face(
		st,
		v1, v2, v3, v4,
		normal,
		chunk_color,
		block_type,
		face,
		size_z,  # u_repeat
		size_y   # v_repeat
	)


func _greedy_xz_on_y_slice(st, y: int, face, dx: int, dy: int, dz: int) -> void:
	var active := {}
	var next_active := {}
	
	for z in range(chunk_manager.chunk_size):
		next_active.clear()

		var run_start_x := 0
		var run_tile := -1

		for x in range(chunk_manager.chunk_size):
			var tile := -1
			var block = _chunk_data[x][z][y]
			if block != BlockDefinitions.BlockType.AIR and is_air(x + dx, y + dy, z + dz):
				tile = BlockDefinitions.BLOCK_TILES[block][face]

			if x == 0:
				run_tile = tile
				run_start_x = 0
				continue

			if tile != run_tile:
				if run_tile >= 0:
					var x0 := run_start_x
					var x1 := x - 1
					var key := "%d:%d:%d" % [x0, x1, run_tile]

					if active.has(key):
						var r = active[key]
						r.z1 = z
						next_active[key] = r
					else:
						next_active[key] = {"x0": x0, "x1": x1, "z0": z, "z1": z, "tile": run_tile}

				run_tile = tile
				run_start_x = x

		if run_tile >= 0:
			var x0 := run_start_x
			var x1 = chunk_manager.chunk_size - 1
			var key := "%d:%d:%d" % [x0, x1, run_tile]

			if active.has(key):
				var r = active[key]
				r.z1 = z
				next_active[key] = r
			else:
				next_active[key] = {"x0": x0, "x1": x1, "z0": z, "z1": z, "tile": run_tile}

		for key in active:
			if not next_active.has(key):
				var r = active[key]
				_flush_y_run_2d(st, r.x0, r.x1, r.z0, r.z1, y, r.tile, face)

		# swap (no allocation)
		var tmp = active
		active = next_active
		next_active = tmp

	# flush remaining
	for key in active:
		var r = active[key]
		_flush_y_run_2d(st, r.x0, r.x1, r.z0, r.z1, y, r.tile, face)


func _flush_y_run_2d(st, x0, x1, z0, z1, y, tile, face):
	if tile < 0:
		return

	var size_x = x1 - x0 + 1
	var size_z = z1 - z0 + 1

	var y_off := 0.5 if face == BlockDefinitions.Face.POS_Y else -0.5
	var normal := Vector3(0, 1, 0) if face == BlockDefinitions.Face.POS_Y else Vector3(0, -1, 0)

	var x_start = x0 + chunk_offset.x
	var x_end   = x1 + chunk_offset.x
	var z_start = z0 + chunk_offset.z
	var z_end   = z1 + chunk_offset.z
	var wy      = y  + chunk_offset.y

	var v1: Vector3
	var v2: Vector3
	var v3: Vector3
	var v4: Vector3

	if face == BlockDefinitions.Face.NEG_Y:
		v1 = Vector3(x_start - 0.5, wy + y_off, z_start - 0.5)
		v2 = Vector3(x_start - 0.5, wy + y_off, z_end   + 0.5)
		v3 = Vector3(x_end   + 0.5, wy + y_off, z_end   + 0.5)
		v4 = Vector3(x_end   + 0.5, wy + y_off, z_start - 0.5)
	else:
		v1 = Vector3(x_end   + 0.5, wy + y_off, z_start - 0.5)
		v2 = Vector3(x_end   + 0.5, wy + y_off, z_end   + 0.5)
		v3 = Vector3(x_start - 0.5, wy + y_off, z_end   + 0.5)
		v4 = Vector3(x_start - 0.5, wy + y_off, z_start - 0.5)

	var block_type = _chunk_data[x0][z0][y]

	_add_face(
		st,
		v1, v2, v3, v4,
		normal,
		chunk_color,
		block_type,
		face,
		size_x,  # u_repeat
		size_z   # v_repeat
	)


func _build_collider() -> void:
	
	# remove previous collider if any
	for child in get_children():
		if child is StaticBody3D:
			remove_child(child)
			child.queue_free()
	
	var body := StaticBody3D.new()
	var shape := mesh.create_trimesh_shape()
	
	var col := CollisionShape3D.new()
	col.shape = shape
	
	body.add_child(col)
	add_child(body)


func get_triangle_count() -> int:
	return _triangles


func _world_to_local(world_coords: Vector3i) -> Vector3i:
	return Vector3i(
		world_coords.x - chunk_offset.x,
		world_coords.y - chunk_offset.y,
		world_coords.z - chunk_offset.z
	)


func delete_block(block_coords: Vector3i) -> void:
	var local := _world_to_local(block_coords)
	
	# check block is in chunk
	if local.x < 0 or local.x >= chunk_manager.chunk_size \
	or local.y < 0 or local.y >= chunk_manager.chunk_size \
	or local.z < 0 or local.z >= chunk_manager.chunk_size:
		# wrong chunk -> delegate to chunk manager
		return chunk_manager.delete_block_world(block_coords)
	
	_chunk_data[local.x][local.z][local.y] = BlockDefinitions.BlockType.AIR
	build_mesh()
	_check_border(local)


func add_block(block_coords: Vector3i) -> void:
	var local := _world_to_local(block_coords)
	
	# check block is in chunk
	if local.x < 0 or local.x >= chunk_manager.chunk_size \
	or local.y < 0 or local.y >= chunk_manager.chunk_size \
	or local.z < 0 or local.z >= chunk_manager.chunk_size:
		# wrong chunk -> delegate to chunk manager
		return chunk_manager.add_block_world(block_coords)
	
	_chunk_data[local.x][local.z][local.y] = BlockDefinitions.BlockType.DIRT
	build_mesh()
	_check_border(local)


func _check_border(local: Vector3i) -> void:
	var cs = chunk_manager.chunk_size
	
	if local.x == 0:
		emit_signal("border_update_requested", key + Vector2i(-1, 0))
	elif local.x == cs - 1:
		emit_signal("border_update_requested", key + Vector2i(1, 0))
	
	if local.z == 0:
		emit_signal("border_update_requested", key + Vector2i(0, -1))
	elif local.z == cs - 1:
		emit_signal("border_update_requested", key + Vector2i(0, 1))


func check_block_selected(block_coords: Vector3i) -> bool:
	var local := _world_to_local(block_coords)
	
	# check block is in chunk
	if local.x < 0 or local.x >= chunk_manager.chunk_size \
	or local.y < 0 or local.y >= chunk_manager.chunk_size \
	or local.z < 0 or local.z >= chunk_manager.chunk_size:
		return false
	
	return _chunk_data[local.x][local.z][local.y] != BlockDefinitions.BlockType.AIR
