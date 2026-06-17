extends Control
class_name MapPathRenderer

var connections: Array[Dictionary] = []

func _ready() -> void:
	# Ensure this control is drawn behind other UI elements but covers the area
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	# Explicitly set a very large size so Godot never culls it inside ScrollContainer
	custom_minimum_size = Vector2(1920, 2000)
	size = Vector2(1920, 2000)

func clear_connections() -> void:
	connections.clear()
	queue_redraw()

func add_connection(from_pos: Vector2, to_pos: Vector2) -> void:
	connections.append({
		"from": from_pos,
		"to": to_pos
	})

func _draw() -> void:
	var dot_color = Color(0.2, 0.2, 0.2, 0.8) # Dark grey for the path
	var dot_radius = 4.0
	var dash_spacing = 24.0
	
	for conn in connections:
		var from = conn.from
		var to = conn.to
		
		var curve = Curve2D.new()
		# Since map goes bottom-up, from.y > to.y
		var y_dist = abs(from.y - to.y)
		var handle_len = y_dist * 0.3
		
		# Control points for a nice vertical ease in/out
		curve.add_point(from, Vector2.ZERO, Vector2(0, -handle_len))
		curve.add_point(to, Vector2(0, handle_len), Vector2.ZERO)
		
		var length = curve.get_baked_length()
		
		# Offset slightly so the dots don't start exactly inside the node icon
		var current_dist = 20.0 
		var end_margin = 20.0
		
		# Ensure we draw at least one dot if the nodes are super close
		if length <= current_dist + end_margin:
			var mid_pos = curve.sample_baked(length / 2.0)
			draw_circle(mid_pos, dot_radius, dot_color)
		else:
			while current_dist < length - end_margin:
				var pos = curve.sample_baked(current_dist)
				draw_circle(pos, dot_radius, dot_color)
				current_dist += dash_spacing
