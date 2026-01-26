extends Node

var version: int = 1
var load_from_save: bool = false
var seed: int = 20140114

const SETTINGS_PATH := "user://settings.save"



func _ready() -> void:
	load_settings()


func save_settings() -> void:
	var data := {
		"version": version,
		"seed": seed,
		"load_from_save": load_from_save,
	}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Failed to save settings")
		return
	f.store_var(data)
	f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("Failed to load settings")
		return
	var data = f.get_var()
	f.close()

	if typeof(data) == TYPE_DICTIONARY:
		version = int(data.get("version", version))
		seed = int(data.get("seed", seed))
		load_from_save = bool(data.get("load_from_save", load_from_save))
