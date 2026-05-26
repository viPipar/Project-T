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
var _stat_provider : MockStatProvider
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


func _ready() -> void:
	await get_tree().process_frame
	_setup_combat_core()
	_hook_signals()
	_print_banner()


# ── SETUP ─────────────────────────────────────────────────────────────────────

func _setup_combat_core() -> void:
	# RNG
	_stat_provider = MockStatProvider.new(); add_child(_stat_provider)
	_dice_roller   = DiceRoller.new();       add_child(_dice_roller)
	_luck_roller   = LuckRoller.new();       add_child(_luck_roller)
	_hit_resolver  = HitMissResolver.new();  add_child(_hit_resolver)
	_crit_resolver = CritResolver.new();     add_child(_crit_resolver)
	_hit_resolver.setup(_stat_provider)
	_crit_resolver.setup(_stat_provider)

	# P1 (Fighter) — DEX=8, INT=10, MOV=6, base 5 Energy Charge
	_p1_ap  = ActionPointManager.new();   add_child(_p1_ap)
	_p1_mov = MovementPointManager.new(); add_child(_p1_mov)
	_p1_ec  = EnergyChargeManager.new();  add_child(_p1_ec)
	_p1_ap.setup(8, 10)
	_p1_mov.setup(6)
	_p1_ec.setup()

	# P2 (Wizard) — DEX=6, INT=15, MOV=4, ATT=10
	_p2_ap  = ActionPointManager.new();   add_child(_p2_ap)
	_p2_mov = MovementPointManager.new(); add_child(_p2_mov)
	_p2_ss  = SpellSlotManager.new();     add_child(_p2_ss)
	_p2_ap.setup(6, 15)
	_p2_mov.setup(4)
	_p2_ss.setup(10)  # ATT=10 → Lv1: 2+2=4, Lv2: 2+1=3, Lv3: 1+0=1

	# Mana cross-converter
	_mana = ManaConverter.new(); add_child(_mana)
	_mana.setup(_p1_ec, _p2_ss)

	print("[CombatTestBridge] Combat core systems ready ✅")


# ── SIGNAL HOOKS (ke TurnManager yang sudah ada) ──────────────────────────────

func _hook_signals() -> void:
	# Attack: Player.gd sekarang emit EventBus.attackcam_started(attacker, target, ability_id)
	EventBus.attackcam_started.connect(_on_attack)

	# Phase tracking dari TurnManager
	TurnManager.turn_state_changed.connect(_on_phase_changed)
	TurnManager.player_end_state_changed.connect(_on_player_end_turn)

	# Enemy turn dari TurnManager — kita yang drive AI-nya
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)

	print("[CombatTestBridge] Signals terhubung ke TurnManager ✅")


# ── ATTACK RESOLVE ────────────────────────────────────────────────────────────

func _on_attack(attacker: Node, target: Node, _ability_id: String) -> void:
	if attacker == null or target == null:
		return

	print("\n[COMBAT] ────────────────────────────")
	print("[COMBAT] %s → menyerang → %s" % [
		attacker.get("char_name") if attacker.get("char_name") else attacker.name,
		target.get("enemy_name")  if target.get("enemy_name")  else target.name
	])

	# Resolve Hit/Crit
	var result        := _crit_resolver.resolve_with_crit(attacker, target, false)
	var raw    : int   = result["raw_roll"]
	var total  : int   = result["roll"]
	var thresh : int   = result["threshold"]
	var hit    : bool  = result["hit"]
	var crit   : bool  = result["crit"]

	print("[COMBAT] D20: %d (raw) + modifier → %d  vs  Armor: %d" % [raw, total, thresh])

	if not hit:
		print("[COMBAT] 💨 MISS!")
		print("[COMBAT] ────────────────────────────")
		return

	# Roll damage
	var dmg_formula := "1D8"
	var dmg         : int
	if crit:
		dmg = _dice_roller.roll_crit(dmg_formula)
		print("[COMBAT] 💥 CRITICAL HIT! Damage (%s × 2) = %d" % [dmg_formula, dmg])
	else:
		dmg = _dice_roller.roll_from_string(dmg_formula)
		print("[COMBAT] ⚔️  HIT! Damage (%s) = %d" % [dmg_formula, dmg])

	# Apply damage ke target
	if target.has_method("take_damage"):
		target.take_damage(dmg)
	else:
		print("[COMBAT] ⚠️  Target tidak punya take_damage() — damage tidak di-apply")

	# Emit ke EventBus untuk HUD/sistem lain
	EventBus.damage_dealt.emit(target, dmg, "physical", crit)
	print("[COMBAT] ────────────────────────────")


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

	var name_str : String = enemy.get("enemy_name") if enemy.get("enemy_name") else enemy.name
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
	print("║  P1 Aria  (Fighter)                          ║")
	print("║    AP: %d/%d  BAP: %d/%d  Mov: %d tiles         " % [
		_p1_ap.current_ap, _p1_ap.max_ap,
		_p1_ap.current_bap, _p1_ap.max_bap,
		_p1_mov.max_tiles])
	print("║    Energy Charge: %d/%d                        " % [_p1_ec.current_charges, _p1_ec.max_charges])
	print("║  P2 Kael  (Wizard)                           ║")
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
