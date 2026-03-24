extends Node2D

signal hovered_tile_changed(tile: Vector2i)

@export var move_speed: float = 380.0
@export var show_tile_highlight: bool = true
@export var highlight_color: Color = Color(0.2, 0.8, 1.0, 0.35)
@export var cursor_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var player_id: int = 1

var hovered_tile: Vector2i = Vector2i(-1, -1)
var _tile_local: Vector2 = Vector2.ZERO
var _tile_valid: bool = false

func get_hovered_tile() -> Vector2i:
	return hovered_tile

func _process(delta: float) -> void:
	_move_cursor(delta)
	_update_hovered_tile()
	queue_redraw()

func _move_cursor(delta: float) -> void:
	# --- Kode gerakan yang sudah ada ---
	var move := Vector2.ZERO
	if InputManager.is_pressed(player_id, "move_right"): move.x += 1.0
	if InputManager.is_pressed(player_id, "move_left"):  move.x -= 1.0
	if InputManager.is_pressed(player_id, "move_down"):  move.y += 1.0
	if InputManager.is_pressed(player_id, "move_up"):    move.y -= 1.0

	if move != Vector2.ZERO:
		global_position += move.normalized() * move_speed * delta

	# --- LOGIKA "BALIK KE TENGAH" (TAMBAHKAN INI) ---
	var center_px = IsoUtils.world_to_iso(Vector2i(7, 7)) # Titik tengah (7,7) dalam pixel
	
	# Jika jarak kursor ke tengah > 900 pixel , balikkan!
	if global_position.distance_to(center_px) > 800.0:
		global_position = center_px

func _update_hovered_tile() -> void:
	var grid_pos := _get_tile_under_point(global_position)
	if grid_pos != hovered_tile:
		hovered_tile = grid_pos
		if hovered_tile.x >= 0:
			hovered_tile_changed.emit(hovered_tile)

	if hovered_tile.x >= 0:
		_tile_valid = true
		var tile_world := IsoUtils.world_to_iso(hovered_tile)
		_tile_local = to_local(tile_world)
		z_index = IsoUtils.get_depth(hovered_tile) + 2
	else:
		_tile_valid = false

func _get_tile_under_point(point: Vector2) -> Vector2i:
	# Convert to fractional grid coords (no floor)
	var gx: float = (point.x / (IsoUtils.TILE_W / 2.0) + point.y / (IsoUtils.TILE_H / 2.0)) / 2.0
	var gy: float = (point.y / (IsoUtils.TILE_H / 2.0) - point.x / (IsoUtils.TILE_W / 2.0)) / 2.0
	var base := Vector2i(int(floor(gx)), int(floor(gy)))

	var best := Vector2i(-1, -1)
	var best_score: float = 9999.0
	for dx in [0, 1]:
		for dy in [0, 1]:
			var tile := base + Vector2i(dx, dy)
			if tile.x < 0 or tile.y < 0 or tile.x >= GridManager.grid_size.x or tile.y >= GridManager.grid_size.y:
				continue
			var center := IsoUtils.world_to_iso(tile)
			var local := point - center
			var score: float = abs(local.x) / (IsoUtils.TILE_W / 2.0) + abs(local.y) / (IsoUtils.TILE_H / 2.0)
			if score <= 1.0 and score < best_score:
				best_score = score
				best = tile
	return best

func _draw() -> void:
	# Floating keyboard cursor crosshair
	draw_line(Vector2(-4, 0), Vector2(4, 0), cursor_color, 1.0)
	draw_line(Vector2(0, -4), Vector2(0, 4), cursor_color, 1.0)

	if not show_tile_highlight or not _tile_valid:
		return

	var hw := IsoUtils.TILE_W / 2.0
	var hh := IsoUtils.TILE_H / 2.0
	var center := _tile_local
	var pts := PackedVector2Array([
		center + Vector2(0, -hh), center + Vector2(hw, 0),
		center + Vector2(0,  hh), center + Vector2(-hw, 0),
	])
	draw_colored_polygon(pts, highlight_color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), highlight_color.lightened(0.3), 2.0)
