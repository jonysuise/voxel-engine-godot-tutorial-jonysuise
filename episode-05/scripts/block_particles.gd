extends Node3D
class_name BlockParticles

const MAX_PARTICLES := 256         
const BREAK_COUNT := 64             
const LIFE := 0.65                  
const GRAVITY := -12.0
const RADIUS := 0.06                
const BOUNCE := 0.5                
const GROUND_FRICTION := 0.72
const AIR_DRAG := 0.985
const QUAD_SIZE_MIN := 1.0 / 10.0
const QUAD_SIZE_MAX := 1.0 / 6.0


var chunk_manager: Node = null
var atlas_texture: Texture2D = null
var tiles_per_row: int = 3
var _mmi := MultiMeshInstance3D.new()
var _mm := MultiMesh.new()
var _alive := PackedByteArray()
var _life := PackedFloat32Array()
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _scale := PackedFloat32Array()
var _free: Array[int] = []

func _ready() -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)

	_mm.mesh = qm
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.use_colors = true
	_mm.instance_count = MAX_PARTICLES
	

	_mmi.multimesh = _mm
	add_child(_mmi)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/block_particles_overlay.gdshader")
	_mmi.material_override = mat

	_alive.resize(MAX_PARTICLES)
	_life.resize(MAX_PARTICLES)
	_pos.resize(MAX_PARTICLES)
	_vel.resize(MAX_PARTICLES)
	_scale.resize(MAX_PARTICLES)

	_free.clear()
	for i in range(MAX_PARTICLES):
		_alive[i] = 0
		_free.append(i)
		_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -9999, 0)))
		_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
		_mm.set_instance_color(i, Color(1, 1, 1, 1))

func setup(cm: Node, atlas: Texture2D, tpr: int) -> void:
	chunk_manager = cm
	atlas_texture = atlas
	tiles_per_row = max(1, tpr)

	var mat := _mmi.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("atlas_tex", atlas_texture)

func _process(dt: float) -> void:
	if chunk_manager == null:
		return

	for i in range(MAX_PARTICLES):
		if _alive[i] == 0:
			continue

		var life := _life[i] - dt
		_life[i] = life
		if life <= 0.0:
			_kill(i)
			continue

		var p := _pos[i]
		var v := _vel[i]

		v.y += GRAVITY * dt
		v *= AIR_DRAG
		var res := _move_and_collide(p, v, dt)
		p = res[0]
		v = res[1]

		if _touching_ground(p):
			v.x *= GROUND_FRICTION
			v.z *= GROUND_FRICTION

		_pos[i] = p
		_vel[i] = v

		var s := _scale[i]
		var t := Transform3D(Basis().scaled(Vector3(s, s, s)), p)
		_mm.set_instance_transform(i, t)


func spawn_break(world_pos: Vector3, tile_index: int, is_lit: bool) -> void:
	if chunk_manager == null or atlas_texture == null:
		return

	var tile_size := 1.0 / float(tiles_per_row)

	var col := tile_index % tiles_per_row
	var row := tile_index / tiles_per_row
	var base_origin := Vector2(float(col) * tile_size, float(row) * tile_size)
	var light = 1.0 if is_lit else 0.25
	
	for k in range(BREAK_COUNT):
		if _free.is_empty():
			return
		var i = _free.pop_back()

		_alive[i] = 1
		_life[i] = LIFE

		var p := world_pos + Vector3(
			randf_range(-0.45, 0.45),
			randf_range(-0.45, 0.45),
			randf_range(-0.45, 0.45)
		)

		var dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range( 0.2, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()

		var speed := randf_range(2.0, 4.0)
		var v := dir * speed

		_pos[i] = p
		_vel[i] = v

		var s := randf_range(QUAD_SIZE_MIN, QUAD_SIZE_MAX)
		_scale[i] = s

		var sub := tile_size * 0.25
		var ox := randf_range(0.0, tile_size - sub)
		var oy := randf_range(0.0, tile_size - sub)
		var origin := base_origin + Vector2(ox, oy)
		var size := Vector2(sub, sub)

		_mm.set_instance_custom_data(i, Color(origin.x, origin.y, size.x, size.y))
		_mm.set_instance_color(i, Color(light, light, light, 1.0))
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p))


func _kill(i: int) -> void:
	_alive[i] = 0
	_free.append(i)
	_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -9999, 0)))
	_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))


func _is_solid_world(wx: int, wy: int, wz: int) -> bool:
	return not chunk_manager.is_air_world(wx, wy, wz)


func _touching_ground(p: Vector3) -> bool:
	var wx := floori(p.x)
	var wy := floori(p.y - RADIUS - 0.01)
	var wz := floori(p.z)
	return _is_solid_world(wx, wy, wz)


func _move_and_collide(p: Vector3, v: Vector3, dt: float) -> Array:
	var np := p
	var nv := v

	np.x += nv.x * dt
	if _collides(np):
		np.x = p.x
		nv.x = -nv.x * BOUNCE

	np.y += nv.y * dt
	if _collides(np):
		np.y = p.y
		if nv.y < 0.0:
			nv.y = -nv.y * BOUNCE
		else:
			nv.y = 0.0

	np.z += nv.z * dt
	if _collides(np):
		np.z = p.z
		nv.z = -nv.z * BOUNCE

	return [np, nv]


func _collides(p: Vector3) -> bool:
	var minx := floori(p.x - RADIUS)
	var maxx := floori(p.x + RADIUS)
	var miny := floori(p.y - RADIUS)
	var maxy := floori(p.y + RADIUS)
	var minz := floori(p.z - RADIUS)
	var maxz := floori(p.z + RADIUS)

	for wy in range(miny, maxy + 1):
		for wz in range(minz, maxz + 1):
			for wx in range(minx, maxx + 1):
				if _is_solid_world(wx, wy, wz):
					return true
	return false
