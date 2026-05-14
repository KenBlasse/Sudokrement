extends VBoxContainer

@onready var sudoku_board: GridContainer = $BoardContainer/SudokuBoard
@onready var number_pad: HBoxContainer = $NumberPadContainer/NumberPad
@onready var top_bar: HBoxContainer = $TopBar

var validator: Validator
var generator: BoardGenerator

func _ready() -> void:
	validator = Validator.new()
	generator = BoardGenerator.new()
	number_pad.number_pressed.connect(_on_number_pressed)
	number_pad.erase_pressed.connect(_on_erase_pressed)
	sudoku_board.cell_filled.connect(_on_cell_filled)
	var bottom_tabs: TabContainer = $BottomTabs
	var shop: VBoxContainer = bottom_tabs.get_node("Shop")
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

func _save_game() -> void:
	SaveSystem.save_data({
		"economy": Economy.serialize(),
	})

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

func _start_new_board() -> void:
	var board := generator.generate("easy")
	sudoku_board.set_board(board)
	top_bar.reset_timer()

func _on_number_pressed(value: int) -> void:
	sudoku_board.input_value(value)

func _on_erase_pressed() -> void:
	sudoku_board.input_value(0)

func _on_cell_filled(row: int, col: int, value: int, is_correct: bool) -> void:
	if not is_correct:
		return
	var before: float = Economy.coins
	Economy.award_cell()
	PrestigeManager.record_coins(Economy.coins - before)
	var board: Board = sudoku_board.board
	if validator.is_row_complete(board, row):
		var b: float = Economy.coins
		Economy.award_combo("row")
		PrestigeManager.record_coins(Economy.coins - b)
	if validator.is_column_complete(board, col):
		var b: float = Economy.coins
		Economy.award_combo("column")
		PrestigeManager.record_coins(Economy.coins - b)
	if validator.is_block_complete(board, row, col):
		var b: float = Economy.coins
		Economy.award_combo("block")
		PrestigeManager.record_coins(Economy.coins - b)
	if validator.is_board_complete(board):
		var before2: float = Economy.coins
		Economy.award_board_complete(0.0)
		PrestigeManager.record_coins(Economy.coins - before2)
		PrestigeManager.record_board_solved()
		_save_game()
		_start_new_board()
