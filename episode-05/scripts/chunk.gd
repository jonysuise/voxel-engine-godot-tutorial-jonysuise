extends Node3D

const SECTION_H := 16
const FACE_SHADE := {
	BlockDefinitions.Face.POS_Y: 1.0,
	BlockDefinitions.Face.NEG_Y: 0.2,
	BlockDefinitions.Face.POS_X: 0.4,
	BlockDefinitions.Face.NEG_X: 0.4,
	BlockDefinitions.Face.POS_Z: 0.75,
	BlockDefinitions.Face.NEG_Z: 0.75,
}


@onready var _section_meshes: Array[MeshInstance3D] = [
	$Section0,
	$Section1,
	$Section2,
	$Section3
]

var chunk_manager : Node
var chunk_offset := Vector3i(0, 0, 0)
var chunk_color = Color.WHITE
var key := Vector2i(0, 0)

var _chunk_data: PackedByteArray
var tiles_per_row: int
var tile_size: float
var _uv_cache: Dictionary = {}

var _sun_cutoff_y: PackedInt32Array
var sun_bright := 1.0 
var sun_dim := 0.07 if Config.version <= 2 else 0.25  

signal border_update_requested(neighbor_key: Vector2i, y: int)




func _is_opaque_block(bt: int) -> bool:
	return bt != int(BlockDefinitions.BlockType.AIR)


func _sun_idx(x: int, z: int) -> int:
	var cs: int = chunk_manager.chunk_size
	return x + cs * z


func _rebuild_sunlight_all() -> void:
	var cs: int = chunk_manager.chunk_size
	var h: int = chunk_manager.max_height

	_sun_cutoff_y = PackedInt32Array()
	_sun_cutoff_y.resize(cs * cs)

	for z in range(cs):
		var z_base := cs * z
		for x in range(cs):
			var cutoff := -1
			for y in range(h - 1, -1, -1):
				var idx := x + cs * (z + cs * y)
				if _is_opaque_block(int(_chunk_data[idx])):
					cutoff = y
					break
			_sun_cutoff_y[z_base + x] = cutoff


func _get_uvs_for_block(bt: int) -> Array:
	var _key := bt
	if _uv_cache.has(_key):
		return _uv_cache[_key]

	var face_uvs: Array = []
	face_uvs.resize(BlockDefinitions.Face.size())

	var tiles = BlockDefinitions.BLOCK_TILES[bt]
	for f in tiles.keys():
		face_uvs[int(f)] = _tile_uv(int(tiles[f]))

	_uv_cache[_key] = face_uvs
	return face_uvs


func _world_to_local(world_coords: Vector3i) -> Vector3i:
	return Vector3i(
		world_coords.x - chunk_offset.x,
		world_coords.y - chunk_offset.y,
		world_coords.z - chunk_offset.z
	)


func _check_border(local: Vector3i) -> void:
	var cs = chunk_manager.chunk_size

	if local.x == 0:
		emit_signal("border_update_requested", key + Vector2i(-1, 0), local.y)
	elif local.x == cs - 1:
		emit_signal("border_update_requested", key + Vector2i(1, 0), local.y)

	if local.z == 0:
		emit_signal("border_update_requested", key + Vector2i(0, -1), local.y)
	elif local.z == cs - 1:
		emit_signal("border_update_requested", key + Vector2i(0, 1), local.y)


func _tile_uv(tile_index: int) -> Vector2:
	var col := tile_index % tiles_per_row
	var row := tile_index / tiles_per_row
	return Vector2(col * tile_size, row * tile_size)


func _emit_quad(
	pos: PackedVector3Array,
	nrm: PackedVector3Array,
	uvs: PackedVector2Array,
	cols: PackedColorArray,
	v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3,
	normal: Vector3,
	base_uv: Vector2,
	color: Color
) -> void:
	var t := tile_size
	var uv1 := base_uv + Vector2(0, t)
	var uv2 := base_uv + Vector2(0, 0)
	var uv3 := base_uv + Vector2(t, 0)
	var uv4 := base_uv + Vector2(t, t)

	pos.append(v1); nrm.append(normal); uvs.append(uv1); cols.append(color)
	pos.append(v2); nrm.append(normal); uvs.append(uv2); cols.append(color)
	pos.append(v3); nrm.append(normal); uvs.append(uv3); cols.append(color)

	pos.append(v1); nrm.append(normal); uvs.append(uv1); cols.append(color)
	pos.append(v3); nrm.append(normal); uvs.append(uv3); cols.append(color)
	pos.append(v4); nrm.append(normal); uvs.append(uv4); cols.append(color)


func init_mesh(sn: FastNoiseLite) -> void:
	if Config.version == 1:
		_init_mesh_v1(sn)
	elif Config.version == 2:
		_init_mesh_v2()
	elif Config.version == 3:
		_init_mesh_v3(sn)


func _init_mesh_v1(sn: FastNoiseLite) -> void:
	var cs = chunk_manager.chunk_size
	var h  = chunk_manager.max_height
	
	_chunk_data = PackedByteArray()
	_chunk_data.resize(cs * cs * h)

	var noise_scale_3d := 20
	var threshold := -0.05
	var height_bias_strength := 0.01

	for y in range(h):
		var y_t := float(y) / float(max(h - 1, 1))

		for z in range(cs):
			for x in range(cs):
				var idx = x + cs * (z + cs * y)

				if y == 0:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.COBBLESTONE_V1)
					continue

				var wx := float(chunk_offset.x + x)
				var wy := float(chunk_offset.y + y)
				var wz := float(chunk_offset.z + z)

				var n := sn.get_noise_3d(
					wx * noise_scale_3d,
					wy * noise_scale_3d,
					wz * noise_scale_3d
				)

				var bias := lerpf(height_bias_strength, -height_bias_strength, y_t)
				var v := n + bias

				_chunk_data[idx] = (
					int(BlockDefinitions.BlockType.COBBLESTONE_V1)
					if v > threshold
					else int(BlockDefinitions.BlockType.AIR)
				)

	_rebuild_sunlight_all()

	var top0 = max(h - 7, 0)
	for y in range(top0, h):
		for z in range(cs):
			var z_base = cs * (z + cs * y)
			for x in range(cs):
				var idx = z_base + x
				if _chunk_data[idx] == int(BlockDefinitions.BlockType.AIR):
					continue
				if _is_sunlit_top_face(x, y, z):
					_chunk_data[idx] = BlockDefinitions.BlockType.GRASS_V1


func _init_mesh_v2() -> void:
	var cs = chunk_manager.chunk_size
	var h  = chunk_manager.max_height

	_chunk_data = PackedByteArray()
	_chunk_data.resize(cs * cs * h)

	for y in range(h):
		for z in range(cs):
			for x in range(cs):
				var idx = x + cs * (z + cs * y)

				if y <= 42:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.COBBLESTONE_V1)
				elif y == 43:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.GRASS_V1)
				else:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.AIR)


	_rebuild_sunlight_all()


func _init_mesh_v3(sn: FastNoiseLite) -> void:
	var cs = chunk_manager.chunk_size
	var h  = chunk_manager.max_height
	_chunk_data = PackedByteArray()
	_chunk_data.resize(cs * cs * h)

	for z in range(cs):
		for x in range(cs):
			var wx := float(chunk_offset.x + x)
			var wz := float(chunk_offset.z + z)

			var n := sn.get_noise_2d(wx, wz)
			var height_y := clampi(int(round(((n + 1.0) * 0.5) * float(h - 1))), 0, h - 1)

			var c := sn.get_noise_2d(wx * 0.25, wz * 0.25) 
			var ridge = 1.0 - abs(c)                      
			var is_cliff = ridge > 0.72

			if is_cliff:
				var step := 0 + int(floor(((sn.get_noise_2d(wx * 0.07, wz * 0.07) + 1.0) * 0.5) * 4.0))

				height_y = clampi(int(round(float(height_y) / float(step))) * step, 0, h - 1)

				var bite := int(round(ridge * float(step)))
				if c > 0.0:
					height_y = clampi(height_y + bite, 0, h - 1)
				else:
					height_y = clampi(height_y - bite, 0, h - 1)


			for y in range(h):
				var idx = x + cs * (z + cs * y)

				if y > height_y:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.AIR)
				elif y == height_y:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.GRASS_V2)
				elif y >= height_y - 3:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.DIRT_V1)
				else:
					_chunk_data[idx] = int(BlockDefinitions.BlockType.STONE_V1)

	_rebuild_sunlight_all()


func _build_section_mesh(section_index: int) -> void:
	if Config.version >= 2:
		_build_section_mesh_v2(section_index)
	else:
		_build_section_mesh_v1(section_index)


func _build_section_mesh_v1(section_index: int) -> void:
	var cs: int = chunk_manager.chunk_size
	var h: int = chunk_manager.max_height
	var ox: int = chunk_offset.x
	var oy: int = chunk_offset.y
	var oz: int = chunk_offset.z
	var cs2: int = cs * cs

	var y0: int = section_index * SECTION_H
	var y1: int = min(y0 + SECTION_H, h)

	var positions := PackedVector3Array()
	var normals   := PackedVector3Array()
	var uvs       := PackedVector2Array()
	var colors    := PackedColorArray()

	var base_col = chunk_color
	base_col.a = 1.0
	var br = base_col.r
	var bg = base_col.g
	var bb = base_col.b

	var mesh := _section_meshes[section_index].mesh
	if mesh == null or not (mesh is ArrayMesh):
		mesh = ArrayMesh.new()

	var last_bt := -1
	var last_uvs: Array = []
	var uv_pos_z := Vector2.ZERO
	var uv_neg_z := Vector2.ZERO
	var uv_pos_x := Vector2.ZERO
	var uv_neg_x := Vector2.ZERO
	var uv_pos_y := Vector2.ZERO
	var uv_neg_y := Vector2.ZERO

	var mul_pos_z: float = float(FACE_SHADE[BlockDefinitions.Face.POS_Z])
	var mul_neg_z: float = float(FACE_SHADE[BlockDefinitions.Face.NEG_Z])
	var mul_pos_x: float = float(FACE_SHADE[BlockDefinitions.Face.POS_X])
	var mul_neg_x: float = float(FACE_SHADE[BlockDefinitions.Face.NEG_X])
	var mul_pos_y: float = float(FACE_SHADE[BlockDefinitions.Face.POS_Y])
	var mul_neg_y: float = float(FACE_SHADE[BlockDefinitions.Face.NEG_Y])

	var n_pos_z := Vector3(0, 0, 1)
	var n_neg_z := Vector3(0, 0, -1)
	var n_pos_x := Vector3(1, 0, 0)
	var n_neg_x := Vector3(-1, 0, 0)
	var n_pos_y := Vector3(0, 1, 0)
	var n_neg_y := Vector3(0, -1, 0)

	for y in range(y0, y1):
		var y_base := cs2 * y
		for z in range(cs):
			var z_base := y_base + cs * z
			for x in range(cs):
				var idx := z_base + x
				var bt := int(_chunk_data[idx])
				if bt == int(BlockDefinitions.BlockType.AIR):
					continue

				if bt != last_bt:
					last_bt = bt
					last_uvs = _get_uvs_for_block(bt)
					uv_pos_z = last_uvs[int(BlockDefinitions.Face.POS_Z)]
					uv_neg_z = last_uvs[int(BlockDefinitions.Face.NEG_Z)]
					uv_pos_x = last_uvs[int(BlockDefinitions.Face.POS_X)]
					uv_neg_x = last_uvs[int(BlockDefinitions.Face.NEG_X)]
					uv_pos_y = last_uvs[int(BlockDefinitions.Face.POS_Y)]
					uv_neg_y = last_uvs[int(BlockDefinitions.Face.NEG_Y)]

				var wx := ox + x
				var wy := oy + y
				var wz := oz + z

				var is_lit := (int(_sun_cutoff_y[x + cs * z]) == y)
				var sun := sun_bright if is_lit else sun_dim

				var m_pos_z := mul_pos_z * sun
				var m_neg_z := mul_neg_z * sun
				var m_pos_x := mul_pos_x * sun
				var m_neg_x := mul_neg_x * sun
				var m_pos_y := mul_pos_y * sun
				var m_neg_y := mul_neg_y * sun

				var col_pos_z := Color(br * m_pos_z, bg * m_pos_z, bb * m_pos_z, 1.0)
				var col_neg_z := Color(br * m_neg_z, bg * m_neg_z, bb * m_neg_z, 1.0)
				var col_pos_x := Color(br * m_pos_x, bg * m_pos_x, bb * m_pos_x, 1.0)
				var col_neg_x := Color(br * m_neg_x, bg * m_neg_x, bb * m_neg_x, 1.0)
				var col_pos_y := Color(br * m_pos_y, bg * m_pos_y, bb * m_pos_y, 1.0)
				var col_neg_y := Color(br * m_neg_y, bg * m_neg_y, bb * m_neg_y, 1.0)

				# POS_Z
				if z + 1 < cs:
					if int(_chunk_data[idx + cs]) == int(BlockDefinitions.BlockType.AIR):
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz + 1),
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx + 1, wy + 1, wz + 1),
							Vector3(wx + 1, wy, wz + 1),
							n_pos_z, uv_pos_z, col_pos_z)
				elif _border_is_air(wx, wy, wz + 1):
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx, wy, wz + 1),
						Vector3(wx, wy + 1, wz + 1),
						Vector3(wx + 1, wy + 1, wz + 1),
						Vector3(wx + 1, wy, wz + 1),
						n_pos_z, uv_pos_z, col_pos_z)

				# NEG_Z
				if z - 1 >= 0:
					if int(_chunk_data[idx - cs]) == int(BlockDefinitions.BlockType.AIR):
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx + 1, wy, wz),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx, wy + 1, wz),
							Vector3(wx, wy, wz),
							n_neg_z, uv_neg_z, col_neg_z)
				elif _border_is_air(wx, wy, wz - 1):
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx + 1, wy, wz),
						Vector3(wx + 1, wy + 1, wz),
						Vector3(wx, wy + 1, wz),
						Vector3(wx, wy, wz),
						n_neg_z, uv_neg_z, col_neg_z)

				# POS_X
				if x + 1 < cs:
					if int(_chunk_data[idx + 1]) == int(BlockDefinitions.BlockType.AIR):
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx + 1, wy, wz + 1),
							Vector3(wx + 1, wy + 1, wz + 1),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx + 1, wy, wz),
							n_pos_x, uv_pos_x, col_pos_x)
				elif _border_is_air(wx + 1, wy, wz):
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx + 1, wy, wz + 1),
						Vector3(wx + 1, wy + 1, wz + 1),
						Vector3(wx + 1, wy + 1, wz),
						Vector3(wx + 1, wy, wz),
						n_pos_x, uv_pos_x, col_pos_x)

				# NEG_X
				if x - 1 >= 0:
					if int(_chunk_data[idx - 1]) == int(BlockDefinitions.BlockType.AIR):
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz),
							Vector3(wx, wy + 1, wz),
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx, wy, wz + 1),
							n_neg_x, uv_neg_x, col_neg_x)
				elif _border_is_air(wx - 1, wy, wz):
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx, wy, wz),
						Vector3(wx, wy + 1, wz),
						Vector3(wx, wy + 1, wz + 1),
						Vector3(wx, wy, wz + 1),
						n_neg_x, uv_neg_x, col_neg_x)

				# NEG_Y
				if y - 1 >= 0:
					if int(_chunk_data[idx - cs2]) == int(BlockDefinitions.BlockType.AIR):
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz),
							Vector3(wx, wy, wz + 1),
							Vector3(wx + 1, wy, wz + 1),
							Vector3(wx + 1, wy, wz),
							n_neg_y, uv_neg_y, col_neg_y)
				else:
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx, wy, wz),
						Vector3(wx, wy, wz + 1),
						Vector3(wx + 1, wy, wz + 1),
						Vector3(wx + 1, wy, wz),
						n_neg_y, uv_neg_y, col_neg_y)

				# POS_Y
				if y + 1 < h:
					if int(_chunk_data[idx + cs2]) == int(BlockDefinitions.BlockType.AIR):
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx, wy + 1, wz),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx + 1, wy + 1, wz + 1),
							n_pos_y, uv_pos_y, col_pos_y)
				else:
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx, wy + 1, wz + 1),
						Vector3(wx, wy + 1, wz),
						Vector3(wx + 1, wy + 1, wz),
						Vector3(wx + 1, wy + 1, wz + 1),
						n_pos_y, uv_pos_y, col_pos_y)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors

	var am := mesh as ArrayMesh
	am.clear_surfaces()
	if positions.size() > 0:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_section_meshes[section_index].mesh = am


func _build_section_mesh_v2(section_index: int) -> void:
	var cs: int = chunk_manager.chunk_size
	var h: int = chunk_manager.max_height
	var ox: int = chunk_offset.x
	var oy: int = chunk_offset.y
	var oz: int = chunk_offset.z
	var cs2: int = cs * cs

	var y0: int = section_index * SECTION_H
	var y1: int = min(y0 + SECTION_H, h)

	var positions := PackedVector3Array()
	var normals   := PackedVector3Array()
	var uvs       := PackedVector2Array()
	var colors    := PackedColorArray()

	var base_col = chunk_color
	base_col.a = 1.0
	var br = base_col.r
	var bg = base_col.g
	var bb = base_col.b

	var mesh := _section_meshes[section_index].mesh
	if mesh == null or not (mesh is ArrayMesh):
		mesh = ArrayMesh.new()

	var last_bt := -1
	var last_uvs: Array = []
	var uv_pos_z := Vector2.ZERO
	var uv_neg_z := Vector2.ZERO
	var uv_pos_x := Vector2.ZERO
	var uv_neg_x := Vector2.ZERO
	var uv_pos_y := Vector2.ZERO
	var uv_neg_y := Vector2.ZERO

	var mul_pos_z: float = float(FACE_SHADE[BlockDefinitions.Face.POS_Z])
	var mul_neg_z: float = float(FACE_SHADE[BlockDefinitions.Face.NEG_Z])
	var mul_pos_x: float = float(FACE_SHADE[BlockDefinitions.Face.POS_X])
	var mul_neg_x: float = float(FACE_SHADE[BlockDefinitions.Face.NEG_X])
	var mul_pos_y: float = float(FACE_SHADE[BlockDefinitions.Face.POS_Y])
	var mul_neg_y: float = float(FACE_SHADE[BlockDefinitions.Face.NEG_Y])

	var n_pos_z := Vector3(0, 0, 1)
	var n_neg_z := Vector3(0, 0, -1)
	var n_pos_x := Vector3(1, 0, 0)
	var n_neg_x := Vector3(-1, 0, 0)
	var n_pos_y := Vector3(0, 1, 0)
	var n_neg_y := Vector3(0, -1, 0)

	for y in range(y0, y1):
		var y_base := cs2 * y

		for z in range(cs):
			var z_base := y_base + cs * z

			for x in range(cs):
				var idx := z_base + x
				var bt := int(_chunk_data[idx])
				if bt == int(BlockDefinitions.BlockType.AIR):
					continue

				if bt != last_bt:
					last_bt = bt
					last_uvs = _get_uvs_for_block(bt)
					uv_pos_z = last_uvs[int(BlockDefinitions.Face.POS_Z)]
					uv_neg_z = last_uvs[int(BlockDefinitions.Face.NEG_Z)]
					uv_pos_x = last_uvs[int(BlockDefinitions.Face.POS_X)]
					uv_neg_x = last_uvs[int(BlockDefinitions.Face.NEG_X)]
					uv_pos_y = last_uvs[int(BlockDefinitions.Face.POS_Y)]
					uv_neg_y = last_uvs[int(BlockDefinitions.Face.NEG_Y)]

				var wx := ox + x
				var wy := oy + y
				var wz := oz + z

				# ---------- POS_Z ----------
				if z + 1 < cs:
					if int(_chunk_data[idx + cs]) == int(BlockDefinitions.BlockType.AIR):
						var cutoff := int(_sun_cutoff_y[x + cs * (z + 1)])
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_pos_z * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz + 1),
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx + 1, wy + 1, wz + 1),
							Vector3(wx + 1, wy, wz + 1),
							n_pos_z, uv_pos_z, Color(br * m, bg * m, bb * m, 1.0))
				else:
					if _border_is_air(wx, wy, wz + 1):
						var cutoff = chunk_manager.get_sun_cutoff_for_world_column(wx, oz + cs)
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_pos_z * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz + 1),
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx + 1, wy + 1, wz + 1),
							Vector3(wx + 1, wy, wz + 1),
							n_pos_z, uv_pos_z, Color(br * m, bg * m, bb * m, 1.0))

				# ---------- NEG_Z ----------
				if z - 1 >= 0:
					if int(_chunk_data[idx - cs]) == int(BlockDefinitions.BlockType.AIR):
						var cutoff := int(_sun_cutoff_y[x + cs * (z - 1)])
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_neg_z * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx + 1, wy, wz),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx, wy + 1, wz),
							Vector3(wx, wy, wz),
							n_neg_z, uv_neg_z, Color(br * m, bg * m, bb * m, 1.0))
				else:
					if _border_is_air(wx, wy, wz - 1):
						var cutoff = chunk_manager.get_sun_cutoff_for_world_column(wx, oz - 1)
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_neg_z * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx + 1, wy, wz),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx, wy + 1, wz),
							Vector3(wx, wy, wz),
							n_neg_z, uv_neg_z, Color(br * m, bg * m, bb * m, 1.0))

				# ---------- POS_X ----------
				if x + 1 < cs:
					if int(_chunk_data[idx + 1]) == int(BlockDefinitions.BlockType.AIR):
						var cutoff := int(_sun_cutoff_y[(x + 1) + cs * z])
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_pos_x * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx + 1, wy, wz + 1),
							Vector3(wx + 1, wy + 1, wz + 1),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx + 1, wy, wz),
							n_pos_x, uv_pos_x, Color(br * m, bg * m, bb * m, 1.0))
				else:
					if _border_is_air(wx + 1, wy, wz):
						var cutoff = chunk_manager.get_sun_cutoff_for_world_column(ox + cs, wz)
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_pos_x * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx + 1, wy, wz + 1),
							Vector3(wx + 1, wy + 1, wz + 1),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx + 1, wy, wz),
							n_pos_x, uv_pos_x, Color(br * m, bg * m, bb * m, 1.0))

				# ---------- NEG_X ----------
				if x - 1 >= 0:
					if int(_chunk_data[idx - 1]) == int(BlockDefinitions.BlockType.AIR):
						var cutoff := int(_sun_cutoff_y[(x - 1) + cs * z])
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_neg_x * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz),
							Vector3(wx, wy + 1, wz),
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx, wy, wz + 1),
							n_neg_x, uv_neg_x, Color(br * m, bg * m, bb * m, 1.0))
				else:
					if _border_is_air(wx - 1, wy, wz):
						var cutoff = chunk_manager.get_sun_cutoff_for_world_column(ox - 1, wz)
						var sun := sun_bright if (cutoff == -1 or y > cutoff) else sun_dim
						var m := mul_neg_x * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz),
							Vector3(wx, wy + 1, wz),
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx, wy, wz + 1),
							n_neg_x, uv_neg_x, Color(br * m, bg * m, bb * m, 1.0))

				# ---------- NEG_Y ----------
				if y - 1 >= 0:
					if int(_chunk_data[idx - cs2]) == int(BlockDefinitions.BlockType.AIR):
						var cutoff := int(_sun_cutoff_y[x + cs * z])
						var ay := y - 1
						var sun := sun_bright if (cutoff == -1 or ay > cutoff) else sun_dim
						var m := mul_neg_y * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy, wz),
							Vector3(wx, wy, wz + 1),
							Vector3(wx + 1, wy, wz + 1),
							Vector3(wx + 1, wy, wz),
							n_neg_y, uv_neg_y, Color(br * m, bg * m, bb * m, 1.0))
				else:
					var m := mul_neg_y * sun_dim
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx, wy, wz),
						Vector3(wx, wy, wz + 1),
						Vector3(wx + 1, wy, wz + 1),
						Vector3(wx + 1, wy, wz),
						n_neg_y, uv_neg_y, Color(br * m, bg * m, bb * m, 1.0))

				# ---------- POS_Y ----------
				if y + 1 < h:
					if int(_chunk_data[idx + cs2]) == int(BlockDefinitions.BlockType.AIR):
						var cutoff := int(_sun_cutoff_y[x + cs * z])
						var ay := y + 1
						var sun := sun_bright if (cutoff == -1 or ay > cutoff) else sun_dim
						var m := mul_pos_y * sun
						_emit_quad(positions, normals, uvs, colors,
							Vector3(wx, wy + 1, wz + 1),
							Vector3(wx, wy + 1, wz),
							Vector3(wx + 1, wy + 1, wz),
							Vector3(wx + 1, wy + 1, wz + 1),
							n_pos_y, uv_pos_y, Color(br * m, bg * m, bb * m, 1.0))
				else:
					var m := mul_pos_y * sun_dim
					_emit_quad(positions, normals, uvs, colors,
						Vector3(wx, wy + 1, wz + 1),
						Vector3(wx, wy + 1, wz),
						Vector3(wx + 1, wy + 1, wz),
						Vector3(wx + 1, wy + 1, wz + 1),
						n_pos_y, uv_pos_y, Color(br * m, bg * m, bb * m, 1.0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors

	var am := mesh as ArrayMesh
	am.clear_surfaces()
	if positions.size() > 0:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_section_meshes[section_index].mesh = am


func check_block_selected(block_coords: Vector3i) -> bool:
	var local := _world_to_local(block_coords)

	if local.x < 0 or local.x >= chunk_manager.chunk_size \
	or local.y < 0 or local.y >= chunk_manager.max_height \
	or local.z < 0 or local.z >= chunk_manager.chunk_size:
		return false

	var cs = chunk_manager.chunk_size
	var idx = local.x + cs * (local.z + cs * local.y)
	return _chunk_data[idx] != BlockDefinitions.BlockType.AIR


func is_air(ix: int, iy: int, iz: int) -> bool:
	if ix >= 0 and ix < chunk_manager.chunk_size \
	and iy >= 0 and iy < chunk_manager.max_height \
	and iz >= 0 and iz < chunk_manager.chunk_size:
		return _is_air_local(ix, iy, iz)

	return chunk_manager.is_air_world(
		ix + chunk_offset.x,
		iy + chunk_offset.y,
		iz + chunk_offset.z
	)


func _idx(x: int, y: int, z: int) -> int:
	return x + chunk_manager.chunk_size * (z + chunk_manager.chunk_size * y)


func _is_air_local(x: int, y: int, z: int) -> bool:
	var cs = chunk_manager.chunk_size
	return _chunk_data[x + cs * (z + cs * y)] == int(BlockDefinitions.BlockType.AIR)


func _border_is_air(wx: int, wy: int, wz: int) -> bool:
	if chunk_manager.fast_build:
		return false
	return chunk_manager.is_air_world(wx, wy, wz)


func _section_of_y(y: int) -> int:
	return int(floor(float(y) / float(SECTION_H)))


func _rebuild_sections_around_y(y: int) -> void:
	var si := _section_of_y(y)
	if si < 0 or si >= _section_meshes.size():
		return

	_build_section_mesh(si)

	var y_in_section := y - si * SECTION_H

	if y_in_section == 0 and si - 1 >= 0:
		_build_section_mesh(si - 1)

	if y_in_section == SECTION_H - 1 and si + 1 < _section_meshes.size():
		_build_section_mesh(si + 1)


func _rebuild_sections_for_column(local_x: int, local_z: int) -> void:
	var cs: int = chunk_manager.chunk_size
	var h: int = chunk_manager.max_height

	for si in range(_section_meshes.size()):
		var y0: int = si * SECTION_H
		var y1: int = min(y0 + SECTION_H, h)

		var has_any := false
		for y in range(y0, y1):
			var idx := local_x + cs * (local_z + cs * y)
			if int(_chunk_data[idx]) != int(BlockDefinitions.BlockType.AIR):
				has_any = true
				break

		if has_any:
			_build_section_mesh(si)


func _recompute_cutoff_column(x: int, z: int) -> Array:
	var cs: int = chunk_manager.chunk_size
	var h: int = chunk_manager.max_height

	var i := _sun_idx(x, z)
	var old_cutoff := int(_sun_cutoff_y[i])

	var new_cutoff := -1
	for y in range(h - 1, -1, -1):
		var idx := x + cs * (z + cs * y)
		if _is_opaque_block(int(_chunk_data[idx])):
			new_cutoff = y
			break

	_sun_cutoff_y[i] = new_cutoff
	return [old_cutoff, new_cutoff]


func _rebuild_lighting_columns_if_needed(local_x: int, local_z: int, cutoff_changed: bool) -> void:
	if not cutoff_changed:
		return

	var cs = chunk_manager.chunk_size

	_rebuild_sections_for_column(local_x, local_z)

	if local_x > 0:       _rebuild_sections_for_column(local_x - 1, local_z)
	if local_x < cs - 1:  _rebuild_sections_for_column(local_x + 1, local_z)
	if local_z > 0:       _rebuild_sections_for_column(local_x, local_z - 1)
	if local_z < cs - 1:  _rebuild_sections_for_column(local_x, local_z + 1)


func _is_sunlit_top_face(x: int, y: int, z: int) -> bool:
	return int(_sun_cutoff_y[_sun_idx(x, z)]) == y


func delete_block(block_coords: Vector3i) -> void:
	var local := _world_to_local(block_coords)

	if local.x < 0 or local.x >= chunk_manager.chunk_size \
	or local.y < 0 or local.y >= chunk_manager.max_height \
	or local.z < 0 or local.z >= chunk_manager.chunk_size:
		chunk_manager.delete_block_world(block_coords)
		return

	var cs = chunk_manager.chunk_size
	var idx = local.x + cs * (local.z + cs * local.y)
	
	var bt_old := int(_chunk_data[idx])
	
	var was_lit := false
	if Config.version > 2 and bt_old != int(BlockDefinitions.BlockType.AIR):
		var cutoff := get_sun_cutoff_local(local.x, local.z)
		was_lit = cutoff != -1 and cutoff == local.y
	
	_chunk_data[idx] = int(BlockDefinitions.BlockType.AIR)
	
	if Config.version > 2 and bt_old != int(BlockDefinitions.BlockType.AIR):
		var tile_index := int(BlockDefinitions.BLOCK_TILES[bt_old][BlockDefinitions.Face.NEG_X])
		var pos := Vector3(block_coords.x + 0.5, block_coords.y + 0.5, block_coords.z + 0.5)
		chunk_manager.block_particles.spawn_break(pos, tile_index, was_lit)


	if Config.version >= 2:
		_recompute_cutoff_column(local.x, local.z)

	_rebuild_sections_around_y(local.y)

	if Config.version >= 2:
		chunk_manager.request_lighting_column(key, local.x, local.z)
		_enqueue_neighbor_border_lighting(local)

	_check_border(local)


func get_block(lx: int, wy: int, lz: int) -> int:
	var cs: int = chunk_manager.chunk_size
	var h: int = chunk_manager.max_height

	if lx < 0 or lx >= cs: return BlockDefinitions.BlockType.AIR
	if lz < 0 or lz >= cs: return BlockDefinitions.BlockType.AIR
	if wy < 0 or wy >= h:  return BlockDefinitions.BlockType.AIR

	var idx := lx + cs * (lz + cs * wy)
	return int(_chunk_data[idx])


func add_block(block_coords: Vector3i, block_type: BlockDefinitions.BlockType) -> void:
	var local := _world_to_local(block_coords)

	if local.x < 0 or local.x >= chunk_manager.chunk_size \
	or local.y < 0 or local.y >= chunk_manager.max_height \
	or local.z < 0 or local.z >= chunk_manager.chunk_size:
		chunk_manager.add_block_world(block_coords)
		return

	var cs = chunk_manager.chunk_size
	var idx = local.x + cs * (local.z + cs * local.y)

	if Config.version == 2:
		_chunk_data[idx] = int(BlockDefinitions.BlockType.GRASS_V1) if block_coords.y == 43 else int(BlockDefinitions.BlockType.COBBLESTONE_V1)
	else:
		_chunk_data[idx] = int(block_type)

	if Config.version >= 2:
		_recompute_cutoff_column(local.x, local.z)

	_rebuild_sections_around_y(local.y)

	if Config.version >= 2:
		chunk_manager.request_lighting_column(key, local.x, local.z)
		_enqueue_neighbor_border_lighting(local)

	_check_border(local)


func build_section(si: int) -> void:
	_build_section_mesh(si)


func serialize() -> PackedByteArray:
	return _chunk_data


func deserialize(data: PackedByteArray) -> void:
	var cs: int = chunk_manager.chunk_size
	var h: int = chunk_manager.max_height
	var want := cs * cs * h

	if data.size() == want:
		_chunk_data = data
	else:
		_chunk_data = PackedByteArray()
		_chunk_data.resize(want)

		var n = min(data.size(), want)
		for i in range(n):
			_chunk_data[i] = data[i]

		for i in range(n, want):
			_chunk_data[i] = int(BlockDefinitions.BlockType.AIR)

	_rebuild_sunlight_all()


func get_sun_cutoff_local(x: int, z: int) -> int:
	return int(_sun_cutoff_y[_sun_idx(x, z)])


func process_lighting_job(local_x: int, local_z: int) -> void:
	var res := _recompute_cutoff_column(local_x, local_z)
	var old_cutoff: int = res[0]
	var new_cutoff: int = res[1]

	if new_cutoff == old_cutoff:
		var sc := _section_meshes.size()
		for si in range(sc):
			chunk_manager.request_section(key, si)
		return

	var lo = min(old_cutoff, new_cutoff)
	var hi = max(old_cutoff, new_cutoff)
	var y0 = lo + 1
	var y1 = hi

	_enqueue_lighting_sections(local_x, local_z, y0, y1)


func _enqueue_lighting_sections(local_x: int, local_z: int, y0: int, y1: int) -> void:
	if y1 < y0:
		return

	var cs = chunk_manager.chunk_size
	var h = chunk_manager.max_height

	y0 = clampi(y0, 0, h - 1)
	y1 = clampi(y1, 0, h - 1)

	var si0 := int(floor(float(y0) / float(SECTION_H)))
	var si1 := int(floor(float(y1) / float(SECTION_H)))

	for si in range(si0, si1 + 1):
		chunk_manager.request_section(key, si)

	if local_x > 0:      for si in range(si0, si1 + 1): chunk_manager.request_section(key, si)
	if local_x < cs - 1: for si in range(si0, si1 + 1): chunk_manager.request_section(key, si)
	if local_z > 0:      for si in range(si0, si1 + 1): chunk_manager.request_section(key, si)
	if local_z < cs - 1: for si in range(si0, si1 + 1): chunk_manager.request_section(key, si)


func _enqueue_neighbor_border_lighting(local: Vector3i) -> void:
	var cs = chunk_manager.chunk_size

	if local.x == 0:
		chunk_manager.request_lighting_column(key + Vector2i(-1, 0), cs - 1, local.z)
	elif local.x == cs - 1:
		chunk_manager.request_lighting_column(key + Vector2i(1, 0), 0, local.z)

	if local.z == 0:
		chunk_manager.request_lighting_column(key + Vector2i(0, -1), local.x, cs - 1)
	elif local.z == cs - 1:
		chunk_manager.request_lighting_column(key + Vector2i(0, 1), local.x, 0)


func set_block_local(lx: int, wy: int, lz: int, block_id: int) -> void:
	var cs: int = chunk_manager.chunk_size
	if lx < 0 or lx >= cs: return
	if lz < 0 or lz >= cs: return
	if wy < 0 or wy >= chunk_manager.max_height: return

	var idx := lx + cs * (lz + cs * wy)
	_chunk_data[idx] = block_id
