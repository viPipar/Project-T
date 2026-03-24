extends Node

var grid_size: Vector2i = Vector2i(16, 16)

# true = bisa diinjak
var _walkable: Dictionary = {}      # Vector2i -> bool
var _entities: Dictionary = {}      # Vector2i -> Node

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

	# Default semua tile walkable
	for x in range(width):
		for y in range(height):
			_walkable[Vector2i(x, y)] = true

func set_tile_walkable(pos: Vector2i, can_walk: bool) -> void:
	_walkable[pos] = can_walk
	_astar.set_point_solid(pos, not can_walk)

func is_walkable(pos: Vector2i) -> bool:
	if not _walkable.has(pos):
		return false
	if _entities.has(pos):
		return false
	return _walkable[pos]

func register_entity(pos: Vector2i, entity: Node) -> void:
	_entities[pos] = entity

func unregister_entity(pos: Vector2i) -> void:
	_entities.erase(pos)

func move_entity(from: Vector2i, to: Vector2i, entity: Node) -> void:
	unregister_entity(from)
	register_entity(to, entity)

func get_entity_at(pos: Vector2i) -> Node:
	return _entities.get(pos, null)

# PENTING: nama fungsi find_path bukan get_path
# get_path adalah built-in AStarGrid2D -> bentrok
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(to):
		return []
	var raw: Array[Vector2i] = _astar.get_id_path(from, to)
	return raw

func get_path_cost(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return 0  # balik ke tempat sendiri = 0 langkah
	# Sementara unregister entity-nya sendiri biar path bisa ngitung
	var path := _astar.get_id_path(from, to)
	if path.is_empty():
		return -1
	return path.size() - 1

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

# Chebyshev distance
func get_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
