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
	_start_new_board()

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
	Economy.award_cell()
	var board: Board = sudoku_board.board
	if validator.is_row_complete(board, row):
		Economy.award_combo("row")
	if validator.is_column_complete(board, col):
		Economy.award_combo("column")
	if validator.is_block_complete(board, row, col):
		Economy.award_combo("block")
	if validator.is_board_complete(board):
		Economy.award_board_complete(0.0)
		_start_new_board()
