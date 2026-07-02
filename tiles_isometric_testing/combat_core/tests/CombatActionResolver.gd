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
				if attacker.has_method("face_target") and target != null:
					attacker.face_target(target.get("grid_pos"))
				attacker.play_attack(_base_ability_id)
				var am_s = get_node_or_null("/root/AudioManager")
				if am_s != null:
					am_s.play_sfx("sword_slice" if ability == null or ability.ability_type == 0 else "spell_impact")
				bridge.vfx_controller._play_skill_cast_vfx(attacker, _base_ability_id, ability.ability_type if ability != null else 0, ability.element_tag if ability != null else "physical")
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
	if ItemEffectApplier != null and ItemEffectApplier.has_method("get_combat_damage_modifier"):
		var extra_mod = ItemEffectApplier.get_combat_damage_modifier(attacker, target, is_magical)
		dmg_mod += extra_mod
		
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
	var all_targets = []
	if target != null: all_targets.append(target)
	all_targets.append_array(aoe_targets)
	var active_pid = pid if pid != null else -1
	_apply_viewport_focus(active_pid, attacker, all_targets)

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
						var kb_power = ability.knockback_tiles
						if InventoryManager != null and InventoryManager.has_item_node(attacker, "big_hand"):
							kb_power += 1
						ForcedMovementResolver.knockback_from_attack(attacker, target, kb_power)
						_knockback_done[0] = true
					# Single fast blitz dash to destination
					if is_instance_valid(GridManager) and GridManager.move_entity(old_pos, dash_dest, attacker):
						attacker.set("grid_pos", dash_dest)
						var end_px = IsoUtils.world_to_iso(dash_dest)
						var dash_tw = attacker.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
						dash_tw.tween_property(attacker, "position", end_px, 0.15)
						await dash_tw.finished
						EventBus.player_moved.emit(attacker, old_pos, dash_dest)
	
	if not is_player and target != null:
		# ENEMY: Dice first, then attack & dash
		var safe_pid = pid if pid != null else -1
		await bridge.vfx_controller._play_enemy_dice_sequence(attacker, raw, total, thresh, hit_modifier, hit, crit, safe_pid)
		
		if hit:
			if is_instance_valid(attacker) and attacker.has_method("play_attack"):
				if attacker.has_method("face_target") and target != null:
					attacker.face_target(target.get("grid_pos"))
				attacker.play_attack(_base_ability_id)
				var am_e = get_node_or_null("/root/AudioManager")
				if am_e != null:
					am_e.play_sfx("sword_slice" if ability == null or ability.ability_type == 0 else "spell_impact")
				bridge.vfx_controller._play_skill_cast_vfx(attacker, _base_ability_id, ability.ability_type if ability != null else 0, ability.element_tag if ability != null else "physical")
				_played_attack = true
				await get_tree().create_timer(0.6, false).timeout
		
		await execute_dash.call()

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
				if attacker.has_method("face_target") and target != null:
					attacker.face_target(target.get("grid_pos"))
				attacker.play_attack(_base_ability_id)
				var am_p = get_node_or_null("/root/AudioManager")
				if am_p != null:
					am_p.play_sfx("sword_slice" if ability == null or ability.ability_type == 0 else "spell_impact")
				bridge.vfx_controller._play_skill_cast_vfx(attacker, _base_ability_id, ability.ability_type if ability != null else 0, ability.element_tag if ability != null else "physical")
				_played_attack = true
				await get_tree().create_timer(0.6, false).timeout
			
		await execute_dash.call()

	# Projectile VFX
	if hit and ability != null and ability.is_projectile:
		if not _played_attack and is_instance_valid(attacker) and attacker.has_method("play_attack"):
			if attacker.has_method("face_target") and target != null:
				attacker.face_target(target.get("grid_pos"))
			attacker.play_attack(_base_ability_id)
			var am_pr = get_node_or_null("/root/AudioManager")
			if am_pr != null:
				am_pr.play_sfx("sword_slice" if ability.ability_type == 0 else "spell_impact")
			bridge.vfx_controller._play_skill_cast_vfx(attacker, _base_ability_id, ability.ability_type, ability.element_tag)
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
		
		# HUGE SCREEN SHAKE
		_shake_cameras(15.0 if not crit else 20.0, affected_pids)
		
		# Shake non-players violently
		for e in affected_enemies:
			if is_instance_valid(e):
				var tw = create_tween()
				var o_x = e.position.x
				var o_y = e.position.y
				tw.tween_property(e, "position:x", o_x - 12, 0.03)
				tw.parallel().tween_property(e, "position:y", o_y - 4, 0.03)
				tw.tween_property(e, "position:x", o_x + 12, 0.03)
				tw.parallel().tween_property(e, "position:y", o_y + 4, 0.03)
				tw.tween_property(e, "position:x", o_x - 6, 0.03)
				tw.tween_property(e, "position:y", o_y, 0.03)
				tw.tween_property(e, "position:x", o_x, 0.03)
		
		# Direct impact SFX (not relying only on EventBus)
		var am = get_node_or_null("/root/AudioManager")
		if am != null:
			var impact_sfx = "impact_heavy_%d" % (randi() % 3 + 1)
			if crit and ability != null and ability.ability_type == 1:
				impact_sfx = "explosion_impact"
			elif ability != null and ability.is_projectile:
				impact_sfx = "spell_impact" if ability.ability_type == 1 else "sword_slice"
			am.play_sfx(impact_sfx)
				
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
		
		# --- Phase 1: Pre-calculate Targets and Spawns ---
		var burst_plans = []
		var sim_hp = {}
		
		if is_burst:
			var current_aoe_targets = aoe_targets.duplicate()
			for burst_idx in range(loop_count):
				if burst_idx > 0:
					for i in range(current_aoe_targets.size() - 1, -1, -1):
						var t = current_aoe_targets[i]
						if not is_instance_valid(t) or t.is_queued_for_deletion() or (t.has_method("is_dead") and t.is_dead()):
							current_aoe_targets.remove_at(i)
						elif sim_hp.has(t) and sim_hp[t] <= 0:
							current_aoe_targets.remove_at(i)
					
					if current_aoe_targets.is_empty():
						var can_retarget = ("burst_retarget" in ability) and ability.burst_retarget
						if can_retarget:
							var best_target: Node = null
							var min_dist = 9999
							var search_pos = target_pos if target_pos.x >= 0 else a_pos
							var all_entities = attacker.get_tree().get_nodes_in_group("enemies") if is_player else attacker.get_tree().get_nodes_in_group("players")
							for ent in all_entities:
								if is_instance_valid(ent) and not ent.is_queued_for_deletion() and not (ent.has_method("is_dead") and ent.is_dead()):
									if not sim_hp.has(ent) or sim_hp[ent] > 0:
										var e_pos = ent.get("grid_pos")
										if e_pos != null:
											var dist = abs(e_pos.x - search_pos.x) + abs(e_pos.y - search_pos.y)
											if dist < min_dist:
												min_dist = dist
												best_target = ent
							if best_target != null:
								current_aoe_targets.append(best_target)
				
				if current_aoe_targets.is_empty():
					break
					
				var plan = {
					"targets": current_aoe_targets.duplicate(),
					"dmg": dmg_rolls[burst_idx] + fractional_mod if hit else 0,
					"crit_dmg": crit_rolls[burst_idx] if crit and burst_idx < crit_rolls.size() else 0
				}
				burst_plans.append(plan)
				
				# Update sim_hp
				if hit:
					for t in current_aoe_targets:
						if not sim_hp.has(t):
							var h = t.get_node_or_null("HealthComponent")
							var ss = t.get_node_or_null("/root/StatSystem")
							if is_instance_valid(ss) and ss.has_method("get_current_hp"):
								sim_hp[t] = ss.get_current_hp(t)
							elif is_instance_valid(h) and h.has_method("get_hp"):
								sim_hp[t] = h.get_hp()
							else:
								sim_hp[t] = 9999
						
						var total_dmg = plan["dmg"] + plan["crit_dmg"]
						if ability != null and not ability.is_heal:
							var cond = StatSystem.get_condition_component(t) if StatSystem != null else t.get_node_or_null("ConditionComponent")
							if is_instance_valid(cond) and cond.has_method("has_condition") and cond.has_condition("vulnerable") and not is_magical:
								total_dmg = maxi(1, floori(total_dmg * 1.5))
							sim_hp[t] -= total_dmg
		else:
			# Not burst
			burst_plans.append({
				"targets": aoe_targets.duplicate(),
				"dmg": dmg_total,
				"crit_dmg": 0
			})

		var hover_projectiles: Array = []
		if ability != null and ability.is_projectile and is_burst:
			if not _played_attack and is_instance_valid(attacker) and attacker.has_method("play_attack"):
				attacker.play_attack(_base_ability_id)
				_played_attack = true
				
			var hover_targets = []
			for p in burst_plans:
				if p["targets"].size() > 0: hover_targets.append(p["targets"][0])
				else: hover_targets.append(null)
				
			hover_projectiles = bridge.vfx_controller._spawn_hover_burst(attacker, hover_targets, ability.element_tag)
			await get_tree().create_timer(0.4, false).timeout
			
		# --- Phase 2: Execution Loop ---
		for burst_idx in range(burst_plans.size()):
			var plan = burst_plans[burst_idx]
			var current_aoe_targets = plan["targets"]
			var current_roll_dmg = plan["dmg"] + plan["crit_dmg"]
			current_roll_dmg = maxi(0, current_roll_dmg)
			
			if current_aoe_targets.is_empty():
				continue
				
			var p_target = current_aoe_targets[0]
			var active_proj = null
			
			if ability != null and ability.is_projectile and p_target != null:
				if is_burst and burst_idx < hover_projectiles.size():
					active_proj = hover_projectiles[burst_idx]
					if is_instance_valid(active_proj):
						active_proj.launch_at(p_target)
				else:
					bridge.vfx_controller._spawn_magic_projectile(attacker, p_target, ability.element_tag, current_aoe_targets)
			
			var is_last = (burst_idx == burst_plans.size() - 1)
			
			var on_impact = func():
				# Apply effects to targets
				for t in current_aoe_targets:
					var is_heal = false
					if ability != null: is_heal = ability.is_heal

					if is_heal:
						var real_heal = current_roll_dmg
						if not hit and ability != null and ability.aoe_type != "none":
							real_heal = maxi(1, floori(current_roll_dmg / 2.0))
						
						var pid_ent = t.get("player_id")
						var attacker_pid = attacker.get("player_id")
						var is_enemy = (attacker.is_in_group("enemies") != t.is_in_group("enemies")) or (pid_ent != null and attacker_pid != null and pid_ent != attacker_pid)
						if is_enemy:
							real_heal = maxi(1, floori(real_heal / 2.0))
							
						var applied = _apply_heal_to_target(t, real_heal, attacker)
						print("[COMBAT] %s heal sebesar %d HP!" % [t.name, applied])
					else:
						var skip_damage = false
						if ability != null:
							if ability.ability_type == 2:
								skip_damage = true
							elif ("damage_primary_only" in ability) and ability.damage_primary_only and t != primary_target:
								skip_damage = true
						
						if not skip_damage:
							var real_dmg = current_roll_dmg
							if not hit and ability != null and ability.aoe_type != "none":
								real_dmg = maxi(1, floori(current_roll_dmg / 2.0))
							
							var cond = StatSystem.get_condition_component(t) if StatSystem != null else t.get_node_or_null("ConditionComponent")
							if is_instance_valid(cond) and cond.has_method("has_condition") and cond.has_condition("vulnerable") and not is_magical:
								real_dmg = maxi(1, floori(real_dmg * 1.5))
							
							var final_damage_type = "magical" if is_magical else "physical"
							if ability != null and ability.element_tag != "":
								final_damage_type = ability.element_tag
							var applied = _apply_damage_to_target(t, real_dmg, attacker, final_damage_type)
							
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
							
							if is_instance_valid(t) and t.has_method("play_hurt"):
								t.play_hurt()
							
							var element_tag = "physical"
							if ability != null: element_tag = ability.element_tag
							if is_magical and ability == null: element_tag = "arcane"
								
							if ElementSystem != null:
								ElementSystem.resolve_elemental_hit(t, element_tag, applied)
						
				if hit and is_last:
					var kb_tiles = 0
					if ability != null:
						kb_tiles = ability.knockback_tiles
						if kb_tiles > 0 and attacker != null and InventoryManager != null and InventoryManager.has_item_node(attacker, "big_hand"):
							kb_tiles += 1
						if ability.status_effect != "":
							var effect_to_apply = ability.status_effect
							if effect_to_apply == "random":
								effect_to_apply = ["weakened", "vulnerable", "bleeding", "stunned", "frozen", "lacerate"].pick_random()
							var dur = ability.status_duration
							var stk = ability.status_stacks
							if attacker != null and InventoryManager != null and InventoryManager.has_item_node(attacker, "boots_lust"):
								dur *= 2
								stk *= 2
							for t in current_aoe_targets:
								EventBus.on_status_applied.emit(t, effect_to_apply, dur, stk)
						if crit and ability.ability_name == "Main Attack":
							var dur = 1
							var stk = 1
							if attacker != null and InventoryManager != null and InventoryManager.has_item_node(attacker, "boots_lust"):
								dur *= 2
								stk *= 2
							for t in current_aoe_targets:
								EventBus.on_status_applied.emit(t, "stunned", dur, stk)
					
					if kb_tiles != 0 and not _knockback_done[0]:
						for t in current_aoe_targets:
							var _t_pos = t.get("grid_pos")
							var diff = _t_pos - a_pos
							var dir = Vector2i.RIGHT
							if abs(diff.x) > abs(diff.y): dir = Vector2i(sign(diff.x), 0)
							else: dir = Vector2i(0, sign(diff.y))
							if kb_tiles < 0: dir = -dir
							ForcedMovementResolver.knockback_entity(t, abs(kb_tiles), dir, attacker)
							_knockback_done[0] = true
			
			if is_instance_valid(active_proj):
				active_proj.impacted.connect(on_impact)
			else:
				on_impact.call()
				
			if is_burst:
				await attacker.get_tree().create_timer(0.15, false).timeout # stagger launch
	else:
		print("[COMBAT] Serangan meleset!")

	if ability != null and ("summon_blockade_front" in ability) and ability.summon_blockade_front and primary_target != null:
		print("[COMBAT-DEBUG] Attempting to spawn blockade...")
		var t_pos: Vector2i = primary_target.get("grid_pos")
		var diff = t_pos - a_pos
		var dir = Vector2i.ZERO
		if abs(diff.x) > abs(diff.y): dir = Vector2i(sign(diff.x), 0)
		elif diff.y != 0: dir = Vector2i(0, sign(diff.y))
		if dir == Vector2i.ZERO: dir = Vector2i(1, 0)
		
		var spawn_pos = t_pos - dir
		print("[COMBAT-DEBUG] Calculated primary spawn_pos: %s (target is %s, dir is %s)" % [spawn_pos, t_pos, dir])
		var valid_spawn = false
		
		# Helper function to print exactly WHY a tile is blocked
		var check_reason = func(pos: Vector2i):
			if not GridManager._is_in_bounds(pos):
				print("[COMBAT-DEBUG] Tile %s is OUT OF BOUNDS!" % pos)
			elif not GridManager._walkable.get(pos, false):
				print("[COMBAT-DEBUG] Tile %s has _walkable == false (Wall/Terrain block)!" % pos)
			elif GridManager._entities.has(pos):
				var e_node = GridManager._entities[pos].node
				print("[COMBAT-DEBUG] Tile %s is occupied by entity: %s!" % [pos, e_node.name if e_node else "null"])
			else:
				print("[COMBAT-DEBUG] Tile %s seems perfectly walkable to GridManager!" % pos)
		
		if spawn_pos != a_pos and is_instance_valid(GridManager) and GridManager.is_walkable(spawn_pos):
			valid_spawn = true
			print("[COMBAT-DEBUG] Primary spawn_pos %s is walkable!" % spawn_pos)
		else:
			print("[COMBAT-DEBUG] Primary spawn_pos %s is blocked or invalid! Checking reason:" % spawn_pos)
			if spawn_pos == a_pos:
				print("[COMBAT-DEBUG] Tile %s is occupied by the Boss itself!" % spawn_pos)
			else:
				check_reason.call(spawn_pos)
				
			print("[COMBAT-DEBUG] Checking fallbacks...")
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var fallback_pos = t_pos + d
				if fallback_pos != a_pos and is_instance_valid(GridManager) and GridManager.is_walkable(fallback_pos):
					spawn_pos = fallback_pos
					valid_spawn = true
					print("[COMBAT-DEBUG] Found valid fallback spawn_pos: %s" % spawn_pos)
					break
				else:
					print("[COMBAT-DEBUG] Fallback %s failed. Reason:" % fallback_pos)
					if fallback_pos == a_pos:
						print("[COMBAT-DEBUG] Tile %s is occupied by the Boss itself!" % fallback_pos)
					else:
						check_reason.call(fallback_pos)
		
		if valid_spawn:
			print("[COMBAT] Summoning Blockade at %s" % spawn_pos)
			var blockade_scene = load("res://entities/props/Blockade.tscn")
			if blockade_scene:
				var world_node = attacker.get_parent()
				print("[COMBAT-DEBUG] Attacker parent is: %s" % (world_node.name if world_node else "null"))
				if world_node and world_node.has_method("spawn_entity"):
					print("[COMBAT-DEBUG] Calling spawn_entity on attacker parent.")
					world_node.spawn_entity(blockade_scene, spawn_pos)
				elif world_node and world_node.get_parent() and world_node.get_parent().has_method("spawn_entity"):
					print("[COMBAT-DEBUG] Calling spawn_entity on attacker's grandparent (%s)." % world_node.get_parent().name)
					world_node.get_parent().spawn_entity(blockade_scene, spawn_pos)
				else:
					print("[COMBAT-DEBUG] Fallback: manual instantiation because spawn_entity not found.")
					var blockade = blockade_scene.instantiate()
					blockade.set("grid_pos", spawn_pos)
					blockade.position = IsoUtils.world_to_iso(spawn_pos)
					if IsoUtils.has_method("get_depth"):
						blockade.z_index = IsoUtils.get_depth(spawn_pos)
					if world_node: world_node.add_child(blockade)
			else:
				print("[COMBAT-DEBUG] Error: Failed to load Blockade.tscn!")
		else:
			print("[COMBAT] Failed to summon Blockade: No walkable tiles around target!")
			print("[COMBAT-DEBUG] Checked fallback positions but none were walkable. GridManager._walkable might be false, or entities block them.")

	_clear_viewport_focus()

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
	
	if (applied > 0 or amount > 0) and is_instance_valid(target):
		if is_instance_valid(bridge) and is_instance_valid(bridge.vfx_controller):
			bridge.vfx_controller._spawn_hit_vfx(target, damage_type)
			
	return applied


var _focus_rect: ColorRect = null
var _focus_ghosts: Array = []
var _hidden_sprites: Array = []

func _apply_viewport_focus(active_pid: int, caster: Node, targets: Array) -> void:
	if active_pid != 1 and active_pid != 2: return
	if not is_instance_valid(caster) or caster.is_queued_for_deletion(): return
	
	var active_layer = 2 if active_pid == 1 else 4
	var inactive_layer = 4 if active_pid == 1 else 2
	
	_clear_viewport_focus()
	
	# 1. Background Dimming & Desaturation (z_index = 0)
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float focus_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 bg = texture(screen_texture, SCREEN_UV);
	float gray = dot(bg.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(bg.rgb, vec3(gray), focus_strength * 0.85);
	vec3 dimmed = desat * (1.0 - focus_strength * 0.5);
	COLOR = vec4(dimmed, 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("focus_strength", 0.0)
	
	_focus_rect = ColorRect.new()
	_focus_rect.material = mat
	_focus_rect.size = Vector2(8000, 8000)
	_focus_rect.position = caster.global_position - _focus_rect.size / 2.0
	_focus_rect.z_index = 0 # Just above the TileMap, below the entities
	_focus_rect.visibility_layer = active_layer
	_focus_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var parent = caster.get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		parent.add_child(_focus_rect)
		var tw = _focus_rect.create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v): mat.set_shader_parameter("focus_strength", v), 0.0, 1.0, 0.3)
	else:
		_focus_rect.free()
		_focus_rect = null
	
	# 2. Character Ghosting (0.3 opacity)
	var all_entities = get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("players")
	for ent in all_entities:
		if not is_instance_valid(ent) or ent.is_queued_for_deletion():
			continue
		if ent == caster or targets.has(ent):
			continue
			
		var sprite = ent.get("sprite") if ent.get("sprite") != null else ent.get("anim_sprite")
		if is_instance_valid(sprite) and sprite is CanvasItem and not sprite.is_queued_for_deletion():
			
			var ghost = null
			if sprite is AnimatedSprite2D:
				ghost = AnimatedSprite2D.new()
				ghost.sprite_frames = sprite.sprite_frames
				ghost.animation = sprite.animation
				ghost.frame = sprite.frame
				ghost.flip_h = sprite.flip_h
				ghost.flip_v = sprite.flip_v
				if sprite.is_playing(): ghost.play()
			elif sprite is Sprite2D:
				ghost = Sprite2D.new()
				ghost.texture = sprite.texture
				ghost.hframes = sprite.hframes
				ghost.vframes = sprite.vframes
				ghost.frame = sprite.frame
				ghost.flip_h = sprite.flip_h
				ghost.flip_v = sprite.flip_v
			
			if ghost != null:
				# Hide original from active player, keep for inactive player
				sprite.visibility_layer = inactive_layer
				_hidden_sprites.append(sprite)
				
				# Setup ghost properties
				ghost.scale = sprite.scale
				ghost.position = sprite.position
				ghost.offset = sprite.offset
				ghost.modulate = sprite.modulate
				ghost.modulate.a = 0.3 # Target opacity requested by user
				ghost.visibility_layer = active_layer
				
				var sprite_parent = sprite.get_parent()
				if is_instance_valid(sprite_parent) and not sprite_parent.is_queued_for_deletion():
					sprite_parent.add_child(ghost)
					_focus_ghosts.append(ghost)
				else:
					ghost.free()

func _clear_viewport_focus() -> void:
	if is_instance_valid(_focus_rect) and not _focus_rect.is_queued_for_deletion():
		var mat = _focus_rect.material as ShaderMaterial
		if mat:
			var tw = _focus_rect.create_tween().set_ease(Tween.EASE_IN)
			tw.tween_method(func(v): mat.set_shader_parameter("focus_strength", v), 1.0, 0.0, 0.25)
			tw.finished.connect(_focus_rect.queue_free)
		else:
			_focus_rect.queue_free()
	_focus_rect = null
	
	for ghost in _focus_ghosts:
		if is_instance_valid(ghost) and not ghost.is_queued_for_deletion():
			ghost.queue_free()
	_focus_ghosts.clear()
	
	for sprite in _hidden_sprites:
		if is_instance_valid(sprite) and not sprite.is_queued_for_deletion():
			sprite.visibility_layer = 1
	_hidden_sprites.clear()


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
			c.shake(clampf(power * 0.06, 0.2, 1.0), 0.5 if power > 12.0 else 0.35)


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
