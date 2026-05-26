# combat_core/action_economy/ManaConverter.gd
# Phase 2 — Action Economy
# Cross-conversion antara Energy Charge (Fighter P1) dan Spell Slot (Wizard P2)
# Dipanggil oleh Item Effect Applier (Ilham) saat item di-equip
#
# Tabel konversi GDD:
#   Slot Lv.1 item → Fighter: +1 Charge | Wizard: +1 Slot Lv.1
#   Slot Lv.2 item → Fighter: +2 Charge | Wizard: +1 Slot Lv.2
#   Slot Lv.3 item → Fighter: +3 Charge | Wizard: +1 Slot Lv.3
#   Slot Lv.4 item → Fighter: +4 Charge | Wizard: +1 Slot Lv.4
#   Energy Charge item → Fighter: +1 Charge | Wizard: +1 Slot Lv.1
class_name ManaConverter
extends Node

## Emitted setelah konversi — untuk HUD blink indicator (sesuai GDD: blink 1.5s)
signal conversion_applied(target_class: String, item_type: String)

# Diisi saat setup di scene — referensi ke manager masing-masing karakter
var fighter_charge_mgr : EnergyChargeManager
var wizard_slot_mgr    : SpellSlotManager


# ── SETUP ─────────────────────────────────────────────────────────────────────

func setup(charge_mgr: EnergyChargeManager, slot_mgr: SpellSlotManager) -> void:
	fighter_charge_mgr = charge_mgr
	wizard_slot_mgr    = slot_mgr


# ── MAIN API (dipanggil oleh Ilham's Item Effect Applier) ────────────────────

## Terapkan efek mana item berdasarkan class penerima
##
## item_type    : "slot_lv1" | "slot_lv2" | "slot_lv3" | "slot_lv4" | "energy_charge"
## target_class : "fighter" | "wizard"
func apply_mana_item(item_type: String, target_class: String) -> void:
	assert(fighter_charge_mgr != null, "[ManaConverter] fighter_charge_mgr belum di-setup!")
	assert(wizard_slot_mgr    != null, "[ManaConverter] wizard_slot_mgr belum di-setup!")

	match target_class:
		"fighter":
			_apply_to_fighter(item_type)
		"wizard":
			_apply_to_wizard(item_type)
		_:
			push_error("[ManaConverter] target_class tidak dikenal: '%s'" % target_class)
			return

	conversion_applied.emit(target_class, item_type)
	print("[ManaConverter] Applied '%s' to %s" % [item_type, target_class])


# ── INTERNAL ──────────────────────────────────────────────────────────────────

func _apply_to_fighter(item_type: String) -> void:
	match item_type:
		"slot_lv1":       fighter_charge_mgr.add_charge_cap(1)
		"slot_lv2":       fighter_charge_mgr.add_charge_cap(2)
		"slot_lv3":       fighter_charge_mgr.add_charge_cap(3)
		"slot_lv4":       fighter_charge_mgr.add_charge_cap(4)
		"energy_charge":  fighter_charge_mgr.add_charge_cap(1)
		_:
			push_error("[ManaConverter] item_type tidak dikenal untuk fighter: '%s'" % item_type)


func _apply_to_wizard(item_type: String) -> void:
	match item_type:
		"slot_lv1":       wizard_slot_mgr.add_slot_cap(1)
		"slot_lv2":       wizard_slot_mgr.add_slot_cap(2)
		"slot_lv3":       wizard_slot_mgr.add_slot_cap(3)
		"slot_lv4":       wizard_slot_mgr.add_slot_cap(4)
		"energy_charge":  wizard_slot_mgr.add_slot_from_charge_item()
		_:
			push_error("[ManaConverter] item_type tidak dikenal untuk wizard: '%s'" % item_type)
