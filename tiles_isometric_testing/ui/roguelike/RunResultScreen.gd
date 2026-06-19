extends CanvasLayer

var title_label: Label
var subtitle_label: Label
var btn_continue: Button

var is_victory: bool = false

func _ready() -> void:
	layer = 120 # Above even the RoguelikeUIShell
	
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.9)
	root.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 32)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle_label)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 40)
	vbox.add_child(margin)
	
	btn_continue = Button.new()
	btn_continue.text = "Return to Menu"
	btn_continue.add_theme_font_size_override("font_size", 28)
	btn_continue.custom_minimum_size = Vector2(300, 60)
	btn_continue.pressed.connect(func():
		queue_free()
	)
	margin.add_child(btn_continue)
	
	_apply_state()

func set_state(_is_victory: bool) -> void:
	is_victory = _is_victory
	if is_inside_tree():
		_apply_state()

func _apply_state() -> void:
	if is_victory:
		title_label.text = "VICTORY ACHIEVED"
		title_label.add_theme_color_override("font_color", Color.GOLD)
		subtitle_label.text = "You have conquered the final layer."
	else:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color.RED)
		subtitle_label.text = "Your party was defeated..."
