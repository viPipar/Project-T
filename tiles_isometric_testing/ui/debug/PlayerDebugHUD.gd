extends MarginContainer

var player_id: int = 1
var label: RichTextLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	add_child(bg)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	bg.add_child(margin)
	
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Provide a fallback standard font size 
	label.add_theme_font_size_override("normal_font_size", 12)
	label.add_theme_font_size_override("bold_font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)

func _process(_delta: float) -> void:
	var main = get_tree().current_scene
	if main != null and ("_show_f3_debug" in main or main.get("_show_f3_debug") != null):
		visible = main.get("_show_f3_debug")
		
	if not visible:
		return
		
	var fps = Engine.get_frames_per_second()
	var text = "[b][color=#55ff55]P%d Debug (F3)[/color][/b]\n" % player_id
	text += "FPS: %d\n" % fps
	if GridManager != null:
		text += "Current Map: %d\n" % GridManager.current_map_id
	
	
	# 1. Player Stats
	var player_node = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.get("player_id") == player_id:
			player_node = p
			break
			
	if player_node:
		var hp = player_node.get_node_or_null("HealthComponent")
		if hp:
			var armor = 0
			var resist = 0
			if StatSystem != null:
				armor = StatSystem.get_armor(player_node)
				resist = StatSystem.get_resist(player_node)
			text += "HP: %d/%d | ARM: %d RES: %d\n" % [hp.current_hp, hp.max_hp, armor, resist]
			
		var grid_pos = player_node.get("grid_pos")
		if grid_pos != null:
			text += "Player Pos: (%d, %d)\n" % [grid_pos.x, grid_pos.y]
	else:
		text += "Player: Not spawned\n"
		
	# 2. Cursor Position
	var cursor_pos = Vector2i(-1, -1)
	for c in get_tree().get_root().find_children("*", "Node2D", true, false):
		if c.get_script() != null and c.get_script().resource_path.ends_with("KeyboardTileCursor.gd"):
			if c.get("player_id") == player_id:
				cursor_pos = c.get_hovered_tile()
				break
				
	text += "Cursor: (%d, %d)\n" % [cursor_pos.x, cursor_pos.y]
	
	# 3. Hovered Entity / Tile
	if cursor_pos.x >= 0 and GridManager != null:
		var hovered_entity = GridManager.get_entity_at(cursor_pos)
		if hovered_entity:
			var e_name = hovered_entity.get("char_name")
			if not e_name: e_name = hovered_entity.get("enemy_name")
			if not e_name: e_name = hovered_entity.name
			
			var ehp = hovered_entity.get_node_or_null("HealthComponent")
			if ehp:
				text += "Looking At: %s (HP %d/%d)\n" % [e_name, ehp.current_hp, ehp.max_hp]
			else:
				text += "Looking At: %s\n" % e_name
		else:
			if GridManager.is_walkable(cursor_pos):
				text += "Looking At: Floor\n"
			else:
				text += "Looking At: Obstacle/Wall\n"
	else:
		text += "Looking At: None\n"
		
	# 4. Turn & Active Skill
	if TurnManager != null:
		var is_ended = TurnManager.is_player_ended(player_id)
		var state_str = "WAITING" if is_ended else "ACTIVE"
		var phase_str = "PLAYERS" if TurnManager.phase == TurnManager.Phase.PLAYERS else "ENEMIES"
		text += "State: %s (Phase %s)\n" % [state_str, phase_str]
		
	var active_skill = "None"
	var bridge = get_tree().get_root().find_child("CombatTestBridge", true, false)
	if bridge:
		var action_mgr = bridge.get("_p%d_action" % player_id)
		if action_mgr and action_mgr.get("primed_ability") != null:
			var ability = action_mgr.primed_ability
			active_skill = ability.get("ability_name") if ability.get("ability_name") else "Unknown Skill"
			
	text += "Primed Skill: %s\n" % active_skill
	
	label.text = text
