extends GdUnitTestSuite

func test_board_initializes_empty_9x9():
	var board = Board.new(9)
	assert_int(board.size).is_equal(9)
	assert_int(board.cells.size()).is_equal(9)
	assert_int(board.cells[0].size()).is_equal(9)
	assert_int(board.cells[0][0].value).is_equal(0)
	assert_bool(board.cells[0][0].given).is_equal(false)

func test_set_cell_updates_value():
	var board = Board.new(9)
	board.set_value(0, 0, 5)
	assert_int(board.cells[0][0].value).is_equal(5)

func test_given_cells_are_immutable():
	var board = Board.new(9)
	board.cells[0][0].given = true
	board.cells[0][0].value = 3
	board.set_value(0, 0, 7)
	assert_int(board.cells[0][0].value).is_equal(3)
