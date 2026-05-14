extends GdUnitTestSuite

func _make_board_with_solution() -> Board:
	var b := Board.new(9)
	for r in range(9):
		for c in range(9):
			b.solution[r][c] = ((r * 3 + r / 3 + c) % 9) + 1
	return b

func test_correct_cell_returns_true():
	var v := Validator.new()
	var b := _make_board_with_solution()
	assert_bool(v.is_correct(b, 0, 0, b.solution[0][0])).is_equal(true)

func test_incorrect_cell_returns_false():
	var v := Validator.new()
	var b := _make_board_with_solution()
	var wrong: int = (b.solution[0][0] % 9) + 1
	assert_bool(v.is_correct(b, 0, 0, wrong)).is_equal(false)

func test_completed_row_is_detected():
	var v := Validator.new()
	var b := _make_board_with_solution()
	for c in range(9):
		b.cells[0][c].value = b.solution[0][c]
	assert_bool(v.is_row_complete(b, 0)).is_equal(true)
	assert_bool(v.is_row_complete(b, 1)).is_equal(false)

func test_completed_column_is_detected():
	var v := Validator.new()
	var b := _make_board_with_solution()
	for r in range(9):
		b.cells[r][0].value = b.solution[r][0]
	assert_bool(v.is_column_complete(b, 0)).is_equal(true)

func test_completed_block_is_detected():
	var v := Validator.new()
	var b := _make_board_with_solution()
	for r in range(3):
		for c in range(3):
			b.cells[r][c].value = b.solution[r][c]
	assert_bool(v.is_block_complete(b, 0, 0)).is_equal(true)

func test_board_complete_only_when_all_correct():
	var v := Validator.new()
	var b := _make_board_with_solution()
	assert_bool(v.is_board_complete(b)).is_equal(false)
	for r in range(9):
		for c in range(9):
			b.cells[r][c].value = b.solution[r][c]
	assert_bool(v.is_board_complete(b)).is_equal(true)
