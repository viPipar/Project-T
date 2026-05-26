# combat_core/tests/CombatTestBridge.gd
# ── JEMBATAN COMBAT CORE ↔ MAIN SCENE ────────────────────────────────────────
# Script ini di-attach ke Node di Main.tscn untuk menghubungkan combat_core
# dengan P1/P2 dan EnemyPlaceholder yang sudah ada.
#
# CARA PAKAI:
#   1. Di Godot Editor: buka Main.tscn
#   2. Tambah Node baru, beri nama "CombatTestBridge"
#   3. Attach script ini ke node tersebut
#   4. Run scene → coba serang enemy, lihat Output panel
#
# KONTROL TESTING (di Output panel saat combat):
#   P1: E → confirm/attack    Q → end turn
#   P2: O → confirm/attack    U → end turn
extends Node

# ── State combat_core ────────────────────────────────────────────────────────
var _stat_provider : MockStatProvider
var _hit_resolver  : HitMissResolver
var _crit_resolver : CritResolver
var _dice_roller   : DiceRoller
var _luck_roller   : LuckRoller

# Action Economy per player (P1 = Fighter, P2 = Wizard)
var _p1_ap  : ActionPointManager
var _p2_ap  : ActionPointManager
var _p1_mov : MovementPointManager
var _p2_mov : MovementPointManager
var _p1_ec  : EnergyChargeManager   # P1 = Fighter
var _p2_ss  : SpellSlotManager      # P2 = Wizard
var _mana   : ManaConverter

# Phase managers
var _player_phase : PlayerPhaseManager
var _enemy_phase  : EnemyPhaseManager
var _phase_handler: PhaseTransitionHandler


func _ready() -> void:
	# Tunggu scene fully loaded
	await get_tree().process_frame
	_setup_combat_core()
	_hook_into_existing_systems()
	_print_status()


# ── SETUP COMBAT CORE ─────────────────────────────────────────────────────────

func _setup_combat_core() -> void:
	print("\n[CombatTestBridge] ── Setup combat_core ──")

	# RNG
	_stat_provider = MockStatProvider.new();  add_child(_stat_provider)
	_dice_roller   = DiceRoller.new();        add_child(_dice_roller)
	_luck_roller   = LuckRoller.new();        add_child(_luck_roller)
	_hit_resolver  = HitMissResolver.new();   add_child(_hit_resolver)
	_crit_resolver = CritResolver.new();      add_child(_crit_resolver)
	_hit_resolver.setup(_stat_provider)
	_crit_resolver.setup(_stat_provider)

	# P1 Action Economy (Fighter — default DEX=8, INT=10)
	_p1_ap  = ActionPointManager.new();   add_child(_p1_ap)
	_p1_mov = MovementPointManager.new(); add_child(_p1_mov)
	_p1_ec  = EnergyChargeManager.new();  add_child(_p1_ec)
	_p1_ap.setup(8, 10)   # DEX=8 → AP=1, INT=10 → BAP=2
	_p1_mov.setup(6)       # MOV=6 → 7 tiles
	_p1_ec.setup()         # base 5 charges

	# P2 Action Economy (Wizard — default DEX=6, INT=15, ATT=10)
	_p2_ap  = ActionPointManager.new();   add_child(_p2_ap)
	_p2_mov = MovementPointManager.new(); add_child(_p2_mov)
	_p2_ss  = SpellSlotManager.new();     add_child(_p2_ss)
	_p2_ap.setup(6, 15)   # DEX=6 → AP=1, INT=15 → BAP=2
	_p2_mov.setup(4)       # MOV=4 → 6 tiles
	_p2_ss.setup(10)       # ATT=10 → Lv1:4, Lv2:3, Lv3:1

	# Mana converter
	_mana = ManaConverter.new(); add_child(_mana)
	_mana.setup(_p1_ec, _p2_ss)

	# Phase managers
	_player_phase  = PlayerPhaseManager.new();   add_child(_player_phase)
	_enemy_phase   = EnemyPhaseManager.new();    add_child(_enemy_phase)
	_phase_handler = PhaseTransitionHandler.new(); add_child(_phase_handler)

	_player_phase.setup(_p1_ap, _p2_ap)
	_enemy_phase.setup(_stat_provider)
	_phase_handler.setup(_player_phase, _enemy_phase)

	# Connect signals untuk logging
	_player_phase.conflict_detected.connect(func(a,b):
		print("[COMBAT] ⚡ Conflict! P1 dan P2 menyerang target yang sama → P1 dulu"))
	_player_phase.action_executed.connect(func(pid, action):
		print("[COMBAT] P%d eksekusi: %s" % [pid, action.get("ability_id","?")]))
	_phase_handler.player_phase_started.connect(func(t):
		print("\n[TURN %d] ═══ PLAYER PHASE ═══" % t))
	_phase_handler.enemy_phase_started.connect(func(t):
		print("\n[TURN %d] ═══ ENEMY PHASE ═══" % t))
	_phase_handler.combat_victory.connect(func():
		print("\n[COMBAT] 🏆 VICTORY! Semua musuh kalah."))

	print("[CombatTestBridge] combat_core setup selesai ✅")


# ── HOOK KE SISTEM YANG SUDAH ADA ────────────────────────────────────────────

func _hook_into_existing_systems() -> void:
	print("[CombatTestBridge] ── Hook ke existing systems ──")

	# Hook ke Player._on_confirm — setiap attack → resolve hit/miss/crit via combat_core
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if p.has_signal(""):
			pass
		# Inject attack resolver ke player — kita monitor EventBus
		pass

	# Listen EventBus.attackcam_started → ini trigger saat player klik enemy
	EventBus.attackcam_started.connect(_on_attack_triggered)

	# Listen TurnManager signals untuk sync dengan PhaseTransitionHandler
	TurnManager.turn_state_changed.connect(_on_turn_state_changed)

	print("[CombatTestBridge] Hooks terpasang ✅")


# ── EVENT HANDLERS ────────────────────────────────────────────────────────────

## Dipanggil saat AttackCam.play() → berarti player sudah menyerang target
func _on_attack_triggered(attacker: Node, target: Node, _ability_id: String) -> void:
	if attacker == null or target == null:
		return

	print("\n[COMBAT] ── Resolving Attack ──")
	print("  Attacker: %s" % attacker.name)
	print("  Target  : %s" % target.name)

	# Resolve Hit/Crit via combat_core
	var result := _crit_resolver.resolve_with_crit(attacker, target, false)
	var raw    : int = result["raw_roll"]
	var total  : int = result["roll"]
	var thresh : int = result["threshold"]
	var hit    : bool= result["hit"]
	var crit   : bool= result["crit"]

	print("  D20 Roll : %d (raw) + modifier → %d vs Armor %d" % [raw, total, thresh])

	if not hit:
		print("  💨 MISS!")
		return

	# Roll damage
	var dmg_formula := "1D8"  # default — nanti diambil dari ability/weapon
	var dmg : int
	if crit:
		dmg = _dice_roller.roll_crit(dmg_formula)
		print("  💥 CRITICAL HIT! Damage x2: %s → %d" % [dmg_formula, dmg])
	else:
		dmg = _dice_roller.roll_from_string(dmg_formula)
		print("  ⚔️  HIT! Damage: %s → %d" % [dmg_formula, dmg])

	# Apply ke target jika punya take_damage()
	if target.has_method("take_damage"):
		target.take_damage(dmg)
		var hp_left = target.get("current_hp")
		if hp_left != null:
			print("  Target HP: %d tersisa" % hp_left)

	# Emit ke EventBus untuk sistem lain (HUD floating text, dll.)
	EventBus.damage_dealt.emit(target, dmg, "physical", crit)


func _on_turn_state_changed(turn: int, phase: int) -> void:
	# Sync info saja — TurnManager tetap yang punya kontrol
	pass


# ── STATUS PRINT ─────────────────────────────────────────────────────────────

func _print_status() -> void:
	print("\n╔══════════════════════════════════════════╗")
	print("║   COMBAT CORE — TEST MODE AKTIF          ║")
	print("╠══════════════════════════════════════════╣")
	print("║  P1 (Fighter/Aria)                       ║")
	print("║    AP: %d/%d  |  Energy: %d/%d  |  Mov: %d tiles" % [
		_p1_ap.current_ap, _p1_ap.max_ap,
		_p1_ec.current_charges, _p1_ec.max_charges,
		_p1_mov.max_tiles])
	print("║  P2 (Wizard/Kael)                        ║")
	print("║    AP: %d/%d  |  Slot Lv1: %d/%d  |  Mov: %d tiles" % [
		_p2_ap.current_ap, _p2_ap.max_ap,
		_p2_ss.current_slots[0], _p2_ss.max_slots[0],
		_p2_mov.max_tiles])
	print("╠══════════════════════════════════════════╣")
	print("║  KONTROL:                                ║")
	print("║  P1: WASD gerak | E konfirm/serang       ║")
	print("║      Q = End Turn                        ║")
	print("║  P2: IJKL gerak | O konfirm/serang       ║")
	print("║      U = End Turn                        ║")
	print("║  F2 = Dice Sandbox (roll manual)         ║")
	print("║  F1 = Debug Panel                        ║")
	print("╚══════════════════════════════════════════╝\n")


# ── DEBUG KEYBOARD ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				# F5 → print current resource status
				_print_status()
			KEY_F6:
				# F6 → simulasi item pickup (slot_lv2 untuk P1 Fighter)
				print("\n[DEBUG] Simulasi equip 'slot_lv2' item ke Fighter (P1)...")
				_mana.apply_mana_item("slot_lv2", "fighter")
				print("  P1 Energy Charge cap baru: %d" % _p1_ec.max_charges)
			KEY_F7:
				# F7 → simulasi luck roll
				print("\n[DEBUG] Luck Roll (LCK=5 avg)...")
				var roll := _luck_roller.roll_luck_coop(5, 10)
				print("  Result: %d → %s" % [roll, "WIN ✅" if roll >= 11 else "LOSE ❌"])
			KEY_F8:
				# F8 → roll contested pick
				print("\n[DEBUG] Contested Item Pick (P1 LCK=5 vs P2 LCK=10)...")
				var winner := _luck_roller.roll_contested_pick(5, 10)
				print("  Pemenang: P%d" % winner)
