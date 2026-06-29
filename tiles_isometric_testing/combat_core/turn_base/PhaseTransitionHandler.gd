# combat_core/turn_base/PhaseTransitionHandler.gd
# Phase 3 — Turn Base System
# Mengatur siklus: Player Phase → Enemy Phase → Player Phase
# Mendeteksi kemenangan combat (semua musuh mati)
#
# Kompatibel dengan TurnManager.gd yang sudah ada — ini adalah lapisan
# LOGIKA di atasnya yang menghubungkan PlayerPhaseManager & EnemyPhaseManager
class_name PhaseTransitionHandler
extends Node

signal player_phase_started(turn_number: int)
signal enemy_phase_started(turn_number: int)
signal combat_victory()
signal combat_started()

enum Phase { PLAYER, ENEMY }

var current_phase : Phase = Phase.PLAYER
var turn_number   : int   = 1

# Referensi — set via @export atau setup()
@export var player_phase_mgr : PlayerPhaseManager
@export var enemy_phase_mgr  : EnemyPhaseManager


# ── SETUP ─────────────────────────────────────────────────────────────────────

func setup(p_mgr: PlayerPhaseManager, e_mgr: EnemyPhaseManager) -> void:
	player_phase_mgr = p_mgr
	enemy_phase_mgr  = e_mgr
	_connect_signals()


func _ready() -> void:
	# Jika sudah di-assign via @export di editor, connect otomatis
	# Guard: hanya connect jika KEDUA manager valid
	if player_phase_mgr != null and enemy_phase_mgr != null:
		_connect_signals()
	# Jika tidak (pakai setup() nanti), signals akan diconnect via setup()


func _connect_signals() -> void:
	# Guard double-connect (aman dipanggil berulang)
	if not player_phase_mgr.both_players_confirmed.is_connected(_on_players_end_turn):
		player_phase_mgr.both_players_confirmed.connect(_on_players_end_turn)

	if not enemy_phase_mgr.phase_ended.is_connected(_on_enemy_phase_ended):
		enemy_phase_mgr.phase_ended.connect(_on_enemy_phase_ended)

	print("[PhaseTransitionHandler] Signals terhubung.")


# ── COMBAT START ──────────────────────────────────────────────────────────────

func start_combat() -> void:
	turn_number = 1
	combat_started.emit()
	print("[PhaseTransitionHandler] Combat dimulai!")
	_begin_player_phase()


# ── PHASE TRANSITIONS ─────────────────────────────────────────────────────────

func _begin_player_phase() -> void:
	current_phase = Phase.PLAYER
	player_phase_mgr.start_phase()
	player_phase_started.emit(turn_number)
	print("[PhaseTransitionHandler] === PLAYER PHASE — Turn %d ===" % turn_number)


func _begin_enemy_phase(enemies: Array[Node]) -> void:
	current_phase = Phase.ENEMY
	enemy_phase_mgr.start_phase(enemies)
	enemy_phase_started.emit(turn_number)
	print("[PhaseTransitionHandler] === ENEMY PHASE — Turn %d ===" % turn_number)


func _on_players_end_turn() -> void:
	var living := _get_living_enemies()
	if living.is_empty():
		_trigger_victory()
		return
	_begin_enemy_phase(living)


func _on_enemy_phase_ended() -> void:
	turn_number += 1
	_begin_player_phase()


# ── VICTORY ───────────────────────────────────────────────────────────────────

func _trigger_victory() -> void:
	print("[PhaseTransitionHandler] 🏆 Semua musuh kalah — COMBAT VICTORY!")
	combat_victory.emit()
	EventBus.combat_ended.emit("victory")


# ── HELPER ───────────────────────────────────────────────────────────────────

## Scan scene tree untuk enemy yang masih hidup
## Gunakan group "enemies" — semua enemy node harus add_to_group("enemies")
func _get_living_enemies() -> Array[Node]:
	var living: Array[Node] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null:
			continue
		# Cek is_alive via property atau method
		var alive: Variant = node.get("is_alive")  # Variant by design
		var alive_bool: bool
		if alive == null:
			if is_instance_valid(node) and node.has_method("is_dead"):
				alive_bool = not node.is_dead()
			else:
				alive_bool = true
		else:
			alive_bool = bool(alive)
		if alive_bool:
			living.append(node)
	return living


# ── QUERY ─────────────────────────────────────────────────────────────────────

func get_current_phase() -> Phase:
	return current_phase

func is_player_phase() -> bool:
	return current_phase == Phase.PLAYER

func is_enemy_phase() -> bool:
	return current_phase == Phase.ENEMY

func get_turn_number() -> int:
	return turn_number
