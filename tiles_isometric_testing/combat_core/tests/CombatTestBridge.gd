# combat_core/tests/CombatTestBridge.gd
# Tanggung jawab:
#   Menjembatani input attack dari Main.tscn ke combat_core Tapip.
#   Runtime utama memakai StatSystem dan HealthComponent; MockStatProvider hanya fallback test.
#
# Cara pakai:
#   Script ini dipasang dari main.gd pada Main.tscn.
#   EventBus.attackcam_started.emit(attacker, target, "main_attack")
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Serang enemy dari player.
#   3. Pastikan hit/miss tetap muncul dan damage masuk ke HealthComponent target.
# combat_core/tests/CombatTestBridge.gd
# ── JEMBATAN COMBAT CORE ↔ MAIN SCENE ────────────────────────────────────────
# Attach ke Node di Main.tscn (sudah dilakukan otomatis dari main.gd).
# Script ini TIDAK memodifikasi TurnManager — hanya hook ke signals-nya.
#
# KONTROL:
#   P1 : WASD gerak | E konfirm/serang | Q end turn
#   P2 : IJKL gerak | O konfirm/serang | U end turn
#   F2 : Dice Sandbox
#   F5 : Print status resource
#   F6 : Simulasi equip slot_lv2 item (Fighter P1 +2 charge)
#   F7 : Simulasi Luck Roll
#   F8 : Simulasi Contested Pick (FIXED — tidak crash lagi)
extends Node

# ── Combat Core Systems ───────────────────────────────────────────────────────
var _stat_provider
var _dice_roller   : DiceRoller
var _luck_roller   : LuckRoller
var _hit_resolver  : HitMissResolver
var _crit_resolver : CritResolver

# Action Economy
var _p1_ap  : ActionPointManager
var _p2_ap  : ActionPointManager
var _p1_mov : MovementPointManager
var _p2_mov : MovementPointManager
var _p1_ec  : EnergyChargeManager
var _p2_ss  : SpellSlotManager
var _mana   : ManaConverter

# ── Dice Overlay (satu per player) ──────────────────────────────────────────
var _overlay_p1: CombatDiceOverlay
var _overlay_p2: CombatDiceOverlay

# Per-player block flag (terpisah dari InputManager untuk tracking internal)
var _p1_busy: bool = false
var _p2_busy: bool = false


func _ready() -> void:
	await get_tree().process_frame
	_setup_combat_core()
	_hook_signals()
	_print_banner()


# ── SETUP ─────────────────────────────────────────────────────────────────────

func _setup_combat_core() -> void:
	# RNG
	_stat_provider = get_node_or_null("/root/StatSystem")
	if _stat_provider == null:
		_stat_provider = MockStatProvider.new()
		add_child(_stat_provider)
	_dice_roller   = DiceRoller.new();       add_child(_dice_roller)
	_luck_roller   = LuckRoller.new();       add_child(_luck_roller)
	_hit_resolver  = HitMissResolver.new();  add_child(_hit_resolver)
	_crit_resolver = CritResolver.new();     add_child(_crit_resolver)
	_hit_resolver.setup(_stat_provider)
	_crit_resolver.setup(_stat_provider)

	# Ambil real stats dari player di world
	var p1: Node = null
	var p2: Node = null
	for p in get_tree().get_nodes_in_group("players"):
		var pid = p.get("player_id")
		if pid == 1:
			p1 = p
		elif pid == 2:
			p2 = p

	# Fallback values if not found
	var p1_dex = 8; var p1_int = 10; var p1_mov = 6
	var p2_dex = 6; var p2_int = 15; var p2_mov = 4; var p2_att = 10

	if p1 != null:
		p1_dex = _stat_provider.get_dex(p1)
		p1_int = _stat_provider.get_int_stat(p1)
		p1_mov = _stat_provider.get_mov(p1)
	if p2 != null:
		p2_dex = _stat_provider.get_dex(p2)
		p2_int = _stat_provider.get_int_stat(p2)
		p2_mov = _stat_provider.get_mov(p2)
		p2_att = _stat_provider.get_att(p2)

	# P1 (Fighter)
	_p1_ap  = ActionPointManager.new();   add_child(_p1_ap)
	_p1_mov = MovementPointManager.new(); add_child(_p1_mov)
	_p1_ec  = EnergyChargeManager.new();  add_child(_p1_ec)
	_p1_ap.setup(p1_dex, p1_int)
	_p1_mov.setup(p1_mov)
	_p1_ec.setup()

	# P2 (Wizard)
	_p2_ap  = ActionPointManager.new();   add_child(_p2_ap)
	_p2_mov = MovementPointManager.new(); add_child(_p2_mov)
	_p2_ss  = SpellSlotManager.new();     add_child(_p2_ss)
	_p2_ap.setup(p2_dex, p2_int)
	_p2_mov.setup(p2_mov)
	_p2_ss.setup(p2_att)

	# Mana cross-converter
	_mana = ManaConverter.new(); add_child(_mana)
	_mana.setup(_p1_ec, _p2_ss)

	# ── Dice Overlay — instansiate 2 (satu untuk kiri/P1, satu untuk kanan/P2) ──
	var overlay_scene := preload("res://combat_core/ui/CombatDiceOverlay.tscn")

	_overlay_p1 = overlay_scene.instantiate() as CombatDiceOverlay
	_overlay_p1.player_id = 1
	get_tree().root.add_child.call_deferred(_overlay_p1)

	_overlay_p2 = overlay_scene.instantiate() as CombatDiceOverlay
	_overlay_p2.player_id = 2
	get_tree().root.add_child.call_deferred(_overlay_p2)

	# Subscribe ke EventBus untuk sync InputManager
	EventBus.combat_input_blocked.connect(_on_combat_input_blocked)

	# ── Broadcast ke HUD overlay ─────────────────────────────────────────────
	# Deferred agar HUD punya waktu untuk _ready() dulu
	_emit_hud_ready.call_deferred()

	print("[CombatTestBridge] Combat core systems ready ✅")


func _emit_hud_ready() -> void:
	EventBus.combat_hud_ready.emit(1, _p1_ap, _p1_mov, _p1_ec)  # P1 Fighter
	EventBus.combat_hud_ready.emit(2, _p2_ap, _p2_mov, _p2_ss)  # P2 Wizard
	print("[CombatTestBridge] combat_hud_ready emitted for P1 & P2 ✅")


# ── SIGNAL HOOKS (ke TurnManager yang sudah ada) ──────────────────────────────

func _hook_signals() -> void:
	# Attack: Player.gd sekarang emit EventBus.attackcam_started(attacker, target, ability_id)
	EventBus.attackcam_started.connect(_on_attack)

	# Phase tracking dari TurnManager
	TurnManager.turn_state_changed.connect(_on_phase_changed)
	TurnManager.player_end_state_changed.connect(_on_player_end_turn)

	# Enemy turn dari TurnManager — kita yang drive AI-nya
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	
	# Listen to player movement to sync with our MovementPointManager
	EventBus.player_moved.connect(_on_player_moved)

	print("[CombatTestBridge] Signals terhubung ke TurnManager & EventBus ✅")


func _on_player_moved(player: Node, _from_pos: Vector2i, _to_pos: Vector2i) -> void:
	var _pid_raw: Variant = player.get("player_id")
	var pid: int = int(_pid_raw) if _pid_raw != null else 1
	var mc = player.get_node_or_null("MovementComponent")
	
	# Sinkronkan nilai movement_left milik player ke HUD MovementPointManager
	if mc != null:
		if pid == 1:
			_p1_mov.current_tiles = mc.movement_left
			_p1_mov.movement_changed.emit(_p1_mov.current_tiles, _p1_mov.max_tiles)
		elif pid == 2:
			_p2_mov.current_tiles = mc.movement_left
			_p2_mov.movement_changed.emit(_p2_mov.current_tiles, _p2_mov.max_tiles)


# ── ATTACK RESOLVE ────────────────────────────────────────────────────────────

func _on_attack(attacker: Node, target: Node, _ability_id: String) -> void:
	if attacker == null or target == null:
		return

	# Tentukan player_id penyerang
	var _pid_raw: Variant = attacker.get("player_id")
	var pid: int = int(_pid_raw) if _pid_raw != null else 1

	# Blok jika animasi player ini sedang berjalan (cegah spam serangan)
	var is_busy := _p1_busy if pid == 1 else _p2_busy
	if is_busy:
		print("[COMBAT] ⚠️ P%d — Animasi sedang berjalan, input diblok" % pid)
		return
		
	# Deduksi 1 Action Point untuk serangan
	var has_ap := false
	if pid == 1: has_ap = _p1_ap.spend_ap(1)
	elif pid == 2: has_ap = _p2_ap.spend_ap(1)
	
	if not has_ap:
		print("[COMBAT] ⚠️ P%d — Tidak ada Action Point yang tersisa untuk menyerang!" % pid)
		return

	# Set busy & blok input hanya untuk player ini
	if pid == 1: _p1_busy = true
	else:         _p2_busy = true
	EventBus.combat_input_blocked.emit(pid, true)

	var _aname_raw: Variant = attacker.get("char_name")
	var _tname_raw: Variant = target.get("enemy_name")
	var attacker_name: String = str(_aname_raw) if _aname_raw != null else attacker.name
	var target_name:   String = str(_tname_raw) if _tname_raw != null else target.name

	print("\n[COMBAT] ────────────────────────────")
	print("[COMBAT] %s → menyerang → %s" % [attacker_name, target_name])

	# ── Resolve Hit/Crit (logika tidak berubah) ───────────────────────────────
	var result        := _crit_resolver.resolve_with_crit(attacker, target, false)
	var raw    : int   = result["raw_roll"]
	var total  : int   = result["roll"]
	var thresh : int   = result["threshold"]
	var hit    : bool  = result["hit"]
	var crit   : bool  = result["crit"]

	print("[COMBAT] D20: %d (raw) + modifier → %d  vs  Armor: %d" % [raw, total, thresh])

	# ── Siapkan data damage (diroll di sini, tapi diapply SETELAH animasi) ────
	var base_dice := "1D8"
	var dmg_formula := base_dice
	var dmg_rolls   : Array[int] = []
	var dmg_total   : int = 0
	
	var stat_comp = attacker.get_node_or_null("StatsComponent") as StatsComponent
	var dmg_mod := 0
	if stat_comp != null:
		dmg_mod = stat_comp.get_stat("physical_damage")
		if dmg_mod > 0:
			dmg_formula += "+%d" % dmg_mod
		elif dmg_mod < 0:
			dmg_formula += "%d" % dmg_mod

	if hit:
		# Roll detail: ambil Array tiap dadu agar bisa divisualisasikan satu per satu
		var base_detail := _dice_roller.roll_detailed(base_dice)
		dmg_rolls = base_detail["rolls"]
		dmg_total = base_detail["total"] + dmg_mod

		if crit:
			# Crit = dadu ganda: tambah satu set lagi
			var extra_detail := _dice_roller.roll_detailed(base_dice)
			for r: int in extra_detail["rolls"]:
				dmg_rolls.append(r)
				dmg_total += r
			var mod_str = ("+%d"%dmg_mod) if dmg_mod >= 0 else ("%d"%dmg_mod)
			print("[COMBAT] 💥 CRITICAL HIT! Damage (%s × 2 %s) = %d" % [base_dice, mod_str, dmg_total])
		else:
			print("[COMBAT] ⚔️  HIT! Damage (%s) = %d" % [dmg_formula, dmg_total])
	else:
		print("[COMBAT] 💨 MISS!")
		# TODO (Team): migrated from miss_occurred to on_miss
		EventBus.on_miss.emit(attacker, target)
	print("[COMBAT] ────────────────────────────")

	# ── Jalankan animasi overlay (AWAIT — blok sampai selesai) ────────────────
	var overlay := _overlay_p1 if pid == 1 else _overlay_p2
	if overlay != null:
		await overlay.play_attack_sequence(
			attacker, target,
			result,
			dmg_rolls,
			dmg_total,
			dmg_formula
		)
	else:
		push_warning("[CombatTestBridge] Overlay P%d null! Langsung apply damage." % pid)
		await get_tree().process_frame

	# ── Apply damage ke target SETELAH animasi selesai ───────────────────────
	if hit:
		if is_instance_valid(target):
			var applied := _apply_damage_to_target(target, dmg_total, attacker)
			EventBus.damage_dealt.emit(target, applied, "physical", crit)
			if applied > 0 and is_instance_valid(target):
				ForcedMovementResolver.knockback_from_attack(attacker, target, 2)
		else:
			print("[COMBAT] ⚠️  Target sudah dikalahkan sebelum serangan mendarat!")

	# Buka blok input player ini
	if pid == 1: _p1_busy = false
	else:         _p2_busy = false
	EventBus.combat_input_blocked.emit(pid, false)


# ── CALLBACK — sync InputManager saat signal diterima ────────────────────────

func _on_combat_input_blocked(player_id: int, blocked: bool) -> void:
	InputManager.set_player_blocked(player_id, blocked)


func _apply_damage_to_target(target: Node, amount: int, attacker: Node) -> int:
	var stat_system := get_node_or_null("/root/StatSystem")
	if stat_system != null and stat_system.has_method("apply_damage"):
		return int(stat_system.apply_damage(target, amount, attacker, "physical"))

	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		return health.take_damage(amount, attacker, "physical")

	if target.has_method("take_damage"):
		target.call("take_damage", amount)
		return maxi(0, amount)

	print("[COMBAT] Target tidak punya HealthComponent/take_damage() - damage tidak di-apply")
	return 0


# ── PHASE TRACKING ────────────────────────────────────────────────────────────

func _on_phase_changed(turn: int, phase: int) -> void:
	if phase == 0:  # TurnManager.Phase.PLAYERS
		print("\n╔═══════════════════════════════╗")
		print("║  TURN %d — PLAYER PHASE        ║" % turn)
		print("╚═══════════════════════════════╝")
		# Reset resource di awal turn player
		_p1_ap.reset();  _p2_ap.reset()
		_p1_mov.reset(); _p2_mov.reset()
		print("[RESOURCE RESET] AP, BAP, Movement di-reset untuk Turn %d" % turn)

	elif phase == 1:  # TurnManager.Phase.ENEMIES
		print("\n╔═══════════════════════════════╗")
		print("║  TURN %d — ENEMY PHASE         ║" % turn)
		print("╚═══════════════════════════════╝")


func _on_player_end_turn(player_id: int, ended: bool) -> void:
	if ended:
		print("[TURN] P%d → End Turn ✅  (tekan tombol player lain untuk end turn juga)" % player_id)


# ── ENEMY AI ─────────────────────────────────────────────────────────────────

func _on_enemy_turn_started(enemy: Node) -> void:
	if enemy == null:
		return

	var _ename_raw: Variant = enemy.get("enemy_name")
	var name_str: String = str(_ename_raw) if _ename_raw != null else enemy.name
	print("\n[ENEMY AI] ─── Giliran %s ───" % name_str)

	# Panggil AI method jika ada (EnemyPlaceholder.do_ai_turn())
	if enemy.has_method("do_ai_turn"):
		enemy.do_ai_turn()
	else:
		print("[ENEMY AI] %s tidak punya do_ai_turn() — idle." % name_str)

	# Akhiri giliran enemy ini → TurnManager advance ke enemy berikutnya
	# Delay 0.5s biar kelihatan prosesnya
	await get_tree().create_timer(0.5).timeout
	TurnManager.request_end_turn()


# ── DEBUG KEYBOARD ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Blok semua debug input juga saat kedua player animasi berjalan
	if _p1_busy and _p2_busy:
		return
	match event.keycode:
		KEY_F5:
			_print_banner()

		KEY_F6:
			print("\n[DEBUG F6] Simulasi equip 'slot_lv2' item ke Fighter (P1)...")
			_mana.apply_mana_item("slot_lv2", "fighter")
			print("  ✅ P1 Energy Charge cap: %d → %d" % [_p1_ec.max_charges - 2, _p1_ec.max_charges])

		KEY_F7:
			print("\n[DEBUG F7] Luck Roll (P1 LCK=5, P2 LCK=10)...")
			var roll := _luck_roller.roll_luck_coop(5, 10)
			print("  Result: %d → %s" % [roll, "WIN ✅" if roll >= 11 else "LOSE ❌"])

		KEY_F8:
			print("\n[DEBUG F8] Contested Item Pick (P1 LCK=5 vs P2 LCK=10)...")
			var winner := _luck_roller.roll_contested_pick(5, 10)
			if winner > 0:
				print("  Pemenang: P%d 🏆" % winner)


# ── STATUS BANNER ─────────────────────────────────────────────────────────────

func _print_banner() -> void:
	print("\n╔══════════════════════════════════════════════╗")
	print("║         COMBAT CORE — TEST MODE AKTIF        ║")
	print("╠══════════════════════════════════════════════╣")
	print("║  P1 Fighter                                  ║")
	print("║    AP: %d/%d  BAP: %d/%d  Mov: %d tiles         " % [
		_p1_ap.current_ap, _p1_ap.max_ap,
		_p1_ap.current_bap, _p1_ap.max_bap,
		_p1_mov.max_tiles])
	print("║    Energy Charge: %d/%d                        " % [_p1_ec.current_charges, _p1_ec.max_charges])
	print("║  P2 Wizard                                   ║")
	print("║    AP: %d/%d  BAP: %d/%d  Mov: %d tiles         " % [
		_p2_ap.current_ap, _p2_ap.max_ap,
		_p2_ap.current_bap, _p2_ap.max_bap,
		_p2_mov.max_tiles])
	print("║    Spell Slots  Lv1:%d/%d  Lv2:%d/%d  Lv3:%d/%d  " % [
		_p2_ss.current_slots[0], _p2_ss.max_slots[0],
		_p2_ss.current_slots[1], _p2_ss.max_slots[1],
		_p2_ss.current_slots[2], _p2_ss.max_slots[2]])
	print("╠══════════════════════════════════════════════╣")
	print("║  P1: WASD gerak | E serang | Q end turn      ║")
	print("║  P2: IJKL gerak | O serang | U end turn      ║")
	print("║  F2 Dice Sandbox | F5 Status | F6 Item sim   ║")
	print("║  F7 Luck Roll    | F8 Contested Pick         ║")
	print("╚══════════════════════════════════════════════╝")
