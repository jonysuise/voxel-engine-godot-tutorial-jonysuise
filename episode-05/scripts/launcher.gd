extends CanvasLayer

@onready var load_button: Button = $VBoxContainer/btnLoad
@onready var version_dropdown: OptionButton = $VBoxContainer/versionDropDown
@onready var load_from_save_check: CheckBox = $VBoxContainer/chkLoadFromSave
@onready var hbox_seed: HBoxContainer = $VBoxContainer/hboxSeed
@onready var seed_slider: HSlider = $VBoxContainer/seedSlider
@onready var seed_label: Label = $VBoxContainer/hboxSeed/lblSeedValue


const VOXEL_SCENE_PATH := "res://scenes/voxel_engine.tscn"

func _ready() -> void:

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	version_dropdown.clear()
	version_dropdown.add_item("rd-131655 - Cave game tech test", 0)
	version_dropdown.add_item("rd-132211", 1)
	version_dropdown.add_item("rd-160052 - Minecraft", 2)
	version_dropdown.select(Config.version - 1)
	
	load_from_save_check.button_pressed = Config.load_from_save
	seed_slider.visible = false if Config.load_from_save else true
	hbox_seed.visible = seed_slider.visible
	seed_label.text = str(Config.seed)
	seed_slider.value = Config.seed
	

	version_dropdown.item_selected.connect(_on_version_selected)
	load_from_save_check.toggled.connect(_on_load_from_save_toggled)
	seed_slider.value_changed.connect(_on_seed_changed)
	load_button.pressed.connect(_on_load_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		
		
func _on_version_selected(index: int) -> void:
	Config.version = index + 1
	
	
func _on_load_from_save_toggled(pressed: bool) -> void:
	Config.load_from_save = pressed
	seed_slider.visible = false if Config.load_from_save else true
	hbox_seed.visible = seed_slider.visible


func _on_seed_changed(value: int) -> void:
	Config.seed = value
	seed_label.text = str(value)
	
	
func _on_load_pressed() -> void:
	Config.save_settings()
	get_tree().change_scene_to_file(VOXEL_SCENE_PATH)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
