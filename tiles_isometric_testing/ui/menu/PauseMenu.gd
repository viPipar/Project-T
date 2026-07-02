extends CanvasLayer

signal continue_pressed()
signal quit_pressed()

var _menu_root: Control
var _btn_continue: Button
var _btn_options: Button
var _btn_quit: Button

func _ready() -> void:
	layer = 200
	process_mode = PROCESS_MODE_WHEN_PAUSED
	visible = false
	_build_ui()

func _build_ui() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	root.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.65, 0.12, 1))
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	_btn_continue = _make_button("Continue")
	_btn_continue.pressed.connect(func(): continue_pressed.emit())
	vbox.add_child(_btn_continue)

	_btn_options = _make_button("Options")
	_btn_options.pressed.connect(_on_options_pressed)
	vbox.add_child(_btn_options)

	_btn_quit = _make_button("Quit To Menu")
	_btn_quit.pressed.connect(func(): quit_pressed.emit())
	vbox.add_child(_btn_quit)

	var ver = Label.new()
	ver.text = "v0.1.0-alpha"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ver.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.6))
	ver.add_theme_font_size_override("font_size", 14)
	ver.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ver)

func _make_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.add_theme_font_size_override("font_size", 20)
	return btn

func show_pause() -> void:
	visible = true
	get_tree().paused = true

func hide_pause() -> void:
	visible = false
	get_tree().paused = false

func _on_options_pressed() -> void:
	var overlay = CanvasLayer.new()
	overlay.layer = 250
	overlay.process_mode = PROCESS_MODE_WHEN_PAUSED
	add_child(overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var settings = load("res://ui/menu/SettingsPanel.gd").new()
	settings.modulate.a = 0.0
	settings.scale = Vector2(0.9, 0.9)
	center.add_child(settings)

	get_tree().process_frame.connect(func():
		if not is_instance_valid(settings): return
		settings.pivot_offset = settings.size / 2.0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(settings, "modulate:a", 1.0, 0.2)
		tw.tween_property(settings, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	, CONNECT_ONE_SHOT)

	settings.closed.connect(func():
		var close_tw = create_tween().set_parallel(true)
		close_tw.tween_property(settings, "modulate:a", 0.0, 0.15)
		close_tw.tween_property(settings, "scale", Vector2(0.9, 0.9), 0.15)
		close_tw.chain().tween_callback(func(): overlay.queue_free())
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		hide_pause()
