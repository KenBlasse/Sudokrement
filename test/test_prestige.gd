extends GdUnitTestSuite

var pm: Node

func before_test() -> void:
	pm = load("res://systems/prestige_manager.gd").new()
	add_child(pm)
	pm.reset()
	Economy.reset()
	Economy.permanent_multiplier = 1.0
	SkillTree.reset()
	AchievementManager.reset()
	AchievementManager.unlocked["first_prestige"] = true

func test_stars_formula():
	pm.lifetime_coins = 4000.0
	var stars: int = pm.calculate_stars()
	assert_int(stars).is_equal(2)

func test_zero_when_under_threshold():
	pm.lifetime_coins = 500.0
	assert_int(pm.calculate_stars()).is_equal(0)

func test_prestige_requires_25_boards():
	pm.boards_solved_current_tier = 24
	assert_bool(pm.can_prestige()).is_equal(false)
	pm.boards_solved_current_tier = 25
	assert_bool(pm.can_prestige()).is_equal(true)

func test_prestige_resets_economy_and_grants_stars():
	pm.lifetime_coins = 4000.0
	pm.boards_solved_current_tier = 25
	Economy.coins = 100.0
	pm.prestige()
	assert_float(Economy.coins).is_equal_approx(0.0, 0.001)
	assert_int(SkillTree.stars).is_equal(2)
	assert_int(pm.prestige_count).is_equal(1)

func test_prestige_increases_permanent_multiplier():
	pm.lifetime_coins = 4000.0
	pm.boards_solved_current_tier = 25
	var before: float = Economy.permanent_multiplier
	pm.prestige()
	assert_float(Economy.permanent_multiplier).is_equal_approx(before + 0.02, 0.001)

func test_record_coins_emits_lifetime_changed() -> void:
	var received: Array = []
	pm.lifetime_coins_changed.connect(func(n: float) -> void: received.append(n))
	pm.record_coins(42.0)
	pm.record_coins(8.0)
	assert_int(received.size()).is_equal(2)
	assert_float(received[0]).is_equal_approx(42.0, 0.001)
	assert_float(received[1]).is_equal_approx(50.0, 0.001)

func test_prestige_emits_on_bus() -> void:
	pm.lifetime_coins = 1_000_000.0
	pm.boards_solved_current_tier = pm.BOARDS_PER_PRESTIGE
	var received: Array = []
	var connector := func(n: int) -> void: received.append(n)
	GameEvents.prestiged.connect(connector)
	pm.prestige()
	GameEvents.prestiged.disconnect(connector)
	assert_int(received.size()).is_equal(1)
	assert_int(received[0]).is_greater(0)
