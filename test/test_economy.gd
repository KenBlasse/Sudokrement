extends GdUnitTestSuite

var economy: Node

func before_test() -> void:
	economy = load("res://systems/economy.gd").new()
	add_child(economy)
	economy.reset()

func test_starts_with_zero_coins():
	assert_float(economy.coins).is_equal_approx(0.0, 0.01)

func test_award_cell_grants_base_coins():
	economy.award_cell()
	assert_float(economy.coins).is_equal_approx(1.0, 0.01)

func test_difficulty_multiplier_applies():
	economy.difficulty_mode = "standard"
	economy.award_cell()
	assert_float(economy.coins).is_equal_approx(1.5, 0.01)

func test_hardcore_multiplier():
	economy.difficulty_mode = "hardcore"
	economy.award_cell()
	assert_float(economy.coins).is_equal_approx(2.5, 0.01)

func test_combo_row_grants_bonus():
	var before: float = economy.coins
	economy.award_combo("row")
	assert_float(economy.coins - before).is_equal_approx(10.0, 0.01)

func test_combo_block_grants_bonus():
	var before: float = economy.coins
	economy.award_combo("block")
	assert_float(economy.coins - before).is_equal_approx(20.0, 0.01)

func test_board_complete_bonus():
	var before: float = economy.coins
	economy.award_board_complete(0.0)
	assert_float(economy.coins - before).is_equal_approx(100.0, 0.01)

func test_permanent_multiplier_stacks():
	economy.permanent_multiplier = 2.0
	economy.award_cell()
	assert_float(economy.coins).is_equal_approx(2.0, 0.01)

func test_coins_changed_signal_fires():
	var received: Array = []
	economy.coins_changed.connect(func(total: float) -> void: received.append(total))
	economy.award_cell()
	assert_int(received.size()).is_equal(1)
	assert_float(received[0]).is_equal_approx(1.0, 0.01)
