extends CharacterBody3D

@onready var cube_selected: Node3D = $"../CubeSelection"
@onready var cam: Camera3D = $Camera3D
@onready var chunk_manager: Node = $"../ChunkManager"
@onready var fog_mat: ShaderMaterial = preload("res://assets/chunk.tres")

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENS = 0.002
const PLAYER_HALF_WIDTH := 0.3
const PLAYER_HEIGHT := 1.7
const EPS := 0.001

var _yaw = 0
var _pitch = 0

var active_block := BlockDefinitions.BlockType.STONE_V1




func _process(_delta: float) -> void:
	fog_mat.set_shader_parameter("player_world_pos", global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_R and Config.version >= 2:
		global_position = Vector3(randi_range(- (chunk_manager.world_size * chunk_manager.chunk_size) / 2, (chunk_manager.world_size * chunk_manager.chunk_size) / 2 - 1), 74, randi_range(- (chunk_manager.world_size * chunk_manager.chunk_size) / 2, (chunk_manager.world_size * chunk_manager.chunk_size) / 2 - 1))
	elif event is InputEventMouseButton and event.button_index == 2 and event.is_pressed() and Config.version != 1:
		var hit := _raycast_voxels(cam.global_transform.origin, -cam.global_transform.basis.z, 5.0)
		if hit.hit:
			chunk_manager.delete_block_world(hit.block)
	elif event is InputEventMouseButton and event.button_index == 1 and event.is_pressed() and Config.version != 1:
		var hit := _raycast_voxels(cam.global_transform.origin, -cam.global_transform.basis.z, 5.0)
		if hit.hit:
			var place_block = hit.block + hit.normal
			if _resolve_block_overlap(place_block, Vector3(hit.normal)):
				chunk_manager.add_block_world(place_block, active_block)
	elif event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch -= event.relative.y * MOUSE_SENS
		_pitch = clamp(_pitch, -PI/2, PI/2)
		
		rotation.y = _yaw
		$Camera3D.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if not _is_on_ground():
		velocity.y += get_gravity().y * delta

	if Input.is_action_just_pressed("ui_select") and _is_on_ground():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if wish_dir:
		velocity.x = wish_dir.x * SPEED
		velocity.z = wish_dir.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	_move_voxel(delta)

	if Config.version != 1:
		_update_block_selection()


func _is_on_ground() -> bool:
	return _collides(global_position + Vector3(0, -EPS * 4.0, 0))


func _move_voxel_v2(delta: float) -> void:
	var pos := global_position
	var motion := velocity * delta

	pos.y += motion.y
	if _collides(pos):
		if motion.y < 0.0:
			pos.y = floor(pos.y + EPS) + 1.0
		else:
			pos.y = ceil(pos.y + PLAYER_HEIGHT - EPS) - PLAYER_HEIGHT - EPS
		velocity.y = 0.0

	pos.x += motion.x
	if _collides(pos):
		if motion.x > 0.0:
			pos.x = floor(pos.x + PLAYER_HALF_WIDTH) - PLAYER_HALF_WIDTH - EPS
		elif motion.x < 0.0:
			pos.x = ceil(pos.x - PLAYER_HALF_WIDTH) + PLAYER_HALF_WIDTH + EPS
		velocity.x = 0.0

	pos.z += motion.z
	if _collides(pos):
		if motion.z > 0.0:
			pos.z = floor(pos.z + PLAYER_HALF_WIDTH) - PLAYER_HALF_WIDTH - EPS
		elif motion.z < 0.0:
			pos.z = ceil(pos.z - PLAYER_HALF_WIDTH) + PLAYER_HALF_WIDTH + EPS
		velocity.z = 0.0

	global_position = pos


func _move_voxel(delta: float) -> void:
	var pos := global_position
	var motion := velocity * delta
	var was_colliding := _collides(pos)
	var prev := pos
	
	pos.y += motion.y
	if _collides(pos) and not was_colliding:
		if motion.y < 0.0:
			var foot_cell_y := floori(pos.y + EPS)
			pos.y = float(foot_cell_y) + 1.0
		elif motion.y > 0.0:
			var head_cell_y := floori(pos.y + PLAYER_HEIGHT - EPS)
			pos.y = float(head_cell_y) - PLAYER_HEIGHT - EPS
		else:
			pos = prev
		velocity.y = 0.0

	was_colliding = _collides(pos)

	prev = pos
	pos.x += motion.x
	if _collides(pos) and not was_colliding:
		if motion.x > 0.0:
			var cell_x := floori(pos.x + PLAYER_HALF_WIDTH - EPS)
			pos.x = float(cell_x) - PLAYER_HALF_WIDTH - EPS
		elif motion.x < 0.0:
			var cell_x := floori(pos.x - PLAYER_HALF_WIDTH + EPS)
			pos.x = float(cell_x + 1) + PLAYER_HALF_WIDTH + EPS
		else:
			pos = prev
		velocity.x = 0.0

	was_colliding = _collides(pos)

	prev = pos
	pos.z += motion.z
	if _collides(pos) and not was_colliding:
		if motion.z > 0.0:
			var cell_z := floori(pos.z + PLAYER_HALF_WIDTH - EPS)
			pos.z = float(cell_z) - PLAYER_HALF_WIDTH - EPS
		elif motion.z < 0.0:
			var cell_z := floori(pos.z - PLAYER_HALF_WIDTH + EPS)
			pos.z = float(cell_z + 1) + PLAYER_HALF_WIDTH + EPS
		else:
			pos = prev
		velocity.z = 0.0

	global_position = pos


func _raycast_voxels(origin: Vector3, dir_in: Vector3, max_dist: float) -> Dictionary:
	var dir := dir_in.normalized()
	if dir.length() < 0.000001:
		return {"hit": false}

	var x := int(floor(origin.x))
	var y := int(floor(origin.y))
	var z := int(floor(origin.z))

	var step_x := 1 if dir.x > 0.0 else -1
	var step_y := 1 if dir.y > 0.0 else -1
	var step_z := 1 if dir.z > 0.0 else -1

	var inv_x = 1.0 / abs(dir.x) if abs(dir.x) > 1e-8 else 1e20
	var inv_y = 1.0 / abs(dir.y) if abs(dir.y) > 1e-8 else 1e20
	var inv_z = 1.0 / abs(dir.z) if abs(dir.z) > 1e-8 else 1e20

	var next_x := float(x + (1 if step_x > 0 else 0))
	var next_y := float(y + (1 if step_y > 0 else 0))
	var next_z := float(z + (1 if step_z > 0 else 0))

	var t_max_x := (next_x - origin.x) / dir.x if abs(dir.x) > 1e-8 else 1e20
	var t_max_y := (next_y - origin.y) / dir.y if abs(dir.y) > 1e-8 else 1e20
	var t_max_z := (next_z - origin.z) / dir.z if abs(dir.z) > 1e-8 else 1e20

	if t_max_x < 0.0: t_max_x = 0.0
	if t_max_y < 0.0: t_max_y = 0.0
	if t_max_z < 0.0: t_max_z = 0.0

	var t_delta_x = inv_x
	var t_delta_y = inv_y
	var t_delta_z = inv_z

	var last_normal := Vector3i(0, 0, 0)
	var t := 0.0

	while t <= max_dist:
		if not chunk_manager.is_air_world(x, y, z):
			return {
				"hit": true,
				"block": Vector3i(x, y, z),
				"normal": last_normal
			}

		if t_max_x < t_max_y and t_max_x < t_max_z:
			x += step_x
			t = t_max_x
			t_max_x += t_delta_x
			last_normal = Vector3i(-step_x, 0, 0)
		elif t_max_y < t_max_z:
			y += step_y
			t = t_max_y
			t_max_y += t_delta_y
			last_normal = Vector3i(0, -step_y, 0)
		else:
			z += step_z
			t = t_max_z
			t_max_z += t_delta_z
			last_normal = Vector3i(0, 0, -step_z)

	return {"hit": false}


func _collides(pos: Vector3) -> bool:
	var min_x := floori(pos.x - PLAYER_HALF_WIDTH + EPS)
	var max_x := floori(pos.x + PLAYER_HALF_WIDTH - EPS)

	var min_y := floori(pos.y + EPS)
	var max_y := floori(pos.y + PLAYER_HEIGHT - EPS)

	var min_z := floori(pos.z - PLAYER_HALF_WIDTH + EPS)
	var max_z := floori(pos.z + PLAYER_HALF_WIDTH - EPS)

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			for z in range(min_z, max_z + 1):
				if not chunk_manager.is_air_world(x, y, z):
					return true
	return false


func _resolve_block_overlap(block_coords: Vector3i, normal: Vector3) -> bool:
	var p := global_position
	var pmin := Vector3(p.x - PLAYER_HALF_WIDTH, p.y, p.z - PLAYER_HALF_WIDTH)
	var pmax := Vector3(p.x + PLAYER_HALF_WIDTH, p.y + PLAYER_HEIGHT, p.z + PLAYER_HALF_WIDTH)

	var bmin := Vector3(block_coords.x, block_coords.y, block_coords.z)
	var bmax := bmin + Vector3.ONE

	var ox = min(pmax.x, bmax.x) - max(pmin.x, bmin.x)
	var oy = min(pmax.y, bmax.y) - max(pmin.y, bmin.y)
	var oz = min(pmax.z, bmax.z) - max(pmin.z, bmin.z)

	var overlaps = (ox > EPS and oy > EPS and oz > EPS)
	if not overlaps:
		return true

	if normal.is_equal_approx(Vector3.UP):
		var new_pos := global_position
		new_pos.y = float(block_coords.y) + 1.0 + EPS
		if not _collides(new_pos):
			global_position = new_pos
			velocity.y = max(velocity.y, 0.0)
			return true
		return false

	return true


func _update_block_selection() -> void:
	var hit := _raycast_voxels(cam.global_transform.origin, -cam.global_transform.basis.z, 5.0)
	if not hit.hit:
		cube_selected.visible = false
		return

	var b: Vector3i = hit.block
	var n: Vector3i = hit.normal

	cube_selected.visible = true

	var outward := 0.001
	var face_center := Vector3(b.x + 0.5, b.y + 0.5, b.z + 0.5) + Vector3(n.x, n.y, n.z) * (0.5 + outward)
	cube_selected.global_position = face_center

	match n:
		Vector3i(0, 0, 1):  cube_selected.global_rotation = Vector3(0, 0, 0)
		Vector3i(0, 0, -1): cube_selected.global_rotation = Vector3(0, PI, 0)
		Vector3i(1, 0, 0):  cube_selected.global_rotation = Vector3(0, -PI/2, 0)
		Vector3i(-1, 0, 0): cube_selected.global_rotation = Vector3(0, PI/2, 0)
		Vector3i(0, 1, 0):  cube_selected.global_rotation = Vector3(-PI/2, 0, 0)
		Vector3i(0, -1, 0): cube_selected.global_rotation = Vector3(PI/2, 0, 0)


func _get_hit_block(point: Vector3, normal: Vector3) -> Vector3i:
	var p := point - normal * 0.001
	return Vector3i(floori(p.x), floori(p.y), floori(p.z))


func _get_adjacent_block(point: Vector3, normal: Vector3) -> Vector3i:
	var p := point + normal * 0.001
	return Vector3i(floori(p.x), floori(p.y), floori(p.z))
