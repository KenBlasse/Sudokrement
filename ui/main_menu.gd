extends Control

const TITLE_COLOR: Color = Color(1, 0, 0.67, 1)
const SUBTITLE_COLOR: Color = Color(0, 0.94, 1, 1)
const CELL_REVEAL_INTERVAL: float = 0.18
const BOARD_RESTART_DELAY: float = 1.5

@onready var continue_button: Button = $Split/LeftCol/ContinueButton
@onready var new_game_button: Button = $Split/LeftCol/NewGameButton
@onready var quit_button: Button = $Split/LeftCol/QuitButton
@onready var title_label: Label = $Split/LeftCol/TitleLabel
@onready var subtitle_label: Label = $Split/LeftCol/SubtitleLabel
@onready var demo_host: Control = $Split/RightCol/DemoBoardHost

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
	_wire_buttons()
	_setup_save_state()
	_setup_demo_board()

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

func _setup_save_state() -> void:
	var data: Dictionary = SaveSystem.load_data()
	continue_button.disabled = data.is_empty()
	if OS.get_name() == "Web":
		quit_button.visible = false

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
	SaveSystem.save_data({})
	Economy.reset()
	Economy.permanent_multiplier = 1.0
	Economy.difficulty_mode = "casual"
	SkillTree.reset()
	PrestigeManager.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_quit() -> void:
	get_tree().quit()
