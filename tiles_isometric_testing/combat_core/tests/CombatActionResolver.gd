class_name CombatActionResolver
extends Node

var bridge: Node

func _init(b: Node) -> void:
	bridge = b

func _on_attack(attacker: Node, target: Node, _ability_id: String, target_pos: Vector2i = Vector2i(-1,-1)) -> void:
	if attacker == null:
		return
	if target == null and target_pos.x < 0:
		return

	# Tentukan player_id penyerang
	var _pid_raw: Variant = attacker.get("player_id")
	var pid: int = int(_pid_raw) if _pid_raw != null else 1

	if is_instance_valid(attacker) and attacker.has_method("is_downed") and attacker.is_downed():
		print("[COMBAT] P%d downed, action dibatalkan." % pid)
		return

	var is_magical := false
	var base_dice  := "1D8"
	var _base_ability_id := _ability_id

	# Parse modifier "-M"
	if _base_ability_id.ends_with("-M"):
		is_magical = true
		_base_ability_id = _base_ability_id.substr(0, _base_ability_id.length() - 2)

	# --- Ability Resource Loading ---
	var ability: BaseAbility = null
	var ab_path := "res://combat_core/abilities/instances/%s.tres" % _base_ability_id
	if ResourceLoader.exists(ab_path):
		ability = load(ab_path) as BaseAbility
		
	if ability != null:
		base_dice = ability.damage_dice
		# Overrides cost
		var has_ap := false
		if pid == 1: has_ap = bridge._p1_ap.spend_ap(ability.cost_action)
		elif pid == 2: has_ap = bridge._p2_ap.spend_ap(ability.cost_action)
		if not has_ap:
			bridge._set_player_busy(pid, false)
			print("[COMBAT] ⚠️ P%d — AP Tidak Cukup untuk %s!" % [pid, ability.ability_name])
			return
			
		print("[COMBAT] Menggunakan Ability: %s (%s)" % [ability.ability_name, base_dice])
	else:
		push_warning("[COMBAT] Ability '%s' tidak ditemukan! Fallback ke 1D8." % _ability_id)
		var has_ap := false
		if pid == 1: has_ap = bridge._p1_ap.spend_ap(1)
		elif pid == 2: has_ap = bridge._p2_ap.spend_ap(1)
		if not has_ap:
			bridge._set_player_busy(pid, false)
			print("[COMBAT] ⚠️ P%d — Tidak ada Action Point yang tersisa!" % pid)
			return

	var _aname_raw: Variant = attacker.get("char_name")
	var attacker_name: String = str(_aname_raw) if _aname_raw != null else str(attacker.name)

	var a_pos: Vector2i = attacker.get("grid_pos")
	# --- AOE Multi-Target Logic ---
	var aoe_targets: Array[Node] = []
	if ability != null:
		var t_pos: Vector2i = target_pos
		if t_pos.x < 0:
			t_pos = target.get("grid_pos") if target != null else a_pos
			
		var affected_tiles = ability.get_affected_tiles(a_pos, t_pos)
		for t in affected_tiles:
			var ent = GridManager.get_entity_at(t)
			if ent != null and ent.has_method("get_armor") and ent != attacker:
				var pid_ent = ent.get("player_id")
				if (attacker.is_in_group("enemies") != ent.is_in_group("enemies")) or (pid_ent != null and pid != null and pid_ent != pid):
					if not aoe_targets.has(ent):
						aoe_targets.append(ent)
		
		if aoe_targets.is_empty():
			print("[COMBAT] AOE tidak mengenai siapa-siapa.")
			target = null
		else:
			var highest_ac = -1
			var best_target: Node = null
			for ent in aoe_targets:
				var ac = StatSystem.get_resist(ent) if is_magical else StatSystem.get_armor(ent)
				if ac > highest_ac:
					highest_ac = ac
					best_target = ent
			target = best_target
	else:
		if target != null and target != attacker:
			aoe_targets.append(target)

	var target_name := "Udara Kosong"
	if target != null:
		var _tname_raw: Variant = target.get("enemy_name")
		target_name = str(_tname_raw) if _tname_raw != null else str(target.name)

	print("\n[COMBAT] ────────────────────────────")
	print("[COMBAT] %s → menyerang → %s" % [attacker_name, target_name])

	# ── Resolve Hit/Crit ───────────────────────────────
	var raw := 10
	var total := 10
	var thresh := 10
	var hit := false
	var crit := false
	var hit_modifier := 0

	var hit_result: Dictionary = {
		"hit": true,
		"crit": false,
		"raw_roll": 10,
		"roll": 10,
		"threshold": 10
	}

	if target != null:
		hit_result = bridge._crit_resolver.resolve_with_crit(attacker, target, is_magical)
		raw    = hit_result["raw_roll"]
		total  = hit_result["roll"]
		thresh = hit_result["threshold"]
		hit    = hit_result["hit"]
		crit   = hit_result["crit"]
		hit_modifier = total - raw

	var defense_label := "Resist" if is_magical else "Armor"
	print("[COMBAT] D20: %d (raw) + %d → %d  vs  %s: %d" % [raw, hit_modifier, total, defense_label, thresh])

	# ── Siapkan data damage ────
	var _dmg_formula := base_dice
	var dmg_rolls   : Array = []
	var dmg_total   : int = 0
	
	var dmg_mod := _get_damage_modifier(attacker, is_magical)
	if dmg_mod > 0:
		_dmg_formula += "+%d" % dmg_mod
	elif dmg_mod < 0:
		_dmg_formula += "%d" % dmg_mod

	if hit or (ability != null and ability.aoe_type != "none" and target == null):
		var base_detail: Dictionary = bridge._dice_roller.roll_detailed(base_dice)
		dmg_rolls = base_detail["rolls"]

		if crit:
			var extra_detail: Dictionary = bridge._dice_roller.roll_detailed(base_dice)
			dmg_rolls.append_array(extra_detail["rolls"])
			dmg_total = base_detail["total"] + extra_detail["total"] + dmg_mod
		else:
			dmg_total = base_detail["total"] + dmg_mod
			
		dmg_total = maxi(0, dmg_total)
	else:
		dmg_total = 0

	# ── ANIMASI: Putar karakter ──
	if target != null:
		var t_pos: Vector2i = target.get("grid_pos")
		if attacker.has_method("set_facing"):
			var diff = t_pos - a_pos
			if abs(diff.x) > abs(diff.y):
				if diff.x > 0: attacker.set_facing(Vector2.RIGHT)
				else: attacker.set_facing(Vector2.LEFT)
			else:
				if diff.y > 0: attacker.set_facing(Vector2.DOWN)
				else: attacker.set_facing(Vector2.UP)
	elif target_pos.x >= 0:
		if attacker.has_method("set_facing"):
			var diff = target_pos - a_pos
			if abs(diff.x) > abs(diff.y):
				if diff.x > 0: attacker.set_facing(Vector2.RIGHT)
				else: attacker.set_facing(Vector2.LEFT)
			else:
				if diff.y > 0: attacker.set_facing(Vector2.DOWN)
				else: attacker.set_facing(Vector2.UP)

	# ── Mainkan Animasi Caster & UI ──
	bridge._set_player_busy(pid, true)
	if target != null and attacker.is_in_group("enemies"):
		await bridge.vfx_controller._play_enemy_dice_sequence(attacker, raw, total, thresh, hit_modifier, hit, crit, pid)

	var is_player = attacker.is_in_group("players")
	if is_player:
		var overlay = bridge._overlay_p1 if pid == 1 else bridge._overlay_p2
		if overlay != null:
			if target != null:
				await overlay.play_attack_sequence(attacker, target, hit_result, dmg_rolls, dmg_total, _dmg_formula, dmg_mod)
			else:
				await overlay.play_attack_sequence(attacker, attacker, hit_result, dmg_rolls, dmg_total, _dmg_formula, dmg_mod)
				
		var char_sprite = attacker.get_node_or_null("CharacterSprite")
		if char_sprite and char_sprite.has_method("play_attack"):
			if ability == null or not ability.is_projectile:
				if hit or (ability != null and ability.aoe_type != "none"):
					var is_dash = false
					if ability != null and ability.has_method("get_dash_destination"):
						var dash_dest = ability.get_dash_destination(attacker, target)
						if dash_dest.x >= 0:
							is_dash = true
					char_sprite.play_attack(is_dash)
					await char_sprite.attack_finished

	if ability != null and ability.is_projectile:
		if is_player:
			var char_sprite = attacker.get_node_or_null("CharacterSprite")
			if char_sprite and char_sprite.has_method("play_attack"):
				char_sprite.play_attack(false)
				await get_tree().create_timer(0.2).timeout
		if target != null:
			await bridge.vfx_controller._spawn_magic_projectile(attacker, target, ability.element_tag)

	if hit or (ability != null and ability.aoe_type != "none" and not aoe_targets.is_empty()):
		for t in aoe_targets:
			var real_dmg = dmg_total
			if not hit and ability != null and ability.aoe_type != "none":
				real_dmg = maxi(1, floori(dmg_total / 2.0))
			
			var applied = _apply_damage_to_target(t, real_dmg, attacker, "magical" if is_magical else "physical")
			print("[COMBAT] %s menerima %d damage! (Total DMG)" % [t.name, applied])
			
			if is_instance_valid(t) and t.has_method("play_hurt"):
				t.play_hurt()
			
			var element_tag = "physical"
			if ability != null:
				element_tag = ability.element_tag
			if is_magical and ability == null:
				element_tag = "arcane"
				
			if ElementSystem != null:
				ElementSystem.resolve_elemental_hit(t, element_tag, applied)
				
			var kb_tiles = 0
			if ability != null:
				kb_tiles = ability.knockback_tiles
			if kb_tiles > 0:
				var _t_pos = t.get("grid_pos")
				var diff = _t_pos - a_pos
				var dir = Vector2i.RIGHT
				if abs(diff.x) > abs(diff.y): dir = Vector2i(sign(diff.x), 0)
				else: dir = Vector2i(0, sign(diff.y))
				
				ForcedMovementResolver.knockback_entity(t, kb_tiles, dir, attacker)
	else:
		print("[COMBAT] Serangan meleset!")

	if is_player:
		EventBus.attackcam_finished.emit(attacker)
	else:
		EventBus.combat_action_finished.emit(attacker)

	bridge._set_player_busy(pid, false)


func _apply_damage_to_target(target: Node, amount: int, attacker: Node, damage_type: String) -> int:
	var applied := 0
	if StatSystem != null:
		applied = StatSystem.apply_damage(target, amount, attacker, damage_type)
	else:
		if target.has_method("take_damage"):
			applied = target.take_damage(amount, attacker, damage_type)
	
	if applied > 0:
		var lbl = bridge.vfx_controller._make_world_label(str(applied), 40, Color.RED)
		lbl.global_position = target.global_position + Vector2(0, -60)
		bridge.vfx_controller.add_child(lbl)
	
	EventBus.damage_dealt.emit(target, applied, damage_type, false, null)
	return applied


func _get_damage_modifier(attacker: Node, is_magical: bool) -> int:
	if StatSystem != null:
		if is_magical: return StatSystem.get_magical_damage_modifier(attacker)
		else: return StatSystem.get_physical_damage_modifier(attacker)
	return 0
