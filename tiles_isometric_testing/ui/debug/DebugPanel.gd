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

	# Move self to a top-level CanvasLayer so it always renders above RoguelikeUIShell (layer 100)
	if is_inside_tree() and not get_parent() is CanvasLayer:
		var layer = CanvasLayer.new()
		layer.layer = 128
		layer.name = "DebugCanvasLayer"
		var p = get_parent()
		# We must defer reparenting so we don't mess up the scene tree during ready propagation
		call_deferred("_reparent_to_layer", p, layer)

	_build_ui()
	_connect_bus()
	_refresh_stats()

func _reparent_to_layer(old_parent: Node, layer: CanvasLayer) -> void:
	old_parent.remove_child(self)
	old_parent.add_child(layer)
	layer.add_child(self)

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
[color=#aaa]- [b]P1 Move:[/b] WASD | [b]Action:[/b] F | [b]Cancel:[/b] X | [b]End Turn:[/b] R[/color]
[color=#aaa]- [b]P2 Move:[/b] IJKL | [b]Action:[/b] ; | [b]Cancel:[/b] , | [b]End Turn:[/b] P[/color]

[b]Hotkeys:[/b]
[color=#aaa]- [b]F1:[/b] Main Console
- [b]F2:[/b] Dice Sandbox
- [b]F3:[/b] Debug Grid
- [b]F4:[/b] Stat Debug Manipulator
- [b]T:[/b] Run All System Tests[/color]

[b]Developer Tips & Cheats:[/b]
[color=#aaa]- [b]Map Teleport:[/b] Hold [b]SHIFT[/b] and click any node on the Map to bypass path restrictions and teleport directly to it.
- [b]Free Coins:[/b] Go to the 'Roguelite Events' tab to instantly grant 1000 coins for Shop testing.
- [b]UI Glass Mode:[/b] Go to the 'Config' tab to lower the opacity of the black backgrounds for any of the debug panels.[/color]"""
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
			if is_instance_valid(main) and main.has_method("_apply_debug_visibility"): main.call("_apply_debug_visibility")
	)
	toggle_hbox.add_child(btn_dice)

	var btn_grid = Button.new()
	btn_grid.text = " ▦ Toggle Debug Grid "
	btn_grid.add_theme_stylebox_override("normal", btn_style_toggle)
	btn_grid.pressed.connect(func():
		var main = get_tree().current_scene
		if main:
			main.set("_show_debug_grid", not main.get("_show_debug_grid"))
			if is_instance_valid(main) and main.has_method("_apply_debug_visibility"): main.call("_apply_debug_visibility")
	)
	toggle_hbox.add_child(btn_grid)
	
	var btn_f3 = Button.new()
	btn_f3.text = " 📊 Toggle F3 Debug HUD "
	btn_f3.add_theme_stylebox_override("normal", btn_style_toggle)
	btn_f3.pressed.connect(func():
		var main = get_tree().current_scene
		if main:
			main.set("_show_f3_debug", not main.get("_show_f3_debug"))
	)
	toggle_hbox.add_child(btn_f3)
	
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
	tab_items.add_theme_constant_override("margin_right", 10)
	tab_items.add_theme_constant_override("margin_bottom", 10)
	tabs.add_child(tab_items)
	
	var items_vbox = VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 10)
	tab_items.add_child(items_vbox)
	
	var player_hbox = HBoxContainer.new()
	player_hbox.add_theme_constant_override("separation", 10)
	items_vbox.add_child(player_hbox)
	
	var select_lbl = Label.new()
	select_lbl.text = "Target Player:"
	player_hbox.add_child(select_lbl)
	
	var target_picker = OptionButton.new()
	target_picker.add_item("Player 1 (Fighter)")
	target_picker.add_item("Player 2 (Wizard)")
	target_picker.selected = 0
	player_hbox.add_child(target_picker)
	
	var click_lbl = Label.new()
	click_lbl.text = "(Hover over icons for details, click to grant item)"
	click_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	items_vbox.add_child(click_lbl)
	
	var items_scroll = ScrollContainer.new()
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_vbox.add_child(items_scroll)
	
	var items_grid = GridContainer.new()
	items_grid.columns = 10
	items_grid.add_theme_constant_override("h_separation", 8)
	items_grid.add_theme_constant_override("v_separation", 8)
	items_scroll.add_child(items_grid)
	
	var all_item_ids = StatDataDB.get_item_ids()
	for item_id in all_item_ids:
		var item_data = ItemRegistry.get_item(item_id)
		if item_data.is_empty():
			continue
			
		var item_btn = Button.new()
		item_btn.custom_minimum_size = Vector2(50, 50)
		item_btn.expand_icon = true
		
		var icon_path = item_data.get("icon_path", "res://assets/ui_assets/placeholder.jpeg")
		item_btn.icon = load(icon_path)
		
		var rarity_name = "Common"
		match int(item_data.get("rarity", 0)):
			1: rarity_name = "Rare"
			2: rarity_name = "Epic"
			3: rarity_name = "Legendary"
			4: rarity_name = "Cursed"
				
		item_btn.tooltip_text = "%s\n(%s)\n\n%s" % [item_data.name, rarity_name, item_data.get("description", "")]
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
		btn_style.border_width_left = 2
		btn_style.border_width_right = 2
		btn_style.border_width_top = 2
		btn_style.border_width_bottom = 2
		
		var b_color = Color(1, 1, 1, 0.7)
		match int(item_data.get("rarity", 0)):
			1: b_color = Color(0.2, 0.5, 0.9, 0.8)
			2: b_color = Color(0.7, 0.2, 0.9, 0.8)
			3: b_color = Color(0.9, 0.7, 0.1, 0.8)
			4: b_color = Color(0.5, 0.1, 0.7, 0.8)
		btn_style.border_color = b_color
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.corner_radius_bottom_right = 4
		
		item_btn.add_theme_stylebox_override("normal", btn_style)
		item_btn.add_theme_stylebox_override("hover", btn_style)
		
		item_btn.pressed.connect(func():
			var target_player = target_picker.selected + 1
			if InventoryManager != null:
				InventoryManager.add_item(target_player, item_id)
		)
		
		items_grid.add_child(item_btn)

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

	# --- TAB 6: VFX Test ---
	var tab_vfx = MarginContainer.new()
	tab_vfx.name = "VFX Test"
	tab_vfx.add_theme_constant_override("margin_left", 10)
	tab_vfx.add_theme_constant_override("margin_top", 10)
	tab_vfx.add_theme_constant_override("margin_right", 10)
	tab_vfx.add_theme_constant_override("margin_bottom", 10)
	tabs.add_child(tab_vfx)
	
	var vfx_scroll = ScrollContainer.new()
	tab_vfx.add_child(vfx_scroll)
	
	var vfx_vbox = VBoxContainer.new()
	vfx_vbox.add_theme_constant_override("separation", 8)
	vfx_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vfx_scroll.add_child(vfx_vbox)
	
	# ── Target Pickers ──
	var picker_hbox = HBoxContainer.new()
	picker_hbox.add_theme_constant_override("separation", 10)
	vfx_vbox.add_child(picker_hbox)
	
	var pkr_lbl1 = Label.new()
	pkr_lbl1.text = "Caster:"
	picker_hbox.add_child(pkr_lbl1)
	var caster_picker = OptionButton.new()
	caster_picker.add_item("(auto)", 0)
	caster_picker.add_item("Player 1", 1)
	caster_picker.add_item("Player 2", 2)
	caster_picker.add_item("First Enemy", 3)
	caster_picker.selected = 0
	picker_hbox.add_child(caster_picker)
	
	var pkr_lbl2 = Label.new()
	pkr_lbl2.text = " Target:"
	picker_hbox.add_child(pkr_lbl2)
	var vfx_target = OptionButton.new()
	vfx_target.add_item("(auto)", 0)
	vfx_target.add_item("Player 1", 1)
	vfx_target.add_item("Player 2", 2)
	vfx_target.add_item("First Enemy", 3)
	vfx_target.selected = 0
	picker_hbox.add_child(vfx_target)
	
	# Helper lambdas
	var _vfx_ctrl := func() -> Node:
		var bridge = get_tree().current_scene.get_node_or_null("CombatTestBridge")
		return bridge.get("vfx_controller") if bridge else null
	
	var _resolve_node := func(pick_val: int) -> Node:
		match pick_val:
			1, 2:
				for p in get_tree().get_nodes_in_group("players"):
					if p.get("player_id") == pick_val:
						return p
				return null
			3:
				var es = get_tree().get_nodes_in_group("enemies")
				return es[0] if es.size() > 0 else null
			_:
				return null
	
	var _shake_all := func(power: float) -> void:
		for c in get_tree().get_nodes_in_group("cameras"):
			if c.has_method("shake"):
				c.shake(clampf(power * 0.06, 0.2, 1.0), 0.5 if power > 12.0 else 0.35)
	
	var mk_cat = func(title: String) -> void:
		var lbl = Label.new()
		lbl.text = title
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		vfx_vbox.add_child(lbl)
	
	var mk_btn = func(text: String, color: Color, fn: Callable) -> void:
		var btn = Button.new()
		btn.text = text
		btn.add_theme_color_override("font_color", color)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(fn)
		vfx_vbox.add_child(btn)
	
	mk_cat.call("── SCREEN SHAKE ──")
	mk_btn.call("💥 Light Shake", Color.CORNSILK, func(): _shake_all.call(4.0))
	mk_btn.call("💥 Medium Shake", Color.YELLOW, func(): _shake_all.call(10.0))
	mk_btn.call("💥 Heavy Shake", Color.ORANGE, func(): _shake_all.call(18.0))
	mk_btn.call("💥 BOSS Shake (25)", Color.RED, func(): _shake_all.call(25.0))
	mk_btn.call("💥 Impact Flash Only", Color.WHITE, func():
		if ScreenEffects != null:
			ScreenEffects.impact_flash(Color(1, 0.9, 0.7, 1), 0.7, 0.3)
	)
	
	mk_cat.call("── VFX CONFIG ──")

	set_meta("vfx_cfg_scale", 1.0)
	set_meta("vfx_cfg_ox", 0.0)
	set_meta("vfx_cfg_oy", 0.0)

	var _apply_debug_vfx_config := func(ctrl: Node):
		if ctrl and ctrl.has_method("_play_skill_cast_vfx"):
			ctrl.debug_scale_multiplier = get_meta("vfx_cfg_scale")
			ctrl.debug_offset = Vector2(get_meta("vfx_cfg_ox"), get_meta("vfx_cfg_oy"))

	var cfg_row1 = HBoxContainer.new()
	cfg_row1.add_theme_constant_override("separation", 6)
	vfx_vbox.add_child(cfg_row1)

	var cfg_scale_val = Label.new()
	cfg_scale_val.text = "1.0"
	cfg_scale_val.custom_minimum_size = Vector2(26, 0)

	var cfg_ox_val = Label.new()
	cfg_ox_val.text = "0"
	cfg_ox_val.custom_minimum_size = Vector2(26, 0)

	var cfg_oy_val = Label.new()
	cfg_oy_val.text = "0"
	cfg_oy_val.custom_minimum_size = Vector2(26, 0)

	var cfg_scale_lbl = Label.new()
	cfg_scale_lbl.text = "Scl"
	cfg_scale_lbl.custom_minimum_size = Vector2(20, 0)
	cfg_row1.add_child(cfg_scale_lbl)

	var cfg_scale = HSlider.new()
	cfg_scale.custom_minimum_size = Vector2(80, 0)
	cfg_scale.min_value = 0.1
	cfg_scale.max_value = 5.0
	cfg_scale.step = 0.1
	cfg_scale.value = 1.0
	cfg_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cfg_row1.add_child(cfg_scale)
	cfg_scale.value_changed.connect(func(v):
		set_meta("vfx_cfg_scale", v)
		cfg_scale_val.text = "%.1f" % v
		_apply_debug_vfx_config.call(_vfx_ctrl.call())
	)

	cfg_row1.add_child(cfg_scale_val)

	var cfg_ox_lbl = Label.new()
	cfg_ox_lbl.text = "OX"
	cfg_ox_lbl.custom_minimum_size = Vector2(16, 0)
	cfg_row1.add_child(cfg_ox_lbl)

	var cfg_ox = HSlider.new()
	cfg_ox.custom_minimum_size = Vector2(60, 0)
	cfg_ox.min_value = -200
	cfg_ox.max_value = 200
	cfg_ox.step = 1
	cfg_ox.value = 0
	cfg_row1.add_child(cfg_ox)
	cfg_ox.value_changed.connect(func(v):
		set_meta("vfx_cfg_ox", v)
		cfg_ox_val.text = "%d" % v
		_apply_debug_vfx_config.call(_vfx_ctrl.call())
	)

	cfg_row1.add_child(cfg_ox_val)

	var cfg_oy_lbl = Label.new()
	cfg_oy_lbl.text = "OY"
	cfg_oy_lbl.custom_minimum_size = Vector2(16, 0)
	cfg_row1.add_child(cfg_oy_lbl)

	var cfg_oy = HSlider.new()
	cfg_oy.custom_minimum_size = Vector2(60, 0)
	cfg_oy.min_value = -200
	cfg_oy.max_value = 200
	cfg_oy.step = 1
	cfg_oy.value = 0
	cfg_row1.add_child(cfg_oy)
	cfg_oy.value_changed.connect(func(v):
		set_meta("vfx_cfg_oy", v)
		cfg_oy_val.text = "%d" % v
		_apply_debug_vfx_config.call(_vfx_ctrl.call())
	)

	cfg_row1.add_child(cfg_oy_val)

	mk_cat.call("── SKILL CAST VFX ──")
	var vfx_tests = [
		["⚔️ PHYSICAL (big_hit)", "physical", 0, ""],
		["🔥 MAGIC FIRE (fire_ring)", "dummy", 1, "fire"],
		["💧 MAGIC WATER (wavy_blue)", "dummy", 1, "water"],
		["🌪️ MAGIC WIND (wavy_purple)", "dummy", 1, "wind"],
		["⚡ MAGIC ELECTRIC (electric_ring)", "dummy", 1, "electric"],
		["✨ MAGIC OTHER (star_explosion)", "dummy", 1, "arcane"],
		["🔧 UTILITY (charge_7x6)", "dummy", 2, ""],
		["🌀 UTILITY (vortex_6x5)", "epimorphic", 0, ""],
		["🌟 UTILITY (lightstreaks_6x5)", "divine_departure", 0, ""],
		["👑 BOSS (explosion_6x5)", "boss_cleave", 0, ""],
	]
	for vt in vfx_tests:
		var btn = Button.new()
		btn.text = vt[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tag = vt[1]
		var atype = vt[2]
		var el = vt[3]
		btn.pressed.connect(func():
			var ctrl = _vfx_ctrl.call()
			var target = _resolve_node.call(caster_picker.selected)
			if target == null:
				var ps = get_tree().get_nodes_in_group("players")
				target = ps[0] if ps.size() > 0 else null
			if ctrl and ctrl.has_method("_play_skill_cast_vfx") and target:
				_apply_debug_vfx_config.call(ctrl)
				var offset = Vector2(get_meta("vfx_cfg_ox"), get_meta("vfx_cfg_oy"))
				if offset.length_squared() > 0:
					var dummy = Node2D.new()
					dummy.global_position = target.global_position + offset
					get_tree().current_scene.add_child(dummy)
					ctrl._play_skill_cast_vfx(dummy, tag, atype, el)
					await get_tree().create_timer(1.0).timeout
					if is_instance_valid(dummy):
						dummy.queue_free()
				else:
					ctrl._play_skill_cast_vfx(target, tag, atype, el)
			else:
				var msg = "no target found" if target == null else "CombatVFXController not found"
				EventNotifier.show_message("VFX: " + msg, Color.RED)
		)
		vfx_vbox.add_child(btn)
	
	mk_cat.call("── HIT VFX ──")
	var hit_elements = ["physical", "fire", "ice", "lightning", "arcane", "enemy"]
	for hel in hit_elements:
		mk_btn.call("💢 HIT: %s" % hel, Color.LIGHT_CORAL, func(el = hel):
			var ctrl = _vfx_ctrl.call()
			var target = _resolve_node.call(vfx_target.selected)
			if target == null:
				var ps = get_tree().get_nodes_in_group("players")
				target = ps[0] if ps.size() > 0 else null
			if ctrl and ctrl.has_method("_spawn_hit_vfx") and target:
				ctrl._spawn_hit_vfx(target, el)
			else:
				var msg = "no target found" if target == null else "CombatVFXController not found"
				EventNotifier.show_message("HIT VFX: " + msg, Color.RED)
		)
	
	mk_cat.call("── PROJECTILE ──")
	mk_btn.call("🎯 Fire Projectile", Color.ORANGE_RED, func():
		var ctrl = _vfx_ctrl.call()
		var src = _resolve_node.call(caster_picker.selected)
		var tgt = _resolve_node.call(vfx_target.selected)
		if src == null: src = _resolve_node.call(1)
		if tgt == null: tgt = _resolve_node.call(3)
		if ctrl and ctrl.has_method("_spawn_magic_projectile") and src and tgt:
			ctrl._spawn_magic_projectile(src, tgt, "fire")
		else:
			var msg = "need caster + target" if not (src and tgt) else "CombatVFXController not found"
			EventNotifier.show_message("Projectile VFX: " + msg, Color.RED)
	)
	mk_btn.call("🎯 Ice Projectile", Color.CYAN, func():
		var ctrl = _vfx_ctrl.call()
		var src = _resolve_node.call(caster_picker.selected)
		var tgt = _resolve_node.call(vfx_target.selected)
		if src == null: src = _resolve_node.call(1)
		if tgt == null: tgt = _resolve_node.call(3)
		if ctrl and ctrl.has_method("_spawn_magic_projectile") and src and tgt:
			ctrl._spawn_magic_projectile(src, tgt, "ice")
		else:
			var msg = "need caster + target" if not (src and tgt) else "CombatVFXController not found"
			EventNotifier.show_message("Projectile VFX: " + msg, Color.RED)
	)
	mk_btn.call("🎯 Enemy Projectile", Color.PURPLE, func():
		var ctrl = _vfx_ctrl.call()
		var src = _resolve_node.call(vfx_target.selected)
		var tgt = _resolve_node.call(caster_picker.selected)
		if src == null: src = _resolve_node.call(3)
		if tgt == null: tgt = _resolve_node.call(1)
		if ctrl and ctrl.has_method("_spawn_magic_projectile") and src and tgt:
			ctrl._spawn_magic_projectile(src, tgt, "enemy")
		else:
			var msg = "need caster + target" if not (src and tgt) else "CombatVFXController not found"
			EventNotifier.show_message("Projectile VFX: " + msg, Color.RED)
	)
	
	mk_cat.call("── ENEMY JITTER ──")
	mk_btn.call("🔀 Jitter Target Entity", Color.KHAKI, func():
		var e = _resolve_node.call(vfx_target.selected)
		if e == null:
			var es = get_tree().get_nodes_in_group("enemies")
			e = es[0] if es.size() > 0 else null
		if e and is_instance_valid(e):
			var tw = e.create_tween()
			var ox = e.position.x
			var oy = e.position.y
			tw.tween_property(e, "position:x", ox - 12, 0.03)
			tw.parallel().tween_property(e, "position:y", oy - 4, 0.03)
			tw.tween_property(e, "position:x", ox + 12, 0.03)
			tw.parallel().tween_property(e, "position:y", oy + 4, 0.03)
			tw.tween_property(e, "position:x", ox - 6, 0.03)
			tw.tween_property(e, "position:y", oy, 0.03)
			tw.tween_property(e, "position:x", ox, 0.03)
		else:
			EventNotifier.show_message("Jitter: no target entity found", Color.RED)
	)
	
	mk_cat.call("── IMPACT SOUNDS ──")
	var sfx_keys = [
		"impact_heavy_1", "impact_heavy_2", "impact_heavy_3",
		"sword_slice", "explosion_impact", "impact_thud",
		"sword_hit", "sword_miss", "spell_impact",
		"clash_impact", "damage_total_slam",
		"result_hit", "result_crit", "result_miss",
	]
	for sk in sfx_keys:
		mk_btn.call("🔊 %s" % sk, Color.ORANGE, func(key = sk):
			var am = get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_sfx"):
				am.play_sfx(key)
		)

	mk_cat.call("── VFX SANDBOX ──")
	var sandbox_row = HBoxContainer.new()
	sandbox_row.add_theme_constant_override("separation", 8)
	vfx_vbox.add_child(sandbox_row)

	var element_dropdown = OptionButton.new()
	element_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element_dropdown.custom_minimum_size = Vector2(100, 0)
	var elements = ["fire", "water", "ice", "wind", "electric", "earth", "arcane", "shadow", "holy", "poison", "enemy"]
	for el in elements:
		element_dropdown.add_item(el.capitalize())
	sandbox_row.add_child(element_dropdown)

	var mc_scale_slider = HSlider.new()
	mc_scale_slider.custom_minimum_size = Vector2(80, 0)
	mc_scale_slider.min_value = 0.3
	mc_scale_slider.max_value = 3.0
	mc_scale_slider.step = 0.1
	mc_scale_slider.value = 1.0
	mc_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sandbox_row.add_child(mc_scale_slider)

	var btn_magic_circle = Button.new()
	btn_magic_circle.text = "✨ Spawn Magic Circle"
	btn_magic_circle.custom_minimum_size = Vector2(0, 36)
	btn_magic_circle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sandbox_row.add_child(btn_magic_circle)
	btn_magic_circle.pressed.connect(func():
		var el_name = elements[element_dropdown.selected]
		var mc = Node2D.new()
		mc.set_script(preload("res://combat_core/tests/MagicCircleVFX.gd"))
		var pos = Vector2(400, 300)
		var cam = get_viewport().get_camera_2d()
		if cam: pos = cam.get_screen_center()
		pos += Vector2(get_meta("vfx_cfg_ox"), get_meta("vfx_cfg_oy"))
		mc.setup(el_name, pos, mc_scale_slider.value * get_meta("vfx_cfg_scale"))
		get_tree().current_scene.add_child(mc)
	)

	var burst_row = HBoxContainer.new()
	burst_row.add_theme_constant_override("separation", 8)
	vfx_vbox.add_child(burst_row)

	var burst_color_picker = ColorPickerButton.new()
	burst_color_picker.color = Color(1, 0.3, 0.1)
	burst_color_picker.custom_minimum_size = Vector2(40, 30)
	burst_row.add_child(burst_color_picker)

	var btn_burst = Button.new()
	btn_burst.text = "💥 Particle Burst"
	btn_burst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	burst_row.add_child(btn_burst)
	btn_burst.pressed.connect(func():
		var pos = Vector2(400, 300)
		var cam = get_viewport().get_camera_2d()
		if cam: pos = cam.get_screen_center()
		pos += Vector2(get_meta("vfx_cfg_ox"), get_meta("vfx_cfg_oy"))
		var pcount = maxi(1, int(16 * get_meta("vfx_cfg_scale")))
		for i in range(pcount):
			var dup = ColorRect.new()
			dup.color = burst_color_picker.color
			dup.custom_minimum_size = Vector2(6, 6)
			dup.size = Vector2(6, 6)
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			dup.material = mat
			dup.global_position = pos
			get_tree().current_scene.add_child(dup)
			var angle = randf_range(0, TAU)
			var dist = randf_range(40, 100)
			var tw = create_tween()
			tw.tween_property(dup, "position", Vector2(cos(angle), sin(angle)) * dist, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(dup, "color:a", 0.0, 0.5)
			tw.tween_callback(func(): dup.queue_free())
	)

	var glow_row = HBoxContainer.new()
	glow_row.add_theme_constant_override("separation", 8)
	vfx_vbox.add_child(glow_row)

	var glow_element_dd = OptionButton.new()
	glow_element_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for el in elements:
		glow_element_dd.add_item(el.capitalize())
	glow_row.add_child(glow_element_dd)

	var btn_glow = Button.new()
	btn_glow.text = "🌟 Glow Ring"
	btn_glow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glow_row.add_child(btn_glow)
	btn_glow.pressed.connect(func():
		var el_name = elements[glow_element_dd.selected]
		var color = MagicCircleVFX.ELEMENT_COLORS.get(el_name, Color.WHITE)
		var pos = Vector2(400, 300)
		var cam = get_viewport().get_camera_2d()
		if cam: pos = cam.get_screen_center()
		pos += Vector2(get_meta("vfx_cfg_ox"), get_meta("vfx_cfg_oy"))
		var tex = preload("res://assets/brackeys_vfx_bundle/particles/alpha/circle_01_a.png")
		if not tex: return
		var glow = Sprite2D.new()
		glow.texture = tex
		glow.self_modulate = Color(color.r, color.g, color.b, 0.35)
		var gs = 2.0 * get_meta("vfx_cfg_scale")
		glow.scale = Vector2(0.01, 0.01)
		glow.global_position = pos
		glow.z_index = 1500
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		get_tree().current_scene.add_child(glow)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(glow, "scale", Vector2(gs, gs), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(glow, "self_modulate:a", 0.0, 0.4).set_delay(0.3)
		tw.tween_callback(func(): glow.queue_free()).set_delay(0.75)
	)

	mk_cat.call("── RELIC / MANAGER STATUS ──")
	var _get_mgr := func(pid: int) -> Dictionary:
		var bridge = get_tree().get_root().find_child("CombatTestBridge", true, false)
		if not bridge: return {}
		var ap_key = "_p%d_ap" % pid
		var mov_key = "_p%d_mov" % pid
		return {"ap": bridge.get(ap_key), "mov": bridge.get(mov_key)}

	var _mgr_label := RichTextLabel.new()
	_mgr_label.bbcode_enabled = true
	_mgr_label.custom_minimum_size = Vector2(0, 160)
	_mgr_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vfx_vbox.add_child(_mgr_label)

	var _refresh_mgr := func():
		var bb = ""
		for pid in [1, 2]:
			var m = _get_mgr.call(pid)
			var ap = m.get("ap")
			var mov = m.get("mov")
			bb += "[b][color=#aaffaa]P%d[/color][/b]  " % pid
			if ap:
				bb += "AP: [color=#88ff88]%d/%d[/color]  BAP: [color=#88aaff]%d/%d[/color]  " % [ap.current_ap, ap.max_ap, ap.current_bap, ap.max_bap]
			else:
				bb += "AP: [color=#ff6666]N/A[/color]  "
			if mov:
				bb += "Move: [color=#ffff88]%d/%d[/color]" % [mov.current_tiles, mov.max_tiles]
			else:
				bb += "Move: [color=#ff6666]N/A[/color]"
			bb += "\n"

		var ps = get_tree().get_nodes_in_group("players")
		for p in ps:
			var pid = p.get("player_id")
			if pid == null: continue
			var stats = p.get_node_or_null("StatsComponent") as StatsComponent
			if not stats: continue
			var hc = p.get_node_or_null("HealthComponent") as HealthComponent
			bb += "\n[b]P%d Stats + Mods:[/b]\n" % pid
			bb += "DEX=%d INT=%d MOV=%d\n" % [stats.get_stat("dex"), stats.get_stat("int"), stats.get_stat("mov")]
			bb += "AP_mod=%d BAP_mod=%d MOV_mod=%d\n" % [stats.get_mod_total("action_points"), stats.get_mod_total("bonus_action_points"), stats.get_mod_total("movement_tiles")]
			bb += "Calculated: AP=%d BAP=%d Tiles=%d\n" % [1 + floori(stats.get_stat("dex") / 10.0) + stats.get_mod_total("action_points"), 1 + floori(stats.get_stat("int") / 10.0) + stats.get_mod_total("bonus_action_points"), 6 + floori(stats.get_stat("mov") / 5.0) + stats.get_mod_total("movement_tiles")]
			if hc:
				bb += "HP: %d/%d  " % [hc.current_hp, hc.max_hp]
			var inv = InventoryManager.get_player_items(pid) if InventoryManager else []
			if inv.size() > 0:
				bb += "\nItems: [color=#aaaaaa]%s[/color]" % ", ".join(inv)
			bb += "\n"
		_mgr_label.text = bb

	var refresh_row = HBoxContainer.new()
	refresh_row.add_theme_constant_override("separation", 10)
	vfx_vbox.add_child(refresh_row)

	var btn_refresh = Button.new()
	btn_refresh.text = "🔄 Refresh Manager Status"
	btn_refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_refresh.pressed.connect(func(): _refresh_mgr.call())
	refresh_row.add_child(btn_refresh)

	var btn_equip = Button.new()
	btn_equip.text = "📦 Equip ALL special relics"
	btn_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_equip.pressed.connect(func():
		var test_items = [
			"book_chronos_topos", "book_seven_deadly_sins", "book_united_swarm_alliance",
			"berserker_axe", "big_hand", "holy_ring", "clock_chronos",
			"blade_wrath", "mask_gluttony", "gauntlet_sloth", "switchblade",
			"crown_pride", "boots_lust", "ring_greed", "robe_envy", "grid_topos",
			"skywalker", "sandal", "greathorn_staff", "holymoly_necklace",
			"rainbow_hand", "greatskull_sword", "red_cloud_cape", "red_cape",
			"egg_pouch", "ant_fang", "sleeping_bag", "honey_wax", "glasswing",
			"sleeping_pouch", "white_robe", "cursed_amulet",
		]
		for pid in [1, 2]:
			for item_id in test_items:
				if InventoryManager:
					InventoryManager.add_item(pid, item_id)
		EventNotifier.show_message("All special relics granted to both players!", Color.GREEN)
		_refresh_mgr.call()
	)
	refresh_row.add_child(btn_equip)
	
	# Auto-refresh every 1s when tab visible
	var _auto_refresh := false
	var btn_auto = CheckButton.new()
	btn_auto.text = "Auto-refresh"
	btn_auto.toggled.connect(func(tog: bool): _auto_refresh = tog)
	refresh_row.add_child(btn_auto)

	# Add to process for auto-refresh
	var _orig_process = _process
	# We'll just use a timer-based approach in the existing _process
	# Store the auto-refresh label updater
	set_meta("vfx_mgr_refresh", _refresh_mgr)
	set_meta("vfx_mgr_auto", func() -> bool: return _auto_refresh)

	# Initial refresh
	_refresh_mgr.call()

	mk_cat.call("── RELIC TOGGLES ──")

	var toggle_items = [
		"ant_fang", "glasswing", "greathorn_staff", "holy_ring", "clock_chronos",
		"greatskull_sword", "honey_wax", "sandal", "robe_envy", "grid_topos",
		"rainbow_hand", "red_cloud_cape", "switchblade", "blade_wrath", "berserker_axe",
		"mask_gluttony", "skywalker", "holymoly_necklace", "red_cape", "egg_pouch",
		"white_robe", "crown_pride", "gauntlet_sloth", "sleeping_bag", "sleeping_pouch",
		"ring_greed", "boots_lust", "big_hand", "cursed_amulet",
	]
	var toggle_btns: Dictionary = {}

	var mk_toggle_row := func(start_idx: int, count: int) -> HBoxContainer:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vfx_vbox.add_child(row)
		for i in range(count):
			var idx = start_idx + i
			if idx >= toggle_items.size():
				break
			var item_id = toggle_items[idx]
			var item_data = StatDataDB.get_item_data(item_id) if StatDataDB else {}
			var label = item_data.get("display_name", item_id)
			var cb = CheckButton.new()
			cb.text = label
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.toggled.connect(func(tog: bool, id = item_id):
				if not InventoryManager:
					return
				for pid in [1, 2]:
					if tog:
						InventoryManager.add_item(pid, id)
					else:
						var items = InventoryManager.get_player_items(pid)
						if id in items:
							InventoryManager.remove_item(pid, id)
				_refresh_mgr.call()
			)
			row.add_child(cb)
			toggle_btns[item_id] = cb
		return row

	for i in range(0, toggle_items.size(), 5):
		mk_toggle_row.call(i, 5)

	var _sync_toggle_buttons := func():
		if not InventoryManager:
			return
		for item_id in toggle_items:
			var cb = toggle_btns.get(item_id)
			if cb:
				cb.set_pressed_no_signal(InventoryManager.has_item(1, item_id))

	var toggle_row2 = HBoxContainer.new()
	toggle_row2.add_theme_constant_override("separation", 8)
	vfx_vbox.add_child(toggle_row2)

	var btn_disable_all = Button.new()
	btn_disable_all.text = "❌ Disable ALL"
	btn_disable_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_row2.add_child(btn_disable_all)
	btn_disable_all.pressed.connect(func():
		if not InventoryManager:
			return
		for pid in [1, 2]:
			for item_id in toggle_items:
				if InventoryManager.has_item(pid, item_id):
					InventoryManager.remove_item(pid, item_id)
		_sync_toggle_buttons.call()
		_refresh_mgr.call()
	)

	var btn_enable_all = Button.new()
	btn_enable_all.text = "✅ Enable ALL"
	btn_enable_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_row2.add_child(btn_enable_all)
	btn_enable_all.pressed.connect(func():
		if not InventoryManager:
			return
		for pid in [1, 2]:
			for item_id in toggle_items:
				InventoryManager.add_item(pid, item_id)
		_sync_toggle_buttons.call()
		_refresh_mgr.call()
	)

	_sync_toggle_buttons.call()

	# --- TAB 7: Config ---
	var tab_config = MarginContainer.new()
	tab_config.name = "Config"
	tab_config.add_theme_constant_override("margin_left", 15)
	tab_config.add_theme_constant_override("margin_top", 15)
	tab_config.add_theme_constant_override("margin_right", 15)
	tabs.add_child(tab_config)

	var cfg_vbox = VBoxContainer.new()
	cfg_vbox.add_theme_constant_override("separation", 20)
	tab_config.add_child(cfg_vbox)

	var mk_slider = func(lbl_text: String, start_val: float, min_v: float, max_v: float, step: float, callback: Callable) -> void:
		var hb = HBoxContainer.new()
		var l = Label.new()
		l.text = lbl_text
		l.custom_minimum_size = Vector2(170, 0)
		var s = HSlider.new()
		s.min_value = min_v
		s.max_value = max_v
		s.step = step
		s.value = start_val
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var vl = Label.new()
		vl.text = str(start_val)
		vl.custom_minimum_size = Vector2(40, 0)
		s.value_changed.connect(func(v: float):
			vl.text = str(v)
			callback.call(v)
		)
		hb.add_child(l)
		hb.add_child(s)
		hb.add_child(vl)
		cfg_vbox.add_child(hb)

	var lbl_desc = Label.new()
	lbl_desc.text = "Adjust the UI scale and opacity for Debug overlays:"
	lbl_desc.add_theme_color_override("font_color", Color.GRAY)
	cfg_vbox.add_child(lbl_desc)

	# 1. Master Scale with Apply Button
	var scale_hbox = HBoxContainer.new()
	var scale_lbl = Label.new()
	scale_lbl.text = "Master UI Scale"
	scale_lbl.custom_minimum_size = Vector2(170, 0)
	var scale_slider = HSlider.new()
	scale_slider.min_value = 0.5
	scale_slider.max_value = 2.0
	scale_slider.step = 0.05
	scale_slider.value = 1.0
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var scale_val = Label.new()
	scale_val.text = "1.0"
	scale_val.custom_minimum_size = Vector2(40, 0)
	scale_slider.value_changed.connect(func(v: float): scale_val.text = str(v))
	var btn_apply_scale = Button.new()
	btn_apply_scale.text = "Apply Scale"
	btn_apply_scale.custom_minimum_size = Vector2(100, 30)
	btn_apply_scale.pressed.connect(func():
		var v = scale_slider.value
		self.scale = Vector2(v, v)
		var sd = get_tree().get_root().find_child("StatDebugPanel", true, false)
		if sd: sd.scale = Vector2(v, v)
		var ds = get_tree().get_root().find_child("DiceSandbox", true, false)
		if ds: ds.scale = Vector2(v, v)
	)
	scale_hbox.add_child(scale_lbl)
	scale_hbox.add_child(scale_slider)
	scale_hbox.add_child(scale_val)
	scale_hbox.add_child(btn_apply_scale)
	cfg_vbox.add_child(scale_hbox)
	
	cfg_vbox.add_child(HSeparator.new())
	
	# 2. Opacity Sliders
	mk_slider.call("Master Opacity", 0.9, 0.1, 1.0, 0.05, func(v: float):
		self.modulate.a = v
		var sd = get_tree().get_root().find_child("StatDebugPanel", true, false)
		if sd: sd.modulate.a = v
		var ds = get_tree().get_root().find_child("DiceSandbox", true, false)
		if ds: ds.modulate.a = v
	)
	
	mk_slider.call("Main Menu Opacity", 0.9, 0.1, 1.0, 0.05, func(v: float):
		self.modulate.a = v
	)
	
	mk_slider.call("Live Stats UI Opacity", 0.9, 0.1, 1.0, 0.05, func(v: float):
		var sd = get_tree().get_root().find_child("StatDebugPanel", true, false)
		if sd: sd.modulate.a = v
	)
	
	mk_slider.call("Stats BG Opacity", 0.95, 0.1, 1.0, 0.05, func(v: float):
		var sd = get_tree().get_root().find_child("StatDebugPanel", true, false)
		if sd and "bg_panel" in sd and sd.bg_panel: sd.bg_panel.modulate.a = v
	)
	
	mk_slider.call("Dice Sandbox Opacity", 0.9, 0.1, 1.0, 0.05, func(v: float):
		var ds = get_tree().get_root().find_child("DiceSandbox", true, false)
		if ds: ds.modulate.a = v
	)
func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.5:
		_refresh_timer = 0.0
		_refresh_stats()
		var auto_fn = get_meta("vfx_mgr_auto", func() -> bool: return false)
		if auto_fn.call():
			var fn = get_meta("vfx_mgr_refresh", func(): pass)
			fn.call()

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
			hp_text, stats.get_physical_damage_modifier(), stats.get_magical_damage_modifier(), stats.get_armor(), stats.get_resist(),
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
