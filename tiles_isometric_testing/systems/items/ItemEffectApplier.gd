extends Node

# Listens to events and applies item effects to players based on their inventory.

var _last_ap: Dictionary = {}
var _managers: Dictionary = {}

func _ready() -> void:
	if EventBus != null:
		if not EventBus.turn_started.is_connected(_on_turn_started):
			EventBus.turn_started.connect(_on_turn_started)
		if not EventBus.turn_ended.is_connected(_on_turn_ended):
			EventBus.turn_ended.connect(_on_turn_ended)
		if not EventBus.player_moved.is_connected(_on_player_moved):
			EventBus.player_moved.connect(_on_player_moved)
		if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
			EventBus.damage_dealt.connect(_on_damage_dealt)
		if not EventBus.entity_died.is_connected(_on_entity_died):
			EventBus.entity_died.connect(_on_entity_died)
		if not EventBus.combat_hud_ready.is_connected(_on_combat_hud_ready):
			EventBus.combat_hud_ready.connect(_on_combat_hud_ready)
			
	if InventoryManager != null:
		if not InventoryManager.item_added.is_connected(_on_inventory_changed):
			InventoryManager.item_added.connect(_on_inventory_changed)
		if not InventoryManager.item_removed.is_connected(_on_inventory_changed):
			InventoryManager.item_removed.connect(_on_inventory_changed)

func _get_player_by_id(pid: int) -> Node:
	if not is_inside_tree():
		return null
	for p in get_tree().get_nodes_in_group("players"):
		var p_id = p.get("player_id")
		if p_id != null and typeof(p_id) == TYPE_INT and p_id == pid:
			return p
	return null

func _on_inventory_changed(player_id: int, _item_id: String) -> void:
	var player = _get_player_by_id(player_id)
	if player != null:
		recalculate_player_stats(player, player_id)

func recalculate_player_stats(player_node: Node, player_id: int) -> void:
	var stats = player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
		
	# Clear previous item modifiers (keep custom runtime ones like blade_wrath)
	stats.clear_mod_sources("item:")
	
	var items = InventoryManager.get_player_items(player_id)
	for i in range(items.size()):
		var item_id = items[i]
		var item_data: Dictionary = StatDataDB.get_item_data(item_id)
		if item_data.is_empty():
			continue
			
		var stat_mods = item_data.get("stat_mods", {})
		if stat_mods.is_empty():
			continue
			
		var source_id: String = str(item_data.get("source_id", "item:%s" % item_id))
		# Twin items (stacks) should not override each other
		source_id = "%s_%d" % [source_id, i]
		
		StatDataDB.apply_stat_mod(player_node, source_id, stat_mods)
		
	# Sync AP / BAP / Movement managers with current stats + item mods
	var mgr = _managers.get(player_id, {})
	var ap_mgr = mgr.get("ap")
	if ap_mgr and stats:
		var new_max_ap = 1 + floori(stats.get_stat("dex") / 10.0) + stats.get_mod_total("action_points")
		if new_max_ap != ap_mgr.max_ap:
			if new_max_ap > ap_mgr.max_ap:
				ap_mgr.current_ap += (new_max_ap - ap_mgr.max_ap)
			ap_mgr.max_ap = new_max_ap
			ap_mgr.current_ap = clampi(ap_mgr.current_ap, 0, new_max_ap)
			ap_mgr.ap_changed.emit(ap_mgr.current_ap, new_max_ap)
		var new_max_bap = 1 + floori(stats.get_stat("int") / 10.0) + stats.get_mod_total("bonus_action_points")
		if new_max_bap != ap_mgr.max_bap:
			if new_max_bap > ap_mgr.max_bap:
				ap_mgr.current_bap += (new_max_bap - ap_mgr.max_bap)
			ap_mgr.max_bap = new_max_bap
			ap_mgr.current_bap = clampi(ap_mgr.current_bap, 0, new_max_bap)
			ap_mgr.bap_changed.emit(ap_mgr.current_bap, new_max_bap)
	var mov_mgr = mgr.get("mov")
	if mov_mgr and stats:
		var new_max_tiles = 6 + floori(stats.get_stat("mov") / 5.0) + stats.get_mod_total("movement_tiles")
		if new_max_tiles != mov_mgr.max_tiles:
			if new_max_tiles > mov_mgr.max_tiles:
				mov_mgr.current_tiles += (new_max_tiles - mov_mgr.max_tiles)
			mov_mgr.max_tiles = new_max_tiles
			mov_mgr.current_tiles = clampi(mov_mgr.current_tiles, 0, new_max_tiles)
			mov_mgr.movement_changed.emit(mov_mgr.current_tiles, new_max_tiles)
			
	var res_mgr = mgr.get("res")
	if res_mgr and stats:
		if res_mgr is SpellSlotManager:
			var att_val = stats.get_stat("att")
			var new_l1 = 2 + floori(att_val / 5.0) + stats.get_mod_total("spell_slots_l1")
			var new_l2 = 2 + floori(att_val / 10.0) + stats.get_mod_total("spell_slots_l2")
			var new_l3 = 1 + floori(att_val / 15.0) + stats.get_mod_total("spell_slots_l3")
			var new_l4 = stats.get_mod_total("spell_slots_l4")
			
			var levels = [1, 2, 3, 4]
			var new_maxes = [new_l1, new_l2, new_l3, new_l4]
			for idx in range(4):
				var lvl = levels[idx]
				var n_max = new_maxes[idx]
				if n_max != res_mgr.max_slots[idx]:
					var diff = n_max - res_mgr.max_slots[idx]
					res_mgr.max_slots[idx] = n_max
					res_mgr.current_slots[idx] = clampi(res_mgr.current_slots[idx] + diff, 0, n_max)
					res_mgr.slots_changed.emit(lvl, res_mgr.current_slots[idx], n_max)
		elif res_mgr is EnergyChargeManager:
			var slot_conv = stats.get_mod_total("spell_slots_l1") * 1 \
				+ stats.get_mod_total("spell_slots_l2") * 2 \
				+ stats.get_mod_total("spell_slots_l3") * 3 \
				+ stats.get_mod_total("spell_slots_l4") * 4
			var direct_charge = stats.get_mod_total("energy_charge")
			var new_max_charges = 5 + slot_conv + direct_charge
			if new_max_charges != res_mgr.max_charges:
				var diff = new_max_charges - res_mgr.max_charges
				res_mgr.max_charges = new_max_charges
				res_mgr.current_charges = clampi(res_mgr.current_charges + diff, 0, new_max_charges)
				res_mgr.charge_changed.emit(res_mgr.current_charges, new_max_charges)

	# Bind health component for HP threshold items
	var hc = player_node.get_node_or_null("HealthComponent")
	if is_instance_valid(hc):
		if not hc.hp_changed.is_connected(_on_hp_changed.bind(player_node, player_id)):
			hc.hp_changed.connect(_on_hp_changed.bind(player_node, player_id))
		# Holy Ring: bonus heal
		if not hc.healed.is_connected(_on_healed.bind(player_node, player_id)):
			hc.healed.connect(_on_healed.bind(player_node, player_id))
		# Clock o' Chronos: revive on down
		if not hc.downed.is_connected(_on_downed.bind(player_node, player_id)):
			hc.downed.connect(_on_downed.bind(player_node, player_id))
		# Force trigger one time
		_on_hp_changed(hc.current_hp, hc.max_hp, player_node, player_id)

func _on_hp_changed(current: int, max_hp: int, player_node: Node, player_id: int) -> void:
	var stats = player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
		
	# 1. Ant Fang: HP > 80% → All Hit Rolls +2
	if InventoryManager.has_item(player_id, "ant_fang"):
		var want_bonus = current >= int(max_hp * 0.8)
		var has_bonus = stats.get_mod_sources().has("ant_fang_bonus")
		if want_bonus != has_bonus:
			if want_bonus:
				stats.set_mod_source("ant_fang_bonus", {"hit_roll": 2})
			else:
				stats.remove_mod_source("ant_fang_bonus")
	else:
		if stats.get_mod_sources().has("ant_fang_bonus"):
			stats.remove_mod_source("ant_fang_bonus")
			
	# 2. Glasswing: HP >= 50% → +2 All Attack, but HP < 50% → -2 AC
	if InventoryManager.has_item(player_id, "glasswing"):
		var want_buff = current >= int(max_hp * 0.5)
		var active_mods = stats.get_mod_sources().get("glasswing_bonus", {})
		var has_buff = active_mods.has("physical_damage")
		var has_debuff = active_mods.has("armor")
		if want_buff and not has_buff:
			stats.set_mod_source("glasswing_bonus", {"physical_damage": 2, "magical_damage": 2})
		elif not want_buff and not has_debuff:
			stats.set_mod_source("glasswing_bonus", {"armor": -2})
	else:
		if stats.get_mod_sources().has("glasswing_bonus"):
			stats.remove_mod_source("glasswing_bonus")
			
	# 3. Greathorn Staff: HP < 50% → Self +2 AC
	if InventoryManager.has_item(player_id, "greathorn_staff"):
		var want_bonus = current < int(max_hp * 0.5)
		var has_bonus = stats.get_mod_sources().has("greathorn_staff_bonus")
		if want_bonus != has_bonus:
			if want_bonus:
				stats.set_mod_source("greathorn_staff_bonus", {"armor": 2})
			else:
				stats.remove_mod_source("greathorn_staff_bonus")
	else:
		if stats.get_mod_sources().has("greathorn_staff_bonus"):
			stats.remove_mod_source("greathorn_staff_bonus")

func _on_healed(_amount: int, player_node: Node, player_id: int) -> void:
	if not InventoryManager.has_item(player_id, "holy_ring"):
		return
	if player_node.get_meta("holy_ring_busy", false):
		return
	player_node.set_meta("holy_ring_busy", true)
	var bonus = randi_range(1, 6)
	var hc = player_node.get_node_or_null("HealthComponent")
	if hc:
		hc.heal(bonus)
		EventNotifier.show_message("Holy Ring: +%d Bonus Heal!" % bonus, Color.MEDIUM_SPRING_GREEN)
	player_node.set_meta("holy_ring_busy", false)

func _on_downed(attacker: Node, player_node: Node, player_id: int) -> void:
	if not InventoryManager.has_item(player_id, "clock_chronos"):
		return
	if player_node.get_meta("clock_chronos_revived", false):
		return
	player_node.set_meta("clock_chronos_revived", true)
	var hc = player_node.get_node_or_null("HealthComponent")
	if hc:
		hc.revive(0.01)
		EventNotifier.show_message("Clock o' Chronos: Revived with 1% HP!", Color.LIGHT_SKY_BLUE)

func _on_combat_hud_ready(player_id: int, ap_mgr: Node, mov_mgr: Node, resource_mgr: Node) -> void:
	_managers[player_id] = {
		"ap": ap_mgr,
		"mov": mov_mgr,
		"res": resource_mgr
	}
	var player = _get_player_by_id(player_id)
	if player != null:
		recalculate_player_stats(player, player_id)
	if ap_mgr != null and not ap_mgr.ap_changed.is_connected(_on_ap_changed.bind(player_id)):
		ap_mgr.ap_changed.connect(_on_ap_changed.bind(player_id))
	if resource_mgr != null:
		if resource_mgr.has_signal("slots_changed") and not resource_mgr.slots_changed.is_connected(_on_slots_changed.bind(player_id)):
			resource_mgr.slots_changed.connect(_on_slots_changed.bind(player_id))
		if resource_mgr.has_signal("charge_changed") and not resource_mgr.charge_changed.is_connected(_on_charge_changed.bind(player_id)):
			resource_mgr.charge_changed.connect(_on_charge_changed.bind(player_id))

func _on_ap_changed(current_ap: int, max_ap: int, player_id: int) -> void:
	var last = _last_ap.get(player_id, max_ap)
	_last_ap[player_id] = current_ap
	if current_ap < last:
		# AP consumed
		var player = _get_player_by_id(player_id)
		if player != null and InventoryManager.has_item(player_id, "greatskull_sword"):
			# Greatskull Sword: Get a BAP when Action Point is spent
			var ap_mgr = _managers.get(player_id, {}).get("ap")
			if ap_mgr and ap_mgr.has_method("spend_bap"):
				ap_mgr.current_bap = min(ap_mgr.current_bap + 1, ap_mgr.max_bap)
				ap_mgr.bap_changed.emit(ap_mgr.current_bap, ap_mgr.max_bap)
				EventNotifier.show_message("Greatskull Sword: +1 BAP!", Color.ORANGE)

func _on_slots_changed(level: int, current: int, max_slots: int, player_id: int) -> void:
	# Keep track of slot changes for Honey Wax
	var last = get_meta("last_slots_%d_%d" % [player_id, level], max_slots)
	set_meta("last_slots_%d_%d" % [player_id, level], current)
	if current < last:
		# Slot consumed
		_trigger_honey_wax(player_id)

func _on_charge_changed(current: int, max_charges: int, player_id: int) -> void:
	# Keep track of charge changes for Honey Wax
	var last = get_meta("last_charge_%d" % player_id, max_charges)
	set_meta("last_charge_%d" % player_id, current)
	if current < last:
		# Charge consumed
		_trigger_honey_wax(player_id)

func _trigger_honey_wax(player_id: int) -> void:
	var player = _get_player_by_id(player_id)
	if player != null and InventoryManager.has_item(player_id, "honey_wax"):
		var roll = randi_range(1, 6)
		var hc = player.get_node_or_null("HealthComponent")
		if hc:
			hc.heal(roll)
			EventNotifier.show_message("Honey Wax heals P%d for %d HP!" % [player_id, roll], Color.MEDIUM_SPRING_GREEN)

func _on_player_moved(entity: Node, from: Vector2i, to: Vector2i) -> void:
	var pid = entity.get("player_id")
	if pid == null:
		return
	var player_id = int(pid)
	
	# Mark as moved this turn (for Sloth)
	entity.set_meta("moved_this_turn", true)
	
	# Sandal: Heal 1 HP per tile moved
	if InventoryManager.has_item(player_id, "sandal"):
		var dist = abs(to.x - from.x) + abs(to.y - from.y)
		if dist > 0:
			var hc = entity.get_node_or_null("HealthComponent")
			if hc:
				hc.heal(dist)
				EventNotifier.show_message("Sandal heals P%d for %d HP!" % [player_id, dist], Color.SPRING_GREEN)

func _on_damage_dealt(target: Node, amount: int, type: String, is_crit: bool, source: Node) -> void:
	# If source is player (on-hit effects)
	var spid = source.get("player_id") if source != null else null
	if spid != null:
		var player_id = int(spid)
		
		# 1. Robe o' Envy: Hit Enemy → +5 to a Random Stat (lasts 1 turn)
		if InventoryManager.has_item(player_id, "robe_envy"):
			var stats = source.get_node_or_null("StatsComponent") as StatsComponent
			if stats != null:
				var random_stat = ["str", "int", "con", "acc", "dex", "mov", "att", "lck"].pick_random()
				stats.set_mod_source("robe_envy_hit", {random_stat: 5})
				source.set_meta("robe_envy_stat_mod_applied", true)
				EventNotifier.show_message("Robe o' Envy: +5 %s!" % random_stat.to_upper(), Color.DEEP_PINK)
				
		# 2. Grid o' Topos: Hit Enemy → Swap positions
		if InventoryManager.has_item(player_id, "grid_topos"):
			var source_pos = source.get("grid_pos")
			var target_pos = target.get("grid_pos")
			if source_pos != null and target_pos != null and GridManager != null:
				if GridManager.swap_entities(source_pos, target_pos):
					source.set("grid_pos", target_pos)
					target.set("grid_pos", source_pos)
					if IsoUtils != null:
						source.position = IsoUtils.world_to_iso(target_pos)
						source.z_index = IsoUtils.get_depth(target_pos)
						target.position = IsoUtils.world_to_iso(source_pos)
						target.z_index = IsoUtils.get_depth(source_pos)
					EventNotifier.show_message("Grid o' Topos: Swap Position!", Color.LIGHT_BLUE)
				
		# 3. Rainbow Hand: Hit Enemy with Physical damage → Give enemy 1 random status
		if type.to_lower() == "physical" and InventoryManager.has_item(player_id, "rainbow_hand"):
			var random_effects = ["weakened", "vulnerable", "bleeding", "stunned", "frozen", "lacerate"]
			var effect = random_effects.pick_random()
			EventBus.on_status_applied.emit(target, effect, 2, 1)
			EventNotifier.show_message("Rainbow Hand: Applied %s!" % effect.to_upper(), Color.GOLD)
			
		# 4. Gauntlet o' Sloth stacks consumed on attack
		if source.has_meta("lazy_stacks") and source.get_meta("lazy_stacks", 0) > 0:
			source.set_meta("lazy_stacks", 0)
			
	# If target is player (get-hit effects)
	var tpid = target.get("player_id") if target != null else null
	if tpid != null:
		var target_id = int(tpid)
		target.set_meta("was_hit_since_last_turn", true)
		
		# Red Cloud Cape: Get hit → Deal 2 damage back
		if InventoryManager.has_item(target_id, "red_cloud_cape") and source != null:
			if StatSystem != null:
				StatSystem.apply_damage(source, 2, target, "true_damage")
				EventNotifier.show_message("Red Cloud Cape: 2 thorn damage back!", Color.CRIMSON)

func get_combat_damage_modifier(attacker: Node, _target: Node, is_magical: bool) -> int:
	var pid = attacker.get("player_id") if attacker != null else null
	if pid == null:
		return 0
	var player_id = int(pid)
	var extra_mod := 0
	
	# 1. Switchblade: +1d8 Physical damage on physical attacks
	if not is_magical and InventoryManager.has_item(player_id, "switchblade"):
		var roll = randi_range(1, 8)
		extra_mod += roll
		print("[ItemEffectApplier] Switchblade +%d Phys Damage" % roll)
		EventNotifier.show_message("Switchblade: +%d Phys Damage" % roll, Color.TOMATO)
		
	# 2. Gauntlet o' Sloth: consume lazy stacks for +[stack]d4 damage
	if attacker.has_meta("lazy_stacks") and attacker.get_meta("lazy_stacks", 0) > 0:
		var stacks = attacker.get_meta("lazy_stacks", 0)
		var total_sloth = 0
		for k in range(stacks):
			total_sloth += randi_range(1, 4)
		extra_mod += total_sloth
		print("[ItemEffectApplier] Gauntlet o' Sloth consumes %d stacks for +%d damage" % [stacks, total_sloth])
		EventNotifier.show_message("Gauntlet o' Sloth: +%d Damage!" % total_sloth, Color.GOLDENROD)
		
	return extra_mod

func _on_entity_died(entity: Node, killer: Node) -> void:
	var kpid = killer.get("player_id") if killer != null else null
	if kpid == null:
		return
	var player_id = int(kpid)
	
	# 1. Blade o' Wrath: Kill Enemy → Gain +1 Flat Damage stack (max 7)
	if InventoryManager.has_item(player_id, "blade_wrath"):
		var current = killer.get_meta("blade_wrath_stacks", 0)
		if current < 7:
			var next = current + 1
			killer.set_meta("blade_wrath_stacks", next)
			var stats = killer.get_node_or_null("StatsComponent") as StatsComponent
			if stats != null:
				stats.set_mod_source("blade_wrath_stacks", {"physical_damage": next, "magical_damage": next})
			EventNotifier.show_message("Blade o' Wrath: Stack %d (+%d DMG)" % [next, next], Color.RED)
		
	# 2. Berserker Axe: Kill Enemy → +1d4 STR (stacks)
	if InventoryManager.has_item(player_id, "berserker_axe"):
		var roll = randi_range(1, 4)
		var current_str = killer.get_meta("berserker_str_stacks", 0)
		var next_str = current_str + roll
		killer.set_meta("berserker_str_stacks", next_str)
		var stats = killer.get_node_or_null("StatsComponent") as StatsComponent
		if stats != null:
			stats.set_mod_source("berserker_axe_buff", {"str": next_str})
		EventNotifier.show_message("Berserker Axe: +%d STR (total %d)" % [roll, next_str], Color.ORANGE_RED)

	# 3. Mask o' Gluttony: Heals +10 HP on kill
	if InventoryManager.has_item(player_id, "mask_gluttony"):
		var hc = killer.get_node_or_null("HealthComponent")
		if hc:
			hc.heal(10)
			EventNotifier.show_message("Mask o' Gluttony heals +10 HP!", Color.GREEN)
			
	# 4. Skywalker: +2 tiles movement on kill
	if InventoryManager.has_item(player_id, "skywalker"):
		var mov_mgr = _managers.get(player_id, {}).get("mov")
		if mov_mgr:
			mov_mgr.current_tiles += 2
			mov_mgr.movement_changed.emit(mov_mgr.current_tiles, mov_mgr.max_tiles)
			EventNotifier.show_message("Skywalker: +2 Moves!", Color.AQUA)
			
	# 5. Holymoly Necklace: +1 slot cap / +1 Charge
	if InventoryManager.has_item(player_id, "holymoly_necklace"):
		if player_id == 1:
			var ec = _managers.get(player_id, {}).get("res")
			if ec: ec.restore_charges(1)
		elif player_id == 2:
			var ss = _managers.get(player_id, {}).get("res")
			if ss: ss.restore_slots(1, 1)
		EventNotifier.show_message("Holymoly Necklace: +1 Charge/Spell Slot!", Color.MEDIUM_PURPLE)
		
	# 6. Red Cape: First kill in this Combat → +2 All Stats until combat ends
	if InventoryManager.has_item(player_id, "red_cape") and not killer.has_meta("red_cape_triggered"):
		killer.set_meta("red_cape_triggered", true)
		var stats = killer.get_node_or_null("StatsComponent") as StatsComponent
		if stats != null:
			stats.set_mod_source("red_cape_buff", {
				"str": 2, "int": 2, "con": 2, "acc": 2, "dex": 2, "mov": 2, "att": 2, "lck": 2
			})
		EventNotifier.show_message("Red Cape triggered: +2 All Stats!", Color.CRIMSON)
		
	# 7. Egg Pouch: +10 coins on kill
	if InventoryManager.has_item(player_id, "egg_pouch") and CoinEconomy != null:
		CoinEconomy.add_coins(player_id, 10)
		EventNotifier.show_message("Egg Pouch: +10 Coins!", Color.YELLOW)
		
	# 8. White Robe: Ally kills an enemy → +1 BAP
	# Trigger white robe for the OTHER player
	var ally_id = 2 if player_id == 1 else 1
	var ally = _get_player_by_id(ally_id)
	if ally != null and InventoryManager.has_item(ally_id, "white_robe"):
		var ap_mgr = _managers.get(ally_id, {}).get("ap")
		if ap_mgr:
			ap_mgr.current_bap = min(ap_mgr.current_bap + 1, ap_mgr.max_bap)
			ap_mgr.bap_changed.emit(ap_mgr.current_bap, ap_mgr.max_bap)
			EventNotifier.show_message("White Robe: Ally got +1 BAP!", Color.WHITE)

func _on_turn_started(entity: Node, player_id: int) -> void:
	if player_id < 1:
		return
		
	# Crown o' Pride: heal 10% HP if not hit
	if InventoryManager.has_item(player_id, "crown_pride"):
		if not entity.get_meta("was_hit_since_last_turn", false):
			var hc = entity.get_node_or_null("HealthComponent")
			if hc:
				var amt = int(hc.max_hp * 0.1)
				hc.heal(amt)
				EventNotifier.show_message("Crown o' Pride heals +%d HP!" % amt, Color.GOLD)
		entity.set_meta("was_hit_since_last_turn", false)
		
	# Gauntlet o' Sloth: gain lazy stack if didn't move (max 5)
	if InventoryManager.has_item(player_id, "gauntlet_sloth"):
		if not entity.get_meta("moved_this_turn", false):
			var current = entity.get_meta("lazy_stacks", 0)
			if current < 5:
				entity.set_meta("lazy_stacks", current + 1)
				EventNotifier.show_message("Gauntlet o' Sloth: Lazy Stack (%d)" % (current + 1), Color.GOLDENROD)
		entity.set_meta("moved_this_turn", false)
		
	# Sleeping Bag & Sleeping Pouch recovery
	if entity.get_meta("skipped_previous_turn", false):
		entity.set_meta("skipped_previous_turn", false)
		if InventoryManager.has_item(player_id, "sleeping_bag"):
			var ap = _managers.get(player_id, {}).get("ap")
			if ap:
				ap.current_ap = min(ap.current_ap + 1, ap.max_ap)
				ap.ap_changed.emit(ap.current_ap, ap.max_ap)
			var res = _managers.get(player_id, {}).get("res")
			if res:
				if player_id == 1: res.restore_charges(1)
				elif player_id == 2: res.restore_slots(1, 1)
			EventNotifier.show_message("Sleeping Bag recovery!", Color.MEDIUM_PURPLE)
		if InventoryManager.has_item(player_id, "sleeping_pouch"):
			var ap = _managers.get(player_id, {}).get("ap")
			if ap:
				ap.current_bap = min(ap.current_bap + 1, ap.max_bap)
				ap.bap_changed.emit(ap.current_bap, ap.max_bap)
			var hc = entity.get_node_or_null("HealthComponent")
			if hc:
				hc.heal(int(hc.max_hp * 0.1))
			EventNotifier.show_message("Sleeping Pouch recovery!", Color.MEDIUM_PURPLE)

	# Robe o' Envy hit modifiers decay
	var stats = entity.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null and entity.has_meta("robe_envy_stat_mod_applied"):
		stats.remove_mod_source("robe_envy_hit")
		entity.remove_meta("robe_envy_stat_mod_applied")
		
	# Apply cursed amulet tick damage
	if InventoryManager.has_item(player_id, "cursed_amulet"):
		var hc = entity.get_node_or_null("HealthComponent")
		if hc:
			hc.take_damage(1, null, "true_damage")
			EventNotifier.show_message("Cursed Amulet ticks -1 HP!", Color.PURPLE)

func _on_turn_ended(entity: Node) -> void:
	var pid = entity.get("player_id")
	if pid == null: return
	var player_id = int(pid)
	
	# Track if player skipped their turn (all actions, bonus, tiles unused)
	var mgrs = _managers.get(player_id, {})
	var ap = mgrs.get("ap")
	var mov = mgrs.get("mov")
	if ap != null and mov != null:
		var skipped = (ap.current_ap == ap.max_ap) and (ap.current_bap == ap.max_bap) and (mov.current_tiles == mov.max_tiles)
		entity.set_meta("skipped_previous_turn", skipped)

func reset() -> void:
	# Clear metadata on players when run resets
	for player in get_tree().get_nodes_in_group("players"):
		player.remove_meta("blade_wrath_stacks")
		player.remove_meta("berserker_str_stacks")
		player.remove_meta("lazy_stacks")
		player.remove_meta("was_hit_since_last_turn")
		player.remove_meta("moved_this_turn")
		player.remove_meta("skipped_previous_turn")
		player.remove_meta("red_cape_triggered")
		player.remove_meta("clock_chronos_revived")
		var stats = player.get_node_or_null("StatsComponent") as StatsComponent
		if stats != null:
			stats.remove_mod_source("blade_wrath_stacks")
			stats.remove_mod_source("berserker_axe_buff")
			stats.remove_mod_source("red_cape_buff")
			stats.remove_mod_source("robe_envy_hit")
			stats.remove_mod_source("ant_fang_bonus")
			stats.remove_mod_source("glasswing_bonus")
			stats.remove_mod_source("greathorn_staff_bonus")
	print("[ItemEffectApplier] Restored items data state.")
