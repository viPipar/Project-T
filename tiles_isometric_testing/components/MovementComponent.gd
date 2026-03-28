extends Node
class_name MovementComponent

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

## Steps per second while walking
@export var walk_speed: float = 6.0

## Base movement range in tiles (reset each turn)
@export var base_movement: int = 100

var movement_left: int = 100

# Internal travel state
var _is_moving:    bool           = false
var _path:         Array[Vector2i] = []
var _path_index:   int            = 0
var _travel_t:     float          = 0.0   # 0..1 within current step
var _step_origin:  Vector2        = Vector2.ZERO
var _step_target:  Vector2        = Vector2.ZERO
var _ctrl_offset:  Vector2        = Vector2.ZERO  # Bézier control-point lift


func _ready() -> void:
	movement_left = base_movement + _get_movement_bonus()


# ── Public API ───────────────────────────────────────────────────────────────

## Walk to an empty, walkable tile.
## Returns false immediately if the move is invalid.
func move_to(target: Vector2i) -> bool:
	var my_pos: Vector2i = _owner_grid_pos()

	if target == my_pos:
		return false

	# Must be a walkable tile with no entity on it
	if not GridManager.can_enter_tile(target, owner):
		move_blocked.emit(target)
		return false

	var cost := GridManager.get_path_cost(my_pos, target)
	if cost < 0 or cost > movement_left:
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
	var my_pos: Vector2i = _owner_grid_pos()

	# Gather walkable neighbours of the entity tile
	var neighbours: Array[Vector2i] = _walkable_neighbours(entity_tile)
	if neighbours.is_empty():
		move_blocked.emit(entity_tile)
		return false

	# Pick the neighbour with cheapest path cost, then by tile distance
	var best_tile := Vector2i(-1, -1)
	var best_cost := movement_left + 1

	for nb in neighbours:
		var c := GridManager.get_path_cost(my_pos, nb)
		if c >= 0 and c <= movement_left and c < best_cost:
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


func has_movement() -> bool:
	return movement_left > 0 and not _is_moving


func reset_movement() -> void:
	movement_left = base_movement + _get_movement_bonus()


func get_reachable_tiles() -> Array[Vector2i]:
	return GridManager.get_reachable_tiles(_owner_grid_pos(), movement_left)


# ── Travel Engine ────────────────────────────────────────────────────────────

func _begin_travel(path: Array[Vector2i], cost: int) -> void:
	var from: Vector2i = _owner_grid_pos()
	var to:   Vector2i = path[path.size() - 1]

	# Commit to grid immediately so other systems see the new position
	if not GridManager.move_entity(from, to, owner):
		move_blocked.emit(to)
		return
	owner.set("grid_pos", to)
	movement_left -= cost

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
		# Snap to end of this step
		owner.position = _step_target
		_path_index += 1

		if _path_index >= _path.size() - 1:
			# Reached the final tile
			_is_moving = false
			var dest: Vector2i = _path[_path.size() - 1]
			move_finished.emit(_path[0], dest)
			EventBus.player_moved.emit(owner, _path[0], dest)
		else:
			# Advance to next step
			_travel_t -= 1.0
			_start_step(_path_index)
	else:
		owner.position = _bezier(_step_origin, _ctrl_offset, _step_target, _travel_t)


func _start_step(index: int) -> void:
	_step_origin = IsoUtils.world_to_iso(_path[index])
	_step_target = IsoUtils.world_to_iso(_path[index + 1])

	# Control point: lift slightly above the midpoint for a gentle arc
	var mid := (_step_origin + _step_target) * 0.5
	_ctrl_offset = mid + Vector2(0, -IsoUtils.TILE_H * 0.35)


## Quadratic Bézier: origin → ctrl → target
func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


# ── Helpers ───────────────────────────────────────────────────────────────────

func _owner_grid_pos() -> Vector2i:
	return owner.get("grid_pos") as Vector2i


func _get_movement_bonus() -> int:
	var stats := owner.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return 0
	return stats.bonus_movement_tiles()


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
