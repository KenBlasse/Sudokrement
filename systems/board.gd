class_name Board
extends RefCounted

var size: int
var cells: Array          # 2D Array of Cell
var solution: Array       # 2D Array of int (correct values)
var difficulty: String = "easy"
var start_time: float = 0.0
var lives_left: int = 3
var rows_awarded: Dictionary = {}
var cols_awarded: Dictionary = {}
var blocks_awarded: Dictionary = {}

func _init(board_size: int) -> void:
	size = board_size
	cells = []
	solution = []
	for r in range(size):
		var row: Array = []
		var sol_row: Array = []
		for c in range(size):
			row.append(Cell.new())
			sol_row.append(0)
		cells.append(row)
		solution.append(sol_row)

func set_value(row: int, col: int, value: int) -> void:
	if cells[row][col].given:
		return
	if cells[row][col].locked:
		return
	cells[row][col].value = value
