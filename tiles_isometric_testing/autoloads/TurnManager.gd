extends Node

# Turn system with shared player phase and queued enemy phase.
# Players can act freely during the player phase and must all end
# their turns before enemies act.

signal turn_state_changed(turn_number: int, phase: int)
signal player_end_state_changed(player_id: int, ended: bool)
signal enemy_turn_started(enemy: Node)
signal enemy_turn_ended(enemy: Node)

enum Phase { PLAYERS, ENEMIES }

var turn_number: int = 1
var phase: Phase = Phase.PLAYERS

var _players: Array[Node] = []
var _player_ids: Array[int] = []
var _ended_players: Dictionary = {}

var _enemy_queue: Array[Node] = []
var _current_enemy: Node = null

var _started: bool = false


func register_player(player: Node) -> void:
	if player == null:
		return
	if _players.has(player):
		return
	_players.append(player)
	var pid = player.get("player_id")
	if typeof(pid) == TYPE_INT and not _player_ids.has(pid):
		_player_ids.append(pid)


func unregister_player(player: Node) -> void:
	if player == null:
		return
	if _players.has(player):
		_players.erase(player)
	var pid = player.get("player_id")
	if typeof(pid) == TYPE_INT and _player_ids.has(pid):
		_player_ids.erase(pid)
	_ended_players.erase(pid)


func start_battle() -> void:
	if _started:
		return
	_started = true
	if _players.is_empty():
		_auto_register_players()
	_begin_player_phase()


func can_player_act(player_id: int) -> bool:
	if not _started:
		return true
	if phase != Phase.PLAYERS:
		return false
	return not _ended_players.has(player_id)


func is_player_ended(player_id: int) -> bool:
	return _ended_players.has(player_id)


func request_end_turn(player_id: int = -1) -> void:
	if phase == Phase.PLAYERS:
		if player_id < 0:
			return
		_end_player_turn(player_id)
	elif phase == Phase.ENEMIES:
		_end_enemy_turn()


func get_turn_display_text() -> String:
	var phase_text := "Players" if phase == Phase.PLAYERS else "Enemies"
	return "Turn %d — %s" % [turn_number, phase_text]


# --- Phase Flow ---

func _begin_player_phase() -> void:
	phase = Phase.PLAYERS
	_ended_players.clear()
	_current_enemy = null
	_reset_movement_for_team(_players)
	for p in _players:
		if p != null:
			EventBus.turn_started.emit(p, p.get("player_id"))
	_emit_turn_state()


func _begin_enemy_phase() -> void:
	phase = Phase.ENEMIES
	_enemy_queue = _get_enemies()
	_reset_movement_for_team(_enemy_queue)
	_emit_turn_state()
	call_deferred("_advance_enemy_turn")


func _advance_enemy_turn() -> void:
	if _enemy_queue.is_empty():
		_end_enemy_phase()
		return
	_current_enemy = _enemy_queue.pop_front()
	EventBus.turn_started.emit(_current_enemy, -1)
	enemy_turn_started.emit(_current_enemy)


func _end_enemy_turn() -> void:
	if _current_enemy != null:
		EventBus.turn_ended.emit(_current_enemy)
		enemy_turn_ended.emit(_current_enemy)
	_current_enemy = null
	call_deferred("_advance_enemy_turn")


func _end_enemy_phase() -> void:
	turn_number += 1
	_begin_player_phase()


# --- Player End ---

func _end_player_turn(player_id: int) -> void:
	if _ended_players.has(player_id):
		return
	_ended_players[player_id] = true
	player_end_state_changed.emit(player_id, true)
	var player := _get_player_by_id(player_id)
	if player != null:
		EventBus.turn_ended.emit(player)
	if _all_players_ended():
		_begin_enemy_phase()


func _all_players_ended() -> bool:
	if _player_ids.is_empty():
		return true
	for pid in _player_ids:
		if not _ended_players.has(pid):
			return false
	return true


# --- Helpers ---

func _auto_register_players() -> void:
	var nodes := get_tree().get_nodes_in_group("players")
	for n in nodes:
		register_player(n)


func _get_player_by_id(player_id: int) -> Node:
	for p in _players:
		if p != null and p.get("player_id") == player_id:
			return p
	return null


func _get_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != null:
			result.append(e)
	return result


func _reset_movement_for_team(nodes: Array) -> void:
	for n in nodes:
		if n == null:
			continue
		var move := n.get_node_or_null("MovementComponent") as MovementComponent
		if move != null:
			move.reset_movement()


func _emit_turn_state() -> void:
	turn_state_changed.emit(turn_number, phase)
