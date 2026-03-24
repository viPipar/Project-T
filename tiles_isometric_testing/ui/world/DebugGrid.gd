extends Node2D

@export var font: Font
func _ready():
	if font == null:
		font = ThemeDB.fallback_font
	queue_redraw()
	z_index = 100

	
func _draw() -> void:
	var cols: int = GridManager.grid_size.x
	var rows: int = GridManager.grid_size.y
	var color := Color(1, 1, 1, 0.15)
	var text_color := Color(1, 1, 1, 0.8)

	for x in range(cols):
		for y in range(rows):
			var center: Vector2 = IsoUtils.world_to_iso(Vector2i(x, y))
			var hw: float = IsoUtils.TILE_W / 2.0
			var hh: float = IsoUtils.TILE_H / 2.0

			# Diamond
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -hh),
				center + Vector2(hw, 0),
				center + Vector2(0, hh),
				center + Vector2(-hw, 0),
			])
			draw_polyline(pts, color, 1.0)
			draw_line(pts[3], pts[0], color, 1.0)

			# 🔥 Tambahin nomor grid
			var text := str(x) + "," + str(y)

			# Biar agak ke tengah (offset dikit)
			var text_pos := center + Vector2(-10, 5)

			if font:
				draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, text_color)
