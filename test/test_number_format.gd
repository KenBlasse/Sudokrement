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

func test_m_tier() -> void:
	assert_str(NumberFormat.coins(1_000_000.0)).is_equal("1.0M")
	assert_str(NumberFormat.coins(2_500_000.0)).is_equal("2.5M")

func test_b_tier() -> void:
	assert_str(NumberFormat.coins(3_200_000_000.0)).is_equal("3.2B")

func test_t_tier() -> void:
	assert_str(NumberFormat.coins(1_400_000_000_000.0)).is_equal("1.4T")

func test_qa_tier() -> void:
	assert_str(NumberFormat.coins(1_000_000_000_000_000.0)).is_equal("1.0Qa")

func test_negative_value_preserves_sign() -> void:
	assert_str(NumberFormat.coins(-1500.0)).is_equal("-1.5K")

func test_nan_returns_zero() -> void:
	assert_str(NumberFormat.coins(NAN)).is_equal("0")

func test_inf_returns_zero() -> void:
	assert_str(NumberFormat.coins(INF)).is_equal("0")
	assert_str(NumberFormat.coins(-INF)).is_equal("0")
