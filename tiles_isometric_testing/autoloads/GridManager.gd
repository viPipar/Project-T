extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  GridManager  (autoload)
#
#  Single source of truth for:
#    • Which tiles exist and whether they are walkable terrain
#    • Which entity occupies each tile
#    • A* pathfinding (cardinal only)
#
#  NOTE: is_walkable() checks BOTH terrain flag AND entity occupation.
#        Use is_terrain_walkable() when you only need the terrain flag
#        (e.g. when building paths that must reach an occupied tile).
# ─────────────────────────────────────────────────────────────────────────────

var grid_size: Vector2i = Vector2i(16, 16)

var _walkable:  Dictionary = {}   # Vector2i -> bool  (terrain only)
var _entities:  Dictionary = {}   # Vector2i -> Node

var _astar: AStarGrid2D


func _ready() -> void:
	setup_grid(grid_size.x, grid_size.y)


func setup_grid(width: int, height: int) -> void:
	grid_size = Vector2i(width, height)
	_walkable.clear()
	_entities.clear()

	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, width, height)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	for x in range(width):
		for y in range(height):
			_walkable[Vector2i(x, y)] = true


# ── Terrain ───────────────────────────────────────────────────────────────────

func set_tile_walkable(pos: Vector2i, can_walk: bool) -> void:
	_walkable[pos] = can_walk
	_astar.set_point_solid(pos, not can_walk)


## True only when terrain is walkable AND no entity stands here.
func is_walkable(pos: Vector2i) -> bool:
	if not _walkable.get(pos, false):
		return false
	if _entities.has(pos):
		return false
	return true


## True when terrain allows walking, ignoring entity occupation.
func is_terrain_walkable(pos: Vector2i) -> bool:
	return _walkable.get(pos, false)


# ── Entity Registry ───────────────────────────────────────────────────────────

func register_entity(pos: Vector2i, entity: Node) -> void:
	_entities[pos] = entity


func unregister_entity(pos: Vector2i) -> void:
	_entities.erase(pos)


func move_entity(from: Vector2i, to: Vector2i, entity: Node) -> void:
	unregister_entity(from)
	register_entity(to, entity)


func get_entity_at(pos: Vector2i) -> Node:
	return _entities.get(pos, null)


func has_entity_at(pos: Vector2i) -> bool:
	return _entities.has(pos)


# ── Pathfinding ───────────────────────────────────────────────────────────────

## Returns the full tile path from `from` to `to`.
## The destination must be walkable (no entity, passable terrain).
## Returns [] when unreachable.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(to):
		return []
	var raw: Array[Vector2i] = _astar.get_id_path(from, to)
	return raw


## Cost (steps) of the cheapest path, or -1 if unreachable.
## Temporarily unblocks the destination entity slot so the cost
## can be calculated even toward an occupied tile.
func get_path_cost(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return 0
	# Temporarily remove the entity at 'to' so AStar can evaluate the path
	var had_entity := _entities.has(to)
	var saved_entity: Node = null
	if had_entity:
		saved_entity = _entities[to]
		_entities.erase(to)

	var path := _astar.get_id_path(from, to)
	var cost := -1 if path.is_empty() else path.size() - 1

	if had_entity:
		_entities[to] = saved_entity

	return cost


## All tiles reachable within `max_steps` (walkable, no entity, within range).
func get_reachable_tiles(origin: Vector2i, max_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(origin.x - max_steps, origin.x + max_steps + 1):
		for y in range(origin.y - max_steps, origin.y + max_steps + 1):
			var pos := Vector2i(x, y)
			if pos == origin:
				continue
			if get_distance(origin, pos) <= max_steps and is_walkable(pos):
				result.append(pos)
	return result


## Chebyshev distance (8-directional).
func get_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
