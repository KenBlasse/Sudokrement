extends GridContainer

signal cell_selected(row: int, col: int)
signal cell_filled(row: int, col: int, value: int, is_correct: bool)

const CELL_SIZE: Vector2 = Vector2(48, 48)
const BLOCK_BG: Color = Color(0.05, 0.02, 0.12, 1)
const BLOCK_BORDER: Color = Color(1, 0, 0.67, 0.55)
const CELL_BG: Color = Color(0.10, 0.06, 0.20, 1)
const CELL_BG_HOVER: Color = Color(0.16, 0.10, 0.30, 1)
const CELL_BG_SELECTED: Color = Color(0.22, 0.10, 0.36, 1)
const COLOR_GIVEN: Color = Color(0, 0.94, 1, 1)
const COLOR_USER_CORRECT: Color = Color(1, 0.95, 0.7, 1)
const COLOR_WRONG: Color = Color(1, 0.2, 0.45, 1)

var board: Board
var validator: Validator
var selected_row: int = -1
var selected_col: int = -1
var hide_wrong: bool = false
var _cell_buttons: Array = []
var _block_grids: Array = []

func _ready() -> void:
	validator = Validator.new()

func set_board(new_board: Board) -> void:
	board = new_board
	columns = 3
	_rebuild_grid()

func _make_cell_stylebox(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_right = 2
	sb.corner_radius_bottom_left = 2
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

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
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = BLOCK_BORDER
			sb.corner_radius_top_left = 4
			sb.corner_radius_top_right = 4
			sb.corner_radius_bottom_right = 4
			sb.corner_radius_bottom_left = 4
			sb.content_margin_left = 3
			sb.content_margin_right = 3
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
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
					btn.add_theme_stylebox_override("normal", _make_cell_stylebox(CELL_BG))
					btn.add_theme_stylebox_override("hover", _make_cell_stylebox(CELL_BG_HOVER))
					btn.add_theme_stylebox_override("pressed", _make_cell_stylebox(CELL_BG_SELECTED))
					btn.add_theme_stylebox_override("focus", _make_cell_stylebox(CELL_BG_SELECTED))
					btn.add_theme_font_size_override("font_size", 22)
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
	var color: Color
	if cell.given:
		color = COLOR_GIVEN
	elif cell.value > 0 and cell.value != board.solution[r][c] and not hide_wrong:
		color = COLOR_WRONG
	else:
		color = COLOR_USER_CORRECT
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_color_override("font_focus_color", color)
	btn.modulate = Color(1, 1, 1, 1)

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
	var btn: Button = _cell_buttons[selected_row][selected_col]
	_update_button(btn, selected_row, selected_col)
	if correct and value > 0:
		_flash_cell(btn, Color(0, 0.94, 1, 1))
		SoundManager.correct()
	elif value > 0 and not correct:
		if not hide_wrong:
			_flash_cell(btn, Color(1, 0.2, 0.45, 1))
		SoundManager.wrong()
	elif value == 0:
		SoundManager.click()
	cell_filled.emit(selected_row, selected_col, value, correct)

func _flash_cell(btn: Button, color: Color) -> void:
	btn.pivot_offset = btn.size * 0.5
	var t := btn.create_tween()
	t.tween_property(btn, "modulate", color * 1.6, 0.08)
	t.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.18)
	t.parallel().tween_property(btn, "scale", Vector2(1.15, 1.15), 0.08).from(Vector2(1, 1))
	t.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.18)

func combo_wave(cells: Array, color: Color) -> void:
	for i in range(cells.size()):
		var pos: Vector2i = cells[i]
		if pos.x < 0 or pos.x >= _cell_buttons.size():
			continue
		if pos.y < 0 or pos.y >= _cell_buttons[pos.x].size():
			continue
		var btn: Button = _cell_buttons[pos.x][pos.y]
		if btn == null:
			continue
		var delay: float = i * 0.04
		btn.pivot_offset = btn.size * 0.5
		var t := btn.create_tween()
		t.tween_interval(delay)
		t.tween_property(btn, "modulate", color * 1.8, 0.10)
		t.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.22)
		t.parallel().tween_property(btn, "scale", Vector2(1.25, 1.25), 0.10).from(Vector2(1, 1))
		t.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.22)
