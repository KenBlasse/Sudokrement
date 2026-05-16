extends Node

signal coins_changed(new_total: float)

const DIFFICULTY_MULT: Dictionary = {
	"casual":   1.0,
	"standard": 1.5,
	"hardcore": 2.5,
}

const COMBO_BONUS: Dictionary = {
	"row":    10.0,
	"column": 10.0,
	"block":  20.0,
}

const BOARD_COMPLETE_BONUS: float = 100.0

const PERMANENT_MULT_BASE: float = 0.15

var coins: float = 0.0
var permanent_multiplier: float = 1.0
var run_multiplier: float = 1.0
var difficulty_mode: String = "casual"

func _recompute_permanent_multiplier(total_stars: int) -> void:
	var stars: int = max(total_stars, 0)
	permanent_multiplier = 1.0 + PERMANENT_MULT_BASE * log(1.0 + float(stars))

func reset() -> void:
	coins = 0.0
	run_multiplier = 1.0
	coins_changed.emit(coins)

func _effective_multiplier() -> float:
	return DIFFICULTY_MULT.get(difficulty_mode, 1.0) * permanent_multiplier * run_multiplier

func award_cell() -> void:
	coins += 1.0 * _effective_multiplier()
	coins_changed.emit(coins)

func award_combo(combo_type: String) -> void:
	var bonus: float = COMBO_BONUS.get(combo_type, 0.0)
	coins += bonus * _effective_multiplier()
	coins_changed.emit(coins)

func award_board_complete(speed_bonus: float) -> void:
	coins += (BOARD_COMPLETE_BONUS + speed_bonus) * _effective_multiplier()
	coins_changed.emit(coins)

func serialize() -> Dictionary:
	return {
		"coins": coins,
		"permanent_multiplier": permanent_multiplier,
		"difficulty_mode": difficulty_mode,
	}

func deserialize(data: Dictionary) -> void:
	coins = data.get("coins", 0.0)
	permanent_multiplier = data.get("permanent_multiplier", 1.0)
	difficulty_mode = data.get("difficulty_mode", "casual")
	coins_changed.emit(coins)
