extends Node3D

@onready var chunk: MeshInstance3D = $chunk
@onready var logo = preload("res://icon.svg")

@export var chunk_size = 128

var _triangles = 0

enum Face {
	POS_X,
	NEG_X,
	POS_Y,
	NEG_Y,
	POS_Z,
	NEG_Z
}

enum BlockType {
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
	_build_mesh()
	
	
func _process(delta: float) -> void:
	$FPSLabel.text = "FPS : " + str(Engine.get_frames_per_second())
	$TrianglesLabel.text = "Triangles : " + str(_triangles)
	
	
func _add_cube(st: SurfaceTool, _position: Vector3, size: int, color: Color, block_type: BlockType) -> void:
	
	# positive Z
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
	
	
	
func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# First big cube
	#for x in range(-32, 32):
		#for z in range(-32, 32):
			#for y in range(-32, 32):
				#var c := Color((x+32)/64.0, (y+32)/64.0, (z+32)/64.0)
				#_add_cube(st, Vector3(x, y, z), 1, c)
				
	# Logo Terrain
	#var heightmap := logo.get_image()
	#var size = heightmap.get_size().x
	#for x in range(size):
		#for z in range(size):
			#var c := heightmap.get_pixel(x, z)
			#var y = snapped(heightmap.get_pixel(x, z).r * 10, 1)
			#for _y in range(y):
				#_add_cube(st, Vector3(x-size/2, _y, z-size/2), 1, c)
				
	# Perlin Noise Terrain
	var sn = FastNoiseLite.new()
	sn.noise_type = FastNoiseLite.TYPE_PERLIN
	sn.seed = 20140114
	
	for x in range(-chunk_size / 2, chunk_size / 2):
		for z in range(-chunk_size / 2, chunk_size / 2):
			var y = snapped(sn.get_noise_2d(x, z) * chunk_size / 2, 1)
			for _y in range(-chunk_size / 2, y):
				if _y == y -1:
					if _y > 0:
						_add_cube(st, Vector3(x, _y, z), 1, Color.WHITE, BlockType.STONE)
					else:
						_add_cube(st, Vector3(x, _y, z), 1, Color.WHITE, BlockType.GRASS)
				else:
					_add_cube(st, Vector3(x, _y, z), 1, Color.WHITE, BlockType.DIRT)
					
	
	chunk.mesh = st.commit()
	_build_collider(chunk.mesh)
	
	

func _build_collider(mesh: ArrayMesh) -> void:
	var body := StaticBody3D.new()
	var shape := mesh.create_trimesh_shape()
	
	var col := CollisionShape3D.new()
	col.shape = shape
	
	body.add_child(col)
	add_child(body)
