extends Node3D


func _process(_delta: float) -> void:
	$FPSLabel.text = "FPS : " + str(Engine.get_frames_per_second())
	$TrianglesLabel.text = "Triangles : " + str($ChunkManager.triangles_total)
	$LoadTimeLabel.text = "Load Time : " + str($ChunkManager.load_time)
