# combat_core/rng/LuckRoller.gd
# Phase 1 — RNG Foundation
# Formula: D20 + floor(LCK / 5)
# Digunakan untuk: Luck Event Roll, Contested Item Pick
class_name LuckRoller
extends Node

## Emitted setiap kali roll dilakukan — berguna untuk animasi dadu di UI
signal luck_rolled(roller_name: String, raw_d20: int, modifier: int, total: int)
signal contested_result(winner_id: int, p1_roll: int, p2_roll: int)

@onready var _dice: DiceRoller = DiceRoller.new()

func _ready() -> void:
	add_child(_dice)


# ── SINGLE ROLL ───────────────────────────────────────────────────────────────

## Roll luck untuk satu entity — D20 + floor(LCK/5)
func roll_luck(lck_stat: int, roller_name: String = "") -> int:
	var raw  := _dice.d20()
	var mod  := floori(lck_stat / 5.0)
	var total := raw + mod
	luck_rolled.emit(roller_name, raw, mod, total)
	return total


## Roll luck co-op (rata-rata LCK kedua pemain) — untuk Luck Event
func roll_luck_coop(p1_lck: int, p2_lck: int) -> int:
	var avg_lck := floori((p1_lck + p2_lck) / 2.0)
	return roll_luck(avg_lck, "COOP")


# ── CONTESTED PICK ────────────────────────────────────────────────────────────

## D20 + LCK/5 per player — reroll otomatis jika tie (sesuai GDD)
## Return: 1 (P1 menang) atau 2 (P2 menang)
func roll_contested_pick(p1_lck: int, p2_lck: int) -> int:
	var p1_roll : int = 0
	var p2_roll : int = 0
	var attempts: int = 0

	while attempts < 20:
		p1_roll  = roll_luck(p1_lck, "P1")
		p2_roll  = roll_luck(p2_lck, "P2")
		if p1_roll != p2_roll:
			break
		attempts += 1
		print("[LuckRoller] Tie! Reroll %d..." % attempts)

	# Safety fallback — jika 20x masih tie, P1 menang
	var winner : int = 1 if p1_roll >= p2_roll else 2
	contested_result.emit(winner, p1_roll, p2_roll)
	print("[LuckRoller] Contested: P1=%d vs P2=%d → Pemenang: P%d" % [p1_roll, p2_roll, winner])
	return winner


# ── WIN / LOSE THRESHOLD ─────────────────────────────────────────────────────

## Tentukan apakah luck roll adalah WIN atau LOSE
## Threshold default: 11 (>= 11 = WIN, sesuai standar D20 median)
func is_luck_win(total_roll: int, threshold: int = 11) -> bool:
	return total_roll >= threshold
