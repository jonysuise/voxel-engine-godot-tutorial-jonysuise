extends Node
class_name WorldTick

const TICK_HZ := 20.0
const TICK_DT := 1.0 / TICK_HZ

@export var grass_samples_per_tick := 1000

@onready var chunk_manager := get_parent()

var _accum := 0.0
var _tick_id := 0
var _rng := RandomNumberGenerator.new()
var _rebuild_queue: Array = []



func _ready() -> void:
	_rng.randomize()


func _process(dt: float) -> void:
	if Config.version <= 2:
		pass

	_accum += dt
	while _accum >= TICK_DT:
		_accum -= TICK_DT
		_tick_id += 1
		_do_tick()


func _do_tick() -> void:
	var cs: int = chunk_manager.chunk_size
	var half := int(chunk_manager.world_size / 2)

	var min_x := -half * cs
	var max_x := (half * cs) - 1
	var min_z := -half * cs
	var max_z := (half * cs) - 1

	var dirty: Dictionary = {}

	for i in range(grass_samples_per_tick):
		var wx := _rng.randi_range(min_x, max_x)
		var wz := _rng.randi_range(min_z, max_z)
		var wy := _rng.randi_range(0, chunk_manager.max_height - 1)

		var id = chunk_manager.get_block_world(wx, wy, wz)
		if id != BlockDefinitions.BlockType.GRASS_V2:
			continue

		var sun_cutoff = chunk_manager.get_sun_cutoff_for_world_column(wx, wz)
		if sun_cutoff == -1:
			continue
		var grass_lit = (wy >= sun_cutoff)

		if not grass_lit:
			_apply_world_set_and_dirty(wx, wy, wz, BlockDefinitions.BlockType.DIRT_V1, cs, dirty)
			continue

		var tx := _rng.randi_range(wx - 1, wx + 1)
		var tz := _rng.randi_range(wz - 1, wz + 1)
		var ty := _rng.randi_range(wy - 1, wy + 3)

		if chunk_manager.get_block_world(tx, ty, tz) != BlockDefinitions.BlockType.DIRT_V1:
			continue

		var target_cutoff = chunk_manager.get_sun_cutoff_for_world_column(tx, tz)
		if target_cutoff == -1:
			continue
		var target_lit = (ty >= target_cutoff)
		if not target_lit:
			continue

		_apply_world_set_and_dirty(tx, ty, tz, BlockDefinitions.BlockType.GRASS_V2, cs, dirty)

	for key in dirty.keys():
		for si in dirty[key].keys():
			_rebuild_queue.append({"key": key, "si": int(si)})

	var max_rebuilds_now := 3
	for n in range(max_rebuilds_now):
		if _rebuild_queue.is_empty():
			break
		var job = _rebuild_queue.pop_front()
		chunk_manager.request_section(job["key"], job["si"])


func _apply_world_set_and_dirty(wx:int, wy:int, wz:int, new_id:int, cs:int, dirty:Dictionary) -> void:
	var cx = chunk_manager._floor_div(wx, cs)
	var cz = chunk_manager._floor_div(wz, cs)
	var key := Vector2i(cx, cz)
	if not chunk_manager._chunks.has(key):
		return

	var lx = wx - cx * cs
	var lz = wz - cz * cs
	var si := int(wy / 16)

	var chunk = chunk_manager._chunks[key]
	chunk.set_block_local(lx, wy, lz, new_id)

	_mark_dirty(dirty, key, si)

	if lx == 0:
		_mark_dirty(dirty, Vector2i(cx - 1, cz), si)
	elif lx == cs - 1: 
		_mark_dirty(dirty, Vector2i(cx + 1, cz), si)

	if lz == 0:
		_mark_dirty(dirty, Vector2i(cx, cz - 1), si)
	elif lz == cs - 1:
		_mark_dirty(dirty, Vector2i(cx, cz + 1), si)
	
	if wy % 16 == 0:
		_mark_dirty(dirty, key, si - 1)
	elif wy % 16 == 15: 
		_mark_dirty(dirty, key, si + 1)


func _mark_dirty(dirty: Dictionary, key: Vector2i, si: int) -> void:
	if not chunk_manager._chunks.has(key):
		return

	if not dirty.has(key):
		dirty[key] = {}
	dirty[key][si] = true
