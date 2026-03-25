extends Node2D

signal hovered_tile_changed(tile: Vector2i)

@export var move_speed: float = 380.0
@export var cursor_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var player_id: int = 1

# show_tile_highlight dan highlight_color dihapus —
# tile highlight kini ditangani SelectionCursor via AnimatedSprite2D.

var hovered_tile: Vector2i = Vector2i(-1, -1)
var _tile_valid: bool = false


func get_hovered_tile() -> Vector2i:
	return hovered_tile


func _process(delta: float) -> void:
	_move_cursor(delta)
	_update_hovered_tile()
	queue_redraw()


func _move_cursor(delta: float) -> void:
	var move := Vector2.ZERO
	if InputManager.is_pressed(player_id, "move_right"): move.x += 1.0
	if InputManager.is_pressed(player_id, "move_left"):  move.x -= 1.0
	if InputManager.is_pressed(player_id, "move_down"):  move.y += 1.0
	if InputManager.is_pressed(player_id, "move_up"):    move.y -= 1.0

	if move != Vector2.ZERO:
		global_position += move.normalized() * move_speed * delta

	# Batas area — kembalikan ke tengah map jika terlalu jauh
	var center_px = IsoUtils.world_to_iso(Vector2i(7, 7))
	if global_position.distance_to(center_px) > 800.0:
		global_position = center_px


func _update_hovered_tile() -> void:
	var grid_pos := _get_tile_under_point(global_position)
	if grid_pos != hovered_tile:
		hovered_tile = grid_pos
		if hovered_tile.x >= 0:
			hovered_tile_changed.emit(hovered_tile)

	_tile_valid = hovered_tile.x >= 0
	if _tile_valid:
		z_index = IsoUtils.get_depth(hovered_tile) + 2


func _get_tile_under_point(point: Vector2) -> Vector2i:
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
	# Hanya gambar crosshair kursor — tile highlight dihandle SelectionCursor
	draw_line(Vector2(-4, 0), Vector2(4, 0), cursor_color, 1.0)
	draw_line(Vector2(0, -4), Vector2(0, 4), cursor_color, 1.0)
