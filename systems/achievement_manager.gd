extends Node

signal achievement_unlocked(id: String, stars: int)

const ACHIEVEMENTS: Dictionary = {
	"solve_10_boards":     {"type": "counter", "counter": "boards_solved",            "threshold": 10,     "stars": 1, "label": "Routine",         "desc": "10 Boards gelöst"},
	"solve_50_boards":     {"type": "counter", "counter": "boards_solved",            "threshold": 50,     "stars": 2, "label": "Veteran",         "desc": "50 Boards gelöst"},
	"combo_100_total":     {"type": "counter", "counter": "combos_total",             "threshold": 100,    "stars": 1, "label": "Comboliebhaber",  "desc": "100 Combos ausgelöst"},
	"earn_10k_lifetime":   {"type": "counter", "counter": "lifetime_coins_observed",  "threshold": 10000,  "stars": 1, "label": "Sparbuch",        "desc": "10.000 Coins lifetime verdient"},
	"first_hardcore":      {"type": "event", "event": "board_solved",     "check": "difficulty_hardcore", "stars": 2, "label": "Mutprobe",     "desc": "Erstes Hardcore-Board gelöst"},
	"first_prestige":      {"type": "event", "event": "prestiged",        "check": "",                    "stars": 2, "label": "Wiedergeburt", "desc": "Erstes Prestige"},
	"unlock_solvers_branch": {"type": "event", "event": "skill_unlocked", "check": "branch_solvers",      "stars": 1, "label": "Theoretiker",  "desc": "Ersten Solver-Skill freigeschaltet"},
	"perfect_board":         {"type": "condition", "event": "board_solved", "check": "no_mistakes",          "stars": 1, "label": "Makellos",       "desc": "Board ohne Fehler gelöst"},
	"speedrun_60s":          {"type": "condition", "event": "board_solved", "check": "under_60s",            "stars": 2, "label": "Blitzlöser",     "desc": "Board unter 60 Sek gelöst"},
	"five_combos_one_board": {"type": "condition", "event": "board_solved", "check": "five_combos_in_board", "stars": 1, "label": "Kettenreaktion", "desc": "5 Combos in einem Board"},
}

var counters: Dictionary = {
	"boards_solved": 0,
	"combos_total": 0,
	"lifetime_coins_observed": 0,
}
var unlocked: Dictionary = {}

func _ready() -> void:
	GameEvents.board_solved.connect(_on_board_solved)
	GameEvents.combo_triggered.connect(_on_combo_triggered)
	GameEvents.prestiged.connect(_on_prestiged)
	GameEvents.skill_unlocked.connect(_on_skill_unlocked)
	PrestigeManager.lifetime_coins_changed.connect(_on_lifetime_coins_changed)

func reset() -> void:
	counters = {"boards_solved": 0, "combos_total": 0, "lifetime_coins_observed": 0}
	unlocked = {}

func _on_board_solved(payload: Dictionary) -> void:
	counters["boards_solved"] = int(counters.get("boards_solved", 0)) + 1
	_evaluate_counter("boards_solved")
	_evaluate_event("board_solved", payload)
	_evaluate_condition("board_solved", payload)

func _on_combo_triggered(_combo_type: String) -> void:
	counters["combos_total"] = int(counters.get("combos_total", 0)) + 1
	_evaluate_counter("combos_total")

func _on_prestiged(_stars_gained: int) -> void:
	_evaluate_event("prestiged", {})

func _on_skill_unlocked(node_id: String) -> void:
	_evaluate_event("skill_unlocked", {"node_id": node_id})

func _on_lifetime_coins_changed(new_total: float) -> void:
	var lifetime: int = int(floor(new_total))
	if lifetime > int(counters.get("lifetime_coins_observed", 0)):
		counters["lifetime_coins_observed"] = lifetime
		_evaluate_counter("lifetime_coins_observed")

func _evaluate_counter(counter_key: String) -> void:
	var current: int = int(counters.get(counter_key, 0))
	for id in ACHIEVEMENTS:
		var a: Dictionary = ACHIEVEMENTS[id]
		if a["type"] != "counter":
			continue
		if a["counter"] != counter_key:
			continue
		if unlocked.get(id, false):
			continue
		if current >= int(a["threshold"]):
			_unlock(id)

func _evaluate_event(event_name: String, payload: Dictionary) -> void:
	for id in ACHIEVEMENTS:
		var a: Dictionary = ACHIEVEMENTS[id]
		if a["type"] != "event":
			continue
		if a.get("event", "") != event_name:
			continue
		if unlocked.get(id, false):
			continue
		if not _check_passes(a.get("check", ""), payload):
			continue
		_unlock(id)

func _evaluate_condition(event_name: String, payload: Dictionary) -> void:
	for id in ACHIEVEMENTS:
		var a: Dictionary = ACHIEVEMENTS[id]
		if a["type"] != "condition":
			continue
		if a.get("event", "") != event_name:
			continue
		if unlocked.get(id, false):
			continue
		if not _check_passes(a.get("check", ""), payload):
			continue
		_unlock(id)

func _check_passes(check: String, payload: Dictionary) -> bool:
	match check:
		"":
			return true
		"difficulty_hardcore":
			return payload.get("difficulty", "") == "hardcore"
		"branch_solvers":
			var node_id: String = payload.get("node_id", "")
			var node: Dictionary = SkillTree.NODES.get(node_id, {})
			return node.get("branch", "") == "solvers"
		"no_mistakes":
			return int(payload.get("mistakes", -1)) == 0
		"under_60s":
			return float(payload.get("time_seconds", INF)) < 60.0
		"five_combos_in_board":
			return int(payload.get("combos_in_board", 0)) >= 5
		_:
			push_warning("AchievementManager: unknown check '%s'" % check)
			return false

func _unlock(id: String) -> void:
	unlocked[id] = true
	var stars: int = int(ACHIEVEMENTS[id]["stars"])
	SkillTree.add_stars(stars)
	achievement_unlocked.emit(id, stars)

func serialize() -> Dictionary:
	return {
		"counters": counters.duplicate(),
		"unlocked": unlocked.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	counters = data.get("counters", {}).duplicate()
	unlocked = data.get("unlocked", {}).duplicate()
	for key in ["boards_solved", "combos_total", "lifetime_coins_observed"]:
		if not counters.has(key):
			counters[key] = 0
