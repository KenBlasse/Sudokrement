extends Node

signal node_unlocked(node_id: String)
signal stars_changed(new_total: int)

const NODES: Dictionary = {
	"naked_single":  {"cost": 1,  "requires": [],                "branch": "solvers",     "status": "coming_soon", "label": "Naked Single",  "desc": "Markiert Zellen, in die nur eine Ziffer passt."},
	"hidden_single": {"cost": 2,  "requires": ["naked_single"],  "branch": "solvers",     "status": "coming_soon", "label": "Hidden Single", "desc": "Markiert Ziffern, die nur in eine Zelle ihrer Gruppe passen."},
	"pointing_pair": {"cost": 3,  "requires": ["hidden_single"], "branch": "solvers",     "status": "coming_soon", "label": "Pointing Pair", "desc": "Markiert Pointing-Pair-Konstellationen."},
	"coin_plus_10":  {"cost": 2,  "requires": [],                "branch": "economy",     "status": "coming_soon", "label": "Goldgriff",     "desc": "+10 % Coins pro Aktion."},
	"combo_1_5x":    {"cost": 3,  "requires": ["coin_plus_10"],  "branch": "economy",     "status": "coming_soon", "label": "Kettenmeister", "desc": "Combos geben ×1.5 statt ×1 Coins."},
	"tier_medium":   {"cost": 5,  "requires": [],                "branch": "progression", "status": "live",        "label": "Mittelstufe",   "desc": "Schaltet Schwierigkeitsstufe Medium frei."},
	"tier_hard":     {"cost": 10, "requires": ["tier_medium"],   "branch": "progression", "status": "live",        "label": "Profistufe",    "desc": "Schaltet Schwierigkeitsstufe Hard frei."},
}

var stars: int = 0
var unlocked: Dictionary = {}

func reset() -> void:
	stars = 0
	unlocked.clear()
	stars_changed.emit(stars)

func is_unlocked(node_id: String) -> bool:
	return unlocked.get(node_id, false) == true

func can_unlock(node_id: String) -> bool:
	if is_unlocked(node_id):
		return false
	var node: Dictionary = NODES.get(node_id, {})
	if node.is_empty():
		return false
	if stars < node["cost"]:
		return false
	for req in node["requires"]:
		if not is_unlocked(req):
			return false
	return true

func unlock(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	var node: Dictionary = NODES[node_id]
	stars -= node["cost"]
	unlocked[node_id] = true
	node_unlocked.emit(node_id)
	stars_changed.emit(stars)
	GameEvents.skill_unlocked.emit(node_id)
	return true

func add_stars(amount: int) -> void:
	stars += amount
	stars_changed.emit(stars)

func serialize() -> Dictionary:
	return {"stars": stars, "unlocked": unlocked.duplicate()}

func deserialize(data: Dictionary) -> void:
	stars = data.get("stars", 0)
	unlocked = data.get("unlocked", {}).duplicate()
	stars_changed.emit(stars)
