# combat_core/tests/test_phase_manager.gd
# ── TEST PHASE 3: Turn Base System & Phase 4: RNG Combat ─────────────────────
# Cara run: Attach script ini ke Node di scene kosong, jalankan scene.
extends Node


func _ready() -> void:
	print("\n========================================")
	print("  TEST PHASE 3 & 4 — Turn Base + RNG")
	print("========================================\n")
	_test_hit_miss_resolver()
	_test_crit_resolver()
	await _test_enemy_phase_manager()
	await _test_full_phase_cycle()


# ── HIT/MISS RESOLVER (Phase 4) ───────────────────────────────────────────────

func _test_hit_miss_resolver() -> void:
	print("--- HitMissResolver Tests ---")

	var mock_stats := MockStatProvider.new()
	var resolver   := HitMissResolver.new()
	add_child(mock_stats)
	add_child(resolver)
	resolver.setup(mock_stats)

	var attacker := MockEntity.new()
	var target   := MockEntity.new()
	attacker.entity_name = "Attacker"
	target.entity_name   = "Target"
	add_child(attacker)
	add_child(target)

	# Lakukan 20 resolve dan verifikasi format hasilnya
	var hit_count := 0
	for i in range(20):
		var result := resolver.resolve(attacker, target)
		assert(result.has("hit"),       "❌ result harus punya key 'hit'")
		assert(result.has("roll"),      "❌ result harus punya key 'roll'")
		assert(result.has("raw_d20"),   "❌ result harus punya key 'raw_d20'")
		assert(result.has("threshold"), "❌ result harus punya key 'threshold'")
		assert(result["raw_d20"] >= 1 and result["raw_d20"] <= 20,
			"❌ raw_d20 harus 1–20, dapat: %d" % result["raw_d20"])
		if result["hit"]:
			hit_count += 1

	print("✅ 20x resolve() berhasil. Hit count: %d/20 (vs Armor=%d)" % [hit_count, mock_stats.mock_armor])
	print("✅ Result format valid (hit, roll, raw_d20, threshold ada semua)")
	print("→ HitMissResolver: SEMUA TEST PASSED ✅\n")


# ── CRIT RESOLVER (Phase 4) ───────────────────────────────────────────────────

func _test_crit_resolver() -> void:
	print("--- CritResolver Tests ---")

	var mock_stats := MockStatProvider.new()
	var resolver   := CritResolver.new()
	add_child(mock_stats)
	add_child(resolver)
	resolver.setup(mock_stats)

	var attacker := MockEntity.new()
	attacker.entity_name = "Crit_Attacker"
	var target := MockEntity.new()
	target.entity_name   = "Crit_Target"
	add_child(attacker)
	add_child(target)

	# ACC=10 → crit_threshold = 20 - floor(10/10) = 19
	var threshold := resolver.get_crit_threshold(attacker)
	assert(threshold == 19, "❌ crit threshold harus 19 (ACC=10), dapat: %d" % threshold)
	print("✅ get_crit_threshold(ACC=10) = %d" % threshold)

	# is_critical: raw 19 → harus crit, raw 18 → tidak
	assert(resolver.is_critical(19, attacker) == true,
		"❌ raw_roll=19 harus critical (threshold=19)")
	assert(resolver.is_critical(18, attacker) == false,
		"❌ raw_roll=18 harus NOT critical (threshold=19)")
	print("✅ is_critical(19) = true, is_critical(18) = false")

	# resolve_with_crit: verifikasi format result
	var result := resolver.resolve_with_crit(attacker, target)
	assert(result.has("hit"),            "❌ result harus punya 'hit'")
	assert(result.has("crit"),           "❌ result harus punya 'crit'")
	assert(result.has("raw_roll"),       "❌ result harus punya 'raw_roll'")
	assert(result.has("crit_threshold"), "❌ result harus punya 'crit_threshold'")
	# Crit harus selalu hit
	if result["crit"]:
		assert(result["hit"] == true, "❌ Crit harus selalu HIT!")
		print("✅ Crit terjadi (raw=%d) → hit=true (crit selalu hit)" % result["raw_roll"])
	else:
		print("✅ resolve_with_crit() → hit=%s, crit=false (raw=%d)" % [str(result["hit"]), result["raw_roll"]])

	print("→ CritResolver: SEMUA TEST PASSED ✅\n")


# ── ENEMY PHASE MANAGER (Phase 3) ─────────────────────────────────────────────

func _test_enemy_phase_manager() -> void:
	print("--- EnemyPhaseManager Tests ---")

	var mock_stats := MockStatProvider.new()
	var enemy_mgr  := EnemyPhaseManager.new()
	add_child(mock_stats)
	add_child(enemy_mgr)
	enemy_mgr.setup(mock_stats)

	# Buat 3 dummy enemy
	var e1 := MockEntity.new(); e1.entity_name = "Goblin";  e1.mock_dex = 12; e1.add_to_group("enemies")
	var e2 := MockEntity.new(); e2.entity_name = "Orc";     e2.mock_dex = 8;  e2.add_to_group("enemies")
	var e3 := MockEntity.new(); e3.entity_name = "Skeleton"; e3.mock_dex = 15; e3.add_to_group("enemies")
	add_child(e1); add_child(e2); add_child(e3)

	# Track urutan giliran
	var turn_order: Array[String] = []
	enemy_mgr.enemy_turn_started.connect(func(enemy):
		turn_order.append(enemy.entity_name)
	)

	var phase_done := [false]
	enemy_mgr.phase_ended.connect(func():
		phase_done[0] = true
	)

	# Jalankan enemy phase
	enemy_mgr.start_phase([e1, e2, e3])

	# Tunggu phase selesai (3 musuh × 0.5s delay = ~1.5s)
	await get_tree().create_timer(2.5).timeout

	assert(phase_done[0], "❌ Enemy phase harus sudah selesai dalam 2.5s")
	assert(turn_order.size() == 3, "❌ Harus ada 3 giliran enemy, dapat: %d" % turn_order.size())

	# Verifikasi urutan: Skeleton(15) → Goblin(12) → Orc(8)
	assert(turn_order[0] == "Skeleton",
		"❌ Giliran pertama harus Skeleton (DEX=15), dapat: %s" % turn_order[0])
	assert(turn_order[1] == "Goblin",
		"❌ Giliran kedua harus Goblin (DEX=12), dapat: %s" % turn_order[1])
	assert(turn_order[2] == "Orc",
		"❌ Giliran ketiga harus Orc (DEX=8), dapat: %s" % turn_order[2])

	print("✅ Urutan giliran: %s (DEX descending ✅)" % str(turn_order))
	print("→ EnemyPhaseManager: SEMUA TEST PASSED ✅\n")

	# Clean up mock enemies (remove dari group secara instan agar tidak mengganggu test berikutnya)
	e1.remove_from_group("enemies")
	e2.remove_from_group("enemies")
	e3.remove_from_group("enemies")
	e1.queue_free()
	e2.queue_free()
	e3.queue_free()
	enemy_mgr.queue_free()


# ── FULL PHASE CYCLE (Phase 3) ────────────────────────────────────────────────

func _test_full_phase_cycle() -> void:
	print("--- PhaseTransitionHandler Tests ---")

	var ap1 := ActionPointManager.new()
	var ap2 := ActionPointManager.new()
	var p_mgr := PlayerPhaseManager.new()
	var e_mgr := EnemyPhaseManager.new()
	var handler := PhaseTransitionHandler.new()

	add_child(ap1); add_child(ap2)
	add_child(p_mgr); add_child(e_mgr); add_child(handler)

	ap1.setup(0, 0)
	ap2.setup(0, 0)
	p_mgr.setup(ap1, ap2)
	handler.setup(p_mgr, e_mgr)

	# Buat 1 enemy
	var enemy := MockEntity.new()
	enemy.entity_name = "TestEnemy"
	enemy.add_to_group("enemies")
	add_child(enemy)

	var phases_visited: Array[String] = []
	handler.player_phase_started.connect(func(_t): phases_visited.append("PLAYER"))
	handler.enemy_phase_started.connect(func(_t): phases_visited.append("ENEMY"))

	# Start combat
	handler.start_combat()
	assert(handler.is_player_phase(), "❌ Setelah start_combat harus PLAYER phase")
	print("✅ start_combat() → PLAYER phase aktif")

	# Kedua player end turn
	p_mgr.confirm_end_turn(1)
	p_mgr.confirm_end_turn(2)

	# Tunggu enemy phase + 1 turn selesai
	await get_tree().create_timer(1.5).timeout

	assert(phases_visited.has("ENEMY"), "❌ Harus pernah masuk ENEMY phase")
	print("✅ Setelah both_players_confirmed → masuk ENEMY phase")

	# Tunggu kembali ke player phase (beri waktu ekstra jika ada musuh betulan di main.tscn)
	await get_tree().create_timer(4.0).timeout
	assert(handler.get_turn_number() >= 2, "❌ Turn harus sudah increment setelah enemy phase")
	print("✅ Turn number increment ke %d setelah enemy phase selesai" % handler.get_turn_number())

	print("→ PhaseTransitionHandler: SEMUA TEST PASSED ✅\n")
	print("========================================")
	print("  PHASE 3 & 4 TEST COMPLETE")
	print("========================================\n")
