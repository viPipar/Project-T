extends CanvasLayer

var container: VBoxContainer

func _ready() -> void:
	layer = 100 # Put it above everything
	
	# Create a full-screen wrapper so it's perfectly centered
	var wrapper = MarginContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_theme_constant_override("margin_top", 180)
	add_child(wrapper)
	
	container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	wrapper.add_child(container)

func show_message(text: String, color: Color = Color.WHITE) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(150, 20) # Approx center for scale
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.9)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = color.lerp(Color.WHITE, 0.25) # Slightly brighter border
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	label.add_theme_stylebox_override("normal", style)
	
	container.add_child(label)
	
	# Entrance Animation
	label.scale = Vector2(0.8, 0.8)
	label.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	
	# Fade out logic
	var fade_tween = create_tween()
	fade_tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(2.5).set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_callback(label.queue_free)
