extends Control
class_name MapPathRenderer

var connections: Array[Dictionary] = []
var map_size: Vector2 = Vector2(2400, 900)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = map_size
	size = map_size

func configure(new_size: Vector2) -> void:
	map_size = new_size
	custom_minimum_size = map_size
	size = map_size

func clear_connections() -> void:
	connections.clear()
	for child in get_children():
		child.queue_free()

func add_connection(from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.62, 0.66, 0.64, 0.85)) -> void:
	connections.append({
		"from": from_pos,
		"to": to_pos,
		"color": color
	})

func redraw_connections() -> void:
	for child in get_children():
		child.queue_free()

	for conn in connections:
		var from = conn.from
		var to = conn.to
		var curve = Curve2D.new()
		var y_dist = abs(to.y - from.y)
		var handle_len = y_dist * 0.35

		curve.add_point(from, Vector2.ZERO, Vector2(0, -handle_len))
		curve.add_point(to, Vector2(0, handle_len), Vector2.ZERO)

		var length = curve.get_baked_length()
		var current_dist = 34.0
		var end_margin = 34.0
		var dash_len = 10.0
		var dash_gap = 20.0

		while current_dist < length - end_margin:
			var start_pos = curve.sample_baked(current_dist)
			var end_pos = curve.sample_baked(min(current_dist + dash_len, length - end_margin))
			var segment = Line2D.new()
			segment.width = 6.0
			segment.default_color = conn.color
			segment.points = PackedVector2Array([start_pos, end_pos])
			add_child(segment)
			current_dist += dash_len + dash_gap
