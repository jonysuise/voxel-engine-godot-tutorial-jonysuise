extends CharacterBody3D

@onready var raycast := $Camera3D/RayCast3D
@onready var cube_selected: Node3D = $"../CubeSelection"
@onready var cam: Camera3D = $Camera3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENS = 0.002

var _yaw = 0
var _pitch = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):
		if get_viewport().debug_draw == Viewport.DEBUG_DRAW_WIREFRAME:
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
		else:
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
			
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
			
	elif event is InputEventMouseButton and event.button_index == 2 and event.is_pressed():
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider:
				var chunk = collider.get_parent()
				
				if chunk.has_method("delete_block"):
					var point = raycast.get_collision_point()
					var normal = raycast.get_collision_normal()
					var block_coords: Vector3i = _get_hit_block(point, normal)
					
					chunk.delete_block(block_coords)
				
	elif event is InputEventMouseButton and event.button_index == 1 and event.is_pressed():
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider:
				var chunk = collider.get_parent()
				
				if chunk.has_method("add_block"):
					var point = raycast.get_collision_point()
					var normal = raycast.get_collision_normal()
					var block_coords: Vector3i = _get_adjacent_block(point, normal)
					
					if _resolve_block_overlap(block_coords, normal):
						chunk.add_block(block_coords)
		
		
	elif event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch -= event.relative.y * MOUSE_SENS
		_pitch = clamp(_pitch, -PI/2, PI/2)
		
		rotation.y = _yaw
		$Camera3D.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	_update_block_selection()


func _resolve_block_overlap(block_coords: Vector3i, normal: Vector3) -> bool:
	var bx := float(block_coords.x)
	var by := float(block_coords.y)
	var bz := float(block_coords.z)

	var pos := global_transform.origin
	
	# rough AABB check:
	var overlap_x = abs(pos.x - bx) < 0.6
	var overlap_y = abs(pos.y - by) < 1.3
	var overlap_z = abs(pos.z - bz) < 0.6
	
	if overlap_x and overlap_y and overlap_z:
		if normal == Vector3.UP:
			var collision = move_and_collide(Vector3.UP)
			return collision == null
		
		return false
		
	return true


func _update_block_selection() -> void:
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if not collider:
			return
			
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		var block_coords: Vector3i = _get_hit_block(point, normal)
		var chunk = collider.get_parent()
		
		if chunk and chunk.has_method("check_block_selected"):
			if chunk.check_block_selected(block_coords):
				cube_selected.visible = true
				cube_selected.global_position = Vector3(block_coords.x, block_coords.y, block_coords.z)
	else:
		cube_selected.visible = false
	
	
func _get_hit_block(point: Vector3, normal: Vector3) -> Vector3i:
	return Vector3i(
		roundi(point.x - normal.x * 0.5),
		roundi(point.y - normal.y * 0.5),
		roundi(point.z - normal.z * 0.5)
	)


func _get_adjacent_block(point: Vector3, normal: Vector3) -> Vector3i:
	return Vector3i(
		roundi(point.x + normal.x * 0.5),
		roundi(point.y + normal.y * 0.5),
		roundi(point.z + normal.z * 0.5)
	)
