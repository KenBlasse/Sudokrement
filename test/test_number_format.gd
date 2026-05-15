extends GdUnitTestSuite

func test_under_threshold_no_suffix() -> void:
	assert_str(NumberFormat.coins(0.0)).is_equal("0")
	assert_str(NumberFormat.coins(42.0)).is_equal("42")
	assert_str(NumberFormat.coins(999.0)).is_equal("999")
	assert_str(NumberFormat.coins(999.9)).is_equal("999")

func test_threshold_boundary() -> void:
	assert_str(NumberFormat.coins(1000.0)).is_equal("1.0K")

func test_k_range() -> void:
	assert_str(NumberFormat.coins(1234.0)).is_equal("1.2K")
	assert_str(NumberFormat.coins(12345.0)).is_equal("12.3K")
	assert_str(NumberFormat.coins(123456.0)).is_equal("123.5K")
