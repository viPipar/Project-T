# combat_core/tests/test_dice_roller.gd
# ── TEST PHASE 1: DiceRoller & LuckRoller ────────────────────────────────────
# Cara run: Attach script ini ke Node di scene kosong, jalankan scene.
# Lihat output di Godot Output panel.
extends Node


func _ready() -> void:
	print("\n========================================")
	print("  TEST PHASE 1 — DiceRoller & LuckRoller")
	print("========================================\n")
	_test_dice_roller()
	_test_luck_roller()


# ── DICE ROLLER ───────────────────────────────────────────────────────────────

func _test_dice_roller() -> void:
	var roller := DiceRoller.new()
	add_child(roller)

	print("--- DiceRoller Tests ---")

	# Test single dice
	var d4_result := roller.d4()
	assert(d4_result >= 1 and d4_result <= 4,
		"❌ d4() harus 1–4, dapat: %d" % d4_result)
	print("✅ d4()  = %d (valid 1–4)" % d4_result)

	var d20_result := roller.d20()
	assert(d20_result >= 1 and d20_result <= 20,
		"❌ d20() harus 1–20, dapat: %d" % d20_result)
	print("✅ d20() = %d (valid 1–20)" % d20_result)

	# Test string parsing
	var two_d6 := roller.roll_from_string("2D6")
	assert(two_d6 >= 2 and two_d6 <= 12,
		"❌ '2D6' harus 2–12, dapat: %d" % two_d6)
	print("✅ roll_from_string('2D6')  = %d (valid 2–12)" % two_d6)

	var one_d20 := roller.roll_from_string("1D20")
	assert(one_d20 >= 1 and one_d20 <= 20,
		"❌ '1D20' harus 1–20, dapat: %d" % one_d20)
	print("✅ roll_from_string('1D20') = %d (valid 1–20)" % one_d20)

	var four_d6 := roller.roll_from_string("4D6")
	assert(four_d6 >= 4 and four_d6 <= 24,
		"❌ '4D6' harus 4–24, dapat: %d" % four_d6)
	print("✅ roll_from_string('4D6')  = %d (valid 4–24)" % four_d6)

	# Test detailed roll
	var detail := roller.roll_detailed("3D6")
	assert(detail["rolls"].size() == 3, "❌ roll_detailed('3D6') harus punya 3 rolls")
	print("✅ roll_detailed('3D6') = total:%d rolls:%s" % [detail["total"], str(detail["rolls"])])

	# Test crit roll (double dice)
	var crit := roller.roll_crit("1D10")
	assert(crit >= 2 and crit <= 20, "❌ roll_crit('1D10') harus 2–20, dapat: %d" % crit)
	print("✅ roll_crit('1D10') = %d (valid 2–20)" % crit)

	print("→ DiceRoller: SEMUA TEST PASSED ✅\n")


# ── LUCK ROLLER ───────────────────────────────────────────────────────────────

func _test_luck_roller() -> void:
	var luck := LuckRoller.new()
	add_child(luck)

	print("--- LuckRoller Tests ---")

	# Test roll_luck dengan LCK = 10 → modifier = 2
	# Hasil harus 1+2=3 sampai 20+2=22
	var lck_result := luck.roll_luck(10)
	assert(lck_result >= 3 and lck_result <= 22,
		"❌ roll_luck(10) harus 3–22, dapat: %d" % lck_result)
	print("✅ roll_luck(LCK=10)  = %d (modifier +%d, valid 3–22)" % [lck_result, floori(10.0/5)])

	# Test coop roll
	var coop := luck.roll_luck_coop(10, 20)  # avg = 15, modifier = 3
	assert(coop >= 4 and coop <= 23,
		"❌ roll_luck_coop(10,20) harus 4–23, dapat: %d" % coop)
	print("✅ roll_luck_coop(P1_LCK=10, P2_LCK=20) = %d (avg_lck=15, valid 4–23)" % coop)

	# Test contested pick — harus return 1 atau 2
	var winner := luck.roll_contested_pick(5, 10)
	assert(winner == 1 or winner == 2,
		"❌ roll_contested_pick harus return 1 atau 2, dapat: %d" % winner)
	print("✅ roll_contested_pick(P1_LCK=5, P2_LCK=10) → Pemenang: P%d" % winner)

	# Test no-tie guarantee (10 kali)
	print("   Verifikasi no-tie (10 rounds contested pick):")
	for i in range(10):
		var w := luck.roll_contested_pick(5, 5)
		assert(w == 1 or w == 2, "❌ Contested pick invalid: %d" % w)
	print("✅ 10x Contested Pick selesai tanpa error.")

	print("→ LuckRoller: SEMUA TEST PASSED ✅\n")
	print("========================================")
	print("  PHASE 1 TEST COMPLETE")
	print("========================================\n")
