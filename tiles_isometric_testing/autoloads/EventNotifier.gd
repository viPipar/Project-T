extends CanvasLayer

var container: VBoxContainer

func _ready() -> void:
	layer = 100 # Put it above everything
	
	# Create a full-screen wrapper so it's perfectly centered
	var wrapper = MarginContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_theme_constant_override("margin_top", 200)
	add_child(wrapper)
	
	container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 15)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	wrapper.add_child(container)

func show_message(text: String, color: Color = Color.WHITE) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = color
	style.set_content_margin_all(15)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	label.add_theme_stylebox_override("normal", style)
	
	container.add_child(label)
	
	# Fade out logic
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 3.0).set_delay(2.0).set_ease(Tween.EASE_OUT)
	tween.tween_callback(label.queue_free)
