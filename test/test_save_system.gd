extends GdUnitTestSuite

var save_system: Node

func before_test() -> void:
	save_system = load("res://systems/save_system.gd").new()
	add_child(save_system)
	save_system.save_path = "user://test_save.json"

func after_test() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_save.json"):
		dir.remove("test_save.json")

func test_round_trip_preserves_state():
	var data := {
		"version": 1,
		"coins": 1234.5,
		"prestige_count": 2,
		"unlocked_tiers": ["easy", "medium"],
	}
	save_system.save_data(data)
	var loaded: Dictionary = save_system.load_data()
	assert_float(loaded["coins"]).is_equal_approx(1234.5, 0.01)
	assert_int(int(loaded["prestige_count"])).is_equal(2)
	assert_array(loaded["unlocked_tiers"]).contains_exactly(["easy", "medium"])

func test_load_returns_empty_dict_when_no_save():
	var loaded: Dictionary = save_system.load_data()
	assert_dict(loaded).is_empty()

func test_export_returns_json_string():
	var data := {"coins": 42}
	save_system.save_data(data)
	var json_str: String = save_system.export_as_string()
	assert_str(json_str).contains("42")

func test_import_parses_json_string():
	var json_str := "{\"coins\": 99, \"version\": 1}"
	var success: bool = save_system.import_from_string(json_str)
	assert_bool(success).is_equal(true)
	var loaded: Dictionary = save_system.load_data()
	assert_int(int(loaded["coins"])).is_equal(99)

func test_slots_are_isolated():
	var slot_system: Node = load("res://systems/save_system.gd").new()
	add_child(slot_system)
	slot_system.set_active_slot(0)
	slot_system.save_data({"coins": 100})
	slot_system.set_active_slot(1)
	slot_system.save_data({"coins": 200})
	slot_system.set_active_slot(2)
	slot_system.save_data({"coins": 300})
	slot_system.set_active_slot(0)
	assert_int(int(slot_system.load_data()["coins"])).is_equal(100)
	slot_system.set_active_slot(1)
	assert_int(int(slot_system.load_data()["coins"])).is_equal(200)
	slot_system.set_active_slot(2)
	assert_int(int(slot_system.load_data()["coins"])).is_equal(300)
	for i in range(3):
		slot_system.delete_slot(i)
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("meta.json"):
		dir.remove("meta.json")

func test_slot_exists_false_until_saved():
	var slot_system: Node = load("res://systems/save_system.gd").new()
	add_child(slot_system)
	slot_system.delete_slot(1)
	assert_bool(slot_system.slot_exists(1)).is_equal(false)
	slot_system.set_active_slot(1)
	slot_system.save_data({"coins": 5})
	assert_bool(slot_system.slot_exists(1)).is_equal(true)
	slot_system.delete_slot(1)
	assert_bool(slot_system.slot_exists(1)).is_equal(false)
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("meta.json"):
		dir.remove("meta.json")
