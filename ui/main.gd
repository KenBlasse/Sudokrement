extends VBoxContainer

@onready var sudoku_board: GridContainer = $ContentRow/LeftCol/BoardContainer/SudokuBoard
@onready var number_pad: HBoxContainer = $ContentRow/LeftCol/NumberPadContainer/NumberPad
@onready var top_bar: HBoxContainer = $TopBar
@onready var side_tabs: TabContainer = $ContentRow/SideTabs

var validator: Validator
var generator: BoardGenerator
const STANDARD_LIVES: int = 3
var _lives: int = STANDARD_LIVES

func _ready() -> void:
	validator = Validator.new()
	generator = BoardGenerator.new()
	number_pad.number_pressed.connect(_on_number_pressed)
	number_pad.erase_pressed.connect(_on_erase_pressed)
	sudoku_board.cell_filled.connect(_on_cell_filled)
	top_bar.menu_requested.connect(_on_menu_requested)
	top_bar.mode_changed.connect(_on_mode_changed)
	var shop: VBoxContainer = side_tabs.get_node("Shop")
	shop.hint_purchased.connect(_on_hint_purchased)
	_load_game()
	_start_new_board()
	var autosave := Timer.new()
	autosave.wait_time = 30.0
	autosave.autostart = true
	autosave.timeout.connect(_save_game)
	add_child(autosave)

func _load_game() -> void:
	var data: Dictionary = SaveSystem.load_data()
	if data.has("economy"):
		Economy.deserialize(data["economy"])
	if data.has("skill_tree"):
		SkillTree.deserialize(data["skill_tree"])
	if data.has("prestige"):
		PrestigeManager.deserialize(data["prestige"])
	if data.has("achievements"):
		AchievementManager.deserialize(data["achievements"])

func _save_game() -> void:
	SaveSystem.save_data({
		"economy": Economy.serialize(),
		"skill_tree": SkillTree.serialize(),
		"prestige": PrestigeManager.serialize(),
		"achievements": AchievementManager.serialize(),
	})

func _on_menu_requested() -> void:
	_save_game()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_hint_purchased() -> void:
	var board: Board = sudoku_board.board
	var empty_cells: Array = []
	for r in range(board.size):
		for c in range(board.size):
			if board.cells[r][c].value == 0:
				empty_cells.append(Vector2i(r, c))
	if empty_cells.is_empty():
		return
	empty_cells.shuffle()
	var pos: Vector2i = empty_cells[0]
	board.cells[pos.x][pos.y].value = board.solution[pos.x][pos.y]
	board.cells[pos.x][pos.y].locked = true
	sudoku_board._rebuild_grid()

func _current_tier() -> String:
	if SkillTree.is_unlocked("tier_hard"):
		return "hard"
	if SkillTree.is_unlocked("tier_medium"):
		return "medium"
	return "easy"

func _start_new_board() -> void:
	var board := generator.generate(_current_tier())
	sudoku_board.hide_wrong = Economy.difficulty_mode == "hardcore"
	sudoku_board.set_board(board)
	top_bar.reset_timer()
	board.start_time = Time.get_ticks_msec() / 1000.0
	_lives = STANDARD_LIVES
	_refresh_lives_label()
	var shop := side_tabs.get_node_or_null("Shop")
	if shop and shop.has_method("reset_board_session"):
		shop.reset_board_session()

func _refresh_lives_label() -> void:
	if Economy.difficulty_mode == "standard":
		top_bar.set_lives(_lives)
	else:
		top_bar.set_lives(-1)

func _on_mode_changed(_mode: String) -> void:
	_start_new_board()

func _on_number_pressed(value: int) -> void:
	sudoku_board.input_value(value)

func _on_erase_pressed() -> void:
	sudoku_board.input_value(0)

func _on_cell_filled(row: int, col: int, value: int, is_correct: bool) -> void:
	var board: Board = sudoku_board.board
	if value > 0 and not is_correct and Economy.difficulty_mode == "standard":
		board.mistakes_this_run += 1
		_lives -= 1
		_refresh_lives_label()
		if _lives <= 0:
			_start_new_board()
			return
	if Economy.difficulty_mode == "hardcore" and value > 0 and validator.is_board_full(board):
		if validator.is_board_complete(board):
			_award_board_complete(board)
		else:
			SoundManager.wrong()
			board.mistakes_this_run += 1
			_start_new_board()
		return
	if not is_correct or value == 0:
		return
	var cell: Cell = board.cells[row][col]
	if cell.awarded:
		return
	cell.awarded = true
	var before: float = Economy.coins
	Economy.award_cell()
	PrestigeManager.record_coins(Economy.coins - before)
	var combo_triggered: bool = false
	if validator.is_row_complete(board, row) and not board.rows_awarded.get(row, false):
		board.rows_awarded[row] = true
		var b: float = Economy.coins
		Economy.award_combo("row")
		PrestigeManager.record_coins(Economy.coins - b)
		board.combos_this_run += 1
		GameEvents.combo_triggered.emit("row")
		var cells: Array = []
		for c in range(board.size):
			cells.append(Vector2i(row, c))
		sudoku_board.combo_wave(cells, Color(0, 0.94, 1, 1))
		combo_triggered = true
	if validator.is_column_complete(board, col) and not board.cols_awarded.get(col, false):
		board.cols_awarded[col] = true
		var b: float = Economy.coins
		Economy.award_combo("column")
		PrestigeManager.record_coins(Economy.coins - b)
		board.combos_this_run += 1
		GameEvents.combo_triggered.emit("column")
		var cells: Array = []
		for r in range(board.size):
			cells.append(Vector2i(r, col))
		sudoku_board.combo_wave(cells, Color(0, 0.94, 1, 1))
		combo_triggered = true
	var block_key: int = (row / 3) * 3 + (col / 3)
	if validator.is_block_complete(board, row, col) and not board.blocks_awarded.get(block_key, false):
		board.blocks_awarded[block_key] = true
		var b: float = Economy.coins
		Economy.award_combo("block")
		PrestigeManager.record_coins(Economy.coins - b)
		board.combos_this_run += 1
		GameEvents.combo_triggered.emit("block")
		var cells: Array = []
		var br: int = (row / 3) * 3
		var bc: int = (col / 3) * 3
		for r in range(br, br + 3):
			for c in range(bc, bc + 3):
				cells.append(Vector2i(r, c))
		sudoku_board.combo_wave(cells, Color(1, 0, 0.67, 1))
		combo_triggered = true
	if combo_triggered:
		SoundManager.combo()
	if validator.is_board_complete(board):
		_award_board_complete(board)

func _award_board_complete(board: Board) -> void:
	var before2: float = Economy.coins
	Economy.award_board_complete(0.0)
	PrestigeManager.record_coins(Economy.coins - before2)
	PrestigeManager.record_board_solved()
	SoundManager.board_complete()
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - board.start_time
	GameEvents.board_solved.emit({
		"difficulty": Economy.difficulty_mode,
		"time_seconds": elapsed,
		"mistakes": board.mistakes_this_run,
		"combos_in_board": board.combos_this_run,
	})
	var prestige_tab := side_tabs.get_node_or_null("Prestige")
	if prestige_tab:
		prestige_tab._refresh()
	_save_game()
	_start_new_board()
