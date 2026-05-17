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

func test_multiplier_caps_at_three() -> void:
	for i in range(15):
		GameEvents.combo_triggered.emit("row")
	assert_int(StreakManager.count).is_equal(15)
	assert_float(StreakManager.multiplier).is_equal_approx(3.0, 0.001)

func test_wrong_cell_resets() -> void:
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.emit("row")
	assert_int(StreakManager.count).is_equal(2)
	GameEvents.cell_filled.emit(false)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.multiplier).is_equal_approx(1.0, 0.001)

func test_correct_cell_does_not_reset() -> void:
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.emit("row")
	GameEvents.cell_filled.emit(true)
	assert_int(StreakManager.count).is_equal(2)

func test_time_expires_resets() -> void:
	GameEvents.combo_triggered.emit("row")
	StreakManager._tick(16.0)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.multiplier).is_equal_approx(1.0, 0.001)

func test_combo_refreshes_window() -> void:
	GameEvents.combo_triggered.emit("row")
	StreakManager._tick(10.0)
	GameEvents.combo_triggered.emit("row")
	StreakManager._tick(10.0)
	assert_int(StreakManager.count).is_equal(2)

func test_prestige_resets() -> void:
	GameEvents.combo_triggered.emit("row")
	GameEvents.combo_triggered.emit("row")
	GameEvents.prestiged.emit(5)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.multiplier).is_equal_approx(1.0, 0.001)

func test_tick_early_returns_when_count_zero() -> void:
	StreakManager._tick(100.0)
	assert_int(StreakManager.count).is_equal(0)
	assert_float(StreakManager.time_left).is_equal_approx(0.0, 0.001)

func test_combo_updates_economy_run_multiplier() -> void:
	for i in range(5):
		GameEvents.combo_triggered.emit("row")
	assert_float(Economy.run_multiplier).is_equal_approx(2.0, 0.001)

func test_reset_restores_economy_run_multiplier() -> void:
	GameEvents.combo_triggered.emit("row")
	assert_float(Economy.run_multiplier).is_equal_approx(1.2, 0.001)
	GameEvents.cell_filled.emit(false)
	assert_float(Economy.run_multiplier).is_equal_approx(1.0, 0.001)
