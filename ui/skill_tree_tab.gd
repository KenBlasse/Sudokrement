extends VBoxContainer

@onready var stars_label: Label = $StarsLabel
@onready var nodes_list: VBoxContainer = $NodesList

var _node_buttons: Dictionary = {}

func _ready() -> void:
	SkillTree.stars_changed.connect(_on_stars_changed)
	SkillTree.node_unlocked.connect(_on_node_unlocked)
	_build_nodes()
	_refresh()

func _build_nodes() -> void:
	for node_id in SkillTree.NODES.keys():
		var btn := Button.new()
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
			btn.disabled = true
		else:
			btn.text = "%s (%d ★)" % [node_id, node["cost"]]
			btn.disabled = not SkillTree.can_unlock(node_id)

func _on_node_pressed(node_id: String) -> void:
	SkillTree.unlock(node_id)
	_refresh()

func _on_stars_changed(_new_total: int) -> void:
	_refresh()

func _on_node_unlocked(_node_id: String) -> void:
	_refresh()
