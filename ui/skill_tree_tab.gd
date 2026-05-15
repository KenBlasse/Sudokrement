extends VBoxContainer

const STAR_ICON: Texture2D = preload("res://assets/icons/star.svg")

@onready var stars_label: Label = $StarsLabel
@onready var nodes_list: VBoxContainer = $Scroll/NodesList

var _node_buttons: Dictionary = {}

func _ready() -> void:
	stars_label.add_theme_color_override("font_color", Color(1, 0.8, 0.1, 1))
	stars_label.add_theme_font_size_override("font_size", 18)
	SkillTree.stars_changed.connect(_on_stars_changed)
	SkillTree.node_unlocked.connect(_on_node_unlocked)
	_build_nodes()
	_refresh()

func _build_nodes() -> void:
	for node_id in SkillTree.NODES.keys():
		var btn := Button.new()
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nodes_list.add_child(btn)
		btn.pressed.connect(_on_node_pressed.bind(node_id))
		_node_buttons[node_id] = btn

func _refresh() -> void:
	stars_label.text = "Stars: %d" % SkillTree.stars
	for node_id in SkillTree.NODES.keys():
		var btn: Button = _node_buttons[node_id]
		var node: Dictionary = SkillTree.NODES[node_id]
		if SkillTree.is_unlocked(node_id):
			btn.text = "%s — UNLOCKED" % node_id
			btn.icon = null
			btn.disabled = true
		else:
			btn.text = "%s (%d)" % [node_id, node["cost"]]
			btn.icon = STAR_ICON
			btn.disabled = not SkillTree.can_unlock(node_id)

func _on_node_pressed(node_id: String) -> void:
	SkillTree.unlock(node_id)
	_refresh()

func _on_stars_changed(_new_total: int) -> void:
	_refresh()

func _on_node_unlocked(_node_id: String) -> void:
	_refresh()
