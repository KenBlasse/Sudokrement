extends Control

const TITLE_COLOR: Color = Color(1, 0, 0.67, 1)
const SUBTITLE_COLOR: Color = Color(0, 0.94, 1, 1)
const SLOT_ACTIVE_COLOR: Color = Color(1, 0, 0.67, 1)
const SLOT_INACTIVE_COLOR: Color = Color(0.4, 0.4, 0.5, 1)
const CELL_REVEAL_INTERVAL: float = 0.18
const BOARD_RESTART_DELAY: float = 1.5

@onready var continue_button: Button = $Split/LeftCol/ContinueButton
@onready var new_game_button: Button = $Split/LeftCol/NewGameButton
@onready var quit_button: Button = $Split/LeftCol/QuitButton
@onready var title_label: Label = $Split/LeftCol/TitleLabel
@onready var subtitle_label: Label = $Split/LeftCol/SubtitleLabel
@onready var slot_label: Label = $Split/LeftCol/SlotLabel
@onready var slot_row: HBoxContainer = $Split/LeftCol/SlotRow
@onready var demo_host: Control = $Split/RightCol/DemoBoardHost

var _slot_buttons: Array = []
var _slot_delete_buttons: Array = []

var _generator: BoardGenerator
var _demo_board: Board
var _demo_grid: GridContainer
var _demo_cells: Array = []
var _demo_reveal_order: Array = []
var _demo_index: int = 0
var _demo_timer: Timer

func _ready() -> void:
	_style_title()
	_style_buttons()
	_build_slot_buttons()
	_wire_buttons()
	_refresh_slot_state()
	_setup_demo_board()
	if OS.get_name() == "Web":
		quit_button.visible = false

func _style_title() -> void:
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(title_label, "modulate", Color(1.2, 0.6, 1.0, 1), 1.4)
	tween.tween_property(title_label, "modulate", Color(0.9, 0.4, 0.85, 1), 1.4)

func _style_buttons() -> void:
	for btn in [continue_button, new_game_button, quit_button]:
		btn.custom_minimum_size = Vector2(280, 48)
		btn.add_theme_font_size_override("font_size", 20)

func _wire_buttons() -> void:
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	quit_button.pressed.connect(_on_quit)

func _build_slot_buttons() -> void:
	slot_label.add_theme_font_size_override("font_size", 16)
	slot_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	for i in range(SaveSystem.SLOT_COUNT):
		var slot_box := VBoxContainer.new()
		slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_row.add_child(slot_box)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 56)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slot_box.add_child(btn)
		_slot_buttons.append(btn)

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(110, 20)
		del_btn.add_theme_font_size_override("font_size", 11)
		del_btn.pressed.connect(_on_slot_delete_pressed.bind(i))
		slot_box.add_child(del_btn)
		_slot_delete_buttons.append(del_btn)

func _refresh_slot_state() -> void:
	var active: int = SaveSystem.get_active_slot()
	for i in range(SaveSystem.SLOT_COUNT):
		var btn: Button = _slot_buttons[i]
		var summary: Dictionary = SaveSystem.slot_summary(i)
		var exists: bool = not summary.is_empty()
		var coins: int = 0
		if exists and summary.has("economy"):
			var eco_data: Dictionary = summary["economy"]
			coins = int(eco_data.get("coins", 0))
		if exists:
			btn.text = "Slot %d\n%s coins" % [i + 1, NumberFormat.coins(float(coins))]
		else:
			btn.text = "Slot %d\n(empty)" % (i + 1)
		var color: Color = SLOT_ACTIVE_COLOR if i == active else SLOT_INACTIVE_COLOR
		btn.add_theme_color_override("font_color", color)
		_slot_delete_buttons[i].disabled = not exists
	var data: Dictionary = SaveSystem.load_data()
	continue_button.disabled = data.is_empty()

func _setup_demo_board() -> void:
	_generator = BoardGenerator.new()
	_demo_grid = GridContainer.new()
	_demo_grid.columns = 9
	_demo_grid.add_theme_constant_override("h_separation", 2)
	_demo_grid.add_theme_constant_override("v_separation", 2)
	demo_host.add_child(_demo_grid)
	_demo_timer = Timer.new()
	_demo_timer.wait_time = CELL_REVEAL_INTERVAL
	_demo_timer.timeout.connect(_reveal_next_cell)
	add_child(_demo_timer)
	_start_new_demo()

func _start_new_demo() -> void:
	for child in _demo_grid.get_children():
		child.queue_free()
	_demo_cells.clear()
	_demo_reveal_order.clear()
	_demo_index = 0
	_demo_board = _generator.generate("easy")
	for r in range(_demo_board.size):
		var row: Array = []
		for c in range(_demo_board.size):
			var lbl := Label.new()
			lbl.custom_minimum_size = Vector2(36, 36)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.modulate = Color(1, 1, 1, 0)
			_demo_grid.add_child(lbl)
			row.append(lbl)
			_demo_reveal_order.append(Vector2i(r, c))
		_demo_cells.append(row)
	_demo_reveal_order.shuffle()
	_demo_timer.start()

func _reveal_next_cell() -> void:
	if _demo_index >= _demo_reveal_order.size():
		_demo_timer.stop()
		await get_tree().create_timer(BOARD_RESTART_DELAY).timeout
		_fade_out_and_restart()
		return
	var pos: Vector2i = _demo_reveal_order[_demo_index]
	_demo_index += 1
	var lbl: Label = _demo_cells[pos.x][pos.y]
	lbl.text = str(_demo_board.solution[pos.x][pos.y])
	var is_given: bool = _demo_board.cells[pos.x][pos.y].given
	var color: Color
	if is_given:
		color = Color(0, 0.94, 1, 0.85)
	else:
		color = Color(1, 0.95, 0.7, 0.75)
	lbl.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.25)

func _fade_out_and_restart() -> void:
	var t := create_tween()
	t.tween_property(_demo_grid, "modulate", Color(1, 1, 1, 0), 0.4)
	await t.finished
	_demo_grid.modulate = Color(1, 1, 1, 1)
	_start_new_demo()

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_new_game() -> void:
	if not SaveSystem.load_data().is_empty():
		_confirm_overwrite()
		return
	_start_fresh_run()

func _confirm_overwrite() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Slot %d hat einen Spielstand. Überschreiben?" % (SaveSystem.get_active_slot() + 1)
	dialog.confirmed.connect(_start_fresh_run)
	add_child(dialog)
	dialog.popup_centered()

func _start_fresh_run() -> void:
	SaveSystem.save_data({})
	Economy.reset()
	Economy.permanent_multiplier = 1.0
	Economy.difficulty_mode = "casual"
	SkillTree.reset()
	PrestigeManager.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_slot_pressed(slot: int) -> void:
	SaveSystem.set_active_slot(slot)
	_refresh_slot_state()

func _on_slot_delete_pressed(slot: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Slot %d wirklich löschen?" % (slot + 1)
	dialog.confirmed.connect(_delete_slot.bind(slot))
	add_child(dialog)
	dialog.popup_centered()

func _delete_slot(slot: int) -> void:
	SaveSystem.delete_slot(slot)
	_refresh_slot_state()

func _on_quit() -> void:
	get_tree().quit()
