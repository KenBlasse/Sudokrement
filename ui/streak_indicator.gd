extends HBoxContainer

const STREAK_COLOR: Color = Color(1, 0.84, 0.2, 1)

@onready var label: Label = $StreakLabel
@onready var bar: ProgressBar = $TimerBar

func _ready() -> void:
	label.add_theme_color_override("font_color", STREAK_COLOR)
	label.add_theme_font_size_override("font_size", 18)
	StreakManager.streak_changed.connect(_on_streak_changed)
	_apply(StreakManager.count, StreakManager.multiplier, StreakManager.time_left, StreakManager.WINDOW_SEC)

func _process(_delta: float) -> void:
	if StreakManager.count > 0:
		bar.value = StreakManager.time_left

func _on_streak_changed(count: int, multiplier: float, time_left: float, window: float) -> void:
	_apply(count, multiplier, time_left, window)

func _apply(count: int, multiplier: float, time_left: float, window: float) -> void:
	visible = count > 0
	if count == 0:
		return
	label.text = "Streak %d ×%.1f" % [count, multiplier]
	bar.max_value = window
	bar.value = time_left
