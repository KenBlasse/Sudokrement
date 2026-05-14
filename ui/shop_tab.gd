extends VBoxContainer

signal hint_purchased()

const HINT_BASE_COST: float = 50.0
const HINT_COST_SCALING: float = 1.5

var _hint_purchases: int = 0
var hint_button: Button

func _ready() -> void:
	hint_button = Button.new()
	hint_button.text = _hint_label()
	hint_button.pressed.connect(_on_hint_pressed)
	add_child(hint_button)
	Economy.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Economy.coins)

func _hint_cost() -> float:
	return HINT_BASE_COST * pow(HINT_COST_SCALING, _hint_purchases)

func _hint_label() -> String:
	return "Hint (+1 cell) — %d coins" % int(_hint_cost())

func _on_coins_changed(total: float) -> void:
	hint_button.disabled = total < _hint_cost()
	hint_button.text = _hint_label()

func _on_hint_pressed() -> void:
	var cost: float = _hint_cost()
	if Economy.coins < cost:
		return
	Economy.coins -= cost
	Economy.coins_changed.emit(Economy.coins)
	_hint_purchases += 1
	hint_purchased.emit()
