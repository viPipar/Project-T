# combat_core/turn_base/EnemyPhaseManager.gd
# Phase 3 — Turn Base System
# Semua musuh bertindak SATU PER SATU berdasarkan urutan inisiatif (DEX-based).
# Delay 0.5 detik antar aksi untuk readability.
#
# Catatan: kompatibel dengan TurnManager.gd yang sudah ada di autoloads/
# EnemyPhaseManager ini fokus ke LOGIKA URUTAN & AI turn execution
class_name EnemyPhaseManager
extends Node

signal phase_started()
signal enemy_turn_started(enemy: Node)
signal enemy_turn_ended(enemy: Node)
signal phase_ended()

const ACTION_DELAY_SEC := 0.5

var enemy_queue  : Array[Node] = []
var is_processing: bool        = false
var current_enemy: Node        = null

# DuckTyped stat provider — untuk sorting by DEX
var _stat_provider  # MockStatProvider atau sistem nyata


# ── SETUP ─────────────────────────────────────────────────────────────────────

func setup(stat_prov) -> void:
	_stat_provider = stat_prov


# ── PHASE FLOW ────────────────────────────────────────────────────────────────

## Mulai enemy phase dengan daftar musuh yang masih hidup
func start_phase(enemies: Array[Node]) -> void:
	# Filter hanya yang masih hidup
	enemy_queue = []
	for e in enemies:
		if e != null and _is_alive(e):
			enemy_queue.append(e)

	# Sort berdasarkan DEX (descending) — inisiatif tertinggi duluan
	enemy_queue.sort_custom(_sort_by_initiative)

	is_processing = true
	phase_started.emit()
	print("[EnemyPhaseManager] Enemy Phase dimulai. %d musuh dalam antrian." % enemy_queue.size())

	_process_next_enemy()


func _sort_by_initiative(a: Node, b: Node) -> bool:
	# FIX: Fallback chain yang lebih jelas
	# 1. Coba stat_provider (sistem Candra) — jalur utama
	if _stat_provider != null:
		var dex_a: int = _stat_provider.get_dex(a)
		var dex_b: int = _stat_provider.get_dex(b)
		return dex_a > dex_b
	# 2. Fallback: baca mock_dex langsung dari property node (MockEntity)
	var raw_a: Variant = a.get("mock_dex")
	var raw_b: Variant = b.get("mock_dex")
	var fallback_a: int = int(raw_a) if raw_a != null else 0
	var fallback_b: int = int(raw_b) if raw_b != null else 0
	if fallback_a == 0 and fallback_b == 0:
		push_warning("[EnemyPhaseManager] Tidak ada stat_provider dan entity tidak punya mock_dex — inisiatif semua 0!")
	return fallback_a > fallback_b


func _process_next_enemy() -> void:
	if enemy_queue.is_empty():
		is_processing  = false
		current_enemy  = null
		phase_ended.emit()
		print("[EnemyPhaseManager] Semua musuh sudah bertindak → Player Phase.")
		return

	current_enemy = enemy_queue.pop_front()

	# Skip musuh yang sudah mati saat giliran tiba
	if not _is_alive(current_enemy):
		print("[EnemyPhaseManager] Skip musuh mati: %s" % _get_name(current_enemy))
		_process_next_enemy()
		return

	enemy_turn_started.emit(current_enemy)
	print("[EnemyPhaseManager] Giliran musuh: %s" % _get_name(current_enemy))
	_execute_enemy_turn(current_enemy)


func _execute_enemy_turn(enemy: Node) -> void:
	# Panggil AI turn pada enemy node
	if enemy.has_method("do_ai_turn"):
		enemy.do_ai_turn()
	else:
		print("[EnemyPhaseManager] %s tidak punya do_ai_turn()" % _get_name(enemy))

	# Tunggu delay sebelum musuh berikutnya (await agar tidak blocking)
	_schedule_next(enemy)


func _schedule_next(enemy: Node) -> void:
	await get_tree().create_timer(ACTION_DELAY_SEC).timeout
	enemy_turn_ended.emit(enemy)
	print("[EnemyPhaseManager] %s selesai bertindak." % _get_name(enemy))
	_process_next_enemy()


# ── HELPER ───────────────────────────────────────────────────────────────────

func _is_alive(entity: Node) -> bool:
	# Cek via property is_alive (MockEntity) atau method is_dead
	if entity.has_method("is_dead"):
		return not entity.is_dead()
	var alive: Variant = entity.get("is_alive")  # Variant by design
	return alive if alive != null else true


func _get_name(entity: Node) -> String:
	var n: Variant = entity.get("entity_name")  # Variant by design
	if n != null:
		return str(n)
	return entity.name


# ── QUERY ─────────────────────────────────────────────────────────────────────

func get_current_enemy() -> Node:
	return current_enemy

func is_phase_active() -> bool:
	return is_processing
