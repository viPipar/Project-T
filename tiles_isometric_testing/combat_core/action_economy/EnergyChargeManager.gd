# combat_core/action_economy/EnergyChargeManager.gd
# Phase 2 — Action Economy
# Mengelola Energy Charge untuk Fighter (P1)
#
# Formula dari GDD:
#   Base Charges = 5
#   Max Charges  = 5 + item bonuses + Spell Slot conversions
#
# Cross-Conversion (lihat ManaConverter.gd):
#   Slot Lv.1 item → +1 Charge cap
#   Slot Lv.2 item → +2 Charge cap
#   Slot Lv.3 item → +3 Charge cap
#   Slot Lv.4 item → +4 Charge cap
#   Energy Charge item → +1 Charge cap
class_name EnergyChargeManager
extends Node

## Emitted ke HUD — Rapit connect ke signal ini
signal charge_changed(current: int, max_charges: int)

const BASE_CHARGES := 99

var max_charges    : int = BASE_CHARGES
var current_charges: int = BASE_CHARGES


# ── SETUP ─────────────────────────────────────────────────────────────────────

func setup() -> void:
	max_charges     = BASE_CHARGES
	current_charges = max_charges
	charge_changed.emit(current_charges, max_charges)


# ── ITEM BONUS (dipanggil oleh ManaConverter / Item Effect Applier) ───────────

## Tambah permanent charge cap dari item
func add_charge_cap(amount: int) -> void:
	max_charges += amount
	charge_changed.emit(current_charges, max_charges)

## Konversi dari Spell Slot item — level == jumlah charge yang ditambah
## (Dipanggil oleh ManaConverter saat Fighter equip Spell Slot item)
func add_charge_from_slot_item(slot_level: int) -> void:
	add_charge_cap(slot_level)


# ── SPEND ─────────────────────────────────────────────────────────────────────

func spend_charge(amount: int = 1) -> bool:
	if current_charges >= amount:
		current_charges -= amount
		charge_changed.emit(current_charges, max_charges)
		return true
	return false

func can_spend(amount: int = 1) -> bool:
	return current_charges >= amount

func charges_remaining() -> int:
	return current_charges


# ── RESTORE ──────────────────────────────────────────────────────────────────

func restore_charges(amount: int) -> void:
	current_charges = mini(current_charges + amount, max_charges)
	charge_changed.emit(current_charges, max_charges)

## Restore berdasarkan persentase — untuk Rest node
## percent: 0.5 = 50%, 1.0 = 100%
func restore_percent(percent: float) -> void:
	var amount := int(max_charges * percent)
	restore_charges(amount)

func reset_full() -> void:
	current_charges = max_charges
	charge_changed.emit(current_charges, max_charges)
