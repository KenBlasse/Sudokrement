extends GdUnitTestSuite

func test_board_solved_signal_carries_dictionary() -> void:
	var received: Array = []
	var connector := func(payload: Dictionary) -> void:
		received.append(payload)
	GameEvents.board_solved.connect(connector)
	GameEvents.board_solved.emit({"difficulty": "casual", "time_seconds": 30.0, "mistakes": 0, "combos_in_board": 2})
	GameEvents.board_solved.disconnect(connector)
	assert_int(received.size()).is_equal(1)
	assert_str(received[0]["difficulty"]).is_equal("casual")
	assert_int(received[0]["mistakes"]).is_equal(0)

func test_combo_triggered_signal_carries_type() -> void:
	var received: Array = []
	var connector := func(t: String) -> void:
		received.append(t)
	GameEvents.combo_triggered.connect(connector)
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.disconnect(connector)
	assert_int(received.size()).is_equal(1)
	assert_str(received[0]).is_equal("row")

func test_prestiged_signal_carries_int() -> void:
	var received: Array = []
	var connector := func(n: int) -> void:
		received.append(n)
	GameEvents.prestiged.connect(connector)
	GameEvents.prestiged.emit(5)
	GameEvents.prestiged.disconnect(connector)
	assert_int(received[0]).is_equal(5)

func test_skill_unlocked_signal_carries_id() -> void:
	var received: Array = []
	var connector := func(id: String) -> void:
		received.append(id)
	GameEvents.skill_unlocked.connect(connector)
	GameEvents.skill_unlocked.emit("naked_single")
	GameEvents.skill_unlocked.disconnect(connector)
	assert_str(received[0]).is_equal("naked_single")
