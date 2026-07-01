class_name CombatActionResolver
extends Node

var bridge: Node

func _init(b: Node) -> void:
	bridge = b

func _on_attack(attacker: Node, target: Node, _ability_id: String, target_pos: Vector2i = Vector2i(-1, -1)) -> void:
	var primary_target: Node = target
	if attacker == null:
		return
	if target == null and target_pos.x < 0:
		if not attacker.is_in_group("players"):
			EventBus.combat_action_finished.emit(attacker)
		return

	# Tentukan player_id penyerang
	var _pid_raw: Variant = attacker.get("player_id")
	var pid: int = int(_pid_raw) if _pid_raw != null else 1

	var is_player = attacker.is_in_group("players")

	if is_instance_valid(attacker) and attacker.has_method("is_downed") and attacker.is_downed():
		print("[COMBAT] P%d downed, action dibatalkan." % pid)
		if not is_player:
			EventBus.combat_action_finished.emit(attacker)
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
		if is_player:
			var ap_mgr = bridge._p1_ap if pid == 1 else bridge._p2_ap
			var mana_mgr = bridge._p1_ec if pid == 1 else bridge._p2_ss
			
			# Validasi cukup tidaknya cost
			var can_afford = true
			if not ap_mgr.can_spend_ap(ability.cost_action): can_afford = false
			if not ap_mgr.can_spend_bap(ability.cost_bonus_action): can_afford = false
			if ability.cost_mana > 0:
				if pid == 1 and not (mana_mgr as EnergyChargeManager).can_spend(ability.cost_mana): can_afford = false
				elif pid == 2 and not (mana_mgr as SpellSlotManager).can_spend(1, ability.cost_mana): can_afford = false
				
			if not can_afford:
				bridge._set_player_busy(pid, false)
				print("[COMBAT] ⚠️ P%d — Tidak cukup AP/BAP/Mana untuk %s!" % [pid, ability.ability_name])
				return
				
			# Jika cukup, baru kita spend semuanya
			ap_mgr.spend_ap(ability.cost_action)
			ap_mgr.spend_bap(ability.cost_bonus_action)
			if ability.cost_mana > 0:
				if pid == 1: (mana_mgr as EnergyChargeManager).spend_charge(ability.cost_mana)
				elif pid == 2: (mana_mgr as SpellSlotManager).spend_slot(1, ability.cost_mana)
			
		print("[COMBAT] Menggunakan Ability: %s (%s)" % [ability.ability_name, base_dice])
	else:
		push_warning("[COMBAT] Ability '%s' tidak ditemukan! Fallback ke 1D8." % _ability_id)
		if is_player:
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
	if ability != null and ability.get("aoe_type") != null and ability.aoe_type != "none":
		var t_pos: Vector2i = target_pos
		if t_pos.x < 0:
			t_pos = target.get("grid_pos") if target != null else a_pos
			
		var affected_tiles = ability.get_affected_tiles(a_pos, t_pos)
		for t in affected_tiles:
			var ent = GridManager.get_entity_at(t)
			if ent != null and ent.has_method("get_armor"):
				var pid_ent = ent.get("player_id")
				var is_enemy = (attacker.is_in_group("enemies") != ent.is_in_group("enemies")) or (pid_ent != null and pid != null and pid_ent != pid)
				var is_valid_target = false
				
				if ability.target_alignment == 3: # ANY
					is_valid_target = true
				elif ability.target_alignment == 1: # ALLY_ONLY
					is_valid_target = not is_enemy
				elif ability.target_alignment == 2: # SELF_ONLY
					is_valid_target = (ent == attacker)
				else: # ENEMY_ONLY (0)
					is_valid_target = is_enemy and ent != attacker
					
				if is_valid_target:
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

	# ── Intercept untuk Position Switch Utility ──
	var is_pos_switch = ability != null and ("is_position_switch" in ability) and ability.is_position_switch
	if is_pos_switch:
		if target != null and is_instance_valid(GridManager):
			bridge._set_player_busy(pid, true)
			if is_instance_valid(attacker) and attacker.has_method("play_attack"):
				attacker.play_attack(_base_ability_id)
				await get_tree().create_timer(0.2).timeout
				
			var a_grid = attacker.get("grid_pos")
			var t_grid = target.get("grid_pos")
			
			if GridManager.swap_entities(a_grid, t_grid):
				attacker.set("grid_pos", t_grid)
				target.set("grid_pos", a_grid)
				
				# IsoUtils is an autoload or utility. We might need to ensure it's available.
				# Assuming IsoUtils is a global singleton since it's used elsewhere.
				var a_px = IsoUtils.world_to_iso(t_grid)
				var t_px = IsoUtils.world_to_iso(a_grid)
				
				attacker.z_index = IsoUtils.get_depth(t_grid)
				target.z_index = IsoUtils.get_depth(a_grid)
				
				# Play sweeping teleport tween
				var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(attacker, "position", a_px, 0.5)
				tw.tween_property(target, "position", t_px, 0.5)
				
				# Add a small hop effect
				var hop_a = attacker.position.y - 40
				var hop_t = target.position.y - 40
				tw.tween_property(attacker, "position:y", hop_a, 0.25).set_ease(Tween.EASE_OUT)
				tw.tween_property(target, "position:y", hop_t, 0.25).set_ease(Tween.EASE_OUT)
				
				await tw.finished
				
				EventBus.player_moved.emit(attacker, a_grid, t_grid)
				EventBus.player_moved.emit(target, t_grid, a_grid)
			else:
				print("[COMBAT] Gagal menukar posisi di GridManager!")
				
			if attacker.is_in_group("players"):
				EventBus.attackcam_finished.emit(attacker)
			else:
				EventBus.combat_action_finished.emit(attacker)
			bridge._set_player_busy(pid, false)
		else:
			print("[COMBAT] Target missed atau invalid untuk Position Switch.")
			if attacker.is_in_group("players"):
				EventBus.attackcam_finished.emit(attacker)
			else:
				EventBus.combat_action_finished.emit(attacker)
			bridge._set_player_busy(pid, false)
		return


	# ── Siapkan data damage ────
	var _dmg_formula := base_dice
	var dmg_rolls   : Array = []
	var crit_rolls  : Array = []
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
			crit_rolls = extra_detail["rolls"]
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
	
	var _played_attack := false
	var _knockback_done := [false]
	is_player = attacker.is_in_group("players")
	
	# Function to handle dash movement
	var execute_dash = func():
		if hit and ability != null and ability.has_method("get_dash_destination"):
			var dash_dest: Vector2i = ability.get_dash_destination(attacker, target)
			if dash_dest.x >= 0:
				var old_pos: Vector2i = attacker.get("grid_pos")
				if old_pos != dash_dest:
					var t_pos: Vector2i = target.get("grid_pos") if target != null else Vector2i(-1, -1)
					# Knockback FIRST to clear the tile if we are dashing into them
					if dash_dest == t_pos and ability.knockback_tiles > 0 and not _knockback_done[0]:
						ForcedMovementResolver.knockback_from_attack(attacker, target, ability.knockback_tiles)
						_knockback_done[0] = true
					# Single fast blitz dash to destination
					if is_instance_valid(GridManager) and GridManager.move_entity(old_pos, dash_dest, attacker):
						attacker.set("grid_pos", dash_dest)
						var end_px = IsoUtils.world_to_iso(dash_dest)
						attacker.z_index = IsoUtils.get_depth(dash_dest)
						var dash_tw = attacker.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
						dash_tw.tween_property(attacker, "position", end_px, 0.15)
						await dash_tw.finished
						EventBus.player_moved.emit(attacker, old_pos, dash_dest)
	
	if not is_player and target != null:
		# ENEMY: Attack first, dash, then dice
		if is_instance_valid(attacker) and attacker.has_method("play_attack"):
			attacker.play_attack(_base_ability_id)
			_played_attack = true
			await get_tree().create_timer(0.6, false).timeout
		
		await execute_dash.call()
		var safe_pid = pid if pid != null else -1
		await bridge.vfx_controller._play_enemy_dice_sequence(attacker, raw, total, thresh, hit_modifier, hit, crit, safe_pid)

	var _has_overlay = false
	if is_player:
		# PLAYER: Dice overlay first
		var overlay = bridge._overlay_p1 if pid == 1 else bridge._overlay_p2
		if overlay != null:
			_has_overlay = true
			var visual_rolls = dmg_rolls.duplicate()
			if crit and crit_rolls.size() > 0:
				visual_rolls.append_array(crit_rolls)
			
			if target != null:
				await overlay.play_attack_sequence(attacker, target, hit_result, visual_rolls, dmg_total, _dmg_formula, dmg_mod)
			else:
				await overlay.play_attack_sequence(attacker, attacker, hit_result, visual_rolls, dmg_total, _dmg_formula, dmg_mod)
		
		# Then Attack & Dash
		if hit:
			if not _played_attack and is_instance_valid(attacker) and attacker.has_method("play_attack"):
				attacker.play_attack(_base_ability_id)
				_played_attack = true
				await get_tree().create_timer(0.6, false).timeout
			
		await execute_dash.call()

	# Projectile VFX
	if hit and ability != null and ability.is_projectile:
		if not _played_attack and is_instance_valid(attacker) and attacker.has_method("play_attack"):
			attacker.play_attack(_base_ability_id)
			await get_tree().create_timer(0.2).timeout
		if target != null:
			var is_burst_check = ability.get("is_burst_attack") if "is_burst_attack" in ability else false
			if is_burst_check:
				bridge.vfx_controller._spawn_magic_projectile(attacker, target, ability.element_tag, aoe_targets)
				await get_tree().create_timer(0.15, false).timeout
			else:
				await bridge.vfx_controller._spawn_magic_projectile(attacker, target, ability.element_tag)

	var _had_kill := false

	if hit or (ability != null and ability.aoe_type != "none" and not aoe_targets.is_empty()):
		await _impact_freeze(0.1 if not crit else 0.18)
		ScreenEffects.impact_flash(Color(1, 0.9, 0.7, 1), 0.7, 0.3)
		var affected_pids = []
		var affected_enemies = []
		for t in aoe_targets:
			if t.is_in_group("players"):
				var target_pid = t.get("player_id")
				if target_pid != null:
					affected_pids.append(target_pid)
			else:
				affected_enemies.append(t)
				
		_shake_cameras(8.0 if not crit else 15.0, affected_pids)
		
		# Shake non-players
		for e in affected_enemies:
			if is_instance_valid(e):
				var tw = create_tween()
				var o_x = e.position.x
				tw.tween_property(e, "position:x", o_x - 6, 0.04)
				tw.tween_property(e, "position:x", o_x + 6, 0.04)
				tw.tween_property(e, "position:x", o_x - 3, 0.04)
				tw.tween_property(e, "position:x", o_x, 0.04)
				
		_hit_label(attacker, bool(crit))

		for t in aoe_targets:
			var is_heal = false
			if ability != null:
				is_heal = ability.is_heal

			if is_heal:
				var _real_heal = dmg_total
				if not hit and ability != null and ability.aoe_type != "none":
					_real_heal = maxi(1, floori(dmg_total / 2.0))
		var is_burst = ability != null and ("is_burst_attack" in ability) and ability.is_burst_attack
		var loop_count = 1
		if is_burst:
			var split_dice = ability.damage_dice.to_lower().split("d")
			if split_dice.size() > 0:
				loop_count = int(split_dice[0])
				
		var fractional_mod = floori(float(dmg_mod) / float(loop_count)) if is_burst and loop_count > 0 else 0
			
		for burst_idx in range(loop_count):
			var current_roll_dmg = dmg_total
			var real_dmg = current_roll_dmg
			if is_burst:
				current_roll_dmg = dmg_rolls[burst_idx] + fractional_mod
				if crit and burst_idx < crit_rolls.size():
					current_roll_dmg += crit_rolls[burst_idx]
					
			current_roll_dmg = maxi(0, current_roll_dmg)
			var kb_tiles := 0
			var dir := Vector2i.ZERO
			
			if is_burst and burst_idx > 0:
				for i in range(aoe_targets.size() - 1, -1, -1):
					var t = aoe_targets[i]
					if not is_instance_valid(t) or t.is_queued_for_deletion() or (t.has_method("is_dead") and t.is_dead()):
						aoe_targets.remove_at(i)
				
				if aoe_targets.is_empty():
					var can_retarget = ("burst_retarget" in ability) and ability.burst_retarget
					if can_retarget:
						var best_target: Node = null
						var min_dist = 9999
						var search_pos = target_pos if target_pos.x >= 0 else a_pos
						var all_entities = attacker.get_tree().get_nodes_in_group("enemies") if is_player else attacker.get_tree().get_nodes_in_group("players")
						for ent in all_entities:
							if is_instance_valid(ent) and not ent.is_queued_for_deletion() and not (ent.has_method("is_dead") and ent.is_dead()):
								var e_pos = ent.get("grid_pos")
								if e_pos != null:
									var dist = abs(e_pos.x - search_pos.x) + abs(e_pos.y - search_pos.y)
									if dist < min_dist:
										min_dist = dist
										best_target = ent
						if best_target != null:
							aoe_targets.append(best_target)
							target_pos = best_target.get("grid_pos")
							target = best_target
							print("[COMBAT] Burst retargeting to %s!" % best_target.name)
					
					if aoe_targets.is_empty():
						print("[COMBAT] No more valid targets for burst. Stopping.")
						break
				
				if ability.is_projectile and target != null:
					bridge.vfx_controller._spawn_magic_projectile(attacker, target, ability.element_tag, aoe_targets)
				await attacker.get_tree().create_timer(0.15, false).timeout

			for t in aoe_targets:
				var is_heal = false
				if ability != null:
					is_heal = ability.is_heal

				if is_heal:
					var real_heal = current_roll_dmg
					if not hit and ability != null and ability.aoe_type != "none":
						real_heal = maxi(1, floori(current_roll_dmg / 2.0))
					
					# Halve heal amount for enemies
					var pid_ent = t.get("player_id")
					var attacker_pid = attacker.get("player_id")
					var is_enemy = (attacker.is_in_group("enemies") != t.is_in_group("enemies")) or (pid_ent != null and attacker_pid != null and pid_ent != attacker_pid)
					if is_enemy:
						real_heal = maxi(1, floori(real_heal / 2.0))
						
					var applied = _apply_heal_to_target(t, real_heal, attacker)
					print("[COMBAT] %s heal sebesar %d HP!" % [t.name, applied])
				else:
					var skip_damage = false
					if ability != null and ("damage_primary_only" in ability) and ability.damage_primary_only:
						if t != primary_target:
							skip_damage = true
							print("[COMBAT] %s takes no damage (damage_primary_only) but receives secondary effects." % t.name)
					
					if not skip_damage:
						real_dmg = current_roll_dmg
						if not hit and ability != null and ability.aoe_type != "none":
							real_dmg = maxi(1, floori(current_roll_dmg / 2.0))
						
						var cond = StatSystem.get_condition_component(t) if StatSystem != null else t.get_node_or_null("ConditionComponent")
						if is_instance_valid(cond) and cond.has_method("has_condition") and cond.has_condition("vulnerable") and not is_magical:
							real_dmg = maxi(1, floori(real_dmg * 1.5))
							print("[COMBAT] %s is VULNERABLE! Damage increased to %d" % [t.name, real_dmg])
						
						var applied = _apply_damage_to_target(t, real_dmg, attacker, "magical" if is_magical else "physical")
						
						var element_str = "magical" if is_magical else "physical"
						if is_burst:
							EventBus.damage_dealt.emit(t, real_dmg, element_str, bool(crit), attacker)
						else:
							for i in range(dmg_rolls.size()):
								var final_val = dmg_rolls[i] + dmg_mod if (i == 0) else dmg_rolls[i]
								EventBus.damage_dealt.emit(t, final_val, element_str, false, attacker)
							if crit and crit_rolls.size() > 0:
								for i in range(crit_rolls.size()):
									EventBus.damage_dealt.emit(t, crit_rolls[i], element_str, true, attacker)
						
						if is_burst:
							print("[COMBAT] Burst %d: %s menerima %d damage!" % [burst_idx + 1, t.name, applied])
						else:
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
					
				if hit and burst_idx == loop_count - 1:
					kb_tiles = 0
					if ability != null:
						kb_tiles = ability.knockback_tiles
						if ability.status_effect != "":
							var effect_to_apply = ability.status_effect
							if effect_to_apply == "random":
								var random_effects = ["weakened", "vulnerable", "bleeding", "stunned", "frozen", "lacerate"]
								effect_to_apply = random_effects.pick_random()
							EventBus.on_status_applied.emit(t, effect_to_apply, ability.status_duration, ability.status_stacks)
					
					if kb_tiles != 0 and not _knockback_done[0]:
						var _t_pos = t.get("grid_pos")
						var diff = _t_pos - a_pos
						dir = Vector2i.RIGHT
						if abs(diff.x) > abs(diff.y): dir = Vector2i(sign(diff.x), 0)
						else: dir = Vector2i(0, sign(diff.y))
						
						if kb_tiles < 0:
							dir = -dir
							
						ForcedMovementResolver.knockback_entity(t, abs(kb_tiles), dir, attacker)
	else:
		print("[COMBAT] Serangan meleset!")

	if hit and ability != null and ("summon_blockade_front" in ability) and ability.summon_blockade_front and primary_target != null:
		var t_pos: Vector2i = primary_target.get("grid_pos")
		var diff = t_pos - a_pos
		var dir = Vector2i.ZERO
		if abs(diff.x) > abs(diff.y): dir = Vector2i(sign(diff.x), 0)
		elif diff.y != 0: dir = Vector2i(0, sign(diff.y))
		if dir == Vector2i.ZERO: dir = Vector2i(1, 0)
		
		var spawn_pos = t_pos - dir
		if spawn_pos != a_pos and is_instance_valid(GridManager) and GridManager.is_walkable(spawn_pos):
			print("[COMBAT] Summoning Blockade at %s" % spawn_pos)
			var blockade_scene = load("res://entities/props/Blockade.tscn")
			if blockade_scene:
				var world = attacker.get_parent()
				if world and world.has_method("spawn_entity"):
					world.spawn_entity(blockade_scene, spawn_pos)
				else:
					var blockade = blockade_scene.instantiate()
					blockade.set("grid_pos", spawn_pos)
					blockade.position = IsoUtils.world_to_iso(spawn_pos)
					blockade.z_index = IsoUtils.get_depth(spawn_pos)
					if world: world.add_child(blockade)

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
	
	return applied


func _apply_heal_to_target(target: Node, amount: int, source: Node) -> int:
	var applied := 0
	if StatSystem != null and StatSystem.has_method("apply_heal"):
		applied = StatSystem.apply_heal(target, amount, source)
	else:
		if target.has_method("add_hp"):
			applied = target.add_hp(amount, source)
	
	if applied > 0:
		EventBus.floating_text_requested.emit(target, str(applied), Color.GREEN, "heal")
	
	return applied


func _get_damage_modifier(attacker: Node, is_magical: bool) -> int:
	if StatSystem != null:
		if is_magical: return StatSystem.get_magical_damage_modifier(attacker)
		else: return StatSystem.get_physical_damage_modifier(attacker)
	return 0


func _impact_freeze(duration: float = 0.05) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, false, false, true).timeout
	Engine.time_scale = 1.0


func _shake_cameras(power: float = 3.0, affected_pids: Array = []) -> void:
	if affected_pids.is_empty():
		return
	for c in get_tree().get_nodes_in_group("cameras"):
		if c.has_method("shake"):
			var cid = c.get("player_id")
			if cid != null and not affected_pids.has(cid):
				continue
			c.shake(power * 0.08, 0.2)


func _slow_mo_kill() -> void:
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.3, false, false, true).timeout
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v): Engine.time_scale = v, 0.15, 1.0, 0.6)
	await tw.finished


func _hit_label(attacker: Node, is_crit: bool) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(bridge.vfx_controller):
		return
	var label = Label.new()
	label.text = "CRIT!" if is_crit else "HIT!"
	label.add_theme_color_override("font_color", Color(1, 0.8, 0) if is_crit else Color(1, 0.3, 0.3))
	label.add_theme_font_size_override("font_size", 48 if is_crit else 32)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	bridge.vfx_controller.add_child(label)
	label.global_position = attacker.global_position + Vector2(0, -100)
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "global_position:y", label.global_position.y - 60, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	await tw.finished
	if is_instance_valid(label):
		label.queue_free()
