extends Node

signal board_solved(payload: Dictionary)
signal combo_triggered(combo_type: String)
signal cell_filled(correct: bool)
signal prestiged(stars_gained: int)
signal skill_unlocked(node_id: String)
