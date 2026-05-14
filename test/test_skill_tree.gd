extends GdUnitTestSuite

var tree: Node

func before_test() -> void:
	tree = load("res://systems/skill_tree.gd").new()
	add_child(tree)
	tree.reset()

func test_starts_with_no_nodes_unlocked():
	assert_bool(tree.is_unlocked("naked_single")).is_equal(false)

func test_starts_with_zero_stars():
	assert_int(tree.stars).is_equal(0)

func test_unlock_requires_enough_stars():
	var ok: bool = tree.unlock("naked_single")
	assert_bool(ok).is_equal(false)

func test_unlock_succeeds_when_stars_available():
	tree.stars = 5
	var ok: bool = tree.unlock("naked_single")
	assert_bool(ok).is_equal(true)
	assert_bool(tree.is_unlocked("naked_single")).is_equal(true)
	assert_int(tree.stars).is_equal(4)

func test_unlock_blocked_by_prerequisite():
	tree.stars = 10
	var ok: bool = tree.unlock("hidden_single")
	assert_bool(ok).is_equal(false)

func test_unlock_succeeds_with_prerequisite():
	tree.stars = 10
	tree.unlock("naked_single")
	var ok: bool = tree.unlock("hidden_single")
	assert_bool(ok).is_equal(true)
