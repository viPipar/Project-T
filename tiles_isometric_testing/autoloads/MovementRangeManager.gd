extends Node

# Auto-highlight movement range tiles for each player.
# Uses HighlightManager types: move_p1 / move_p2 (falls back to "move").

@export var enabled: bool = true
@export var refresh_on_turn_events: bool = true

var _tiles_by_player: Dictionary = {}
var _origin_by_player: Dictionary = {}


func _ready() -> void:
	if EventBus != null:
		if not EventBus.player_moved.is_connected(_on_player_moved):
			EventBus.player_moved.connect(_on_player_moved)
		if not EventBus.stats_changed.is_connected(_on_stats_changed):
			EventBus.stats_changed.connect(_on_stats_changed)
		if not EventBus.buffs_changed.is_connected(_on_buffs_changed):
			EventBus.buffs_changed.connect(_on_buffs_changed)

	if TurnManager != null and refresh_on_turn_events:
		if not TurnManager.turn_state_changed.is_connected(_on_turn_state_changed):
			TurnManager.turn_state_changed.connect(_on_turn_state_changed)
		if not TurnManager.player_end_state_changed.is_connected(_on_player_end_changed):
			TurnManager.player_end_state_changed.connect(_on_player_end_changed)

	call_deferred("_refresh_all")


func _on_player_moved(_entity: Node, _from: Vector2i, _to: Vector2i) -> void:
	_refresh_all()


func _on_turn_state_changed(_turn_number: int, _phase: int) -> void:
	_refresh_all()


func _on_player_end_changed(_player_id: int, _ended: bool) -> void:
	_refresh_all()


func _on_stats_changed(_entity: Node) -> void:
	_refresh_all()


func _on_buffs_changed(_entity: Node) -> void:
	_refresh_all()


func _refresh_all() -> void:
	if not enabled:
		_clear_all()
		return
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		_refresh_player(p)


func _refresh_player(player: Node) -> void:
	if player == null:
		return
	var pid = _safe_get_int(player, "player_id", -1)
	var type := _type_for_player(pid)

	if TurnManager != null and pid >= 0 and not TurnManager.can_player_act(pid):
		_clear_type(type)
		_store_range(pid, player.get("grid_pos") as Vector2i, [] as Array[Vector2i])
		return

	var move := player.get_node_or_null("MovementComponent") as MovementComponent
	if move == null or move.movement_left <= 0:
		_clear_type(type)
		_store_range(pid, player.get("grid_pos") as Vector2i, [] as Array[Vector2i])
		return

	var origin := player.get("grid_pos") as Vector2i
	var tiles := GridManager.get_reachable_tiles_pathing(origin, move.movement_left, player)
	HighlightManager.replace_tiles(tiles, type)
	_store_range(pid, origin, tiles)


func _clear_all() -> void:
	_clear_type("move_p1")
	_clear_type("move_p2")
	_clear_type("move")
	_tiles_by_player.clear()
	_origin_by_player.clear()


func _clear_type(type: String) -> void:
	if HighlightManager != null:
		HighlightManager.clear(type)


func _type_for_player(player_id: int) -> String:
	if player_id == 1:
		return "move_p1"
	if player_id == 2:
		return "move_p2"
	return "move"


func get_range_tiles_for_player(player_id: int) -> Array[Vector2i]:
	if not _tiles_by_player.has(player_id):
		return []
	var tiles: Array[Vector2i] = _tiles_by_player[player_id]
	return tiles.duplicate()


func get_origin_tile_for_player(player_id: int) -> Vector2i:
	if not _origin_by_player.has(player_id):
		return Vector2i(-1, -1)
	var origin: Vector2i = _origin_by_player[player_id]
	return origin


func _store_range(player_id: int, origin: Vector2i, tiles: Array[Vector2i]) -> void:
	if player_id < 0:
		return
	_origin_by_player[player_id] = origin
	_tiles_by_player[player_id] = tiles.duplicate()


func _safe_get_int(node: Node, prop: String, fallback: int) -> int:
	if node == null:
		return fallback
	for info in node.get_property_list():
		if info.name == prop:
			var val = node.get(prop)
			if typeof(val) == TYPE_INT:
				return val
	return fallback
