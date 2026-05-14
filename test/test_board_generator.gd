extends GdUnitTestSuite

func test_generates_9x9_board():
	var gen = BoardGenerator.new()
	var board = gen.generate("easy")
	assert_int(board.size).is_equal(9)
	assert_str(board.difficulty).is_equal("easy")

func test_solution_is_complete_and_valid():
	var gen = BoardGenerator.new()
	var board = gen.generate("easy")
	for r in range(9):
		for c in range(9):
			assert_int(board.solution[r][c]).is_between(1, 9)
	for r in range(9):
		var seen: Dictionary = {}
		for c in range(9):
			seen[board.solution[r][c]] = true
		assert_int(seen.size()).is_equal(9)
	for c in range(9):
		var seen: Dictionary = {}
		for r in range(9):
			seen[board.solution[r][c]] = true
		assert_int(seen.size()).is_equal(9)
	for br in range(3):
		for bc in range(3):
			var seen: Dictionary = {}
			for r in range(br * 3, br * 3 + 3):
				for c in range(bc * 3, bc * 3 + 3):
					seen[board.solution[r][c]] = true
			assert_int(seen.size()).is_equal(9)

func test_easy_has_around_40_givens():
	var gen = BoardGenerator.new()
	var board = gen.generate("easy")
	var givens = 0
	for r in range(9):
		for c in range(9):
			if board.cells[r][c].given:
				givens += 1
	assert_int(givens).is_between(36, 46)

func test_given_cells_have_correct_value():
	var gen = BoardGenerator.new()
	var board = gen.generate("easy")
	for r in range(9):
		for c in range(9):
			if board.cells[r][c].given:
				assert_int(board.cells[r][c].value).is_equal(board.solution[r][c])
