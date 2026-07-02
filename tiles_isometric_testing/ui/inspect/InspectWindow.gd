class_name InspectWindow
extends Control

var _panel: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _hp_label: Label
var _armor_label: Label
var _resist_label: Label
var _stats_container: GridContainer
var _conditions_label: RichTextLabel

var _is_visible: bool = false

func _ready() -> void:
	z_index = 60
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Main panel
	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.6, 0.5, 0.3, 1.0)
	style.border_width_bottom = 2; style.border_width_top = 2; style.border_width_left = 2; style.border_width_right = 2
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8; style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.content_margin_left = 16; style.content_margin_right = 16; style.content_margin_top = 16; style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(main_vbox)
	
	# Header (Name)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_name_label)
	
	# Middle (Portrait + Vital Stats)
	var mid_hbox = HBoxContainer.new()
	mid_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(mid_hbox)
	
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(128, 128)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_bg = ColorRect.new()
	portrait_bg.color = Color(0.05, 0.05, 0.1, 1.0)
	portrait_bg.custom_minimum_size = Vector2(128, 128)
	portrait_bg.add_child(_portrait)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid_hbox.add_child(portrait_bg)
	
	var vitals_vbox = VBoxContainer.new()
	vitals_vbox.add_theme_constant_override("separation", 8)
	vitals_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_hbox.add_child(vitals_vbox)
	
	_hp_label = _create_stat_row("HP", Color(1, 0.4, 0.4))
	vitals_vbox.add_child(_hp_label)
	_armor_label = _create_stat_row("Armor", Color(0.6, 0.7, 0.9))
	vitals_vbox.add_child(_armor_label)
	_resist_label = _create_stat_row("Resist", Color(0.8, 0.6, 0.9))
	vitals_vbox.add_child(_resist_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Primary Stats Grid
	_stats_container = GridContainer.new()
	_stats_container.columns = 3
	_stats_container.add_theme_constant_override("h_separation", 16)
	_stats_container.add_theme_constant_override("v_separation", 8)
	main_vbox.add_child(_stats_container)
	
	main_vbox.add_child(HSeparator.new())
	
	# Conditions
	var cond_title = Label.new()
	cond_title.text = "Conditions"
	cond_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(cond_title)
	
	_conditions_label = RichTextLabel.new()
	_conditions_label.custom_minimum_size = Vector2(300, 80)
	_conditions_label.bbcode_enabled = true
	_conditions_label.fit_content = true
	main_vbox.add_child(_conditions_label)

func _create_stat_row(label_text: String, color: Color) -> Label:
	var l = Label.new()
	l.text = label_text + ": 0"
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 20)
	return l

func show_for_entity(entity: Node, layer_mask: int, viewport_center: Vector2) -> void:
	if not is_instance_valid(entity): return
	
	# Fetch Name
	_name_label.text = entity.name
	if entity.get("char_name") and str(entity.get("char_name")) != "":
		_name_label.text = str(entity.get("char_name"))
	elif entity.get("enemy_name") and str(entity.get("enemy_name")) != "":
		_name_label.text = str(entity.get("enemy_name"))
		
	# Fetch Portrait
	_portrait.texture = null
	if entity.has_node("AnimatedSprite2D"):
		var anim = entity.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if anim.sprite_frames != null:
			var anim_name = anim.animation
			if anim.sprite_frames.has_animation("idle"): anim_name = "idle"
			if anim.sprite_frames.get_frame_count(anim_name) > 0:
				_portrait.texture = anim.sprite_frames.get_frame_texture(anim_name, 0)
	elif entity.has_node("Player1Sprite"):
		var anim = entity.get_node("Player1Sprite") as AnimatedSprite2D
		if anim.visible and anim.sprite_frames != null and anim.sprite_frames.get_frame_count(anim.animation) > 0:
			_portrait.texture = anim.sprite_frames.get_frame_texture(anim.animation, 0)
	elif entity.has_node("Player2Sprite"):
		var anim = entity.get_node("Player2Sprite") as AnimatedSprite2D
		if anim.visible and anim.sprite_frames != null and anim.sprite_frames.get_frame_count(anim.animation) > 0:
			_portrait.texture = anim.sprite_frames.get_frame_texture(anim.animation, 0)
			
	# Fetch Vitals
	var health = entity.get_node_or_null("HealthComponent")
	if health:
		_hp_label.text = "HP: %d / %d" % [health.get_hp(), health.get_max_hp()]
	else:
		_hp_label.text = "HP: ???"
		
	var stats = entity.get_node_or_null("StatsComponent")
	if stats:
		_armor_label.text = "Armor: %d" % stats.get_armor()
		_resist_label.text = "Resist: %d" % stats.get_resist()
	else:
		_armor_label.text = "Armor: ???"
		_resist_label.text = "Resist: ???"
		
	# Fetch Primary Stats
	for child in _stats_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	if stats:
		var stat_keys = ["vit", "str", "int", "con", "acc", "dex", "mov", "att", "lck"]
		for key in stat_keys:
			var val = stats.get_stat(key)
			var l = Label.new()
			l.text = "%s: %d" % [key.to_upper(), val]
			l.add_theme_font_size_override("font_size", 18)
			_stats_container.add_child(l)
			
	# Fetch Conditions
	var conditions = entity.get_node_or_null("ConditionComponent")
	_conditions_label.text = ""
	if conditions:
		var dict = conditions.get_conditions()
		if dict.is_empty():
			_conditions_label.text = "[color=#888888]None[/color]"
		else:
			for id in dict.keys():
				var entry = dict[id]
				var turns = entry.get("turns", 1)
				_conditions_label.text += "[color=#ffaa55]%s[/color] (%d turns)\n" % [id.capitalize(), turns]
	else:
		_conditions_label.text = "[color=#888888]None[/color]"
		
	# Use deferred so size calculation is correct after adding children
	_is_visible = true
	call_deferred("_finalize_position", viewport_center)

func _finalize_position(viewport_center: Vector2) -> void:
	if not _is_visible:
		return
		
	_panel.reset_size() # Force recalculate size
	var panel_size = _panel.get_minimum_size()
	# Center it on the specified viewport center (local to the side container)
	position = viewport_center - (panel_size / 2.0)
	
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_window() -> void:
	if _is_visible:
		_is_visible = false
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_IN)
		await tw.finished
		if not _is_visible:
			visible = false
