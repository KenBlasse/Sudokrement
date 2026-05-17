extends GdUnitTestSuite

func before_test() -> void:
	StreakManager.reset()
	Economy.reset()

func test_combo_increments_count_and_multiplier() -> void:
	GameEvents.combo_triggered.emit("row")
	assert_int(StreakManager.count).is_equal(1)
	assert_float(StreakManager.multiplier).is_equal_approx(1.2, 0.001)
	GameEvents.combo_triggered.emit("column")
	GameEvents.combo_triggered.emit("block")
	assert_int(StreakManager.count).is_equal(3)
	assert_float(StreakManager.multiplier).is_equal_approx(1.6, 0.001)
