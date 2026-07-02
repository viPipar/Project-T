extends PanelContainer

signal closed()

var master_slider: HSlider
var fullscreen_checkbox: CheckButton

func _ready() -> void:
	custom_minimum_size = Vector2(500, 360)
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_ui()

func _make_panel_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.098, 0.11, 0.133, 0.95)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.231, 0.259, 0.314, 1)
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_right = 12
	s.corner_radius_bottom_left = 12
	s.shadow_size = 15
	s.shadow_offset = Vector2(0, 8)
	return s

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 25)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Settings"
	title.label_settings = _make_title_settings()
	vbox.add_child(title)

	var separator = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.231, 0.259, 0.314, 1)
	sep_style.thickness = 2
	separator.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(separator)

	var vol_settings = VBoxContainer.new()
	vol_settings.add_theme_constant_override("separation", 8)
	vbox.add_child(vol_settings)

	var master_row = HBoxContainer.new()
	vol_settings.add_child(master_row)

	var vol_label = Label.new()
	vol_label.custom_minimum_size = Vector2(150, 0)
	vol_label.text = "Master Volume"
	vol_label.label_settings = _make_item_settings()
	master_row.add_child(vol_label)

	master_slider = HSlider.new()
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	master_slider.value = 0.8
	master_slider.value_changed.connect(_on_master_slider_changed)
	master_row.add_child(master_slider)

	var display_row = HBoxContainer.new()
	vbox.add_child(display_row)

	var display_label = Label.new()
	display_label.custom_minimum_size = Vector2(150, 0)
	display_label.text = "Fullscreen"
	display_label.label_settings = _make_item_settings()
	display_row.add_child(display_label)

	fullscreen_checkbox = CheckButton.new()
	fullscreen_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	display_row.add_child(fullscreen_checkbox)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var close_btn = Button.new()
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_override("font", _make_font())
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_stylebox_override("hover", _make_close_style(Color(0.35, 0.15, 0.15, 1)))
	close_btn.add_theme_stylebox_override("pressed", _make_close_style(Color(0.18, 0.204, 0.251, 1)))
	close_btn.add_theme_stylebox_override("normal", _make_close_style(Color(0.18, 0.204, 0.251, 1)))
	close_btn.text = "Save & Close"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

	_setup_values()

func _make_title_settings() -> LabelSettings:
	var s = LabelSettings.new()
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Sans-Serif", "Arial", "Helvetica"])
	f.font_weight = 800
	s.font = f
	s.font_size = 28
	s.font_color = Color(0.851, 0.651, 0.125, 1)
	return s

func _make_item_settings() -> LabelSettings:
	var s = LabelSettings.new()
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Sans-Serif", "Arial", "Helvetica"])
	f.font_weight = 700
	s.font = f
	s.font_color = Color(0.9, 0.9, 0.9, 1)
	return s

func _make_font() -> SystemFont:
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Sans-Serif", "Arial", "Helvetica"])
	f.font_weight = 700
	return f

func _make_close_style(bg: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.content_margin_left = 16
	s.content_margin_top = 8
	s.content_margin_right = 16
	s.content_margin_bottom = 8
	s.bg_color = bg
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	return s

func _setup_values() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))

	var mode = DisplayServer.window_get_mode()
	fullscreen_checkbox.button_pressed = (mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_master_slider_changed(value: float) -> void:
	var idx = AudioServer.get_bus_index("Master")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_fullscreen_toggled(is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
