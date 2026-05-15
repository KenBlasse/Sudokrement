extends Control

const MAX_VISIBLE: int = 5
const FADE_IN: float = 0.3
const HOLD: float = 2.5
const FADE_OUT: float = 0.5
const STAR_ICON: Texture2D = preload("res://assets/icons/star.svg")

@onready var stack: VBoxContainer = $Stack

var _queue: Array[Dictionary] = []

func _ready() -> void:
	AchievementManager.achievement_unlocked.connect(_on_unlocked)

func _on_unlocked(id: String, stars: int) -> void:
	if stack.get_child_count() >= MAX_VISIBLE:
		_queue.append({"id": id, "stars": stars})
		return
	_spawn(id, stars)

func _spawn(id: String, stars: int) -> void:
	var data: Dictionary = AchievementManager.ACHIEVEMENTS[id]
	var panel := PanelContainer.new()
	panel.modulate = Color(1, 1, 1, 0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	panel.add_child(hb)
	var icon := TextureRect.new()
	icon.texture = STAR_ICON
	icon.custom_minimum_size = Vector2(20, 20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)
	var label := Label.new()
	label.text = "Achievement: %s" % data["label"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(label)
	var stars_label := Label.new()
	stars_label.text = "★ +%d" % stars
	hb.add_child(stars_label)
	stack.add_child(panel)
	SoundManager.achievement()
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, FADE_IN)
	tw.tween_interval(HOLD)
	tw.tween_property(panel, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(func() -> void:
		panel.queue_free()
		_drain_queue())

func _drain_queue() -> void:
	if _queue.is_empty():
		return
	if stack.get_child_count() >= MAX_VISIBLE:
		return
	var next: Dictionary = _queue.pop_front()
	_spawn(next["id"], next["stars"])
