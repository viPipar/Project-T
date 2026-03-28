extends Node2D

signal hovered_tile_changed(tile: Vector2i)

@export var move_speed: float = 380.0
@export var cursor_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var player_id: int = 1
@export var cursor_size: float = 10.0
@export var cursor_thickness: float = 2.0
@export var clamp_to_grid: bool = false
@export var clamp_to_range: bool = false
@export var max_distance_from_center: float = 0.0

# show_tile_highlight dan highlight_color dihapus —
# tile highlight kini ditangani SelectionCursor via AnimatedSprite2D.

var hovered_tile: Vector2i = Vector2i(-1, -1)
var _tile_valid: bool = false
var _last_valid_tile: Vector2i = Vector2i(-1, -1)
var _player_cache: Node = null


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

	# Optional safety clamp to keep cursor near the map center (0 = unlimited)
	if max_distance_from_center > 0.0:
		var center_px = IsoUtils.world_to_iso(_get_center_tile())
		if global_position.distance_to(center_px) > max_distance_from_center:
			global_position = center_px


func _update_hovered_tile() -> void:
	var grid_pos := _get_tile_under_point(global_position)
	var target := grid_pos
	var player := _get_player()

	if not _is_valid_tile(grid_pos):
		if clamp_to_grid:
			target = _get_fallback_tile(player)
	elif clamp_to_range and not _is_tile_allowed(grid_pos, player):
		target = _get_fallback_tile(player)

	if target.x >= 0 and target != grid_pos:
		global_position = IsoUtils.world_to_iso(target)

	if target != hovered_tile:
		hovered_tile = target
		if hovered_tile.x >= 0:
			hovered_tile_changed.emit(hovered_tile)

	_tile_valid = hovered_tile.x >= 0
	if _tile_valid:
		z_index = IsoUtils.get_depth(hovered_tile) + 2
		_last_valid_tile = hovered_tile


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


func _get_center_tile() -> Vector2i:
	return Vector2i(
		maxi(0, int(GridManager.grid_size.x / 2)),
		maxi(0, int(GridManager.grid_size.y / 2))
	)


func _get_player() -> Node:
	if _player_cache != null and is_instance_valid(_player_cache):
		return _player_cache
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if p != null and p.get("player_id") == player_id:
			_player_cache = p
			return p
	return null


func _is_valid_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0


func _get_fallback_tile(player: Node) -> Vector2i:
	if _last_valid_tile.x >= 0:
		if not clamp_to_range or _is_tile_allowed(_last_valid_tile, player):
			return _last_valid_tile
	if player != null:
		return player.get("grid_pos") as Vector2i
	return Vector2i(-1, -1)


func _is_tile_allowed(tile: Vector2i, player: Node) -> bool:
	if not clamp_to_range:
		return true
	if player == null:
		return true

	var origin := player.get("grid_pos") as Vector2i
	if tile == origin:
		return true

	# Prefer cached range tiles from MovementRangeManager (if available)
	var range_mgr := get_node_or_null("/root/MovementRangeManager")
	if range_mgr != null and range_mgr.has_method("get_range_tiles_for_player"):
		var tiles: Array[Vector2i] = range_mgr.get_range_tiles_for_player(player_id)
		if tile in tiles:
			return true

	# Allow entity tiles if an adjacent tile is reachable
	if GridManager.has_entity_at(tile):
		return _has_reachable_adjacent(origin, tile, player.get_movement_left())

	# Fallback: compute by path cost (keeps it non-breaking if range manager is off)
	var cost := GridManager.get_path_cost(origin, tile)
	return cost >= 0 and cost <= player.get_movement_left()


func _has_reachable_adjacent(origin: Vector2i, entity_tile: Vector2i, budget: int) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if dx != 0 and dy != 0:
				continue  # cardinal only
			var nb := entity_tile + Vector2i(dx, dy)
			if not GridManager.is_walkable(nb):
				continue
			var cost := GridManager.get_path_cost(origin, nb)
			if cost >= 0 and cost <= budget:
				return true
	return false


func _draw() -> void:
	# Hanya gambar crosshair kursor — tile highlight dihandle SelectionCursor
	draw_line(Vector2(-cursor_size, 0), Vector2(cursor_size, 0), cursor_color, cursor_thickness)
	draw_line(Vector2(0, -cursor_size), Vector2(0, cursor_size), cursor_color, cursor_thickness)
