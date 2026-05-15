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

func test_event_hardcore_only_on_hardcore() -> void:
	GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 30.0, "mistakes": 0, "combos_in_board": 0})
	assert_bool(AchievementManager.unlocked.get("first_hardcore", false)).is_false()
	GameEvents.board_solved.emit({"difficulty": "hardcore", "time_seconds": 30.0, "mistakes": 0, "combos_in_board": 0})
	assert_bool(AchievementManager.unlocked.get("first_hardcore", false)).is_true()

func test_event_first_prestige() -> void:
	GameEvents.prestiged.emit(3)
	assert_bool(AchievementManager.unlocked.get("first_prestige", false)).is_true()

func test_event_solvers_branch_skill() -> void:
	GameEvents.skill_unlocked.emit("naked_single")
	assert_bool(AchievementManager.unlocked.get("unlock_solvers_branch", false)).is_true()

func test_event_economy_branch_skill_does_not_unlock_solvers_ach() -> void:
	GameEvents.skill_unlocked.emit("coin_plus_10")
	assert_bool(AchievementManager.unlocked.get("unlock_solvers_branch", false)).is_false()

func test_condition_no_mistakes_required() -> void:
	GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 2, "combos_in_board": 0})
	assert_bool(AchievementManager.unlocked.get("perfect_board", false)).is_false()
	GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 0, "combos_in_board": 0})
	assert_bool(AchievementManager.unlocked.get("perfect_board", false)).is_true()

func test_condition_speedrun_60s() -> void:
	GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 75.0, "mistakes": 5, "combos_in_board": 0})
	assert_bool(AchievementManager.unlocked.get("speedrun_60s", false)).is_false()
	GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 45.0, "mistakes": 5, "combos_in_board": 0})
	assert_bool(AchievementManager.unlocked.get("speedrun_60s", false)).is_true()

func test_condition_five_combos_in_board() -> void:
	GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 120.0, "mistakes": 5, "combos_in_board": 5})
	assert_bool(AchievementManager.unlocked.get("five_combos_one_board", false)).is_true()

func test_lifetime_coins_observed_tracks() -> void:
	PrestigeManager.record_coins(9999.0)
	assert_bool(AchievementManager.unlocked.get("earn_10k_lifetime", false)).is_false()
	PrestigeManager.record_coins(2.0)
	assert_bool(AchievementManager.unlocked.get("earn_10k_lifetime", false)).is_true()

func test_unknown_check_does_not_crash() -> void:
	AchievementManager._check_passes("nonsense_check", {})
	assert_bool(true).is_true()

func test_serialize_deserialize_roundtrip() -> void:
	AchievementManager.counters["boards_solved"] = 7
	AchievementManager.counters["combos_total"] = 42
	AchievementManager.unlocked["solve_10_boards"] = true
	var data: Dictionary = AchievementManager.serialize()
	AchievementManager.reset()
	assert_int(int(AchievementManager.counters["boards_solved"])).is_equal(0)
	AchievementManager.deserialize(data)
	assert_int(int(AchievementManager.counters["boards_solved"])).is_equal(7)
	assert_int(int(AchievementManager.counters["combos_total"])).is_equal(42)
	assert_bool(AchievementManager.unlocked.get("solve_10_boards", false)).is_true()

func test_deserialize_empty_dict_uses_defaults() -> void:
	AchievementManager.deserialize({})
	assert_int(int(AchievementManager.counters["boards_solved"])).is_equal(0)
	assert_int(int(AchievementManager.counters["combos_total"])).is_equal(0)
	assert_int(int(AchievementManager.counters["lifetime_coins_observed"])).is_equal(0)
	assert_int(AchievementManager.unlocked.size()).is_equal(0)
