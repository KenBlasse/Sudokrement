extends HBoxContainer

@onready var coins_label: Label = $CoinsLabel
@onready var prestige_label: Label = $PrestigeLabel
@onready var timer_label: Label = $TimerLabel

var _elapsed: float = 0.0

func _ready() -> void:
	Economy.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Economy.coins)

func _process(delta: float) -> void:
	_elapsed += delta
	var m: int = int(_elapsed) / 60
	var s: int = int(_elapsed) % 60
	timer_label.text = "%02d:%02d" % [m, s]

func _on_coins_changed(new_total: float) -> void:
	coins_label.text = "Coins: %d" % int(new_total)

func reset_timer() -> void:
	_elapsed = 0.0
