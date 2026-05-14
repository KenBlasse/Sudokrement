extends VBoxContainer

@onready var status_label: Label = $StatusLabel
@onready var stars_label: Label = $StarsLabel
@onready var prestige_button: Button = $PrestigeButton

func _ready() -> void:
	prestige_button.pressed.connect(_on_prestige_pressed)
	Economy.coins_changed.connect(_refresh)
	PrestigeManager.prestiged.connect(_on_prestiged)
	_refresh(Economy.coins)

func _refresh(_ignored: float = 0.0) -> void:
	var done: int = PrestigeManager.boards_solved_current_tier
	var target: int = PrestigeManager.BOARDS_PER_PRESTIGE
	status_label.text = "Progress: %d/%d boards" % [done, target]
	stars_label.text = "Stars on prestige: %d" % PrestigeManager.calculate_stars()
	prestige_button.disabled = not PrestigeManager.can_prestige()

func _on_prestige_pressed() -> void:
	PrestigeManager.prestige()
	_refresh()

func _on_prestiged(_stars: int) -> void:
	_refresh()
