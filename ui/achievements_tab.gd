extends VBoxContainer

const STAR_ICON: Texture2D = preload("res://assets/icons/star.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/lock.svg")

@onready var header_label: Label = $Header
@onready var list_container: VBoxContainer = $Scroll/List

func _ready() -> void:
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	_rebuild()

func _on_achievement_unlocked(_id: String, _stars: int) -> void:
	_rebuild()

func _rebuild() -> void:
	for child in list_container.get_children():
		child.queue_free()
	var unlocked_count: int = AchievementManager.unlocked.size()
	var total: int = AchievementManager.ACHIEVEMENTS.size()
	var earned_stars: int = 0
	for id in AchievementManager.unlocked:
		earned_stars += int(AchievementManager.ACHIEVEMENTS[id]["stars"])
	header_label.text = "Achievements (%d / %d)   ★ %d" % [unlocked_count, total, earned_stars]
	var unlocked_ids: Array = AchievementManager.unlocked.keys()
	var locked_ids: Array = []
	for id in AchievementManager.ACHIEVEMENTS:
		if not AchievementManager.unlocked.has(id):
			locked_ids.append(id)
	for id in unlocked_ids:
		_add_row(id, true)
	for id in locked_ids:
		_add_row(id, false)

func _add_row(id: String, is_unlocked: bool) -> void:
	var data: Dictionary = AchievementManager.ACHIEVEMENTS[id]
	var row := HBoxContainer.new()
	row.modulate = Color(1, 1, 1, 1.0 if is_unlocked else 0.4)
	var icon := TextureRect.new()
	icon.texture = STAR_ICON if is_unlocked else LOCK_ICON
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = data["label"]
	if is_unlocked:
		title.add_theme_color_override("font_color", Color(1, 1, 0.7))
	text_box.add_child(title)
	var desc := Label.new()
	desc.text = data["desc"]
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	text_box.add_child(desc)
	row.add_child(text_box)
	var stars_label := Label.new()
	stars_label.text = "★ %d" % int(data["stars"])
	row.add_child(stars_label)
	list_container.add_child(row)
