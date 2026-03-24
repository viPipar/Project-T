extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  SelectionCursor
#
#  States:
#    "self"      — cursor is on the player's own tile  (dark grey)
#    "valid"     — empty walkable tile in range         (green)
#    "entity"    — occupied tile, adjacent tile reachable (yellow/orange)
#    "invalid"   — out of range or blocked              (red)
# ─────────────────────────────────────────────────────────────────────────────

@export var color_valid:   Color = Color(0.2, 1.0, 0.4,  0.55)
@export var color_invalid: Color = Color(1.0, 0.2, 0.2,  0.45)
@export var color_self:    Color = Color(0.1, 0.1, 0.1,  0.30)
@export var color_entity:  Color = Color(1.0, 0.7, 0.1,  0.60)  # orange-yellow

var _player: Node2D = null
var _state:  String = "valid"


func bind(player: Node) -> void:
	_player = player
	var player_id: int = _player.get_player_id()
	var factor := float(player_id) * 0.3
	color_valid = Color(
		0.2,
		clamp(1.0 + factor, 0.0, 1.0),
		clamp(0.4 + factor, 0.0, 1.0),
		0.55
	)


func _process(_delta: float) -> void:
	if _player == null:
		return

	var target: Vector2i = Vector2i(-1, -1)
	if _player._cursor != null and _player._cursor.has_method("get_hovered_tile"):
		target = _player._cursor.get_hovered_tile()

	if target.x < 0:
		visible = false
		return

	var origin: Vector2i = _player.grid_pos

	if target == origin:
		_show("self", target)
		return

	# Is there an entity on that tile?
	# Is there an entity on that tile?
	if GridManager.has_entity_at(target):
		# Check whether an adjacent tile is reachable
		var reachable_adj := _has_reachable_adjacent(origin, target, _player.get_movement_left())
		_show("entity" if reachable_adj else "invalid", target)
		return

	# Normal walkable tile
	var cost := GridManager.get_path_cost(origin, target)
	var reachable: bool = cost >= 0 and cost <= _player.get_movement_left()
	_show("valid" if reachable else "invalid", target)


func _show(state: String, grid_pos: Vector2i) -> void:
	_state   = state
	position = IsoUtils.world_to_iso(grid_pos)
	z_index  = IsoUtils.get_depth(grid_pos) + 1
	visible  = true
	queue_redraw()


func _draw() -> void:
	var hw  := IsoUtils.TILE_W / 2.0
	var hh  := IsoUtils.TILE_H / 2.0
	var pts := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0),
		Vector2(0,  hh), Vector2(-hw, 0),
	])
	var col: Color = match_color(_state)
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), col.lightened(0.3), 2.0)


func match_color(state: String) -> Color:
	match state:
		"invalid": return color_invalid
		"self":    return color_self
		"entity":  return color_entity
		_:         return color_valid


# ── Helpers ───────────────────────────────────────────────────────────────────

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
