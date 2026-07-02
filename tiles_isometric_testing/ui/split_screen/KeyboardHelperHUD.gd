extends PanelContainer
class_name KeyboardHelperHUD

@export var player_id: int = 1

var _keys: Dictionary = {}

const ASSET_PATH = "res://assets/Paper Keys Sprite Pack V2/keyboard_style_a/single/"

var key_config = {
	1: {
		"up": {"key": KEY_W, "tex": "w_paper.png", "pressed_tex": "w_pressed_paper.png"},
		"left": {"key": KEY_A, "tex": "a_paper.png", "pressed_tex": "a_pressed_paper.png"},
		"down": {"key": KEY_S, "tex": "s_paper.png", "pressed_tex": "s_pressed_paper.png"},
		"right": {"key": KEY_D, "tex": "d_paper.png", "pressed_tex": "d_pressed_paper.png"},
		"action": {"key": KEY_F, "tex": "f_paper.png", "pressed_tex": "f_pressed_paper.png", "label": "Action (F)"},
		"cancel": {"key": KEY_X, "tex": "x_paper.png", "pressed_tex": "x_pressed_paper.png", "label": "Cancel (X)"},
		"end_turn": {"key": KEY_R, "tex": "r_paper.png", "pressed_tex": "r_pressed_paper.png", "label": "End Turn (R)"},
		"relics": {"key": KEY_TAB, "tex": "blankletter_paper.png", "pressed_tex": "blankletter_pressed_paper.png", "label": "Relics Focus (TAB)", "overlay": "TAB"},
		"skill1": {"key": KEY_Q, "tex": "q_paper.png", "pressed_tex": "q_pressed_paper.png", "label": "Skill 1 (Q)"},
		"skill2": {"key": KEY_E, "tex": "e_paper.png", "pressed_tex": "e_pressed_paper.png", "label": "Skill 2 (E)"},
		"inv": {"key": KEY_C, "tex": "c_paper.png", "pressed_tex": "c_pressed_paper.png", "label": "Inventory (C)"},
		"stats": {"key": KEY_Z, "tex": "z_paper.png", "pressed_tex": "z_pressed_paper.png", "label": "Stats (Z)"},
		"toggle_hud": {"key": KEY_H, "tex": "h_paper.png", "pressed_tex": "h_pressed_paper.png", "label": "Toggle HUD (H)"}
	},
	2: {
		"up": {"key": KEY_I, "tex": "i_paper.png", "pressed_tex": "i_pressed_paper.png"},
		"left": {"key": KEY_J, "tex": "j_paper.png", "pressed_tex": "j_pressed_paper.png"},
		"down": {"key": KEY_K, "tex": "k_paper.png", "pressed_tex": "k_pressed_paper.png"},
		"right": {"key": KEY_L, "tex": "L_paper.png", "pressed_tex": "L_pressed_paper.png"},
		"action": {"key": KEY_SEMICOLON, "tex": "blankletter_paper.png", "pressed_tex": "blankletter_pressed_paper.png", "label": "Action (;)", "overlay": ";"},
		"cancel": {"key": KEY_COMMA, "tex": "blankletter_paper.png", "pressed_tex": "blankletter_pressed_paper.png", "label": "Cancel (,)", "overlay": ","},
		"end_turn": {"key": KEY_P, "tex": "p_paper.png", "pressed_tex": "p__pressed_paper.png", "label": "End Turn (P)"},
		"relics": {"key": KEY_Y, "tex": "y_paper.png", "pressed_tex": "y_pressed_paper.png", "label": "Relics Focus (Y)"},
		"skill1": {"key": KEY_U, "tex": "u_paper.png", "pressed_tex": "u_pressed_paper.png", "label": "Skill 1 (U)"},
		"skill2": {"key": KEY_O, "tex": "o_paper.png", "pressed_tex": "o_pressed_paper.png", "label": "Skill 2 (O)"},
		"inv": {"key": KEY_PERIOD, "tex": "blankletter_paper.png", "pressed_tex": "blankletter_pressed_paper.png", "label": "Inventory (.)", "overlay": "."},
		"stats": {"key": KEY_M, "tex": "m_paper.png", "pressed_tex": "m_pressed_paper.png", "label": "Stats (M)"},
		"toggle_hud": {"key": KEY_H, "tex": "h_paper.png", "pressed_tex": "h_pressed_paper.png", "label": "Toggle HUD (H)"}
	}
}

func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(430, 185)
	
	_build_hud()

func _build_hud() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_hbox)
	
	# Col 1: MOVE (Grid)
	var move_vbox = VBoxContainer.new()
	move_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(move_vbox)
	
	var move_lbl = Label.new()
	move_lbl.text = "MOVE"
	move_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_lbl.add_theme_font_size_override("font_size", 11)
	move_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.8))
	move_vbox.add_child(move_lbl)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	move_vbox.add_child(grid)
	
	var p_cfg = key_config[player_id]
	
	grid.add_child(Control.new())
	grid.add_child(_create_key_node("up", p_cfg["up"]))
	grid.add_child(Control.new())
	grid.add_child(_create_key_node("left", p_cfg["left"]))
	grid.add_child(_create_key_node("down", p_cfg["down"]))
	grid.add_child(_create_key_node("right", p_cfg["right"]))
	
	# Separator 1
	var sep1 = VSeparator.new()
	main_hbox.add_child(sep1)
	
	# Col 2: COMBAT ACTIONS (Single column list)
	var combat_vbox = VBoxContainer.new()
	combat_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(combat_vbox)
	
	var combat_lbl = Label.new()
	combat_lbl.text = "COMBAT"
	combat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_lbl.add_theme_font_size_override("font_size", 11)
	combat_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6, 0.8))
	combat_vbox.add_child(combat_lbl)
	
	var combat_list = VBoxContainer.new()
	combat_list.add_theme_constant_override("separation", 4)
	combat_vbox.add_child(combat_list)
	
	combat_list.add_child(_create_action_row("action", p_cfg["action"]))
	combat_list.add_child(_create_action_row("cancel", p_cfg["cancel"]))
	combat_list.add_child(_create_action_row("end_turn", p_cfg["end_turn"]))
	combat_list.add_child(_create_action_row("relics", p_cfg["relics"]))
	
	# Separator 2
	var sep2 = VSeparator.new()
	main_hbox.add_child(sep2)
	
	# Col 3: SKILLS & MENU (Single column list)
	var menu_vbox = VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(menu_vbox)
	
	var menu_lbl = Label.new()
	menu_lbl.text = "SKILLS & MENU"
	menu_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_lbl.add_theme_font_size_override("font_size", 11)
	menu_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6, 0.8))
	menu_vbox.add_child(menu_lbl)
	
	var menu_list = VBoxContainer.new()
	menu_list.add_theme_constant_override("separation", 4)
	menu_vbox.add_child(menu_list)
	
	menu_list.add_child(_create_action_row("skill1", p_cfg["skill1"]))
	menu_list.add_child(_create_action_row("skill2", p_cfg["skill2"]))
	menu_list.add_child(_create_action_row("inv", p_cfg["inv"]))
	menu_list.add_child(_create_action_row("stats", p_cfg["stats"]))
	menu_list.add_child(_create_action_row("toggle_hud", p_cfg["toggle_hud"]))

func _create_key_node(id: String, cfg: Dictionary) -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = load(ASSET_PATH + cfg["tex"])
	tr.custom_minimum_size = Vector2(28, 28)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.pivot_offset = Vector2(14, 14)
	
	if cfg.has("overlay"):
		var lbl = Label.new()
		lbl.text = cfg["overlay"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color.BLACK)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.add_child(lbl)
		
	_keys[id] = {
		"node": tr,
		"key": cfg["key"],
		"tex": load(ASSET_PATH + cfg["tex"]),
		"pressed_tex": load(ASSET_PATH + cfg["pressed_tex"])
	}
	return tr

func _create_action_row(id: String, cfg: Dictionary) -> HBoxContainer:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	
	var tr = _create_key_node(id, cfg)
	hb.add_child(tr)
	
	var lbl = Label.new()
	lbl.text = cfg["label"]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hb.add_child(lbl)
	
	return hb

func _process(_delta: float) -> void:
	for id in _keys:
		var info = _keys[id]
		var is_pressed = Input.is_key_pressed(info["key"])
		var tr = info["node"] as TextureRect
		if is_pressed:
			tr.texture = info["pressed_tex"]
			tr.scale = Vector2(0.85, 0.85)
			tr.modulate = Color(1.2, 1.2, 1.2)
		else:
			tr.texture = info["tex"]
			tr.scale = Vector2(1.0, 1.0)
			tr.modulate = Color(1.0, 1.0, 1.0)
