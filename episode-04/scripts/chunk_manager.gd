extends Node


@export var chunk_size := 16
@export var max_height := 16
@export var noise_scale := 3
@export var world_size := 128

@onready var chunk_scene = preload("res://scenes/chunk.tscn")

var _chunk_triangles: Dictionary = {} # key: Vector2i(chunk_x, chunk_z) -> int
var _chunks: Dictionary = {} # key: Vector2i(chunk_x, chunk_z) -> int
var triangles_total: int
var load_time := 0.0 # seconds

func _ready() -> void:
	var sn = FastNoiseLite.new()
	sn.noise_type = FastNoiseLite.TYPE_PERLIN
	sn.seed = 20140114
	
	
	var t0 := Time.get_ticks_usec()
	for x in range(world_size):
		for z in range(world_size):
			var key := Vector2i(x, z)
			
			var chunk = chunk_scene.instantiate()
			add_child(chunk)

			chunk.key = key
			chunk.chunk_offset = Vector3(x * chunk_size, 0, z * chunk_size)
			chunk.chunk_manager = self
			
			chunk.init_mesh(sn)
			_register_chunk(chunk, key)
			
	for chunk in _chunks.values():
		await get_tree().process_frame
		load_time = (Time.get_ticks_usec() - t0) / 1000000.0
		chunk.build_mesh()
			
	load_time = (Time.get_ticks_usec() - t0) / 1000000.0


func _register_chunk(chunk, key) -> void:
	_chunks[key] = chunk
	
	chunk.mesh_updated.connect(_on_chunk_mesh_updated)
	chunk.border_update_requested.connect(_on_border_update_requested)


func is_air_world(wx: int, wy: int, wz: int) -> bool:
	# treat vertical outside as air
	if wy < 0 or wy >= chunk_size:
		return true

	var cx := floori(float(wx) / chunk_size)
	var cz := floori(float(wz) / chunk_size)
	var key := Vector2i(cx, cz)


	if not _chunks.has(key):
		return true # missing chunk = air

	var chunk = _chunks[key]

	var lx := wx - cx * chunk_size
	var lz := wz - cz * chunk_size

	return chunk.is_air(lx, wy, lz)


func _on_chunk_mesh_updated(chunk, triangles) -> void:
	var key = chunk.key
	var old := 0
	
	if _chunk_triangles.has(key):
		old = _chunk_triangles[key]
		
	_chunk_triangles[key] = triangles
	triangles_total += triangles - old


func _on_border_update_requested(neighbor_key: Vector2i) -> void:
	print("has neighbour")
	if _chunks.has(neighbor_key):
		_chunks[neighbor_key].build_mesh()


func add_block_world(world_coords: Vector3i) -> void:
	var wx = world_coords.x
	var wy = world_coords.y
	var wz = world_coords.z
	
	if wx < 0 or wy < 0 or wz < 0 or wx >= chunk_size * world_size or wy >= chunk_size or wz >= chunk_size * world_size:
		return
		
	# check chunk coordinates
	var cx = wx / chunk_size
	var cz = wz / chunk_size
	var key := Vector2i(cx, cz)
	
	if _chunks.has(key):
		_chunks[key].add_block(world_coords)


func delete_block_world(world_coords: Vector3i) -> void:
	var wx = world_coords.x
	var wy = world_coords.y
	var wz = world_coords.z
	
	if wx < 0 or wy < 0 or wz < 0 or wx >= chunk_size * world_size or wy >= chunk_size or wz >= chunk_size * world_size:
		return
		
	# check chunk coordinates
	var cx = wx / chunk_size
	var cz = wz / chunk_size
	var key := Vector2i(cx, cz)
	
	if _chunks.has(key):
		_chunks[key].delete_block(world_coords)
