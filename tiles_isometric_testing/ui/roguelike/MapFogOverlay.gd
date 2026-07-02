extends Control
class_name MapFogOverlay

var fog_start_y := 0.0
var map_size := Vector2(1280, 720)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = map_size
	size = map_size

func configure(new_size: Vector2) -> void:
	map_size = new_size
	custom_minimum_size = map_size
	size = map_size
	queue_redraw()

func set_fog_start_y(new_y: float) -> void:
	fog_start_y = clampf(new_y, 0.0, map_size.y)
	visible = fog_start_y > 0.0
	queue_redraw()

func _draw() -> void:
	if fog_start_y <= 0.0:
		return

	var fog_rect = Rect2(Vector2.ZERO, Vector2(map_size.x, fog_start_y))
	draw_rect(fog_rect, Color(0.12, 0.13, 0.15, 0.78))

	var soft_rect = Rect2(Vector2(0.0, maxf(0.0, fog_start_y - 90.0)), Vector2(map_size.x, 90.0))
	draw_rect(soft_rect, Color(0.42, 0.46, 0.48, 0.12))

	var blob_count = int(ceil(map_size.x / 86.0)) + 4
	for i in range(blob_count):
		var x = (float(i) * 86.0) - 96.0
		var wobble = sin(float(i) * 1.73) * 5.0
		var radius = 38.0 + (cos(float(i) * 1.21) * 9.0)
		var y = fog_start_y - radius - 22.0 + wobble
		draw_circle(Vector2(x, y), radius, Color(0.60, 0.64, 0.66, 0.50))
		draw_circle(Vector2(x + 34.0, y - 18.0), radius * 0.72, Color(0.48, 0.52, 0.54, 0.44))

	for i in range(7):
		var x = fmod(float(i) * 211.0 + 57.0, map_size.x)
		var y = fmod(float(i) * 97.0 + 43.0, maxf(1.0, fog_start_y))
		var radius = 70.0 + (float(i % 3) * 24.0)
		draw_circle(Vector2(x, y), radius, Color(0.36, 0.39, 0.42, 0.16))
