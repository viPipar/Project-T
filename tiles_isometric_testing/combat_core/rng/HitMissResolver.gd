# combat_core/rng/HitMissResolver.gd
# Phase 4 — RNG Combat Resolvers
# Formula: D20 + floor(ACC/2) vs target Armor (fisik) atau Resist (magic)
class_name HitMissResolver
extends Node

## Emitted setiap kali resolve() dipanggil — untuk EventBus & animasi
signal hit_resolved(attacker: Node, target: Node, result: Dictionary)

# DuckTyped: bisa MockStatProvider atau StatsComponent wrapper
# Set via setup() sebelum digunakan
var _stat_provider  # MockStatProvider atau sistem nyata
var _dice: DiceRoller

func _ready() -> void:
	_dice = DiceRoller.new()
	add_child(_dice)


## Setup dependency — wajib dipanggil sebelum resolve()
func setup(stat_prov) -> void:
	_stat_provider = stat_prov


# ── MAIN RESOLVE ──────────────────────────────────────────────────────────────

## Resolve hit/miss untuk satu aksi
## Result Dictionary:
##   { "hit": bool, "roll": int, "raw_d20": int, "modifier": int,
##     "threshold": int, "is_magical": bool }
func resolve(attacker: Node, target: Node, is_magical: bool = false) -> Dictionary:
	assert(_stat_provider != null, "[HitMissResolver] stat_provider belum di-setup!")

	var modifier : int = _get_hit_roll_modifier(attacker)
	var raw_d20  : int = _dice.d20()
	var roll     : int = raw_d20 + modifier

	var threshold : int
	if is_magical:
		threshold = _stat_provider.get_resist(target)
	else:
		threshold = _stat_provider.get_armor(target)

	var result := {
		"hit":        roll >= threshold,
		"roll":       roll,
		"raw_d20":    raw_d20,
		"modifier":   modifier,
		"threshold":  threshold,
		"is_magical": is_magical
	}

	hit_resolved.emit(attacker, target, result)

	# Emit ke EventBus global agar sistem lain bisa mendengar
	# (HUD miss indicator, floating text, dll.)
	if result["hit"]:
		pass  # EventBus.damage_dealt di-emit oleh sistem damage, bukan di sini
	else:
		# TODO (Team): migrated from miss_occurred to on_miss
		EventBus.on_miss.emit(attacker, target)

	return result


## Shorthand — langsung return bool
func did_hit(attacker: Node, target: Node, is_magical: bool = false) -> bool:
	return resolve(attacker, target, is_magical)["hit"]


func _get_hit_roll_modifier(attacker: Node) -> int:
	if _stat_provider.has_method("get_hit_roll_modifier"):
		return int(_stat_provider.get_hit_roll_modifier(attacker))
	var acc: int = _stat_provider.get_acc(attacker)
	return maxi(0, floori(acc / 2.0))
