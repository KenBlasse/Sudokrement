extends Node

const CURRENT_VERSION: int = 1

var save_path: String = "user://save.json"

func save_data(data: Dictionary) -> void:
	var to_write := data.duplicate(true)
	to_write["version"] = CURRENT_VERSION
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open " + save_path)
		return
	file.store_string(JSON.stringify(to_write))
	file.close()

func load_data() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func export_as_string() -> String:
	var data := load_data()
	return JSON.stringify(data)

func import_from_string(json_str: String) -> bool:
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return false
	save_data(parsed)
	return true
