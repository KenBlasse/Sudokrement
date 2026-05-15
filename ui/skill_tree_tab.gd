extends VBoxContainer

const STAR_ICON: Texture2D = preload("res://assets/icons/star.svg")

@onready var stars_label: Label = $StarsLabel
@onready var nodes_list: VBoxContainer = $Scroll/NodesList

var _node_rows: Dictionary = {}

func _ready() -> void:
	stars_label.add_theme_color_override("font_color", Color(1, 0.8, 0.1, 1))
	stars_label.add_theme_font_size_override("font_size", 18)
	SkillTree.stars_changed.connect(_on_stars_changed)
	SkillTree.node_unlocked.connect(_on_node_unlocked)
	_build_nodes()
	_refresh()

func _build_nodes() -> void:
	for node_id in SkillTree.NODES.keys():
		var row := _make_row(node_id)
		nodes_list.add_child(row)
		_node_rows[node_id] = row

func _make_row(node_id: String) -> HBoxContainer:
	var data: Dictionary = SkillTree.NODES[node_id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_line := HBoxContainer.new()
	title_line.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = data.get("label", node_id)
	title.add_theme_color_override("font_color", Color(1, 1, 0.7))
	title_line.add_child(title)
	if data.get("status", "live") == "coming_soon":
		var badge := Label.new()
		badge.text = "Coming Soon"
		badge.add_theme_color_override("font_color", Color(1, 0.5, 0.2))
		badge.add_theme_font_size_override("font_size", 11)
		title_line.add_child(badge)
	text_box.add_child(title_line)

	var desc := Label.new()
	desc.text = data.get("desc", "")
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(desc)

	row.add_child(text_box)

	var btn := Button.new()
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btn.custom_minimum_size = Vector2(110, 0)
	btn.pressed.connect(_on_node_pressed.bind(node_id))
	row.add_child(btn)

	row.set_meta("button", btn)
	return row

func _refresh() -> void:
	stars_label.text = "Stars: %d" % SkillTree.stars
	for node_id in SkillTree.NODES.keys():
		var row: HBoxContainer = _node_rows[node_id]
		var btn: Button = row.get_meta("button")
		var node: Dictionary = SkillTree.NODES[node_id]
		if SkillTree.is_unlocked(node_id):
			btn.text = "UNLOCKED"
			btn.icon = null
			btn.disabled = true
		else:
			btn.text = "%d" % node["cost"]
			btn.icon = STAR_ICON
			btn.disabled = not SkillTree.can_unlock(node_id)

func _on_node_pressed(node_id: String) -> void:
	SkillTree.unlock(node_id)
	_refresh()

func _on_stars_changed(_new_total: int) -> void:
	_refresh()

func _on_node_unlocked(_node_id: String) -> void:
	_refresh()
