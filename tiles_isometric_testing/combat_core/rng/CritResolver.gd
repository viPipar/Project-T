# combat_core/rng/CritResolver.gd
# Phase 4 — RNG Combat Resolvers
# Natural Crit Threshold = 20 − floor(ACC / 10)
# Crit terjadi jika raw D20 roll (SEBELUM modifier) >= threshold
class_name CritResolver
extends Node

signal crit_occurred(attacker: Node, raw_roll: int, threshold: int)

# DuckTyped stat provider
var _stat_provider  # MockStatProvider atau sistem nyata

func _ready() -> void:
	pass


## Setup dependency
func setup(stat_prov) -> void:
	_stat_provider = stat_prov


# ── CRIT CHECK ────────────────────────────────────────────────────────────────

## Hitung crit threshold berdasarkan ACC
func get_crit_threshold(attacker: Node) -> int:
	assert(_stat_provider != null, "[CritResolver] stat_provider belum di-setup!")
	var acc := _stat_provider.get_acc(attacker)
	return 20 - floori(acc / 10.0)


## Cek apakah raw D20 roll adalah critical
func is_critical(raw_roll: int, attacker: Node) -> bool:
	var threshold := get_crit_threshold(attacker)
	var crit      := raw_roll >= threshold
	if crit:
		crit_occurred.emit(attacker, raw_roll, threshold)
	return crit


# ── FULL COMBAT RESOLVE ───────────────────────────────────────────────────────

## Resolve hit/miss DAN crit dalam satu panggilan
## Menggunakan DiceRoller untuk D20 internal
##
## Result Dictionary:
##   { "hit": bool, "crit": bool, "roll": int, "raw_roll": int,
##     "threshold": int, "crit_threshold": int, "modifier": int }
func resolve_with_crit(attacker: Node, target: Node, is_magical: bool = false) -> Dictionary:
	assert(_stat_provider != null, "[CritResolver] stat_provider belum di-setup!")

	var acc            := _stat_provider.get_acc(attacker)
	var modifier       := floori(acc / 2.0)
	var crit_threshold := 20 - floori(acc / 10.0)

	var hit_threshold: int
	if is_magical:
		hit_threshold = _stat_provider.get_resist(target)
	else:
		hit_threshold = _stat_provider.get_armor(target)

	var raw_roll   := randi_range(1, 20)
	var total_roll := raw_roll + modifier
	var crit       := raw_roll >= crit_threshold
	var hit        := total_roll >= hit_threshold or crit  # crit selalu hit

	if crit:
		crit_occurred.emit(attacker, raw_roll, crit_threshold)

	return {
		"hit":            hit,
		"crit":           crit,
		"roll":           total_roll,
		"raw_roll":       raw_roll,
		"modifier":       modifier,
		"threshold":      hit_threshold,
		"crit_threshold": crit_threshold,
		"is_magical":     is_magical
	}
