extends Node

@export var chunk_size := 16
@export var max_height := 64         
@export var world_size := 16
@export var section_budget_ms := 6.0
@export var max_sections_per_frame := 1
@export var lighting_budget_ms := 2.0
@export var max_lighting_jobs_per_frame := 2
@onready var chunk_scene = preload("res://scenes/chunk.tscn")
@onready var fog_mat: ShaderMaterial = preload("res://assets/chunk.tres")
@onready var block_particles: BlockParticles = $BlockParticles

var _chunks: Dictionary = {}          
var _pending_sections: Array = []
var _queued_sections: Dictionary = {}
var _pending_i := 0
var fast_build := true
var _pending_lighting: Array = []
var _queued_lighting: Dictionary = {}
var _pending_light_i := 0

var tiles_per_row: int = 3
var tile_size := 1.0 / tiles_per_row


func _ready() -> void:
	var sn = FastNoiseLite.new()
	sn.noise_type = FastNoiseLite.TYPE_PERLIN
	sn.seed = Config.seed
	sn.frequency = 0.003
	
	fog_mat.set_shader_parameter("darken_max", 0.5 if Config.version > 2 else 1.0)
	fog_mat.set_shader_parameter("version", Config.version)
	block_particles.setup(self, preload("res://assets/blocks.png"), tiles_per_row)

	var saved_world := load_world() if Config.load_from_save else {}
	var has_save := saved_world.size() > 0

	var center := Vector2i(0, 0)
	var half := int(world_size / 2)
	var min_x := center.x - half
	var max_x := center.x + half - 1
	var min_z := center.y - half
	var max_z := center.y + half - 1
	var radius := half

	for r in range(0, radius + 1):
		var keys := _build_ring_window(center, r, min_x, max_x, min_z, max_z)
		for key in keys:
			if _chunks.has(key):
				continue

			var chunk = chunk_scene.instantiate()
			add_child(chunk)

			chunk.key = key
			chunk.chunk_offset = Vector3i(key.x * chunk_size, 0, key.y * chunk_size)
			chunk.chunk_manager = self
			chunk.tiles_per_row = tiles_per_row
			chunk.tile_size = tile_size
			
			if has_save and saved_world.has(key):
				chunk.deserialize(saved_world[key])
			else:
				chunk.init_mesh(sn)

			_register_chunk(chunk, key)

	for chunk in _chunks.values():
		_request_chunk_sections(chunk.key)

	fast_build = false


func _process(_delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var built := 0

	while built < max_sections_per_frame and _pending_i < _pending_sections.size():
		var elapsed_ms := float(Time.get_ticks_usec() - t0) * 0.001
		if elapsed_ms >= section_budget_ms:
			break

		var job = _pending_sections[_pending_i]
		_pending_i += 1

		var key: Vector2i = job["key"]
		var si: int = job["si"]
		_queued_sections.erase(_sec_id(key, si))

		if _chunks.has(key):
			_chunks[key].build_section(si)

		built += 1

	if _pending_i >= _pending_sections.size():
		_pending_sections.clear()
		_pending_i = 0
		

	var lt0 := Time.get_ticks_usec()
	var done := 0

	while done < max_lighting_jobs_per_frame and _pending_light_i < _pending_lighting.size():
		var elapsed_ms := float(Time.get_ticks_usec() - lt0) * 0.001
		if elapsed_ms >= lighting_budget_ms:
			break

		var job = _pending_lighting[_pending_light_i]
		_pending_light_i += 1

		var key: Vector2i = job["key"]
		var lx: int = job["x"]
		var lz: int = job["z"]
		_queued_lighting.erase(_light_id(key, lx, lz))

		if _chunks.has(key):
			_chunks[key].process_lighting_job(lx, lz)

		done += 1

	if _pending_light_i >= _pending_lighting.size():
		_pending_lighting.clear()
		_pending_light_i = 0


func _sec_id(key: Vector2i, si: int) -> String:
	return str(key.x) + "," + str(key.y) + "," + str(si)


func _section_count() -> int:
	return int(ceil(float(max_height) / 16.0))


func _light_id(key: Vector2i, lx: int, lz: int) -> String:
	return str(key.x) + "," + str(key.y) + "," + str(lx) + "," + str(lz)


func request_lighting_column(key: Vector2i, lx: int, lz: int) -> void:
	if not _chunks.has(key):
		return
	var id := _light_id(key, lx, lz)
	if _queued_lighting.has(id):
		return
	_queued_lighting[id] = true
	_pending_lighting.append({"key": key, "x": lx, "z": lz})


func request_section(key: Vector2i, si: int) -> void:
	var id := _sec_id(key, si)
	if _queued_sections.has(id):
		return
	_queued_sections[id] = true
	_pending_sections.insert(_pending_i, {"key": key, "si": si})


func _request_chunk_sections(key: Vector2i) -> void:
	var sc := _section_count()
	for si in range(sc):
		var id := _sec_id(key, si)
		if _queued_sections.has(id):
			continue
		_queued_sections[id] = true
		_pending_sections.append({"key": key, "si": si})


func _build_ring_window(center: Vector2i, r: int, min_x: int, max_x: int, min_z: int, max_z: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	if r == 0:
		if center.x >= min_x and center.x <= max_x and center.y >= min_z and center.y <= max_z:
			out.append(center)
		return out

	var cx := center.x
	var cz := center.y

	for x in range(cx - r, cx + r + 1):
		var z_top := cz - r
		if x >= min_x and x <= max_x and z_top >= min_z and z_top <= max_z:
			out.append(Vector2i(x, z_top))

		var z_bottom := cz + r
		if x >= min_x and x <= max_x and z_bottom >= min_z and z_bottom <= max_z:
			out.append(Vector2i(x, z_bottom))

	for z in range(cz - r + 1, cz + r):
		var x_left := cx - r
		if x_left >= min_x and x_left <= max_x and z >= min_z and z <= max_z:
			out.append(Vector2i(x_left, z))

		var x_right := cx + r
		if x_right >= min_x and x_right <= max_x and z >= min_z and z <= max_z:
			out.append(Vector2i(x_right, z))

	return out
	
	
func _register_chunk(chunk, key) -> void:
	_chunks[key] = chunk
	chunk.border_update_requested.connect(_on_border_update_requested)


func _on_border_update_requested(neighbor_key: Vector2i, y: int) -> void:
	if _chunks.has(neighbor_key):
		_chunks[neighbor_key]._rebuild_sections_around_y(y)


func get_sun_cutoff_for_world_column(wx: int, wz: int) -> int:
	var cx := _floor_div(wx, chunk_size)
	var cz := _floor_div(wz, chunk_size)
	var key := Vector2i(cx, cz)

	if not _chunks.has(key):
		return -1

	var lx := wx - cx * chunk_size
	var lz := wz - cz * chunk_size
	return _chunks[key].get_sun_cutoff_local(lx, lz)


func _floor_div(a: int, b: int) -> int:
	return int(floor(float(a) / float(b)))


func is_air_world(wx: int, wy: int, wz: int) -> bool:
	if wy < 0 or wy >= max_height:
		return true

	var cx := _floor_div(wx, chunk_size)
	var cz := _floor_div(wz, chunk_size)
	var key := Vector2i(cx, cz)

	if not _chunks.has(key):
		return true

	var chunk = _chunks[key]

	var lx := wx - cx * chunk_size
	var lz := wz - cz * chunk_size

	return chunk.is_air(lx, wy, lz)


func add_block_world(world_coords: Vector3i, block_type: BlockDefinitions.BlockType) -> void:
	var wx := world_coords.x
	var wy := world_coords.y
	var wz := world_coords.z

	if wy < 0 or wy >= max_height:
		return

	var half := int(world_size / 2)
	var min_x := -half * chunk_size
	var max_x := (half * chunk_size) - 1
	var min_z := -half * chunk_size
	var max_z := (half * chunk_size) - 1

	if wx < min_x or wx > max_x:
		return
	if wz < min_z or wz > max_z:
		return

	var cx := floori(float(wx) / chunk_size)
	var cz := floori(float(wz) / chunk_size)
	var key := Vector2i(cx, cz)

	if _chunks.has(key):
		_chunks[key].add_block(world_coords, block_type)


func delete_block_world(world_coords: Vector3i) -> void:
	var wx := world_coords.x
	var wy := world_coords.y
	var wz := world_coords.z

	if wy < 0 or wy >= max_height:
		return

	var half := int(world_size / 2)
	var min_x := -half * chunk_size
	var max_x := (half * chunk_size) - 1
	var min_z := -half * chunk_size
	var max_z := (half * chunk_size) - 1

	if wx < min_x or wx > max_x:
		return
	if wz < min_z or wz > max_z:
		return

	var cx := _floor_div(wx, chunk_size)
	var cz := _floor_div(wz, chunk_size)
	var key := Vector2i(cx, cz)

	if _chunks.has(key):
		_chunks[key].delete_block(world_coords)


func get_block_world(wx: int, wy: int, wz: int) -> int:
	if wy < 0 or wy >= max_height:
		return BlockDefinitions.BlockType.AIR

	var cx := _floor_div(wx, chunk_size)
	var cz := _floor_div(wz, chunk_size)
	var key := Vector2i(cx, cz)

	if not _chunks.has(key):
		return BlockDefinitions.BlockType.AIR

	var lx := wx - cx * chunk_size
	var lz := wz - cz * chunk_size

	return _chunks[key].get_block(lx, wy, lz)


func save_world() -> void:
	if Config.version == 1:
		return
		
	var world := {}

	for key in _chunks.keys():
		var chunk = _chunks[key]
		world[key] = chunk.serialize()

	var file := FileAccess.open("user://world_" + str(Config.version) + ".save", FileAccess.WRITE)
	if file == null:
		push_error("Failed to save world")
		return

	file.store_var(world)
	file.close()


func load_world() -> Dictionary:
	if Config.version == 1:
		return {}
		
	if not FileAccess.file_exists("user://world_" + str(Config.version) + ".save"):
		return {}

	var file := FileAccess.open("user://world_" + str(Config.version) + ".save", FileAccess.READ)
	if file == null:
		push_error("Failed to load world")
		return {}

	var world = file.get_var()
	file.close()

	return world
