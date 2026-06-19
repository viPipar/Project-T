extends Control

@export var show_stats_default: bool = false

var _stats_label: RichTextLabel
var _refresh_timer: float = 0.0

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_resizing: bool = false
var _resize_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Hide legacy nodes
	for c in get_children():
		c.visible = false
		c.queue_free()

	_build_ui()
	_connect_bus()
	_refresh_stats()

func _build_ui() -> void:
	# Main container
	var main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(PRESET_FULL_RECT)
	main_panel.anchor_right = 1.0
	main_panel.anchor_bottom = 1.0
	main_panel.offset_right = 0
	main_panel.offset_bottom = 0
	main_panel.custom_minimum_size = Vector2(700, 450)
	main_panel.position = Vector2(0, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	main_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header
	var header = MarginContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)
	vbox.add_child(header)

	var header_lbl = Label.new()
	header_lbl.text = "🛠️ DEVELOPER CONSOLE"
	header_lbl.add_theme_font_size_override("font_size", 18)
	header_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_lbl)

	# Tab Container
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	tab_style.corner_radius_bottom_left = 8
	tab_style.corner_radius_bottom_right = 8
	tabs.add_theme_stylebox_override("panel", tab_style)
	vbox.add_child(tabs)
	
	# Resize Handle
	var resize_handle = ColorRect.new()
	resize_handle.color = Color(1, 1, 1, 0.15)
	resize_handle.custom_minimum_size = Vector2(25, 25)
	resize_handle.size_flags_horizontal = Control.SIZE_SHRINK_END
	resize_handle.size_flags_vertical = Control.SIZE_SHRINK_END
	resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	resize_handle.gui_input.connect(_on_resize_gui_input)
	main_panel.add_child(resize_handle)

	# --- TAB 1: System Info ---
	var tab_info = MarginContainer.new()
	tab_info.name = "Information & Toggles"
	tab_info.add_theme_constant_override("margin_left", 10)
	tab_info.add_theme_constant_override("margin_top", 10)
	tabs.add_child(tab_info)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 15)
	tab_info.add_child(info_vbox)
	
	var info_text = RichTextLabel.new()
	info_text.bbcode_enabled = true
	info_text.fit_content = true
	info_text.text = """[b]Controls:[/b]
[color=#aaa]- [b]P1 Move:[/b] WASD | [b]Confirm:[/b] E | [b]End Turn:[/b] Q[/color]
[color=#aaa]- [b]P2 Move:[/b] IJKL | [b]Confirm:[/b] O | [b]End Turn:[/b] U[/color]

[b]Hotkeys:[/b]
[color=#aaa]- [b]F1:[/b] Main Console
- [b]F2:[/b] Dice Sandbox
- [b]F3:[/b] Debug Grid
- [b]F4:[/b] Stat Debug Manipulator
- [b]T:[/b] Run All System Tests[/color]"""
	info_vbox.add_child(info_text)

	# Toggles Grid
	var toggle_hbox = HBoxContainer.new()
	toggle_hbox.add_theme_constant_override("separation", 10)
	info_vbox.add_child(toggle_hbox)
	
	var btn_style_toggle = StyleBoxFlat.new()
	btn_style_toggle.bg_color = Color(0.2, 0.6, 0.3, 0.8)
	btn_style_toggle.set_corner_radius_all(6)
	
	var btn_stat = Button.new()
	btn_stat.text = " 🎛 Open STATS Manipulator "
	btn_stat.add_theme_stylebox_override("normal", btn_style_toggle)
	btn_stat.pressed.connect(func():
		var main = get_tree().current_scene
		if main and main.get("_stat_debug_panel") != null:
			var p = main.get("_stat_debug_panel")
			p.visible = not p.visible
	)
	toggle_hbox.add_child(btn_stat)

	var btn_dice = Button.new()
	btn_dice.text = " 🎲 Open Dice Sandbox "
	btn_dice.add_theme_stylebox_override("normal", btn_style_toggle)
	btn_dice.pressed.connect(func():
		var main = get_tree().current_scene
		if main:
			main.set("_show_dice_sandbox", not main.get("_show_dice_sandbox"))
			if main.has_method("_apply_debug_visibility"): main.call("_apply_debug_visibility")
	)
	toggle_hbox.add_child(btn_dice)

	var btn_grid = Button.new()
	btn_grid.text = " ▦ Toggle Debug Grid "
	btn_grid.add_theme_stylebox_override("normal", btn_style_toggle)
	btn_grid.pressed.connect(func():
		var main = get_tree().current_scene
		if main:
			main.set("_show_debug_grid", not main.get("_show_debug_grid"))
			if main.has_method("_apply_debug_visibility"): main.call("_apply_debug_visibility")
	)
	toggle_hbox.add_child(btn_grid)
	
	# Cheats HBox
	var cheats_hbox = HBoxContainer.new()
	cheats_hbox.add_theme_constant_override("separation", 10)
	info_vbox.add_child(cheats_hbox)
	
	var btn_infinite_moves = CheckButton.new()
	btn_infinite_moves.text = "♾️ Infinite Player Movement"
	btn_infinite_moves.toggled.connect(func(toggled: bool):
		var bridge = get_tree().get_root().find_child("CombatTestBridge", true, false)
		if bridge:
			if bridge.get("_p1_mov"): bridge.get("_p1_mov").infinite_moves = toggled
			if bridge.get("_p2_mov"): bridge.get("_p2_mov").infinite_moves = toggled
		
		# Apply to actual grid walkers
		for p in get_tree().get_nodes_in_group("players"):
			if p.has_node("MovementComponent"):
				p.get_node("MovementComponent").infinite_moves = toggled
	)
	cheats_hbox.add_child(btn_infinite_moves)

	# --- TAB 2: Combat Stats ---
	var tab_stats = MarginContainer.new()
	tab_stats.name = "Live Stats"
	tab_stats.add_theme_constant_override("margin_left", 10)
	tab_stats.add_theme_constant_override("margin_top", 10)
	tabs.add_child(tab_stats)
	
	var stats_scroll = ScrollContainer.new()
	tab_stats.add_child(stats_scroll)
	
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(_stats_label)

	# --- TAB 3: Item Sandbox ---
	var tab_items = MarginContainer.new()
	tab_items.name = "Item Sandbox"
	tab_items.add_theme_constant_override("margin_left", 10)
	tab_items.add_theme_constant_override("margin_top", 10)
	tabs.add_child(tab_items)
	
	var items_vbox = VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 15)
	tab_items.add_child(items_vbox)
	
	var item_lbl = Label.new()
	item_lbl.text = "Select an item to inject into player inventories:"
	items_vbox.add_child(item_lbl)
	
	var item_picker = OptionButton.new()
	item_picker.custom_minimum_size = Vector2(200, 30)
	items_vbox.add_child(item_picker)
	
	var item_list = []
	if ItemRegistry != null and ItemRegistry.get("items") != null:
		for key in ItemRegistry.items.keys():
			item_picker.add_item(key)
			item_list.append(key)
	else:
		item_list = ["iron_sword", "potion_small", "magic_ring", "berserker_axe", "cursed_amulet"]
		for i in item_list:
			item_picker.add_item(i)

	var hbox_btns = HBoxContainer.new()
	hbox_btns.add_theme_constant_override("separation", 10)
	items_vbox.add_child(hbox_btns)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.4, 0.8, 0.8)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	
	var p1_add = Button.new()
	p1_add.text = " Give P1 "
	p1_add.add_theme_stylebox_override("normal", btn_style)
	p1_add.pressed.connect(func(): if InventoryManager != null: InventoryManager.add_item(1, item_list[item_picker.selected]))
	hbox_btns.add_child(p1_add)
	
	var p2_add = Button.new()
	p2_add.text = " Give P2 "
	p2_add.add_theme_stylebox_override("normal", btn_style)
	p2_add.pressed.connect(func(): if InventoryManager != null: InventoryManager.add_item(2, item_list[item_picker.selected]))
	hbox_btns.add_child(p2_add)

	# --- TAB 4: Roguelite Events ---
	var tab_events = MarginContainer.new()
	tab_events.name = "Roguelite Events"
	tab_events.add_theme_constant_override("margin_left", 10)
	tab_events.add_theme_constant_override("margin_top", 10)
	tab_events.add_theme_constant_override("margin_right", 10)
	tab_events.add_theme_constant_override("margin_bottom", 10)
	tabs.add_child(tab_events)
	
	var ev_scroll = ScrollContainer.new()
	tab_events.add_child(ev_scroll)
	
	var ev_vbox = VBoxContainer.new()
	ev_vbox.add_theme_constant_override("separation", 10)
	ev_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_scroll.add_child(ev_vbox)

	var btn_map = Button.new()
	btn_map.text = "🗺️ Open Roguelite Map Generator"
	btn_map.add_theme_color_override("font_color", Color.AQUA)
	btn_map.pressed.connect(func():
		var shell_scene = load("res://ui/roguelike/RoguelikeUIShell.tscn")
		if shell_scene:
			var shell_inst = shell_scene.instantiate()
			get_tree().current_scene.add_child(shell_inst)
			shell_inst.show_screen("res://ui/roguelike/MapScreen.tscn")
			self.visible = false # hide debug menu
	)
	ev_vbox.add_child(btn_map)
	
	var btn_run_win = Button.new()
	btn_run_win.text = "🏆 Trigger RUN VICTORY (End Game)"
	btn_run_win.add_theme_color_override("font_color", Color.GOLD)
	btn_run_win.pressed.connect(func():
		if RunManager != null:
			RunManager.is_run_active = true # Force active so we can end it
			RunManager.end_run(true)
	)
	ev_vbox.add_child(btn_run_win)
	
	var btn_run_lose = Button.new()
	btn_run_lose.text = "💀 Trigger GAME OVER (Run Failed)"
	btn_run_lose.add_theme_color_override("font_color", Color.RED)
	btn_run_lose.pressed.connect(func():
		if RunManager != null:
			RunManager.is_run_active = true
			RunManager.end_run(false)
	)
	ev_vbox.add_child(btn_run_lose)

	var btn_win = Button.new()
	btn_win.text = "🏆 Trigger Battle Win (Give Items)"
	btn_win.pressed.connect(func():
		var h = WinLoseHandler.new()
		get_tree().current_scene.add_child(h)
		h.handle_win("normal")
		h.queue_free()
	)
	ev_vbox.add_child(btn_win)

	var btn_boss_win = Button.new()
	btn_boss_win.text = "👑 Trigger Boss Win State (Full Heal + Items)"
	btn_boss_win.pressed.connect(func():
		var h = WinLoseHandler.new()
		get_tree().current_scene.add_child(h)
		h.handle_win("boss")
		h.queue_free()
	)
	ev_vbox.add_child(btn_boss_win)
	
	var btn_lose = Button.new()
	btn_lose.text = "💀 Trigger Lose State (-50% HP + Curse)"
	btn_lose.pressed.connect(func():
		var h = WinLoseHandler.new()
		get_tree().current_scene.add_child(h)
		h.handle_lose()
		h.queue_free()
	)
	ev_vbox.add_child(btn_lose)

	var btn_rest_full = Button.new()
	btn_rest_full.text = "⛺ Rest: Full Heal (P1)"
	btn_rest_full.pressed.connect(func():
		var h = RestLootHandler.new()
		get_tree().current_scene.add_child(h)
		h.handle_rest_choice(1, 0) # FULL_HEAL
		h.queue_free()
	)
	ev_vbox.add_child(btn_rest_full)

	var btn_luck_win = Button.new()
	btn_luck_win.text = "🍀 Luck Event: Win (Random Item)"
	btn_luck_win.pressed.connect(func():
		var h = LuckEventHandler.new()
		get_tree().current_scene.add_child(h)
		h._apply_reward_or_penalty({"reward": "random_item"})
		h.queue_free()
	)
	ev_vbox.add_child(btn_luck_win)
	
	var btn_luck_lose = Button.new()
	btn_luck_lose.text = "💥 Luck Event: Lose (-5 HP)"
	btn_luck_lose.pressed.connect(func():
		var h = LuckEventHandler.new()
		get_tree().current_scene.add_child(h)
		h._apply_reward_or_penalty({"reward": "damage", "amount": 5})
		h.queue_free()
	)
	ev_vbox.add_child(btn_luck_lose)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.5:
		_refresh_timer = 0.0
		_refresh_stats()

func _connect_bus() -> void:
	if EventBus != null:
		if not EventBus.stats_changed.is_connected(_refresh_stats_signal):
			EventBus.stats_changed.connect(_refresh_stats_signal)
		if not EventBus.class_changed.is_connected(_refresh_class_signal):
			EventBus.class_changed.connect(_refresh_class_signal)
		if not EventBus.buffs_changed.is_connected(_refresh_buffs_signal):
			EventBus.buffs_changed.connect(_refresh_buffs_signal)

func _refresh_stats_signal(_entity: Node) -> void: _refresh_stats()
func _refresh_class_signal(_entity: Node, _class_id: String) -> void: _refresh_stats()
func _refresh_buffs_signal(_entity: Node) -> void: _refresh_stats()

func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var bbcode = ""
	
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		bbcode += "[b]Players:[/b] (none)\n"
	else:
		for p in players:
			bbcode += _format_entity_stats(p, "P") + "\n"

	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		bbcode += "[b]Enemies:[/b] (none)\n"
	else:
		for e in enemies:
			bbcode += _format_entity_stats(e, "E") + "\n"

	_stats_label.text = bbcode

func _format_entity_stats(entity: Node, prefix: String) -> String:
	var name := ""
	var pid := -1
	if entity != null:
		name = str(_safe_get(entity, "char_name", ""))
		if name == "": name = str(_safe_get(entity, "enemy_name", ""))
		if name == "": name = entity.name
		var raw_pid = _safe_get(entity, "player_id", -1)
		if typeof(raw_pid) == TYPE_INT: pid = raw_pid

	var class_title := "Unknown"
	var buffs_text := "(none)"

	var class_comp := entity.get_node_or_null("ClassComponent") as ClassComponent
	if class_comp != null:
		var class_data := class_comp.get_primary_class()
		class_title = class_data.get("name", "Unknown")
		var buffs := class_comp.get_all_buffs()
		if not buffs.is_empty():
			var names: Array[String] = []
			for b in buffs: names.append(b.get("name", b.get("buff_id", "buff")))
			buffs_text = ", ".join(names)

	var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
	var health := entity.get_node_or_null("HealthComponent") as HealthComponent
	
	var hp_text := ""
	if health != null: hp_text = "HP %d/%d" % [health.current_hp, health.max_hp]
	
	var stat_line := ""
	var derived_line := ""
	if stats != null:
		stat_line = "[color=#88ff88]VIT[/color] %d [color=#ff8888]STR[/color] %d [color=#8888ff]INT[/color] %d CON %d ACC %d DEX %d MOV %d ATT %d LCK %d" % [
			stats.get_stat("vit"), stats.get_stat("str"), stats.get_stat("int"),
			stats.get_stat("con"), stats.get_stat("acc"), stats.get_stat("dex"),
			stats.get_stat("mov"), stats.get_stat("att"), stats.get_stat("lck")
		]
		if hp_text == "": hp_text = "MaxHP %d" % stats.get_max_hp()
		derived_line = "%s | Dmg(P/M) %d/%d | ARM %d RES %d | AP+%d Mv+%d Hit+%d Crit-%d | Slots %d/%d/%d" % [
			hp_text, stats.get_stat("physical_damage"), stats.get_stat("magical_damage"), stats.get_armor(), stats.get_resist(),
			stats.bonus_action_points(), stats.bonus_movement_tiles(),
			stats.hit_roll_bonus(), stats.crit_roll_reduction(),
			stats.get_spell_slots_l1(), stats.get_spell_slots_l2(), stats.get_spell_slots_l3()
		]

	var header = "[b][color=#ffffaa]%s %s[/color][/b] | Class: [color=#aaaaff]%s[/color]" % [prefix, name, class_title]
	if prefix == "P" and pid >= 0:
		header = "[b][color=#aaffaa]%s%d %s[/color][/b] | Class: [color=#aaaaff]%s[/color]" % [prefix, pid, name, class_title]
	
	var items_text := "(none)"
	if pid >= 1 and InventoryManager != null:
		var inv = InventoryManager.get_player_items(pid)
		if not inv.is_empty(): items_text = ", ".join(inv)
	
	var res = header + "\n"
	res += "[color=#cccccc]Items:[/color] " + items_text + "\n"
	res += "[color=#cccccc]Buffs:[/color] " + buffs_text + "\n"
	if stat_line != "":
		res += stat_line + "\n"
		res += "[color=#bbbbbb]" + derived_line + "[/color]\n"
	elif hp_text != "":
		res += "[color=#ffaaaa]" + hp_text + "[/color]\n"
	return res

func _safe_get(entity: Node, prop: String, fallback) -> Variant:
	if entity == null: return fallback
	for info in entity.get_property_list():
		if info.name == prop: return entity.get(prop)
	return fallback

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_offset = event.global_position - self.global_position
		else:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		self.global_position = event.global_position - _drag_offset

func _on_resize_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_resizing = true
			_resize_offset = event.global_position - self.size
		else:
			_is_resizing = false
	elif event is InputEventMouseMotion and _is_resizing:
		self.size = event.global_position - _resize_offset
