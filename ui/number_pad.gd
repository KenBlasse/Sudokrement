extends HBoxContainer

signal number_pressed(value: int)
signal erase_pressed()

const BUTTON_SIZE: Vector2 = Vector2(44, 44)

func _ready() -> void:
	for n in range(1, 10):
		var btn := Button.new()
		btn.text = str(n)
		btn.custom_minimum_size = BUTTON_SIZE
		btn.pressed.connect(_on_number.bind(n))
		add_child(btn)
	var erase := Button.new()
	erase.text = "X"
	erase.custom_minimum_size = BUTTON_SIZE
	erase.pressed.connect(_on_erase)
	add_child(erase)

func _on_number(value: int) -> void:
	number_pressed.emit(value)

func _on_erase() -> void:
	erase_pressed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed:
		return
	var key: int = event.keycode
	if key >= KEY_1 and key <= KEY_9:
		number_pressed.emit(key - KEY_0)
		get_viewport().set_input_as_handled()
	elif key == KEY_BACKSPACE or key == KEY_DELETE or key == KEY_0:
		erase_pressed.emit()
		get_viewport().set_input_as_handled()
