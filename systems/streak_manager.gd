extends Node

signal streak_changed(count: int, multiplier: float, time_left: float, window: float)

const WINDOW_SEC: float = 15.0
const STEP: float = 0.2
const CAP_COUNT: int = 10
const CAP_MULT: float = 3.0

var count: int = 0
var multiplier: float = 1.0
var time_left: float = 0.0

func _ready() -> void:
	GameEvents.combo_triggered.connect(_on_combo)
	GameEvents.cell_filled.connect(_on_cell_filled)
	GameEvents.prestiged.connect(_on_prestiged)

func _process(delta: float) -> void:
	_tick(delta)

func _tick(delta: float) -> void:
	if count == 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		_reset()

func _on_combo(_combo_type: String) -> void:
	count += 1
	time_left = WINDOW_SEC
	multiplier = min(1.0 + float(count) * STEP, CAP_MULT)
	Economy.run_multiplier = multiplier
	streak_changed.emit(count, multiplier, time_left, WINDOW_SEC)

func _on_cell_filled(correct: bool) -> void:
	if not correct:
		_reset()

func _on_prestiged(_stars_gained: int) -> void:
	_reset()

func reset() -> void:
	_reset()

func _reset() -> void:
	count = 0
	multiplier = 1.0
	time_left = 0.0
	Economy.run_multiplier = 1.0
	streak_changed.emit(count, multiplier, time_left, WINDOW_SEC)
