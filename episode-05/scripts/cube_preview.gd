extends Node3D



func _ready():
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	cube.mesh.size = Vector3.ONE
	add_child(cube)

	cube.rotation_degrees = Vector3(35.264, 45.0, 0.0)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.5
	cam.position = Vector3(0, 0, 5)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
