# combat_core/action_economy/SpellSlotManager.gd
# Phase 2 — Action Economy
# Mengelola Spell Slot Lv1–4 untuk Wizard (P2)
#
# Formula dari GDD:
#   Slot Lv.1 = 2 + floor(ATT / 5)
#   Slot Lv.2 = 2 + floor(ATT / 10)
#   Slot Lv.3 = 1 + floor(ATT / 15)
#   Slot Lv.4 = 0  (hanya dari item)
#
# Cross-Conversion (lihat ManaConverter.gd):
#   Slot Lv.1 item  → +1 Slot Lv.1 cap
#   Energy Charge item → +1 Slot Lv.1 cap
class_name SpellSlotManager
extends Node

## Emitted ke HUD — Rapit connect ke signal ini
## level: 1–4, current dan max adalah jumlah slot untuk level itu
signal slots_changed(level: int, current: int, max_slots: int)

# Index 0 = Lv1, 1 = Lv2, 2 = Lv3, 3 = Lv4
var max_slots    : Array[int] = [2, 2, 1, 0]
var current_slots: Array[int] = [2, 2, 1, 0]


# ── SETUP ─────────────────────────────────────────────────────────────────────

func setup(att_stat: int) -> void:
	# Formula sesuai GDD:
	#   Lv1 = 2 + floor(ATT/5)
	#   Lv2 = 2 + floor(ATT/10)
	#   Lv3 = 1 + floor(ATT/15)
	#   Lv4 = 0  (item only)
	max_slots[0] = 99
	max_slots[1] = 99
	max_slots[2] = 99
	max_slots[3] = 99
	reset_all()

func setup_from_stats(stats: StatsComponent) -> void:
	setup(stats.get_stat("att"))


# ── ITEM BONUS (dipanggil oleh ManaConverter) ────────────────────────────────

## Tambah permanent slot cap untuk level tertentu
func add_slot_cap(level: int, amount: int = 1) -> void:
	assert(level >= 1 and level <= 4, "[SpellSlotManager] Slot level harus 1–4")
	var idx := level - 1
	max_slots[idx] += amount
	slots_changed.emit(level, current_slots[idx], max_slots[idx])

## Konversi dari Energy Charge item → Wizard mendapat Lv.1 slot
func add_slot_from_charge_item() -> void:
	add_slot_cap(1)


# ── SPEND ─────────────────────────────────────────────────────────────────────

func spend_slot(level: int, amount: int = 1) -> bool:
	assert(level >= 1 and level <= 4, "[SpellSlotManager] Slot level harus 1–4")
	var idx := level - 1
	if current_slots[idx] >= amount:
		current_slots[idx] -= amount
		slots_changed.emit(level, current_slots[idx], max_slots[idx])
		return true
	return false

func can_spend(level: int, amount: int = 1) -> bool:
	if level < 1 or level > 4:
		return false
	return current_slots[level - 1] >= amount

func has_slots(level: int) -> bool:
	return can_spend(level, 1)

func slots_remaining(level: int) -> int:
	if level < 1 or level > 4:
		return 0
	return current_slots[level - 1]


# ── RESTORE ──────────────────────────────────────────────────────────────────

func restore_slots(level: int, amount: int) -> void:
	var idx := level - 1
	current_slots[idx] = mini(current_slots[idx] + amount, max_slots[idx])
	slots_changed.emit(level, current_slots[idx], max_slots[idx])

## Restore berdasarkan persentase untuk semua level — untuk Rest node
func restore_percent(percent: float) -> void:
	for i in range(4):
		var amount := int(max_slots[i] * percent)
		current_slots[i] = mini(current_slots[i] + amount, max_slots[i])
		slots_changed.emit(i + 1, current_slots[i], max_slots[i])

func reset_all() -> void:
	for i in range(4):
		current_slots[i] = max_slots[i]
		slots_changed.emit(i + 1, current_slots[i], max_slots[i])
