extends GdUnitTestSuite

func before_test() -> void:
	AchievementManager.reset()
	SkillTree.reset()
	PrestigeManager.reset()
	Economy.reset()
	Economy.permanent_multiplier = 1.0

func test_counter_unlocks_at_threshold() -> void:
	var received: Array = []
	var connector := func(id: String, stars: int) -> void:
		received.append({"id": id, "stars": stars})
	AchievementManager.achievement_unlocked.connect(connector)
	for i in range(10):
		GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
	AchievementManager.achievement_unlocked.disconnect(connector)
	var ids: Array = []
	for r in received:
		ids.append(r["id"])
	assert_bool(ids.has("solve_10_boards")).is_true()
	assert_bool(AchievementManager.unlocked.get("solve_10_boards", false)).is_true()

func test_counter_does_not_unlock_below_threshold() -> void:
	for i in range(9):
		GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
	assert_bool(AchievementManager.unlocked.get("solve_10_boards", false)).is_false()

func test_counter_does_not_unlock_twice() -> void:
	var received: Array = []
	var connector := func(id: String, _stars: int) -> void:
		if id == "solve_10_boards":
			received.append(id)
	AchievementManager.achievement_unlocked.connect(connector)
	for i in range(15):
		GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
	AchievementManager.achievement_unlocked.disconnect(connector)
	assert_int(received.size()).is_equal(1)

func test_add_stars_called_on_unlock() -> void:
	var stars_before: int = SkillTree.stars
	for i in range(10):
		GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 0})
	assert_int(SkillTree.stars).is_equal(stars_before + 1)
