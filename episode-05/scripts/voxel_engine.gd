extends Node3D


const MAIN_MENU_SCENE := "res://scenes/launcher.tscn"



func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$CubePreview.visible = true if Config.version > 2 else false
	$Pointer.visible = true if Config.version > 2 else false 
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	elif event.is_action_pressed("ui_accept"):
		$ChunkManager.save_world()
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_1 and Config.version > 2:
		_update_preview_texture(BlockDefinitions.BlockType.STONE_V1)
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_2 and Config.version > 2:
		_update_preview_texture(BlockDefinitions.BlockType.DIRT_V1)
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_3 and Config.version > 2:
		_update_preview_texture(BlockDefinitions.BlockType.COBBLESTONE_V2)
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_4 and Config.version > 2:
		_update_preview_texture(BlockDefinitions.BlockType.PLANK_V1)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
		
		
func _update_preview_texture(block_type: BlockDefinitions.BlockType) -> void:
	$Player.active_block = block_type
	$CubePreview.texture = load("res://assets/preview_" + str(block_type) + ".webp")
