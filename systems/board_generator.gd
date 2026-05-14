class_name BoardGenerator
extends RefCounted

const DIFFICULTY_GIVENS: Dictionary = {
	"easy":    [36, 46],
	"medium":  [30, 36],
	"hard":    [25, 30],
	"expert":  [22, 25],
}

var _rng: RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

func generate(difficulty: String) -> Board:
	var board := Board.new(9)
	board.difficulty = difficulty
	_fill_solution(board)
	_remove_cells(board, difficulty)
	return board

func _fill_solution(board: Board) -> void:
	var grid: Array = []
	for r in range(9):
		var row: Array = []
		for c in range(9):
			row.append(0)
		grid.append(row)
	_solve(grid)
	for r in range(9):
		for c in range(9):
			board.solution[r][c] = grid[r][c]

func _solve(grid: Array) -> bool:
	for r in range(9):
		for c in range(9):
			if grid[r][c] == 0:
				var nums: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9]
				nums.shuffle()
				for n in nums:
					if _is_safe(grid, r, c, n):
						grid[r][c] = n
						if _solve(grid):
							return true
						grid[r][c] = 0
				return false
	return true

func _is_safe(grid: Array, row: int, col: int, n: int) -> bool:
	for i in range(9):
		if grid[row][i] == n:
			return false
		if grid[i][col] == n:
			return false
	var br := (row / 3) * 3
	var bc := (col / 3) * 3
	for r in range(br, br + 3):
		for c in range(bc, bc + 3):
			if grid[r][c] == n:
				return false
	return true

func _remove_cells(board: Board, difficulty: String) -> void:
	var range_arr: Array = DIFFICULTY_GIVENS.get(difficulty, [36, 46])
	var target_givens: int = _rng.randi_range(range_arr[0], range_arr[1])
	var positions: Array = []
	for r in range(9):
		for c in range(9):
			positions.append(Vector2i(r, c))
	positions.shuffle()
	var givens: Array = positions.slice(0, target_givens)
	for pos in givens:
		board.cells[pos.x][pos.y].value = board.solution[pos.x][pos.y]
		board.cells[pos.x][pos.y].given = true
