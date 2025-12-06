extends MeshInstance3D


@export var chunk_size := 32
@export var max_height := 32
@export var noise_scale := 3

var _triangles = 0
var _chunk_data = []

enum Face {
	POS_X,
	NEG_X,
	POS_Y,
	NEG_Y,
	POS_Z,
	NEG_Z
}

enum BlockType {
	AIR,
	GRASS,
	DIRT,
	STONE
}

const BLOCK_TILES := {
	BlockType.GRASS: {
		Face.POS_Y: 3,
		Face.NEG_Y: 1,
		Face.POS_Z: 0,
		Face.NEG_Z: 0,
		Face.POS_X: 0,
		Face.NEG_X: 0
	},
	
	BlockType.DIRT: {
		Face.POS_Y: 1,
		Face.NEG_Y: 1,
		Face.POS_Z: 1,
		Face.NEG_Z: 1,
		Face.POS_X: 1,
		Face.NEG_X: 1
	},
	
	BlockType.STONE: {
		Face.POS_Y: 2,
		Face.NEG_Y: 2,
		Face.POS_Z: 2,
		Face.NEG_Z: 2,
		Face.POS_X: 2,
		Face.NEG_X: 2
	}
}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_mesh()
	_build_mesh()
	

func _add_cube(st: SurfaceTool, _position: Vector3, size: int, color: Color, block_type: BlockType) -> void:
	var x := int(_position.x)
	var y := int(_position.y)
	var z := int(_position.z)
	
	# positive Z
	if _is_air(x, y, z + 1):
		_add_face(
			st,
			_position + Vector3(-0.5, -0.5, 0.5) * size,
			_position + Vector3(-0.5, 0.5, 0.5) * size,
			_position + Vector3(0.5, 0.5, 0.5) * size,
			_position + Vector3(0.5, -0.5, 0.5) * size,
			Vector3(0, 0, 1),
			color,
			block_type,
			Face.POS_Z
		)
	
	# positive X
	if _is_air(x + 1, y, z):
		_add_face(
			st,
			_position + Vector3(0.5, -0.5, 0.5) * size,
			_position + Vector3(0.5, 0.5, 0.5) * size,
			_position + Vector3(0.5, 0.5, -0.5) * size,
			_position + Vector3(0.5, -0.5, -0.5) * size,
			Vector3(1, 0, 0),
			color,
			block_type,
			Face.POS_X
		)
	
	# negative Z
	if _is_air(x, y, z - 1):
		_add_face(
			st,
			_position + Vector3(0.5, -0.5, -0.5) * size,
			_position + Vector3(0.5, 0.5, -0.5) * size,
			_position + Vector3(-0.5, 0.5, -0.5) * size,
			_position + Vector3(-0.5, -0.5, -0.5) * size,
			Vector3(0, 0, -1),
			color,
			block_type,
			Face.NEG_Z
		)
	
	# negative X
	if _is_air(x - 1, y, z):
		_add_face(
			st,
			_position + Vector3(-0.5, -0.5, -0.5) * size,
			_position + Vector3(-0.5, 0.5, -0.5) * size,
			_position + Vector3(-0.5, 0.5, 0.5) * size,
			_position + Vector3(-0.5, -0.5, 0.5) * size,
			Vector3(-1, 0, 0),
			color,
			block_type,
			Face.NEG_X
		)
	
	# negative Y
	if _is_air(x, y - 1, z):
		_add_face(
			st,
			_position + Vector3(-0.5, -0.5, -0.5) * size,
			_position + Vector3(-0.5, -0.5, 0.5) * size,
			_position + Vector3(0.5, -0.5, 0.5) * size,
			_position + Vector3(0.5, -0.5, -0.5) * size,
			Vector3(0, -1, 0),
			color,
			block_type,
			Face.NEG_Y
		)
	
	# positive Y
	if _is_air(x, y + 1, z):
		_add_face(
			st,
			_position + Vector3(-0.5, 0.5, 0.5) * size,
			_position + Vector3(-0.5, 0.5, -0.5) * size,
			_position + Vector3(0.5, 0.5, -0.5) * size,
			_position + Vector3(0.5, 0.5, 0.5) * size,
			Vector3(0, 1, 0),
			color,
			block_type,
			Face.POS_Y
		)
	
	
func _is_air(ix: int, iy: int, iz: int) -> bool:
	
	if ix < 0 or ix >= chunk_size:
		return true
	if iy < 0 or iy >= chunk_size:
		return true
	if iz < 0 or iz >= chunk_size:
		return true
	
	return _chunk_data[ix][iz][iy] == BlockType.AIR
	

	
func _add_face(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, normal: Vector3, color: Color, block_type: BlockType, face: Face) -> void:
	st.set_normal(normal)
	st.set_color(color)
	
	# determine uv coordinates based on block type
	var tile_index = BLOCK_TILES[block_type][face]
	var tiles_per_row := 2
	var tile_size := 1.0 / tiles_per_row
	var col = tile_index % tiles_per_row
	var row = tile_index / tiles_per_row
	var base_uv := Vector2(col * tile_size, row * tile_size)
	
	st.set_uv(base_uv + Vector2(0, tile_size))
	st.add_vertex(v1)
	
	st.set_uv(base_uv + Vector2(0, 0))
	st.add_vertex(v2)
	
	st.set_uv(base_uv + Vector2(tile_size, 0))
	st.add_vertex(v3)
	
	st.set_uv(base_uv + Vector2(0, tile_size))
	st.add_vertex(v1)
	
	st.set_uv(base_uv + Vector2(tile_size, 0))
	st.add_vertex(v3)
	
	st.set_uv(base_uv + Vector2(tile_size, tile_size))
	st.add_vertex(v4)
	
	_triangles += 6
	

func _init_mesh() -> void:
	# Perlin Noise Terrain
	var sn = FastNoiseLite.new()
	sn.noise_type = FastNoiseLite.TYPE_PERLIN
	sn.seed = 20140114
	
	for x in range(chunk_size):
		_chunk_data.append([])
		for z in range(chunk_size):
			_chunk_data[x].append([])
			
			var xf = x * noise_scale
			var zf = z * noise_scale
			
			var height = snapped((sn.get_noise_2d(xf, zf) + 1) * 0.5 * max_height, 1)

			for y in range(chunk_size):
				if y > height:
					_chunk_data[x][z].append(BlockType.AIR)
				elif y == height:
					if y > 15:
						_chunk_data[x][z].append(BlockType.STONE)
					else:
						_chunk_data[x][z].append(BlockType.GRASS)
				else:
					_chunk_data[x][z].append(BlockType.DIRT)
	
	
	
func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_triangles = 0
				
	for x in range(chunk_size):
		for z in range(chunk_size):
			for y in range(chunk_size):
				if _chunk_data[x][z][y] != BlockType.AIR:
					_add_cube(st, Vector3(x, y, z), 1, Color.WHITE, _chunk_data[x][z][y])
					
	
	mesh = st.commit()
	await get_tree().process_frame
	_build_collider()
	
	

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
	
	
func get_hit_block(point: Vector3, normal: Vector3) -> Vector3i:
	return Vector3i(
		roundi(point.x - normal.x * 0.5),
		roundi(point.y - normal.y * 0.5),
		roundi(point.z - normal.z * 0.5)
	)
	

func get_adjacent_block(point: Vector3, normal: Vector3) -> Vector3i:
	return Vector3i(
		roundi(point.x + normal.x * 0.5),
		roundi(point.y + normal.y * 0.5),
		roundi(point.z + normal.z * 0.5)
	)


func delete_block(block_coords: Vector3i) -> void:
	_chunk_data[block_coords.x][block_coords.z][block_coords.y] = BlockType.AIR
	_build_mesh()
	
	
func add_block(block_coords: Vector3i) -> void:
	# Check block is in chunk
	if block_coords.x < 0 or block_coords.x >= chunk_size: return
	if block_coords.y < 0 or block_coords.y >= chunk_size: return
	if block_coords.z < 0 or block_coords.z >= chunk_size: return
	
	_chunk_data[block_coords.x][block_coords.z][block_coords.y] = BlockType.DIRT
	
	_build_mesh()
