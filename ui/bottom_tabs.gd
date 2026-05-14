extends TabContainer

func _ready() -> void:
	var shop_icon: Texture2D = load("res://assets/icons/shop.svg")
	var skill_icon: Texture2D = load("res://assets/icons/skilltree.svg")
	var prestige_icon: Texture2D = load("res://assets/icons/prestige.svg")
	for i in range(get_tab_count()):
		var name: String = get_tab_title(i)
		match name:
			"Shop":
				set_tab_icon(i, shop_icon)
			"SkillTree":
				set_tab_icon(i, skill_icon)
			"Prestige":
				set_tab_icon(i, prestige_icon)
