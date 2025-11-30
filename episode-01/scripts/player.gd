extends CharacterBody3D


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
	elif event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch -= event.relative.y * MOUSE_SENS
		_pitch = clamp(_pitch, -PI/2, PI/2)
		
		rotation.y = _yaw
		rotation.x = _pitch


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
