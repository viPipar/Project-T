extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  GridManager  (autoload)
#
#  Single source of truth untuk:
#    • Tile walkable / wall (terrain)
#    • Entity per tile: Player, NPC, Enemy — satu entity per tile
#    • Item per tile    : bisa tumpuk (beberapa item di satu tile)
#    • A* pathfinding (cardinal only)
#
#  Tipe entity (EntityType enum):
#    PLAYER  – dikontrol pemain
#    NPC     – friendly / netral
#    ENEMY   – musuh
#
#  API utama:
#    is_walkable(pos)              → terrain walkable DAN tidak ada entity
#    is_terrain_walkable(pos)      → terrain saja, abaikan entity
#    is_wall(pos)                  → true jika tile adalah wall
#    get_entity_at(pos)            → Node | null
#    get_entity_type(pos)          → EntityType | -1
#    get_items_at(pos)             → Array[Node]  (bisa kosong)
#    place_item(pos, item)         → taruh item di tile
#    remove_item(pos, item)        → ambil / hapus item dari tile
#    find_path(from, to)           → Array[Vector2i]
#    get_reachable_tiles(...)      → Array[Vector2i]
#    get_tiles_with_entity_type()  → cari semua tile berisi tipe tertentu
# ─────────────────────────────────────────────────────────────────────────────

# ── Tipe Entity ───────────────────────────────────────────────────────────────
enum EntityType { PLAYER, NPC, ENEMY }

# ── State Internal ────────────────────────────────────────────────────────────
var grid_size: Vector2i = Vector2i(16, 16)

## terrain: Vector2i → bool
var _walkable: Dictionary = {}

## entity slot: Vector2i → { node: Node, type: EntityType }
var _entities: Dictionary = {}

## item layer: Vector2i → Array[Node]  (beberapa item boleh di tile yang sama)
var _items: Dictionary = {}

var _astar: AStarGrid2D


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	setup_grid(grid_size.x, grid_size.y)


func setup_grid(width: int, height: int) -> void:
	grid_size = Vector2i(width, height)
	_walkable.clear()
	_entities.clear()
	_items.clear()

	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, width, height)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	for x in range(width):
		for y in range(height):
			_walkable[Vector2i(x, y)] = true


# ── Terrain / Wall ────────────────────────────────────────────────────────────

## Pasang banyak wall sekaligus dari array koordinat.
func setup_walls(coords_list: Array[Vector2i]) -> void:
	for pos in coords_list:
		if _is_in_bounds(pos):
			set_tile_walkable(pos, false)
		else:
			push_warning("[GridManager] setup_walls: pos %s di luar grid, di-skip." % pos)
	_astar.update()
	print("[GridManager] %d wall dipasang." % coords_list.size())


## Load wall dari MapData berdasarkan map_id.
func load_walls_for_map(map_id: int) -> void:
	var walls: Array[Vector2i] = MapData.get_walls(map_id)
	if walls.is_empty():
		print("[GridManager] Map %d tidak punya wall atau tidak ditemukan." % map_id)
		return
	setup_walls(walls)


## Set satu tile walkable atau tidak (wall).
func set_tile_walkable(pos: Vector2i, can_walk: bool) -> void:
	if not _is_in_bounds(pos):
		push_warning("[GridManager] set_tile_walkable: pos %s di luar grid, di-skip." % pos)
		return
	_walkable[pos] = can_walk
	_astar.set_point_solid(pos, not can_walk)


## True jika terrain walkable DAN tidak ada entity di tile ini.
## Ini yang dipakai pathfinding & movement untuk tile tujuan kosong.
func is_walkable(pos: Vector2i) -> bool:
	return _walkable.get(pos, false) and not _entities.has(pos)


## True jika terrain walkable, abaikan entity.
## Dipakai saat hitung path menuju tile yang ditempati entity.
func is_terrain_walkable(pos: Vector2i) -> bool:
	return _walkable.get(pos, false)


## True jika tile adalah wall (terrain tidak walkable).
func is_wall(pos: Vector2i) -> bool:
	return not _walkable.get(pos, false)


# ── Entity Registry ───────────────────────────────────────────────────────────

## Daftarkan entity dengan tipenya (EntityType.PLAYER / NPC / ENEMY).
func register_entity(pos: Vector2i, entity: Node, type: EntityType = EntityType.PLAYER) -> void:
	if _entities.has(pos):
		push_warning("[GridManager] register_entity: tile %s sudah ada entity '%s', ditimpa!" % [pos, _entities[pos].node.name])
	_entities[pos] = { "node": entity, "type": type }


func unregister_entity(pos: Vector2i) -> void:
	_entities.erase(pos)


func move_entity(from: Vector2i, to: Vector2i, entity: Node) -> void:
	# Pertahankan tipe entity saat pindah tile
	var type := get_entity_type(from)
	unregister_entity(from)
	if type < 0:
		# Fallback: tebak tipe dari grup Godot
		type = _guess_type(entity)
	register_entity(to, entity, type as EntityType)


## Kembalikan Node entity di tile, atau null.
func get_entity_at(pos: Vector2i) -> Node:
	var slot = _entities.get(pos, null)
	return slot.node if slot else null


## Kembalikan EntityType di tile, atau -1 jika kosong.
func get_entity_type(pos: Vector2i) -> int:
	var slot = _entities.get(pos, null)
	return slot.type if slot else -1


func has_entity_at(pos: Vector2i) -> bool:
	return _entities.has(pos)


## True jika tile berisi entity dengan tipe tertentu.
func has_entity_type_at(pos: Vector2i, type: EntityType) -> bool:
	return get_entity_type(pos) == type


## Kembalikan semua tile yang berisi entity tipe tertentu.
func get_tiles_with_entity_type(type: EntityType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in _entities:
		if _entities[pos].type == type:
			result.append(pos)
	return result


## Kembalikan semua player dalam dict { Vector2i: Node }.
func get_all_players() -> Dictionary:
	return _get_all_by_type(EntityType.PLAYER)


## Kembalikan semua NPC dalam dict { Vector2i: Node }.
func get_all_npcs() -> Dictionary:
	return _get_all_by_type(EntityType.NPC)


## Kembalikan semua musuh dalam dict { Vector2i: Node }.
func get_all_enemies() -> Dictionary:
	return _get_all_by_type(EntityType.ENEMY)


# ── Item Layer ────────────────────────────────────────────────────────────────
# Item TIDAK memblokir walkability — entity dan item bisa di tile yang sama.

## Taruh item di tile. Boleh ada beberapa item di tile yang sama.
func place_item(pos: Vector2i, item: Node) -> void:
	if not _items.has(pos):
		_items[pos] = []
	_items[pos].append(item)


## Hapus item spesifik dari tile. Kembalikan true jika berhasil.
func remove_item(pos: Vector2i, item: Node) -> bool:
	if not _items.has(pos):
		return false
	var arr: Array = _items[pos]
	var idx := arr.find(item)
	if idx < 0:
		return false
	arr.remove_at(idx)
	if arr.is_empty():
		_items.erase(pos)
	return true


## Ambil semua item di tile (array kosong jika tidak ada).
func get_items_at(pos: Vector2i) -> Array:
	return _items.get(pos, []).duplicate()


## True jika ada minimal satu item di tile.
func has_item_at(pos: Vector2i) -> bool:
	return _items.has(pos) and not _items[pos].is_empty()


## Hapus dan kembalikan semua item di tile (pickup sekaligus).
func collect_all_items(pos: Vector2i) -> Array:
	var items: Array = _items.get(pos, []).duplicate()
	_items.erase(pos)
	return items


## Pindahkan item dari satu tile ke tile lain.
func move_item(from: Vector2i, to: Vector2i, item: Node) -> bool:
	if not remove_item(from, item):
		return false
	place_item(to, item)
	return true


# ── Pathfinding ───────────────────────────────────────────────────────────────

## Kembalikan path penuh dari `from` ke `to`.
## Tujuan harus walkable (tidak ada entity, terrain passable).
## Kembalikan [] jika tidak bisa dicapai.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(to):
		return []
	return _astar.get_id_path(from, to)


## Biaya langkah dari `from` ke `to`, atau -1 jika tidak bisa dicapai.
## Sementara lepas entity di tujuan agar AStar bisa hitung ke tile yang ditempati.
func get_path_cost(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return 0
	var saved_slot = _entities.get(to, null)
	if saved_slot:
		_entities.erase(to)

	var path := _astar.get_id_path(from, to)
	var cost := -1 if path.is_empty() else path.size() - 1

	if saved_slot:
		_entities[to] = saved_slot

	return cost


## Semua tile yang bisa dicapai dalam `max_steps` langkah
## (walkable, tidak ada entity, dalam jangkauan).
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


## Jarak Chebyshev (8-arah).
func get_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ── Debug ─────────────────────────────────────────────────────────────────────

## Print ringkasan isi grid ke console.
func debug_print_state() -> void:
	print("=== GridManager State ===")
	print("Grid size: ", grid_size)
	var wall_count := 0
	for pos in _walkable:
		if not _walkable[pos]:
			wall_count += 1
	print("Walls: ", wall_count)
	print("Entities:")
	for pos in _entities:
		var slot = _entities[pos]
		var type_name: String = EntityType.keys()[slot["type"]]
		print("  [%s] %s (%s)" % [pos, slot.node.name, type_name])
	print("Items:")
	for pos in _items:
		print("  [%s] %d item(s)" % [pos, _items[pos].size()])
	print("=========================")


# ── Internal Helpers ──────────────────────────────────────────────────────────

func _get_all_by_type(type: EntityType) -> Dictionary:
	var result := {}
	for pos in _entities:
		if _entities[pos].type == type:
			result[pos] = _entities[pos].node
	return result


## Tebak EntityType dari grup Godot sebagai fallback.
func _guess_type(entity: Node) -> EntityType:
	if entity.is_in_group("players"):
		return EntityType.PLAYER
	if entity.is_in_group("enemies"):
		return EntityType.ENEMY
	return EntityType.NPC


func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid_size.x and pos.y < grid_size.y
