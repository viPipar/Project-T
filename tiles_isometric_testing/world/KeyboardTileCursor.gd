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
# Referensi ke PlayerCamera2D — di-set oleh main.gd setelah split-screen setup
var camera_ref: Camera2D = null
var _last_hovered_entity: Node = null
var _last_hovered_relic: Control = null


func _ready() -> void:
	process_priority = 10


func get_hovered_tile() -> Vector2i:
	return hovered_tile


func _process(delta: float) -> void:
	_move_cursor(delta)
	_update_hovered_tile()
	
	var relic_focus = false
	if InputManager != null:
		relic_focus = InputManager.relic_focus_p1 if player_id == 1 else InputManager.relic_focus_p2
		
	if relic_focus:
		_check_relic_hover()
	else:
		if is_instance_valid(_last_hovered_relic):
			if _last_hovered_relic.has_method("_on_hover_exited"):
				_last_hovered_relic.call("_on_hover_exited")
			_last_hovered_relic = null
			

			
	queue_redraw()


func _move_cursor(delta: float) -> void:
	var relic_focus = false
	if InputManager != null:
		relic_focus = InputManager.relic_focus_p1 if player_id == 1 else InputManager.relic_focus_p2
		
	if not relic_focus:
		if camera_ref != null and is_instance_valid(camera_ref):
			global_position = camera_ref.global_position
		return
		
	# ── FREE CURSOR MOVEMENT ──
	var prefix := "p%d_" % player_id
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed(prefix + "move_right"): input_dir.x += 1.0
	if Input.is_action_pressed(prefix + "move_left"):  input_dir.x -= 1.0
	if Input.is_action_pressed(prefix + "move_down"):  input_dir.y += 1.0
	if Input.is_action_pressed(prefix + "move_up"):    input_dir.y -= 1.0
	
	if input_dir != Vector2.ZERO:
		var zoom_factor = 1.0
		if camera_ref != null and is_instance_valid(camera_ref):
			zoom_factor = 1.0 / camera_ref.zoom.x
		global_position += input_dir.normalized() * move_speed * delta * zoom_factor

	# ── EDGE SCROLLING (CAMERA PANNING) ──
	if camera_ref != null and is_instance_valid(camera_ref):
		var screen_pos = _get_screen_pos()
		var viewport_size = _get_player_viewport_size()
		
		var edge_margin := 40.0
		var scroll_speed := 400.0
		var cam_dir := Vector2.ZERO
		
		var relic_zone_height := 150.0
		var in_relic_zone = screen_pos.y < relic_zone_height
		
		if not in_relic_zone:
			if screen_pos.x < edge_margin:
				cam_dir.x -= 1.0
			elif screen_pos.x > viewport_size.x - edge_margin:
				cam_dir.x += 1.0
				
		if screen_pos.y < edge_margin:
			cam_dir.y -= 1.0
		elif screen_pos.y > viewport_size.y - edge_margin:
			cam_dir.y += 1.0
			
		if cam_dir != Vector2.ZERO:
			camera_ref._target_pos += cam_dir.normalized() * scroll_speed * delta
			global_position += cam_dir.normalized() * scroll_speed * delta


func _get_player_viewport_size() -> Vector2:
	var main = get_tree().root.get_node_or_null("Main")
	if main != null:
		var ssm = main.get_node_or_null("SplitScreenManager")
		if ssm != null:
			var vp = ssm.get("_p1_viewport") if player_id == 1 else ssm.get("_p2_viewport")
			if vp != null and is_instance_valid(vp):
				return vp.size
	return get_viewport().get_visible_rect().size


func _get_screen_pos() -> Vector2:
	if camera_ref == null or not is_instance_valid(camera_ref):
		return get_global_transform_with_canvas().origin
		
	var viewport_size = _get_player_viewport_size()
	var screen_center = viewport_size / 2.0
	return (global_position - camera_ref.get_screen_center_position()) * camera_ref.zoom + screen_center


func _check_relic_hover() -> void:
	if not is_inside_tree(): return
	var main = get_tree().root.get_node_or_null("Main")
	if main == null: return
	
	var ssm = main.get_node_or_null("SplitScreenManager")
	if ssm == null: return
	
	var container = ssm.get("_p1_relics_container") if player_id == 1 else ssm.get("_p2_relics_container")
	if container == null: return
	
	var screen_pos = _get_screen_pos()
	
	var hovered_btn: Control = null
	for btn in container.get_children():
		if is_instance_valid(btn) and btn is Control:
			if btn.get_global_rect().has_point(screen_pos):
				hovered_btn = btn
				break
				
	if hovered_btn != _last_hovered_relic:
		if is_instance_valid(_last_hovered_relic):
			if _last_hovered_relic.has_method("_on_hover_exited"):
				_last_hovered_relic.call("_on_hover_exited")
				
		if hovered_btn != null:
			if hovered_btn.has_method("_on_hover_entered"):
				hovered_btn.call("_on_hover_entered")
				
		_last_hovered_relic = hovered_btn


func _update_hovered_tile() -> void:
	var grid_pos := _get_tile_under_point(global_position)
	var target := grid_pos
	var player := _get_player()

	if not _is_valid_tile(grid_pos):
		if clamp_to_grid:
			target = _get_fallback_tile(player)
	elif clamp_to_range and not _is_tile_allowed(grid_pos, player):
		target = _get_fallback_tile(player)

	# No grid snapping in free movement mode

	if target != hovered_tile:
		hovered_tile = target
		if hovered_tile.x >= 0:
			hovered_tile_changed.emit(hovered_tile)
			_notify_entity_hover(hovered_tile)

	_tile_valid = hovered_tile.x >= 0
	if _tile_valid:
		z_index = IsoUtils.get_depth(hovered_tile) + 2
		_last_valid_tile = hovered_tile


func _notify_entity_hover(new_tile: Vector2i) -> void:
	var new_entity := GridManager.get_entity_at(new_tile)
	if new_entity == _last_hovered_entity:
		return
	
	if is_instance_valid(_last_hovered_entity) and _last_hovered_entity.has_method("remove_hover_player"):
		_last_hovered_entity.remove_hover_player(player_id)
		
	if new_entity != null and is_instance_valid(new_entity) and new_entity.has_method("add_hover_player"):
		new_entity.add_hover_player(player_id)
		
	_last_hovered_entity = new_entity
	
	var relic_focus = false
	if InputManager != null:
		relic_focus = InputManager.relic_focus_p1 if player_id == 1 else InputManager.relic_focus_p2
	if relic_focus:
		_notify_inspect_overlay(new_entity)


func _notify_inspect_overlay(new_entity: Node) -> void:
	if not is_inside_tree(): return
	var main = get_tree().root.get_node_or_null("Main")
	if main == null: return
	
	var inspect_overlay = main.get_node_or_null("InspectCanvas/InspectOverlay")
	if inspect_overlay != null:
		var window = inspect_overlay.get("_inspect_p1") if player_id == 1 else inspect_overlay.get("_inspect_p2")
		var side = inspect_overlay.get("_left_side") if player_id == 1 else inspect_overlay.get("_right_side")
		if window != null and side != null:
			if is_instance_valid(new_entity):
				var center = Vector2(side.size.x / 2.0, side.size.y / 2.0)
				window.show_for_entity(new_entity, 0, center)
				if get_node_or_null("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_click")
			else:
				window.hide_window()


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
	var relic_focus = false
	if InputManager != null:
		relic_focus = InputManager.relic_focus_p1 if player_id == 1 else InputManager.relic_focus_p2
	if relic_focus:
		return true
		
	if not clamp_to_range:
		return true
	if player == null:
		return true
	if is_instance_valid(player) and player.has_method("is_targeting_ability") and player.is_targeting_ability():
		return player.has_method("is_tile_valid_for_targeting") and player.is_tile_valid_for_targeting(tile)

	var origin := player.get("grid_pos") as Vector2i
	if tile == origin:
		return true

	# Prefer cached range tiles from MovementRangeManager (if available)
	var range_mgr := get_node_or_null("/root/MovementRangeManager")
	if is_instance_valid(range_mgr) and range_mgr.has_method("get_range_tiles_for_player"):
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
