extends Node

const CURRENT_VERSION: int = 1
const SLOT_COUNT: int = 3
const META_PATH: String = "user://meta.json"

var save_path: String = ""
var _active_slot: int = 0

func _ready() -> void:
	_active_slot = _read_meta_active_slot()

func _slot_path(slot: int) -> String:
	return "user://save_slot%d.json" % slot

func _resolved_path() -> String:
	if save_path != "":
		return save_path
	return _slot_path(_active_slot)

func get_active_slot() -> int:
	return _active_slot

func set_active_slot(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		push_error("SaveSystem: invalid slot %d" % slot)
		return
	_active_slot = slot
	_write_meta_active_slot(slot)

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func slot_summary(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func delete_slot(slot: int) -> void:
	var dir := DirAccess.open("user://")
	var fname := "save_slot%d.json" % slot
	if dir and dir.file_exists(fname):
		dir.remove(fname)

func save_data(data: Dictionary) -> void:
	var to_write := data.duplicate(true)
	to_write["version"] = CURRENT_VERSION
	var path := _resolved_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open " + path)
		return
	file.store_string(JSON.stringify(to_write))
	file.close()

func load_data() -> Dictionary:
	var path := _resolved_path()
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
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

func _read_meta_active_slot() -> int:
	if not FileAccess.file_exists(META_PATH):
		return 0
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		return 0
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("active_slot"):
		var s: int = int(parsed["active_slot"])
		if s >= 0 and s < SLOT_COUNT:
			return s
	return 0

func _write_meta_active_slot(slot: int) -> void:
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"active_slot": slot}))
	file.close()
