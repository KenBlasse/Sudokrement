class_name Validator
extends RefCounted

func is_correct(board: Board, row: int, col: int, value: int) -> bool:
	return board.solution[row][col] == value

func is_row_complete(board: Board, row: int) -> bool:
	for c in range(board.size):
		if board.cells[row][c].value != board.solution[row][c]:
			return false
	return true

func is_column_complete(board: Board, col: int) -> bool:
	for r in range(board.size):
		if board.cells[r][col].value != board.solution[r][col]:
			return false
	return true

func is_block_complete(board: Board, row: int, col: int) -> bool:
	var br := (row / 3) * 3
	var bc := (col / 3) * 3
	for r in range(br, br + 3):
		for c in range(bc, bc + 3):
			if board.cells[r][c].value != board.solution[r][c]:
				return false
	return true

func is_board_complete(board: Board) -> bool:
	for r in range(board.size):
		for c in range(board.size):
			if board.cells[r][c].value != board.solution[r][c]:
				return false
	return true

func is_board_full(board: Board) -> bool:
	for r in range(board.size):
		for c in range(board.size):
			if board.cells[r][c].value == 0:
				return false
	return true
