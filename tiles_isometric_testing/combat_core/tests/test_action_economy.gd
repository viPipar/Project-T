# combat_core/tests/test_action_economy.gd
# ── TEST PHASE 2: Action Economy ─────────────────────────────────────────────
# Cara run: Attach script ini ke Node di scene kosong, jalankan scene.
extends Node


func _ready() -> void:
	print("\n========================================")
	print("  TEST PHASE 2 — Action Economy")
	print("========================================\n")
	_test_action_point_manager()
	_test_movement_point_manager()
	_test_energy_charge_manager()
	_test_spell_slot_manager()
	_test_mana_converter()


# ── ACTION POINT MANAGER ──────────────────────────────────────────────────────

func _test_action_point_manager() -> void:
	print("--- ActionPointManager Tests ---")
	var ap := ActionPointManager.new()
	add_child(ap)

	# DEX=10 → AP = 1+1 = 2, INT=20 → BAP = 1+2 = 3
	ap.setup(10, 20)
	assert(ap.max_ap == 2,   "❌ max_ap harus 2 (DEX=10), dapat: %d" % ap.max_ap)
	assert(ap.max_bap == 3,  "❌ max_bap harus 3 (INT=20), dapat: %d" % ap.max_bap)
	print("✅ setup(DEX=10, INT=20) → max_ap=%d, max_bap=%d" % [ap.max_ap, ap.max_bap])

	# Test spend
	assert(ap.spend_ap(1) == true,  "❌ spend_ap(1) harus berhasil")
	assert(ap.current_ap == 1,      "❌ current_ap harus 1 setelah spend")
	assert(ap.spend_ap(2) == false, "❌ spend_ap(2) harus gagal (kurang AP)")
	print("✅ spend_ap(): spend 1 → sukses, spend 2 → gagal (tidak cukup)")

	# Test reset
	ap.reset()
	assert(ap.current_ap == ap.max_ap,   "❌ reset() harus kembalikan AP ke max")
	assert(ap.current_bap == ap.max_bap, "❌ reset() harus kembalikan BAP ke max")
	print("✅ reset() → AP dan BAP kembali ke max")

	# Test item bonus
	ap.add_ap_bonus(1)
	assert(ap.max_ap == 3, "❌ max_ap harus 3 setelah +1 bonus, dapat: %d" % ap.max_ap)
	print("✅ add_ap_bonus(1) → max_ap=%d" % ap.max_ap)

	print("→ ActionPointManager: SEMUA TEST PASSED ✅\n")


# ── MOVEMENT POINT MANAGER ───────────────────────────────────────────────────

func _test_movement_point_manager() -> void:
	print("--- MovementPointManager Tests ---")
	var mv := MovementPointManager.new()
	add_child(mv)

	# MOV=10 → tiles = 6 + floor(10/5) = 8
	mv.setup(10)
	assert(mv.max_tiles == 8, "❌ max_tiles harus 8 (MOV=10), dapat: %d" % mv.max_tiles)
	print("✅ setup(MOV=10) → max_tiles=%d" % mv.max_tiles)

	# Spend 3 tiles
	assert(mv.spend_movement(3) == true, "❌ spend 3 tiles harus sukses")
	assert(mv.current_tiles == 5,        "❌ tiles harus 5 setelah spend 3 (dari 8)")
	print("✅ spend_movement(3) → tiles_remaining=%d" % mv.current_tiles)

	# Tidak bisa spend 6 lagi
	assert(mv.spend_movement(6) == false, "❌ spend 6 tiles harus gagal (hanya ada 5)")
	print("✅ spend_movement(6) → gagal (tidak cukup tiles)")

	mv.reset()
	assert(mv.current_tiles == mv.max_tiles, "❌ reset() harus kembalikan ke max")
	print("✅ reset() → tiles kembali ke %d" % mv.max_tiles)

	print("→ MovementPointManager: SEMUA TEST PASSED ✅\n")


# ── ENERGY CHARGE MANAGER ────────────────────────────────────────────────────

func _test_energy_charge_manager() -> void:
	print("--- EnergyChargeManager Tests ---")
	var ec := EnergyChargeManager.new()
	add_child(ec)

	ec.setup()
	assert(ec.max_charges == 5,     "❌ max_charges harus 5 (base), dapat: %d" % ec.max_charges)
	assert(ec.current_charges == 5, "❌ current_charges harus 5, dapat: %d" % ec.current_charges)
	print("✅ setup() → max=%d, current=%d" % [ec.max_charges, ec.current_charges])

	# Spend 3
	ec.spend_charge(3)
	assert(ec.current_charges == 2, "❌ charges harus 2 setelah spend 3")
	print("✅ spend_charge(3) → current=%d" % ec.current_charges)

	# Slot Lv.2 item → +2 cap
	ec.add_charge_from_slot_item(2)
	assert(ec.max_charges == 7, "❌ max harus 7 setelah +2 dari slot_lv2 item")
	print("✅ add_charge_from_slot_item(2) → max=%d" % ec.max_charges)

	# Restore 50%
	ec.restore_percent(0.5)
	var expected := mini(2 + int(7 * 0.5), 7)
	assert(ec.current_charges == expected,
		"❌ restore 50%% harus %d, dapat: %d" % [expected, ec.current_charges])
	print("✅ restore_percent(0.5) → current=%d" % ec.current_charges)

	ec.reset_full()
	assert(ec.current_charges == ec.max_charges, "❌ reset_full() harus isi penuh")
	print("✅ reset_full() → current=%d (=max)" % ec.current_charges)

	print("→ EnergyChargeManager: SEMUA TEST PASSED ✅\n")


# ── SPELL SLOT MANAGER ────────────────────────────────────────────────────────

func _test_spell_slot_manager() -> void:
	print("--- SpellSlotManager Tests ---")
	var ss := SpellSlotManager.new()
	add_child(ss)

	# ATT=10 → Lv1: 2+2=4, Lv2: 2+1=3, Lv3: 1+0=1, Lv4: 0
	ss.setup(10)
	assert(ss.max_slots[0] == 4, "❌ Lv1 harus 4 (ATT=10), dapat: %d" % ss.max_slots[0])
	assert(ss.max_slots[1] == 3, "❌ Lv2 harus 3 (ATT=10), dapat: %d" % ss.max_slots[1])
	assert(ss.max_slots[2] == 1, "❌ Lv3 harus 1 (ATT=10), dapat: %d" % ss.max_slots[2])
	assert(ss.max_slots[3] == 0, "❌ Lv4 harus 0 (ATT=10), dapat: %d" % ss.max_slots[3])
	print("✅ setup(ATT=10) → Lv1:%d Lv2:%d Lv3:%d Lv4:%d" % [ss.max_slots[0], ss.max_slots[1], ss.max_slots[2], ss.max_slots[3]])

	# Spend Lv1 slot
	assert(ss.spend_slot(1) == true,  "❌ spend Lv1 harus sukses")
	assert(ss.current_slots[0] == 3,  "❌ Lv1 harus 3 setelah spend 1 dari 4")
	print("✅ spend_slot(1) → Lv1 current=%d" % ss.current_slots[0])

	# Tambah Lv4 via item
	ss.add_slot_cap(4, 1)
	assert(ss.max_slots[3] == 1, "❌ Lv4 harus 1 setelah item, dapat: %d" % ss.max_slots[3])
	print("✅ add_slot_cap(4) → Lv4 max=%d" % ss.max_slots[3])

	# Energy charge item → +Lv1
	ss.add_slot_from_charge_item()
	assert(ss.max_slots[0] == 5, "❌ Lv1 harus 5 setelah energy charge item")
	print("✅ add_slot_from_charge_item() → Lv1 max=%d" % ss.max_slots[0])

	ss.reset_all()
	for i in range(4):
		assert(ss.current_slots[i] == ss.max_slots[i],
			"❌ reset_all() harus isi semua slot penuh (Lv%d)" % (i+1))
	print("✅ reset_all() → semua slot penuh")

	print("→ SpellSlotManager: SEMUA TEST PASSED ✅\n")


# ── MANA CONVERTER ────────────────────────────────────────────────────────────

func _test_mana_converter() -> void:
	print("--- ManaConverter Tests ---")

	var ec := EnergyChargeManager.new()
	var ss := SpellSlotManager.new()
	var mc := ManaConverter.new()
	add_child(ec)
	add_child(ss)
	add_child(mc)

	ec.setup()
	ss.setup(0)  # ATT=0 → Lv1:2, Lv2:2, Lv3:1, Lv4:0
	mc.setup(ec, ss)

	# slot_lv2 item untuk Fighter → +2 charge cap
	var before_charge := ec.max_charges
	mc.apply_mana_item("slot_lv2", "fighter")
	assert(ec.max_charges == before_charge + 2,
		"❌ Fighter slot_lv2 harus tambah 2 charges, dapat: %d" % ec.max_charges)
	print("✅ apply_mana_item('slot_lv2','fighter') → charge_cap=%d (+2)" % ec.max_charges)

	# slot_lv3 item untuk Wizard → +1 Slot Lv3
	var before_lv3 := ss.max_slots[2]
	mc.apply_mana_item("slot_lv3", "wizard")
	assert(ss.max_slots[2] == before_lv3 + 1,
		"❌ Wizard slot_lv3 harus tambah 1 Lv3 slot, dapat: %d" % ss.max_slots[2])
	print("✅ apply_mana_item('slot_lv3','wizard') → Lv3 max=%d (+1)" % ss.max_slots[2])

	# energy_charge item untuk Wizard → +1 Slot Lv1
	var before_lv1 := ss.max_slots[0]
	mc.apply_mana_item("energy_charge", "wizard")
	assert(ss.max_slots[0] == before_lv1 + 1,
		"❌ Wizard energy_charge harus tambah 1 Lv1 slot")
	print("✅ apply_mana_item('energy_charge','wizard') → Lv1 max=%d (+1)" % ss.max_slots[0])

	print("→ ManaConverter: SEMUA TEST PASSED ✅\n")
	print("========================================")
	print("  PHASE 2 TEST COMPLETE")
	print("========================================\n")
