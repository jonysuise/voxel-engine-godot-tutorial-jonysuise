extends MeshInstance3D

var chunk_manager : Node
var chunk_offset := Vector3(0, 0, 0)
var chunk_color = Color.WHITE
var key := Vector2i(0, 0)
var _triangles = 0
var _chunk_data = []
var _tiles_per_row := 2
var _tile_size := 1.0 / _tiles_per_row

signal mesh_updated(chunk, triangle_count)
signal border_update_requested(neighbor_key: Vector2i)


func _add_cube(st: SurfaceTool, _position: Vector3, size: int, color: Color, block_type: BlockDefinitions.BlockType) -> void:
	var x := int(_position.x - chunk_offset.x)
	var y := int(_position.y - chunk_offset.y)
	var z := int(_position.z - chunk_offset.z)
	
	# positive Z
	if is_air(x, y, z + 1):
		_add_face(
			st,
			_position + Vector3(-0.5, -0.5, 0.5) * size,
			_position + Vector3(-0.5, 0.5, 0.5) * size,
			_position + Vector3(0.5, 0.5, 0.5) * size,
			_position + Vector3(0.5, -0.5, 0.5) * size,
			Vector3(0, 0, 1),
			color,
			block_type,
			BlockDefinitions.Face.POS_Z
		)
	
	# positive X
	if is_air(x + 1, y, z):
		_add_face(
			st,
			_position + Vector3(0.5, -0.5, 0.5) * size,
			_position + Vector3(0.5, 0.5, 0.5) * size,
			_position + Vector3(0.5, 0.5, -0.5) * size,
			_position + Vector3(0.5, -0.5, -0.5) * size,
			Vector3(1, 0, 0),
			color,
			block_type,
			BlockDefinitions.Face.POS_X
		)
	
	# negative Z
	if is_air(x, y, z - 1):
		_add_face(
			st,
			_position + Vector3(0.5, -0.5, -0.5) * size,
			_position + Vector3(0.5, 0.5, -0.5) * size,
			_position + Vector3(-0.5, 0.5, -0.5) * size,
			_position + Vector3(-0.5, -0.5, -0.5) * size,
			Vector3(0, 0, -1),
			color,
			block_type,
			BlockDefinitions.Face.NEG_Z
		)
	
	# negative X
	if is_air(x - 1, y, z):
		_add_face(
			st,
			_position + Vector3(-0.5, -0.5, -0.5) * size,
			_position + Vector3(-0.5, 0.5, -0.5) * size,
			_position + Vector3(-0.5, 0.5, 0.5) * size,
			_position + Vector3(-0.5, -0.5, 0.5) * size,
			Vector3(-1, 0, 0),
			color,
			block_type,
			BlockDefinitions.Face.NEG_X
		)
	
	# negative Y
	if is_air(x, y - 1, z):
		_add_face(
			st,
			_position + Vector3(-0.5, -0.5, -0.5) * size,
			_position + Vector3(-0.5, -0.5, 0.5) * size,
			_position + Vector3(0.5, -0.5, 0.5) * size,
			_position + Vector3(0.5, -0.5, -0.5) * size,
			Vector3(0, -1, 0),
			color,
			block_type,
			BlockDefinitions.Face.NEG_Y
		)
	
	# positive Y
	if is_air(x, y + 1, z):
		_add_face(
			st,
			_position + Vector3(-0.5, 0.5, 0.5) * size,
			_position + Vector3(-0.5, 0.5, -0.5) * size,
			_position + Vector3(0.5, 0.5, -0.5) * size,
			_position + Vector3(0.5, 0.5, 0.5) * size,
			Vector3(0, 1, 0),
			color,
			block_type,
			BlockDefinitions.Face.POS_Y
		)
	
	
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

	
func _add_face(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, normal: Vector3, color: Color, block_type: BlockDefinitions.BlockType, face: BlockDefinitions.Face) -> void:
	st.set_normal(normal)
	st.set_color(color)
	
	# determine uv coordinates based on block type
	var tile_index = BlockDefinitions.BLOCK_TILES[block_type][face]
	var col = tile_index % _tiles_per_row
	var row = tile_index / _tiles_per_row
	var base_uv := Vector2(col * _tile_size, row * _tile_size)
	
	st.set_uv(base_uv + Vector2(0, _tile_size))
	st.add_vertex(v1)
	
	st.set_uv(base_uv + Vector2(0, 0))
	st.add_vertex(v2)
	
	st.set_uv(base_uv + Vector2(_tile_size, 0))
	st.add_vertex(v3)
	
	st.set_uv(base_uv + Vector2(0, _tile_size))
	st.add_vertex(v1)
	
	st.set_uv(base_uv + Vector2(_tile_size, 0))
	st.add_vertex(v3)
	
	st.set_uv(base_uv + Vector2(_tile_size, _tile_size))
	st.add_vertex(v4)
	
	_triangles += 6
	

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
				
	for x in range(chunk_manager.chunk_size):
		for z in range(chunk_manager.chunk_size):
			for y in range(chunk_manager.chunk_size):
				if _chunk_data[x][z][y] != BlockDefinitions.BlockType.AIR:
					_add_cube(st, Vector3(x + chunk_offset.x, y + chunk_offset.y, z + chunk_offset.z), 1, chunk_color, _chunk_data[x][z][y])
					
	
	mesh = st.commit()
	await get_tree().process_frame
	_build_collider()
	
	emit_signal("mesh_updated", self, _triangles)
	
	

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
