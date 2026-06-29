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
var _battle_finished: bool = false


func _ready() -> void:
	if EventBus != null and not EventBus.entity_downed.is_connected(_on_entity_downed):
		EventBus.entity_downed.connect(_on_entity_downed)


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
	_battle_finished = false
	if _players.is_empty():
		_auto_register_players()
	_begin_player_phase()


func can_player_act(player_id: int) -> bool:
	if _battle_finished:
		return false
	if not _started:
		return true
	if phase != Phase.PLAYERS:
		return false
	if is_player_downed(player_id):
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


## Batalkan end turn player - hanya bisa jika enemy phase BELUM mulai.
func cancel_end_turn(player_id: int) -> void:
	if phase != Phase.PLAYERS:
		return
	if is_player_downed(player_id):
		return
	if not _ended_players.has(player_id):
		return
	_ended_players.erase(player_id)
	player_end_state_changed.emit(player_id, false)
	var player := _get_player_by_id(player_id)
	if player != null:
		EventBus.turn_started.emit(player, player_id)
	print("[TurnManager] P%d membatalkan End Turn." % player_id)


func get_turn_display_text() -> String:
	var phase_text := "Players" if phase == Phase.PLAYERS else "Enemies"
	return "Turn %d - %s" % [turn_number, phase_text]


# --- Phase Flow ---

func _begin_player_phase() -> void:
	phase = Phase.PLAYERS
	_clear_player_end_states()
	_current_enemy = null
	_reset_movement_for_team(_players)

	if _all_players_downed():
		_emit_turn_state()
		_trigger_defeat()
		return

	for p in _players:
		if p != null:
			var pid := int(p.get("player_id"))
			if _is_entity_downed(p):
				_mark_player_ended(pid, true)
			else:
				EventBus.turn_started.emit(p, pid)
	_emit_turn_state()
	if _all_players_ended():
		_begin_enemy_phase()


func _begin_enemy_phase() -> void:
	if _battle_finished:
		return
	phase = Phase.ENEMIES
	_clear_player_end_states()
	_enemy_queue = _get_enemies()
	_reset_movement_for_team(_enemy_queue)
	_emit_turn_state()
	call_deferred("_advance_enemy_turn")


func _advance_enemy_turn() -> void:
	if _battle_finished:
		return
	if _enemy_queue.is_empty():
		_end_enemy_phase()
		return
	_current_enemy = _enemy_queue.pop_front()
	EventBus.turn_started.emit(_current_enemy, -1)
	enemy_turn_started.emit(_current_enemy)


func _end_enemy_turn() -> void:
	if _battle_finished:
		return
	if _current_enemy != null:
		EventBus.turn_ended.emit(_current_enemy)
		enemy_turn_ended.emit(_current_enemy)
	_current_enemy = null
	call_deferred("_advance_enemy_turn")


func _end_enemy_phase() -> void:
	if _battle_finished:
		return
	turn_number += 1
	_begin_player_phase()


# --- Player End ---

func _end_player_turn(player_id: int) -> void:
	if _ended_players.has(player_id):
		return
	_mark_player_ended(player_id)
	var player := _get_player_by_id(player_id)
	if player != null:
		EventBus.turn_ended.emit(player)
	if _all_players_ended():
		_begin_enemy_phase()


func _all_players_ended() -> bool:
	if _player_ids.is_empty():
		return true
	for pid in _player_ids:
		if not _ended_players.has(pid) and not is_player_downed(pid):
			return false
	return true


func _clear_player_end_states() -> void:
	var ended_ids := _ended_players.keys()
	_ended_players.clear()
	for pid in ended_ids:
		player_end_state_changed.emit(int(pid), false)


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


func is_player_downed(player_id: int) -> bool:
	var player := _get_player_by_id(player_id)
	return _is_entity_downed(player)


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
			if _is_entity_downed(n):
				move.movement_left = 0
			else:
				move.reset_movement()


func _emit_turn_state() -> void:
	turn_state_changed.emit(turn_number, phase)


func _on_entity_downed(entity: Node, _attacker: Node) -> void:
	if entity == null or not entity.is_in_group("players"):
		return

	var pid := int(entity.get("player_id"))
	var move := entity.get_node_or_null("MovementComponent") as MovementComponent
	if move != null:
		move.movement_left = 0

	_mark_player_ended(pid, true)
	if _all_players_downed():
		_trigger_defeat()
	elif phase == Phase.PLAYERS and _all_players_ended():
		_begin_enemy_phase()


func _mark_player_ended(player_id: int, emit_turn_ended: bool = false) -> void:
	if player_id < 0 or _ended_players.has(player_id):
		return
	_ended_players[player_id] = true
	player_end_state_changed.emit(player_id, true)
	if emit_turn_ended:
		var player := _get_player_by_id(player_id)
		if player != null:
			EventBus.turn_ended.emit(player)


func _is_entity_downed(entity: Node) -> bool:
	if entity == null:
		return false
	if is_instance_valid(entity) and entity.has_method("is_downed") and entity.is_downed():
		return true
	var health := entity.get_node_or_null("HealthComponent") as HealthComponent
	return health != null and (health.is_downed() or health.is_dead())


func _all_players_downed() -> bool:
	if _players.is_empty():
		return false
	for p in _players:
		if p == null:
			continue
		if not _is_entity_downed(p):
			return false
	return true


func _trigger_defeat() -> void:
	if _battle_finished:
		return
	_battle_finished = true
	_enemy_queue.clear()
	_current_enemy = null
	print("[TurnManager] Semua player downed. Combat defeat.")
	if EventNotifier != null:
		EventNotifier.show_message("Party Defeated!", Color.RED)
	if RunManager != null and RunManager.is_run_active:
		RunManager.end_run(false)
	if EventBus != null:
		EventBus.combat_ended.emit("defeat")
