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
#   P1 : WASD gerak | F konfirm/serang | X cancel | R end turn
#   P2 : IJKL gerak | ; konfirm/serang | , cancel | P end turn
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

	# --- DEBUG INFINITE RESOURCES FOR TESTING ---
	_p1_ap.max_ap += 99; _p1_ap.current_ap += 99
	_p2_ap.max_ap += 99; _p2_ap.current_ap += 99
	_p1_ec.max_charges += 99; _p1_ec.current_charges += 99
	for i in range(4):
		_p2_ss.max_slots[i] += 99
		_p2_ss.current_slots[i] += 99
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

	if is_instance_valid(attacker) and attacker.has_method("is_downed") and attacker.is_downed():
		print("[COMBAT] P%d downed, action dibatalkan." % pid)
		return

	# Blok jika animasi player ini sedang berjalan (cegah spam serangan)
	var is_busy := _p1_busy if pid == 1 else _p2_busy
	if not is_busy:
		_set_player_busy(pid, true)
	if is_busy:
		print("[COMBAT] ⚠️ P%d — Animasi sedang berjalan, input diblok" % pid)
		return
		
	# ── Load Ability ──────────────────────────────────────────────────────────
	var ability_path := "res://combat_core/abilities/instances/%s.tres" % _ability_id
	var ability: BaseAbility = null
	if ResourceLoader.exists(ability_path):
		ability = load(ability_path) as BaseAbility
	var base_dice := "1D8"
	var knockback := 2
	var is_magical := false
	var element_tag := "physical"
	var is_projectile := false
	
	if ability != null:
		base_dice = ability.damage_dice
		knockback = ability.knockback_tiles
		is_magical = (ability.ability_type == BaseAbility.AbilityType.MAGICAL)
		element_tag = ability.element_tag
		if "is_projectile" in ability: is_projectile = ability.is_projectile
		
		var cost_ap = ability.cost_action
		var cost_bap = ability.cost_bonus_action
		var cost_mana = ability.cost_mana
		
		# Validasi AP/BAP
		var ap_mgr = _p1_ap if pid == 1 else _p2_ap
		if ap_mgr.current_ap < cost_ap or ap_mgr.current_bap < cost_bap:
			_set_player_busy(pid, false)
			print("[COMBAT] ⚠️ P%d — Tidak cukup AP/BAP untuk %s!" % [pid, ability.ability_name])
			return
			
		# Validasi Mana
		if pid == 1 and cost_mana > 0:
			if _p1_ec.current_charges < cost_mana:
				_set_player_busy(pid, false)
				print("[COMBAT] ⚠️ P1 — Tidak cukup Energy Charge untuk %s!" % ability.ability_name)
				return
		elif pid == 2 and cost_mana > 0:
			if _p2_ss.current_slots[cost_mana - 1] < 1:
				_set_player_busy(pid, false)
				print("[COMBAT] ⚠️ P2 — Tidak cukup Spell Slot Lv%d untuk %s!" % [cost_mana, ability.ability_name])
				return
				
		# Deduct Cost
		if cost_ap > 0: ap_mgr.spend_ap(cost_ap)
		if cost_bap > 0: ap_mgr.spend_bap(cost_bap)
		if pid == 1 and cost_mana > 0:
			_p1_ec.spend_charge(cost_mana)
			print("[COMBAT] P1 Menghabiskan %d Energy Charge." % cost_mana)
		elif pid == 2 and cost_mana > 0:
			_p2_ss.spend_slot(cost_mana)
			print("[COMBAT] P2 Menghabiskan 1 Spell Slot Lv%d." % cost_mana)
			
		print("[COMBAT] Menggunakan Ability: %s (%s)" % [ability.ability_name, base_dice])
	else:
		push_warning("[COMBAT] Ability '%s' tidak ditemukan! Fallback ke 1D8." % _ability_id)
		var has_ap := false
		if pid == 1: has_ap = _p1_ap.spend_ap(1)
		elif pid == 2: has_ap = _p2_ap.spend_ap(1)
		if not has_ap:
			_set_player_busy(pid, false)
			print("[COMBAT] ⚠️ P%d — Tidak ada Action Point yang tersisa!" % pid)
			return

	var _aname_raw: Variant = attacker.get("char_name")
	var _tname_raw: Variant = target.get("enemy_name")
	var attacker_name: String = str(_aname_raw) if _aname_raw != null else attacker.name
	var target_name:   String = str(_tname_raw) if _tname_raw != null else target.name

	print("\n[COMBAT] ────────────────────────────")
	print("[COMBAT] %s → menyerang → %s" % [attacker_name, target_name])

	# ── Resolve Hit/Crit (logika tidak berubah) ───────────────────────────────
	var result        := _crit_resolver.resolve_with_crit(attacker, target, is_magical)
	var raw    : int   = result["raw_roll"]
	var total  : int   = result["roll"]
	var thresh : int   = result["threshold"]
	var hit    : bool  = result["hit"]
	var crit   : bool  = result["crit"]
	var hit_modifier : int = total - raw

	var defense_label := "Resist" if is_magical else "Armor"
	print("[COMBAT] D20: %d (raw) + %d → %d  vs  %s: %d" % [raw, hit_modifier, total, defense_label, thresh])

	# ── Siapkan data damage (diroll di sini, tapi diapply SETELAH animasi) ────
	var dmg_formula := base_dice
	var dmg_rolls   : Array = []
	var dmg_total   : int = 0
	
	var dmg_mod := _get_damage_modifier(attacker, is_magical)
	if dmg_mod > 0:
		dmg_formula += "+%d" % dmg_mod
	elif dmg_mod < 0:
		dmg_formula += "%d" % dmg_mod

	if hit:
		# Roll detail: ambil Array tiap dadu agar bisa divisualisasikan mentahnya
		var base_detail := _dice_roller.roll_detailed(base_dice)
		dmg_rolls = base_detail["rolls"]

		if crit:
			var extra_detail := _dice_roller.roll_detailed(base_dice)
			for r: int in extra_detail["rolls"]:
				dmg_rolls.append(r)

		# Hitung base total (raw)
		var base_sum := 0
		for r: int in dmg_rolls:
			base_sum += r

		# Kalkulasi total dengan modifier dan multiplier untuk UI saja (teks total akhir)
		var mult := 1.0
		var cond_comp = target.get_node_or_null("ConditionComponent")
		if cond_comp and cond_comp.has_condition("vulnerable"):
			mult += 0.2
		if is_instance_valid(ElementSystem) and ElementSystem.has_method("get_damage_multiplier"):
			var vapor_mult = ElementSystem.get_damage_multiplier(target, element_tag)
			if vapor_mult > 1.0:
				mult += (vapor_mult - 1.0)
				
		dmg_total = 0
		for r: int in dmg_rolls:
			dmg_total += floori(maxi(0, r + dmg_mod) * mult)
			
		if crit:
			print("[COMBAT] CRITICAL HIT! Total Burst Damage = %d" % dmg_total)
		else:
			print("[COMBAT] HIT! Total Burst Damage = %d" % dmg_total)
	else:
		print("[COMBAT] 💨 MISS!")
		# For players, emit immediately (dice overlay handles the reveal)
		# For enemies, defer until after the dice animation
		if not attacker.is_in_group("enemies"):
			EventBus.on_miss.emit(attacker, target)
	var _deferred_miss := not hit and attacker.is_in_group("enemies")
	print("[COMBAT] ────────────────────────────")

	# ── Jalankan animasi overlay (AWAIT — blok sampai selesai) ────────────────
	var is_enemy := attacker.is_in_group("enemies")
	var type_str := "magical" if is_magical else "physical"
	
	# Track apakah sudah ada knockback/status agar tidak dobel
	var _knockback_done := false

	if is_enemy:
		# Enemy: attack animation FIRST, then dice
		if is_instance_valid(attacker) and attacker.has_method("play_attack"):
			await attacker.play_attack(_ability_id)
		# Enemy uses in-world dice popup + stat breakdown!
		await _play_enemy_dice_sequence(attacker, raw, total, thresh, hit_modifier, hit, crit, pid)
		# Now emit the miss signal AFTER the dice has finished
		if _deferred_miss:
			EventBus.on_miss.emit(attacker, target)
	else:
		# Player uses full UI Overlay
		var overlay := _overlay_p1 if pid == 1 else _overlay_p2
		if overlay != null and hit:
			# Biarkan dadu berputar di UI secara mentah (raw), lalu tambahkan modifier visualnya
			await overlay.play_attack_sequence(
				attacker, target, result, dmg_rolls, dmg_total, dmg_formula, dmg_mod
			)
		elif overlay != null:
			# MISS — overlay saja tanpa damage
			await overlay.play_attack_sequence(
				attacker, target, result, dmg_rolls, dmg_total, dmg_formula, 0
			)
		else:
			push_warning("[CombatTestBridge] Overlay P%d null! Fallback damage langsung." % pid)
			await get_tree().process_frame

		# Player: attack animation AFTER dice overlay
		if is_instance_valid(attacker) and attacker.has_method("play_attack"):
			await attacker.play_attack(_ability_id)

	# ---- MAGICAL PROJECTILE PLACEHOLDER ----
	if hit and is_instance_valid(target) and (is_projectile or is_magical):
		await _spawn_magic_projectile(attacker, target, element_tag)

	# ── TEPAT DI IMPACT FRAME: APPLY BURST DAMAGE ─────────────────────────────
	if hit and is_instance_valid(target):
		var mult := 1.0
		var cond_comp = target.get_node_or_null("ConditionComponent")
		if cond_comp and cond_comp.has_condition("vulnerable"):
			mult += 0.2
		if is_instance_valid(ElementSystem) and ElementSystem.has_method("get_damage_multiplier"):
			var vapor_mult = ElementSystem.get_damage_multiplier(target, element_tag)
			if vapor_mult > 1.0:
				mult += (vapor_mult - 1.0)
				
		for i in range(dmg_rolls.size()):
			if not is_instance_valid(target): break
			
			# Kalkulasi final per-dadu persis sebelum diapply
			var r_raw: int = dmg_rolls[i]
			var r_final := floori(maxi(0, r_raw + dmg_mod) * mult)
			
			var applied := _apply_damage_to_target(target, r_final, attacker, type_str)
			
			# Crit visual hanya di hit pertama
			EventBus.damage_dealt.emit(target, applied, type_str, crit and i == 0, attacker)
			
			if ElementSystem != null and element_tag != "physical" and element_tag != "":
				ElementSystem.resolve_elemental_hit(target, element_tag, applied)
				
			# Jeda sangat singkat antar angka agar terkesan "Burst" / "Machine Gun"
			if i < dmg_rolls.size() - 1:
				await get_tree().create_timer(0.08, false).timeout
				
		# Knockback & status effect hanya 1x setelah semua burst selesai
		if is_instance_valid(target) and knockback > 0:
			ForcedMovementResolver.knockback_from_attack(attacker, target, knockback)
		if ability != null and ability.status_effect != "":
			var is_base_element := ability.status_effect in ["fire", "water", "air", "earth"]
			if not is_base_element:
				EventBus.on_status_applied.emit(target, ability.status_effect, ability.status_duration, ability.status_stacks)

	_set_player_busy(pid, false)
	
	# BERITAHU AI BAHWA SERANGAN SELESAI
	if is_enemy:
		EventBus.combat_action_finished.emit()


# ── ENEMY IN-WORLD DICE SEQUENCE ─────────────────────────────────────────────

var _bangers_font = preload("res://assets/ui_assets/Bangers-Regular.ttf")

func _make_world_label(text: String, font_size: int, color: Color, outline_color: Color = Color(0, 0, 0, 0.95), outline_size: int = 6) -> Node2D:
	var wrapper := Node2D.new()
	var l := Label.new()
	l.text = text
	if _bangers_font:
		l.add_theme_font_override("font", _bangers_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline_color)
	l.add_theme_constant_override("outline_size", outline_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Force the label to perfectly center itself on the wrapper Node2D
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	wrapper.add_child(l)
	return wrapper


func _apply_camera_shake(p_id: int, duration: float, amp: float, horizontal_only: bool = false) -> void:
	if not get_tree() or not get_tree().current_scene: return
	var main = get_tree().current_scene
	if main.has_node("SplitScreenManager"):
		var ssm = main.get_node("SplitScreenManager")
		if is_instance_valid(ssm) and ssm.has_method("shake_camera"):
			ssm.shake_camera(p_id, duration, amp, horizontal_only)
	elif main.has_node("World/Camera2D"):
		var cam = main.get_node("World/Camera2D")
		if is_instance_valid(cam) and cam.has_method("shake"):
			cam.shake(duration, amp, horizontal_only)


func _play_enemy_dice_sequence(
	attacker: Node, raw_roll: int, total_roll: int, ac: int,
	modifier: int, is_hit: bool, is_crit: bool, p_id: int
) -> void:
	var base_pos : Vector2 = attacker.global_position + Vector2(0, -180)
	
	# ── Container for all visuals (easy cleanup) ──────────────────────────────
	var container := Node2D.new()
	container.z_index = 4096
	container.global_position = Vector2.ZERO
	# Add to attacker's parent so it lives in world space and shakes WITH the camera!
	if attacker.get_parent():
		attacker.get_parent().add_child(container)
	else:
		get_tree().root.add_child(container)
	
	# ── Phase 1: D20 Dice Roll ────────────────────────────────────────────────
	var dice_scene := load("res://components/dice/sandbox/DiceVisual.tscn") as PackedScene
	if dice_scene == null:
		container.queue_free()
		return
	
	var dice_visual = dice_scene.instantiate()
	dice_visual.z_index = 4096
	container.add_child(dice_visual)
	
	var outcome := "hit"
	if is_crit: outcome = "crit"
	elif not is_hit: outcome = "miss"
	
	if is_instance_valid(dice_visual) and dice_visual.has_method("start_roll"):
		dice_visual.start_roll(raw_roll, "d20enemy", 1.8, base_pos, p_id, outcome, true, Vector2(0.45, 0.45))
		if dice_visual.has_signal("roll_finished"):
			await dice_visual.roll_finished
		else:
			await get_tree().create_timer(1.9).timeout
	
	# Grab actual dice position after it landed
	var dice_landed_pos : Vector2 = dice_visual.global_position
	
	# ── Phase 2: Modifier Absorb (+X flies into the dice) ─────────────────────
	if modifier != 0:
		var mod_text := "+%d" % modifier if modifier > 0 else str(modifier)
		var mod_color := Color(0.75, 0.95, 0.4) if modifier > 0 else Color(1.0, 0.4, 0.4)
		var mod_label := _make_world_label(mod_text, 70, mod_color)
		# Spawn further to the right and higher up
		mod_label.global_position = dice_landed_pos + Vector2(150, -120)
		container.add_child(mod_label)
		mod_label.modulate.a = 0.0
		mod_label.scale = Vector2(1.4, 1.4)
		
		# Pop in
		var tw_mod := create_tween()
		tw_mod.tween_property(mod_label, "modulate:a", 1.0, 0.15)
		tw_mod.parallel().tween_property(mod_label, "scale", Vector2(1.0, 1.0), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_mod.tween_interval(0.3)
		# Fly into the exact center of the dice
		var fly_target = dice_landed_pos
		tw_mod.tween_property(mod_label, "global_position", fly_target, 0.2)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw_mod.tween_property(mod_label, "modulate:a", 0.0, 0.05)
		await tw_mod.finished
		
		# Update dice number to show total
		if dice_visual.has_node("NumberLabel"):
			dice_visual.get_node("NumberLabel").text = str(total_roll)
		# Bounce the dice from the impact
		var absorb_tw := create_tween()
		absorb_tw.tween_property(dice_visual, "scale", dice_visual.scale * 0.85, 0.08)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		absorb_tw.tween_property(dice_visual, "scale", dice_visual.scale, 0.2)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		await absorb_tw.finished
	
	await get_tree().create_timer(0.15).timeout
	
	# ── Phase 3: Violent Clash (No 'vs') ──────────────────────────────────────
	var roll_color := Color(0.3, 1.0, 0.5) if is_hit else Color(1.0, 0.4, 0.4)
	var roll_lbl := _make_world_label(str(total_roll), 70, roll_color)
	roll_lbl.modulate.a = 1.0
	container.add_child(roll_lbl)
	
	var ac_lbl := _make_world_label("AC %d" % ac, 70, Color(0.9, 0.55, 0.2))
	ac_lbl.modulate.a = 1.0
	container.add_child(ac_lbl)
	
	# Determine winner and loser
	var result_text := "MISS!"
	var result_color := Color(0.85, 0.25, 0.25)
	var winner_lbl: Node2D
	var loser_lbl: Node2D
	
	if is_crit:
		result_text = "CRITICAL!"
		result_color = Color(1.0, 0.88, 0.1)
		winner_lbl = roll_lbl
		loser_lbl = ac_lbl
	elif is_hit:
		result_text = "HIT!"
		result_color = Color(0.25, 1.0, 0.45)
		winner_lbl = roll_lbl
		loser_lbl = ac_lbl
	else:
		winner_lbl = ac_lbl
		loser_lbl = roll_lbl
	
	winner_lbl.get_child(0).add_theme_color_override("font_color", result_color)
	
	# Initial positions (far left and right)
	roll_lbl.position = base_pos + Vector2(-300, 40)
	ac_lbl.position = base_pos + Vector2(300, 40)
	
	# Target positions (crash in the middle)
	var center_roll_x := base_pos.x - 30
	var center_ac_x := base_pos.x + 30
	
	# Fade out the dice visual as they slide in
	var tw_fade_dice := create_tween()
	tw_fade_dice.tween_property(dice_visual, "modulate:a", 0.0, 0.15)
	
	# Violent Crash
	var tw_clash := create_tween().set_parallel(true)
	tw_clash.tween_property(roll_lbl, "position:x", center_roll_x, 0.15)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw_clash.tween_property(ac_lbl, "position:x", center_ac_x, 0.15)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw_clash.finished
	
	# Screen shake on impact
	_apply_camera_shake(p_id, 0.1, 4.0, true)
	
	# ── Phase 4: Immediate Fling & Result ─────────────────────────────────────
	
	# Loser gets flung violently upwards and outwards (Physics Arc)
	var fling_dir = -1 if loser_lbl == roll_lbl else 1
	var fling_x = randf_range(250.0, 450.0) * fling_dir
	var fling_y = randf_range(250.0, 350.0)
	var rot_amount = randf_range(3.0, 8.0) * fling_dir
	
	var arc_time = 1.0
	var rise_time = 0.4
	var fall_time = arc_time - rise_time
	
	var tw_lose_x = create_tween().set_parallel(true)
	tw_lose_x.tween_property(loser_lbl, "position:x", fling_x, arc_time)\
		.as_relative().set_trans(Tween.TRANS_LINEAR)
	tw_lose_x.tween_property(loser_lbl, "rotation", rot_amount, arc_time)\
		.as_relative().set_trans(Tween.TRANS_LINEAR)
	# Only start fading near the very end of the arc
	tw_lose_x.tween_property(loser_lbl, "modulate:a", 0.0, 0.3).set_delay(arc_time - 0.3)
	
	var tw_lose_y = create_tween()
	tw_lose_y.tween_property(loser_lbl, "position:y", -fling_y, rise_time)\
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_lose_y.tween_property(loser_lbl, "position:y", fling_y + 200.0, fall_time)\
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Winner scales up into the center and shakes slightly
	var tw_win = create_tween().set_parallel(true)
	tw_win.tween_property(winner_lbl, "position:x", base_pos.x, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_win.tween_property(winner_lbl, "scale", Vector2(1.3, 1.3), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_win.tween_property(winner_lbl, "rotation", 0.15 if is_hit else -0.15, 0.1)
	
	# Result text punches in immediately behind the winner
	var result_lbl := _make_world_label(result_text, 70, result_color)
	result_lbl.position = base_pos + Vector2(0, -60)
	result_lbl.modulate.a = 0.0
	result_lbl.scale = Vector2(0.5, 0.5)
	result_lbl.z_index = -1 # Draw behind the numbers
	container.add_child(result_lbl)
	
	var tw_result := create_tween()
	tw_result.tween_property(result_lbl, "modulate:a", 1.0, 0.1)
	tw_result.parallel().tween_property(result_lbl, "scale", Vector2(1.2, 1.2), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_result.tween_property(result_lbl, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Fade out winner
	tw_result.parallel().tween_property(winner_lbl, "modulate:a", 0.3, 0.3).set_delay(0.4)
	
	await get_tree().create_timer(1.2).timeout
	
	# ── Cleanup ───────────────────────────────────────────────────────────────
	var tw_out := create_tween().set_parallel(true)
	tw_out.tween_property(container, "modulate:a", 0.0, 0.3)
	await tw_out.finished
	container.queue_free()

func _on_combat_input_blocked(player_id: int, blocked: bool) -> void:
	InputManager.set_player_blocked(player_id, blocked)


func _set_player_busy(player_id: int, busy: bool) -> void:
	if player_id == 1:
		_p1_busy = busy
	else:
		_p2_busy = busy
	if InputManager != null:
		InputManager.set_player_blocked(player_id, busy)
	EventBus.combat_input_blocked.emit(player_id, busy)


func _apply_damage_to_target(target: Node, amount: int, attacker: Node, damage_type: String) -> int:
	var stat_system := get_node_or_null("/root/StatSystem")
	if is_instance_valid(stat_system) and stat_system.has_method("apply_damage"):
		return int(stat_system.apply_damage(target, amount, attacker, damage_type))

	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		return health.take_damage(amount, attacker, damage_type)

	if is_instance_valid(target) and target.has_method("take_damage"):
		target.call("take_damage", amount)
		return maxi(0, amount)

	print("[COMBAT] Target tidak punya HealthComponent/take_damage() - damage tidak di-apply")
	return 0


# ── PHASE TRACKING ────────────────────────────────────────────────────────────

func _get_damage_modifier(attacker: Node, is_magical: bool) -> int:
	var stat_system := get_node_or_null("/root/StatSystem")
	if stat_system != null:
		if is_magical and stat_system.has_method("get_magical_damage_modifier"):
			return int(stat_system.get_magical_damage_modifier(attacker))
		if not is_magical and stat_system.has_method("get_physical_damage_modifier"):
			return int(stat_system.get_physical_damage_modifier(attacker))

	var stat_comp = attacker.get_node_or_null("StatsComponent") as StatsComponent
	if stat_comp != null:
		if is_magical and stat_comp.has_method("get_magical_damage_modifier"):
			return int(stat_comp.get_magical_damage_modifier())
		if not is_magical and stat_comp.has_method("get_physical_damage_modifier"):
			return int(stat_comp.get_physical_damage_modifier())
	return 0


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
	# AIComponent automatically listens to EventBus.turn_started and will execute its brain.
	# It will also call TurnManager.request_end_turn() when it's fully done.


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
	print("║  P1: WASD gerak | F serang | X cancel | R end  ║")
	print("║  P2: IJKL gerak | ; serang | , cancel | P end  ║")
	print("║  F2 Dice Sandbox | F5 Status | F6 Item sim   ║")
	print("║  F7 Luck Roll    | F8 Contested Pick         ║")
	print("╚══════════════════════════════════════════════╝")

func _spawn_magic_projectile(attacker: Node, target: Node, element: String) -> void:
	print("[COMBAT] 🌠 Merender efek sihir elemen: %s" % element)
	
	var orb = Polygon2D.new()
	# Gambar lingkaran kecil
	var points = PackedVector2Array()
	var radius = 10.0
	for i in range(16):
		var angle = (i / 16.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	orb.polygon = points
	
	# Warna sesuai elemen
	match element:
		"fire": orb.color = Color.ORANGE_RED
		"water": orb.color = Color.DODGER_BLUE
		"air": orb.color = Color.WHITE_SMOKE
		"earth": orb.color = Color.SADDLE_BROWN
		_: orb.color = Color.MEDIUM_PURPLE
		
	var start_pos = attacker.global_position + Vector2(0, -32) # Angkat sedikit
	var end_pos = target.global_position + Vector2(0, -32)
	
	orb.global_position = start_pos
	add_child(orb)
	
	var tween = create_tween()
	tween.tween_property(orb, "global_position", end_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	orb.queue_free()
