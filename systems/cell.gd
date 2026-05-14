class_name Cell
extends RefCounted

var value: int = 0
var given: bool = false
var notes: Array[int] = []
var locked: bool = false

func _init(initial_value: int = 0, is_given: bool = false) -> void:
	value = initial_value
	given = is_given
