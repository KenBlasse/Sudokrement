extends HBoxContainer

signal menu_requested()
signal mode_changed(mode: String)

const COIN_COLOR: Color = Color(1, 0.8, 0.1, 1)
const PRESTIGE_COLOR: Color = Color(1, 0, 0.67, 1)
const TIMER_COLOR: Color = Color(0, 0.94, 1, 1)
const LIVES_COLOR: Color = Color(1, 0.4, 0.55, 1)

@onready var coins_label: Label = $CoinsLabel
@onready var prestige_label: Label = $PrestigeLabel
@onready var timer_label: Label = $TimerLabel
@onready var menu_button: Button = $MenuButton
@onready var lives_label: Label = $LivesLabel
@onready var lives_icon: TextureRect = $LivesIcon

var _elapsed: float = 0.0

func _ready() -> void:
	coins_label.add_theme_color_override("font_color", COIN_COLOR)
	coins_label.add_theme_font_size_override("font_size", 20)
	prestige_label.add_theme_color_override("font_color", PRESTIGE_COLOR)
	prestige_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", TIMER_COLOR)
	timer_label.add_theme_font_size_override("font_size", 18)
	lives_label.add_theme_color_override("font_color", LIVES_COLOR)
	lives_label.add_theme_font_size_override("font_size", 18)
	Economy.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Economy.coins)
	SkillTree.stars_changed.connect(_on_stars_changed)
	_on_stars_changed(SkillTree.stars)
	menu_button.pressed.connect(func(): menu_requested.emit())
	var diff_btn: OptionButton = $DifficultyButton
	diff_btn.add_item("Casual (×1.0)", 0)
	diff_btn.add_item("Standard (×1.5)", 1)
	diff_btn.add_item("Hardcore (×2.5)", 2)
	diff_btn.tooltip_text = (
		"Casual ×1.0 — Fehler werden sofort rot markiert, keine Strafe.\n"
		+ "Standard ×1.5 — 3 Leben pro Board. Bei 0 Leben startet ein neues Board.\n"
		+ "Hardcore ×2.5 — Falsche Eingaben werden NICHT markiert. Wenn das Board voll ist, wird geprüft: ein Fehler → Board verworfen."
	)
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
	_pop(coins_label)

func _pop(label: Label) -> void:
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector2(1.25, 1.25), 0.08).from(Vector2(1, 1))
	t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	label.pivot_offset = label.size * 0.5

func _on_stars_changed(new_total: int) -> void:
	prestige_label.text = "%d" % new_total

func reset_timer() -> void:
	_elapsed = 0.0

func _on_difficulty_changed(index: int) -> void:
	var modes := ["casual", "standard", "hardcore"]
	Economy.difficulty_mode = modes[index]
	mode_changed.emit(modes[index])

func set_lives(lives: int) -> void:
	if lives < 0:
		lives_label.text = ""
		lives_icon.visible = false
	else:
		lives_label.text = "%d" % lives
		lives_icon.visible = true
