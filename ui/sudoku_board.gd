extends GridContainer

signal cell_selected(row: int, col: int)
signal cell_filled(row: int, col: int, value: int, is_correct: bool)

const CELL_SIZE: Vector2 = Vector2(48, 48)
const BLOCK_BG: Color = Color(0.15, 0.15, 0.18)

var board: Board
var validator: Validator
var selected_row: int = -1
var selected_col: int = -1
var _cell_buttons: Array = []
var _block_grids: Array = []

func _ready() -> void:
	validator = Validator.new()

func set_board(new_board: Board) -> void:
	board = new_board
	columns = 3
	_rebuild_grid()

func _rebuild_grid() -> void:
	for child in get_children():
		child.queue_free()
	_cell_buttons.clear()
	_block_grids.clear()

	for r in range(board.size):
		var row_btns: Array = []
		for c in range(board.size):
			row_btns.append(null)
		_cell_buttons.append(row_btns)

	var block_count: int = board.size / 3
	for br in range(block_count):
		var block_row: Array = []
		for bc in range(block_count):
			var panel := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = BLOCK_BG
			sb.content_margin_left = 2
			sb.content_margin_right = 2
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			panel.add_theme_stylebox_override("panel", sb)
			add_child(panel)

			var inner := GridContainer.new()
			inner.columns = 3
			inner.add_theme_constant_override("h_separation", 1)
			inner.add_theme_constant_override("v_separation", 1)
			panel.add_child(inner)
			block_row.append(inner)

			for sub_r in range(3):
				for sub_c in range(3):
					var r: int = br * 3 + sub_r
					var c: int = bc * 3 + sub_c
					var btn := Button.new()
					btn.custom_minimum_size = CELL_SIZE
					btn.flat = false
					_update_button(btn, r, c)
					btn.pressed.connect(_on_cell_pressed.bind(r, c))
					inner.add_child(btn)
					_cell_buttons[r][c] = btn
		_block_grids.append(block_row)

func _update_button(btn: Button, r: int, c: int) -> void:
	var cell: Cell = board.cells[r][c]
	if cell.value > 0:
		btn.text = str(cell.value)
	else:
		btn.text = ""
	if cell.given:
		btn.modulate = Color(0.7, 0.7, 1.0)
	else:
		btn.modulate = Color(1.0, 1.0, 1.0)

func _on_cell_pressed(row: int, col: int) -> void:
	selected_row = row
	selected_col = col
	cell_selected.emit(row, col)

func input_value(value: int) -> void:
	if selected_row < 0 or selected_col < 0:
		return
	if board.cells[selected_row][selected_col].given:
		return
	board.set_value(selected_row, selected_col, value)
	var correct: bool = validator.is_correct(board, selected_row, selected_col, value)
	_update_button(_cell_buttons[selected_row][selected_col], selected_row, selected_col)
	cell_filled.emit(selected_row, selected_col, value, correct)
