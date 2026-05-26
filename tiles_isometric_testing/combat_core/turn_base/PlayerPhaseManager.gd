# combat_core/turn_base/PlayerPhaseManager.gd
# Phase 3 — Turn Base System
# P1 dan P2 bertindak BERSAMAAN (concurrent).
# Jika keduanya menargetkan entity yang sama → Sequential Resolver (P1 dulu, lalu P2).
#
# API untuk Input System (Rapit/InputManager):
#   submit_action(player_id, action_dict)
#   confirm_end_turn(player_id)
class_name PlayerPhaseManager
extends Node

signal phase_started()
signal player_confirmed_end_turn(player_id: int)
signal both_players_confirmed()        # diterima oleh PhaseTransitionHandler
signal conflict_detected(p1_action: Dictionary, p2_action: Dictionary)
signal action_executed(player_id: int, action: Dictionary)

var p1_confirmed_end : bool = false
var p2_confirmed_end : bool = false

var p1_pending_action: Dictionary = {}
var p2_pending_action: Dictionary = {}

# Referensi ke ActionPointManager masing-masing player (optional — untuk validasi)
var p1_ap_mgr: ActionPointManager
var p2_ap_mgr: ActionPointManager


# ── SETUP ─────────────────────────────────────────────────────────────────────

func setup(ap1: ActionPointManager, ap2: ActionPointManager) -> void:
	p1_ap_mgr = ap1
	p2_ap_mgr = ap2


# ── PHASE FLOW ────────────────────────────────────────────────────────────────

func start_phase() -> void:
	p1_confirmed_end  = false
	p2_confirmed_end  = false
	p1_pending_action = {}
	p2_pending_action = {}
	phase_started.emit()
	print("[PlayerPhaseManager] Player Phase dimulai.")


# ── ACTION SUBMISSION ─────────────────────────────────────────────────────────

## Dipanggil oleh Input System saat player konfirmasi skill + target
## action = { "ability_id": String, "targets": Array[Node], "caster": Node, "cost_ap": int, "cost_bap": int }
func submit_action(player_id: int, action: Dictionary) -> void:
	if player_id == 1:
		p1_pending_action = action
	elif player_id == 2:
		p2_pending_action = action
	else:
		push_error("[PlayerPhaseManager] player_id tidak valid: %d" % player_id)
		return

	# Eksekusi segera jika sudah ada action dari player ini
	# (tidak perlu tunggu action player lain untuk eksekusi individual)
	_try_resolve_action(player_id)


func _try_resolve_action(player_id: int) -> void:
	var action := p1_pending_action if player_id == 1 else p2_pending_action
	var other_action := p2_pending_action if player_id == 1 else p1_pending_action

	if action.is_empty():
		return

	# Cek conflict: apakah ada target yang sama dengan action player lain?
	if not other_action.is_empty():
		var my_targets   : Array = action.get("targets", [])
		var their_targets: Array = other_action.get("targets", [])
		for t in my_targets:
			if t in their_targets:
				conflict_detected.emit(p1_pending_action, p2_pending_action)
				print("[PlayerPhaseManager] Conflict terdeteksi! P1 dan P2 menarget entity yang sama.")
				# Sequential resolve: P1 dulu
				if not p1_pending_action.is_empty():
					_execute_action(1, p1_pending_action)
					p1_pending_action = {}
				if not p2_pending_action.is_empty():
					_execute_action(2, p2_pending_action)
					p2_pending_action = {}
				return

	# Tidak ada conflict — eksekusi langsung
	_execute_action(player_id, action)
	if player_id == 1:
		p1_pending_action = {}
	else:
		p2_pending_action = {}


func _execute_action(player_id: int, action: Dictionary) -> void:
	if action.is_empty():
		return

	var caster    : Node   = action.get("caster")
	var cost_ap   : int    = action.get("cost_ap", 0)
	var cost_bap  : int    = action.get("cost_bap", 0)

	# Validasi dan potong AP
	var ap_mgr := p1_ap_mgr if player_id == 1 else p2_ap_mgr
	if ap_mgr != null:
		if cost_ap > 0 and not ap_mgr.spend_ap(cost_ap):
			print("[PlayerPhaseManager] P%d tidak punya cukup AP!" % player_id)
			return
		if cost_bap > 0 and not ap_mgr.spend_bap(cost_bap):
			print("[PlayerPhaseManager] P%d tidak punya cukup BAP!" % player_id)
			return

	# Emit signal untuk sistem lain (Ability System, HUD, dll.)
	action_executed.emit(player_id, action)
	print("[PlayerPhaseManager] P%d mengeksekusi action: %s" % [player_id, action.get("ability_id", "?")])


# ── END TURN ─────────────────────────────────────────────────────────────────

## Dipanggil oleh Input System saat player tekan End Turn
func confirm_end_turn(player_id: int) -> void:
	if player_id == 1:
		p1_confirmed_end = true
	elif player_id == 2:
		p2_confirmed_end = true

	player_confirmed_end_turn.emit(player_id)
	print("[PlayerPhaseManager] P%d konfirmasi End Turn." % player_id)

	if p1_confirmed_end and p2_confirmed_end:
		print("[PlayerPhaseManager] Kedua player sudah End Turn → Enemy Phase.")
		both_players_confirmed.emit()


# ── QUERY ─────────────────────────────────────────────────────────────────────

func is_player_ended(player_id: int) -> bool:
	return p1_confirmed_end if player_id == 1 else p2_confirmed_end

func can_player_act(player_id: int) -> bool:
	return not is_player_ended(player_id)
