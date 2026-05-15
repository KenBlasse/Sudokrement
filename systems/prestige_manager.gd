extends Node

signal prestiged(stars_gained: int)
signal lifetime_coins_changed(new_total: float)

const BOARDS_PER_PRESTIGE: int = 25

var lifetime_coins: float = 0.0
var boards_solved_current_tier: int = 0
var prestige_count: int = 0

func reset() -> void:
	lifetime_coins = 0.0
	boards_solved_current_tier = 0
	prestige_count = 0

func record_coins(amount: float) -> void:
	lifetime_coins += amount
	lifetime_coins_changed.emit(lifetime_coins)

func record_board_solved() -> void:
	boards_solved_current_tier += 1

func calculate_stars() -> int:
	return int(floor(sqrt(lifetime_coins / 1000.0)))

func can_prestige() -> bool:
	return boards_solved_current_tier >= BOARDS_PER_PRESTIGE

func prestige() -> int:
	if not can_prestige():
		return 0
	var gained: int = calculate_stars()
	SkillTree.add_stars(gained)
	Economy.permanent_multiplier += gained * 0.01
	Economy.reset()
	prestige_count += 1
	boards_solved_current_tier = 0
	prestiged.emit(gained)
	GameEvents.prestiged.emit(gained)
	return gained

func serialize() -> Dictionary:
	return {
		"lifetime_coins": lifetime_coins,
		"boards_solved_current_tier": boards_solved_current_tier,
		"prestige_count": prestige_count,
	}

func deserialize(data: Dictionary) -> void:
	lifetime_coins = data.get("lifetime_coins", 0.0)
	boards_solved_current_tier = data.get("boards_solved_current_tier", 0)
	prestige_count = data.get("prestige_count", 0)
