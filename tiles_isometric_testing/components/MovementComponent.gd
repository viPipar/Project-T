extends Node
class_name MovementComponent

# New dash guide:
#   movement.dash(Vector2i.RIGHT, 3)
#   movement.dash(Vector2i.RIGHT, 3, {"free_dash": false})

# ─────────────────────────────────────────────────────────────────────────────
#  MovementComponent
#
#  Responsibilities:
#    • Validate whether a target tile is walkable and reachable.
#    • Allow targeting tiles that hold entities (for attack / interaction).
#    • Animate the owner along the A* path using a Bézier curve per step.
#    • Expose movement_left so other systems can query remaining range.
#
#  Signals:
#    move_started(from, to)   — fires when travel begins
#    move_finished(from, to)  — fires when the owner reaches the destination
#    move_blocked(target)     — fires when the tile is unreachable
#
#  Usage:
#    move_to(tile)            — walk to an empty walkable tile
#    interact_move_to(tile)   — walk to the tile adjacent to an entity tile
#    has_movement()           — true if movement_left > 0
#    get_reachable_tiles()    — Array[Vector2i] of tiles the owner can reach
# ─────────────────────────────────────────────────────────────────────────────

signal move_started(from: Vector2i, to: Vector2i)
signal move_finished(from: Vector2i, to: Vector2i)
signal move_blocked(target: Vector2i)
signal step_started(from: Vector2i, to: Vector2i)

## Steps per second while walking
@export var walk_speed: float = 6.0

## Base movement range in tiles (reset each turn)
@export var base_movement: int = 4

var movement_left: int = 4
var infinite_moves: bool = false

# Internal travel state
var _is_moving:    bool           = false
var _path:         Array[Vector2i] = []
var _path_index:   int            = 0
var _travel_t:     float          = 0.0   # 0..1 within current step
var _step_origin:  Vector2        = Vector2.ZERO
var _step_target:  Vector2        = Vector2.ZERO
var _ctrl_offset:  Vector2        = Vector2.ZERO  # Bézier control-point lift


func _ready() -> void:
	reset_movement()


# ── Public API ───────────────────────────────────────────────────────────────

## Walk to an empty, walkable tile.
## Returns false immediately if the move is invalid.
func move_to(target: Vector2i) -> bool:
	if _owner_is_downed():
		move_blocked.emit(target)
		return false

	var my_pos: Vector2i = _owner_grid_pos()

	if target == my_pos:
		return false

	# Must be a walkable tile with no entity on it
	if not GridManager.can_enter_tile(target, owner):
		move_blocked.emit(target)
		return false

	var cost := GridManager.get_path_cost(my_pos, target)
	var max_range: int = movement_left
	if infinite_moves: max_range = base_movement + _get_movement_bonus()
	
	if cost < 0 or cost > max_range:
		move_blocked.emit(target)
		return false

	var path := GridManager.find_path(my_pos, target)
	if path.size() < 2:
		move_blocked.emit(target)
		return false

	_begin_travel(path, cost)
	return true


## Use this for attack / interaction — target itself may be blocked.
## Picks the reachable neighbour closest to the entity.
func interact_move_to(entity_tile: Vector2i) -> bool:
	if _owner_is_downed():
		move_blocked.emit(entity_tile)
		return false

	var my_pos: Vector2i = _owner_grid_pos()

	# Gather walkable neighbours of the entity tile
	var neighbours: Array[Vector2i] = _walkable_neighbours(entity_tile)
	if neighbours.is_empty():
		move_blocked.emit(entity_tile)
		return false

	var max_range: int = movement_left
	if infinite_moves: max_range = base_movement + _get_movement_bonus()

	# Pick the neighbour with cheapest path cost, then by tile distance
	var best_tile := Vector2i(-1, -1)
	var best_cost: int = max_range + 1

	for nb in neighbours:
		var c := GridManager.get_path_cost(my_pos, nb)
		if c >= 0 and c <= max_range and c < best_cost:
			best_cost = c
			best_tile = nb

	if best_tile == Vector2i(-1, -1):
		move_blocked.emit(entity_tile)
		return false

	var path := GridManager.find_path(my_pos, best_tile)
	if path.size() < 2:
		move_blocked.emit(entity_tile)
		return false

	_begin_travel(path, best_cost)
	print("Player menabrak: ", entity_tile)
	return true


## Forced dash API.
## Example: movement.dash(Vector2i.RIGHT, 3)
## Default is a free dash. Pass {"free_dash": false} to spend movement_left.
func dash(direction: Vector2i, distance: int, options: Dictionary = {}) -> Dictionary:
	var from := _owner_grid_pos()
	if _owner_is_downed() or _is_moving:
		return _make_dash_result(false, "blocked", from, from)

	var result := ForcedMovementResolver.dash_entity(owner, direction, distance, owner, options)
	if bool(result.get("success", false)):
		var to: Vector2i = result.get("to", from)
		if not bool(options.get("free_dash", true)):
			movement_left = maxi(0, movement_left - int(result.get("moved_steps", 0)))
		if to != from:
			move_started.emit(from, to)
			move_finished.emit(from, to)
			EventBus.player_moved.emit(owner, from, to)
			_trigger_environment_at(to, "dash_finished", from)
	return result


func has_movement() -> bool:
	if _owner_is_downed():
		return false
	if infinite_moves: return true
	return movement_left > 0 and not _is_moving


func reset_movement() -> void:
	if _owner_is_downed():
		movement_left = 0
		return

	# base_movement is ALWAYS 6 in the new action economy. 
	# The stats-based bonus (mov / 5) is already calculated inside _get_movement_bonus()!
	base_movement = 6
	movement_left = base_movement + _get_movement_bonus()


func get_reachable_tiles() -> Array[Vector2i]:
	if _owner_is_downed():
		return []

	var max_range: int = movement_left
	if infinite_moves: max_range = base_movement + _get_movement_bonus()
	return GridManager.get_reachable_tiles(_owner_grid_pos(), max_range)


# ── Travel Engine ────────────────────────────────────────────────────────────

func _begin_travel(path: Array[Vector2i], cost: int) -> void:
	var from: Vector2i = _owner_grid_pos()
	var to:   Vector2i = path[path.size() - 1]
	owner.scale = Vector2.ONE

	# Commit to grid immediately so other systems see the new position
	if not GridManager.move_entity(from, to, owner):
		move_blocked.emit(to)
		return
	owner.set("grid_pos", to)
	
	if not infinite_moves:
		movement_left -= cost
	else:
		movement_left = base_movement + _get_movement_bonus()

	_path        = path
	_path_index  = 0
	_is_moving   = true
	_travel_t    = 0.0

	_start_step(_path_index)
	move_started.emit(from, to)

	# Update z_index at final tile
	owner.z_index = IsoUtils.get_depth(to)


func _process(delta: float) -> void:
	if not _is_moving:
		return

	_travel_t += delta * walk_speed

	if _travel_t >= 1.0:
		owner.position = _step_target
		_land_squash()
		_path_index += 1

		if _path_index >= _path.size() - 1:
			_is_moving = false
			var dest: Vector2i = _path[_path.size() - 1]
			move_finished.emit(_path[0], dest)
			EventBus.player_moved.emit(owner, _path[0], dest)
			_trigger_environment_at(dest, "move_finished", _path[0])
		else:
			_travel_t -= 1.0
			_start_step(_path_index)
	else:
		var eased_t = _ease_out_back(_travel_t)
		owner.position = _bezier(_step_origin, _ctrl_offset, _step_target, eased_t)


func _start_step(index: int) -> void:
	var from_tile := _path[index]
	var to_tile := _path[index + 1]
	_step_origin = IsoUtils.world_to_iso(from_tile)
	_step_target = IsoUtils.world_to_iso(to_tile)

	# Control point: lift slightly above the midpoint for a gentle arc
	var mid := (_step_origin + _step_target) * 0.5
	_ctrl_offset = mid + Vector2(0, -IsoUtils.TILE_H * 0.35)
	step_started.emit(from_tile, to_tile)


## Quadratic Bézier: origin → ctrl → target
func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


func _land_squash() -> void:
	var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(owner, "scale", Vector2(1.1, 0.9), 0.08)
	tw.parallel().tween_property(owner, "scale", Vector2(1.0, 1.0), 0.25).set_delay(0.08)


static func _ease_out_back(t: float) -> float:
	var c1 = 1.70158
	var c3 = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _owner_grid_pos() -> Vector2i:
	return owner.get("grid_pos") as Vector2i


func _get_movement_bonus() -> int:
	var stats := owner.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return 0
	return stats.bonus_movement_tiles()


func _owner_is_downed() -> bool:
	if owner == null:
		return false
	if is_instance_valid(owner) and owner.has_method("is_downed"):
		return bool(owner.is_downed())
	var health := owner.get_node_or_null("HealthComponent") as HealthComponent
	return health != null and health.is_downed()


func _trigger_environment_at(tile: Vector2i, reason: String, from_tile: Vector2i) -> void:
	var environment_handler := get_node_or_null("/root/EnvironmentInteractionHandler")
	if environment_handler == null:
		return
	environment_handler.trigger_tile(owner, tile, {
		"reason": reason,
		"from": from_tile,
	})


func _make_dash_result(success: bool, reason: String, from: Vector2i, to: Vector2i) -> Dictionary:
	return {
		"kind": "dash",
		"success": success,
		"reason": reason,
		"from": from,
		"to": to,
		"moved_steps": 0,
		"collided": false,
	}


func _walkable_neighbours(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			# Only cardinal, matching the grid's DIAGONAL_MODE_NEVER
			if dx != 0 and dy != 0:
				continue
			var nb := center + Vector2i(dx, dy)
			if GridManager.is_walkable(nb):
				result.append(nb)
	return result
