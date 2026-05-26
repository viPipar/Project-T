# combat_core/rng/DiceRoller.gd
# Phase 1 — RNG Foundation
# Sistem roll dice universal untuk semua kebutuhan combat.
# Mendukung: single dice, multi-dice, string parsing (e.g. "2D6", "1D20")
class_name DiceRoller
extends Node


func _ready() -> void:
	randomize()


# ── CORE ROLL ─────────────────────────────────────────────────────────────────

## Roll satu dadu: roll_dice(20) → 1..20
func roll_dice(sides: int) -> int:
	if sides < 1:
		push_error("[DiceRoller] sides harus >= 1, got: %d" % sides)
		return 0
	return randi_range(1, sides)


## Roll dari string: roll_from_string("2D6") → 2..12
## Format yang diterima: "1D6", "2D8", "4D6", "D20" (tanpa angka depan = 1 dadu)
func roll_from_string(dice_str: String) -> int:
	var s := dice_str.to_upper().strip_edges()
	var parts := s.split("D")
	if parts.size() != 2:
		push_error("[DiceRoller] Format dice tidak valid: '%s'" % dice_str)
		return 0

	var count_str := parts[0]
	var count := 1 if count_str.is_empty() else int(count_str)
	var sides := int(parts[1])

	if count < 1 or sides < 1:
		push_error("[DiceRoller] Nilai tidak valid: count=%d sides=%d" % [count, sides])
		return 0

	var total := 0
	for _i in range(count):
		total += roll_dice(sides)
	return total


## Roll dengan bonus flat: roll_with_bonus("2D6", 3) → (2..12) + 3
func roll_with_bonus(dice_str: String, flat_bonus: int) -> int:
	return roll_from_string(dice_str) + flat_bonus


## Roll untuk critical hit — dadu digandakan (roll dua kali, jumlahkan)
func roll_crit(dice_str: String) -> int:
	return roll_from_string(dice_str) + roll_from_string(dice_str)


# ── SHORTHAND ─────────────────────────────────────────────────────────────────

func d4()  -> int: return roll_dice(4)
func d6()  -> int: return roll_dice(6)
func d8()  -> int: return roll_dice(8)
func d10() -> int: return roll_dice(10)
func d12() -> int: return roll_dice(12)
func d20() -> int: return roll_dice(20)


# ── UTILITY ───────────────────────────────────────────────────────────────────

## Roll dan kembalikan detail lengkap sebagai Dictionary
## Result: { "total": int, "rolls": Array[int], "formula": String }
func roll_detailed(dice_str: String) -> Dictionary:
	var s := dice_str.to_upper().strip_edges()
	var parts := s.split("D")
	if parts.size() != 2:
		return {"total": 0, "rolls": [], "formula": dice_str}

	var count_str := parts[0]
	var count := 1 if count_str.is_empty() else int(count_str)
	var sides := int(parts[1])

	var rolls: Array[int] = []
	var total := 0
	for _i in range(count):
		var r := roll_dice(sides)
		rolls.append(r)
		total += r

	return {
		"total":   total,
		"rolls":   rolls,
		"formula": dice_str
	}
