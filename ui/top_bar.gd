extends HBoxContainer

const COIN_COLOR: Color = Color(1, 0.8, 0.1, 1)
const PRESTIGE_COLOR: Color = Color(1, 0, 0.67, 1)
const TIMER_COLOR: Color = Color(0, 0.94, 1, 1)

@onready var coins_label: Label = $CoinsLabel
@onready var prestige_label: Label = $PrestigeLabel
@onready var timer_label: Label = $TimerLabel

var _elapsed: float = 0.0

func _ready() -> void:
	coins_label.add_theme_color_override("font_color", COIN_COLOR)
	coins_label.add_theme_font_size_override("font_size", 20)
	prestige_label.add_theme_color_override("font_color", PRESTIGE_COLOR)
	prestige_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", TIMER_COLOR)
	timer_label.add_theme_font_size_override("font_size", 18)
	Economy.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Economy.coins)
	SkillTree.stars_changed.connect(_on_stars_changed)
	_on_stars_changed(SkillTree.stars)
	var diff_btn: OptionButton = $DifficultyButton
	diff_btn.add_item("Casual (×1.0)", 0)
	diff_btn.add_item("Standard (×1.5)", 1)
	diff_btn.add_item("Hardcore (×2.5)", 2)
	diff_btn.item_selected.connect(_on_difficulty_changed)
	var modes := ["casual", "standard", "hardcore"]
	diff_btn.select(modes.find(Economy.difficulty_mode))

func _process(delta: float) -> void:
	_elapsed += delta
	var m: int = int(_elapsed) / 60
	var s: int = int(_elapsed) % 60
	timer_label.text = "%02d:%02d" % [m, s]

func _on_coins_changed(new_total: float) -> void:
	coins_label.text = "%d" % int(new_total)

func _on_stars_changed(new_total: int) -> void:
	prestige_label.text = "%d" % new_total

func reset_timer() -> void:
	_elapsed = 0.0

func _on_difficulty_changed(index: int) -> void:
	var modes := ["casual", "standard", "hardcore"]
	Economy.difficulty_mode = modes[index]
