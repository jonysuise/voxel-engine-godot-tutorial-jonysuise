extends Node3D


func _process(_delta: float) -> void:
	$FPSLabel.text = "FPS : " + str(Engine.get_frames_per_second())
	$TrianglesLabel.text = "Triangles : " + str($chunk.get_triangle_count())
