extends Node
class_name RestLootHandler

# Handles logic for Rest nodes and Loot nodes (including minigame).

const EventDropGenerator = preload("res://systems/events/ItemPoolGenerator.gd")

func _get_player(pid: int) -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		var p_id = p.get("player_id")
		if p_id != null and typeof(p_id) == TYPE_INT and p_id == pid:
			return p
	return null

func _cleanse_debuffs(player: Node, player_id: int) -> void:
	if RunManager != null and RunManager.has_method("remove_run_effects_by_duration"):
		RunManager.remove_run_effects_by_duration(player_id, "until_rest")

	if player == null:
		return

	if player.has_meta("luck_debuff_attr"):
		var attr = player.get_meta("luck_debuff_attr")
		var amount = player.get_meta("luck_debuff_amount")
		var stats = player.get_node_or_null("StatsComponent")
		if stats != null:
			var current_val = stats.get(attr)
			stats.set(attr, current_val - amount) # Add back the lost stat
			if stats.has_method("emit_changed"):
				stats.emit_changed()
			print("[RestLootHandler] Cleansed run debuff: %s (+%d)" % [attr, -amount])
		player.remove_meta("luck_debuff_attr")
		player.remove_meta("luck_debuff_amount")

func _get_player_max_hp(player_id: int, health_component: Node) -> int:
	if health_component != null:
		return int(health_component.get("max_hp")) if health_component.get("max_hp") != null else 20
	if RunManager != null and RunManager.has_method("get_run_max_hp"):
		return RunManager.get_run_max_hp(player_id)
	return 20

func _heal_player(player_id: int, health_component: Node, amount: int) -> void:
	if health_component != null and health_component.has_method("heal"):
		health_component.heal(amount)
	if RunManager != null and RunManager.has_method("heal_run_player"):
		RunManager.heal_run_player(player_id, amount)

func _damage_player(player_id: int, health_component: Node, amount: int) -> void:
	if health_component != null and health_component.has_method("take_damage"):
		health_component.take_damage(amount, null, "true_damage")
	if RunManager != null and RunManager.has_method("damage_run_player"):
		RunManager.damage_run_player(player_id, amount)

func _add_item(player_id: int, item_id: String) -> void:
	if InventoryManager != null:
		InventoryManager.add_item(player_id, item_id)
	elif RunManager != null and RunManager.has_method("add_run_item"):
		RunManager.add_run_item(player_id, item_id, false)

func _snapshot_or_save(player: Node, player_id: int) -> void:
	if RunManager == null:
		return
	if player != null and RunManager.has_method("snapshot_player_from_node"):
		RunManager.snapshot_player_from_node(player)
	elif RunManager.has_method("save_run_to_disk"):
		RunManager.save_run_to_disk()

func handle_rest_choice(player_id: int, option: int) -> void:
	var player = _get_player(player_id)
	if player == null and RunManager == null:
		print("[RestLootHandler] Player %d not found!" % player_id)
		return
		
	var hc = player.get_node_or_null("HealthComponent") if player != null else null
		
	match option:
		0: # FULL_REST (Option A: +50% HP + +50% resource restore)
			print("[RestLootHandler] P%d selected Full Rest." % player_id)
			var full_rest_max_hp = _get_player_max_hp(player_id, hc)
			_heal_player(player_id, hc, int(full_rest_max_hp * 0.5))
			_cleanse_debuffs(player, player_id)
			
			# Restore 50% spell slots or energy charges
			var bridge = get_tree().root.find_child("CombatTestBridge", true, false)
			if bridge != null:
				var p1_ec = bridge.get("_p1_ec")
				var p2_ss = bridge.get("_p2_ss")
				if player_id == 1 and p1_ec != null:
					p1_ec.restore_percent(0.5)
				elif player_id == 2 and p2_ss != null:
					p2_ss.restore_percent(0.5)
					
			if RunManager != null:
				if player_id == 1 and RunManager.p1_saved_energy != -1:
					var max_charges = 99
					RunManager.p1_saved_energy = clampi(RunManager.p1_saved_energy + int(max_charges * 0.5), 0, max_charges)
					RunManager.set_run_resource(player_id, "energy", RunManager.p1_saved_energy)
				elif player_id == 2 and RunManager.p2_saved_slots.size() == 4:
					var max_slots = [99, 99, 99, 99]
					for i in range(4):
						RunManager.p2_saved_slots[i] = clampi(RunManager.p2_saved_slots[i] + int(max_slots[i] * 0.5), 0, max_slots[i])
					RunManager.set_run_resource(player_id, "spell_slots", RunManager.p2_saved_slots)
					
			EventNotifier.show_message("P%d Full Rest: +50%% HP & +50%% Resources" % player_id, Color.GREEN)
			var am = get_node_or_null("/root/AudioManager")
			if am != null: am.play_sfx("reveal_rare")
			_snapshot_or_save(player, player_id)
			
		1: # PARTIAL_REST (Option B: +25% HP + +100% resource restore)
			print("[RestLootHandler] P%d selected Partial Rest." % player_id)
			var partial_rest_max_hp = _get_player_max_hp(player_id, hc)
			_heal_player(player_id, hc, int(partial_rest_max_hp * 0.25))
			_cleanse_debuffs(player, player_id)
			
			# Restore 100% spell slots or energy charges
			var bridge = get_tree().root.find_child("CombatTestBridge", true, false)
			if bridge != null:
				var p1_ec = bridge.get("_p1_ec")
				var p2_ss = bridge.get("_p2_ss")
				if player_id == 1 and p1_ec != null:
					p1_ec.restore_percent(1.0)
				elif player_id == 2 and p2_ss != null:
					p2_ss.restore_percent(1.0)
					
			if RunManager != null:
				if player_id == 1:
					RunManager.p1_saved_energy = -1
					RunManager.set_run_resource(player_id, "energy", -1)
				elif player_id == 2:
					RunManager.p2_saved_slots.clear()
					RunManager.set_run_resource(player_id, "spell_slots", [])
					
			EventNotifier.show_message("P%d Partial Rest: +25%% HP & +100%% Resources" % player_id, Color.YELLOW_GREEN)
			var am = get_node_or_null("/root/AudioManager")
			if am != null: am.play_sfx("reveal_rare")
			_snapshot_or_save(player, player_id)
			
		2: # TREASURE SEARCH (Option C: 70% safe, 20% trap, 10% jackpot)
			print("[RestLootHandler] P%d selected Treasure Search." % player_id)
			var roll = randf()
			if roll < 0.70:
				# SUCCESS: Gain 1-2 random items (safe)
				var count = 1 if randf() < 0.5 else 2
				var items: Array[String] = []
				for i in range(count):
					items.append(EventDropGenerator.generate_drop("normal"))
				for item in items:
					_add_item(player_id, item)
				print("[RestLootHandler] Treasure Search Success: found %s" % str(items))
				EventNotifier.show_message("Success! Found: %s" % str(items), Color.GOLD)
				var am = get_node_or_null("/root/AudioManager")
				if am != null: am.play_sfx("reveal_rare")
			elif roll < 0.90:
				# TRAP: -30% HP + Gain 1 random Common item
				var trap_max_hp = _get_player_max_hp(player_id, hc)
				_damage_player(player_id, hc, int(trap_max_hp * 0.3))
				var commons = ["iron_sword", "potion_small"]
				if ItemRegistry != null:
					commons = ItemRegistry.get_items_by_rarity(ItemRegistry.Rarity.COMMON)
				var item = commons[randi() % commons.size()] if commons.size() > 0 else "potion_small"
				_add_item(player_id, item)
				print("[RestLootHandler] Treasure Search TRAP: -30% HP, got %s" % item)
				EventNotifier.show_message("TRAP! Took damage but found Common: %s" % item, Color.ORANGE_RED)
				var am = get_node_or_null("/root/AudioManager")
				if am != null: am.play_sfx("ui_error")
			else:
				# JACKPOT: Gain 1 Legendary item (safe)
				var legendaries = ["berserker_axe"]
				if ItemRegistry != null:
					legendaries = ItemRegistry.get_items_by_rarity(ItemRegistry.Rarity.LEGENDARY)
				var item = legendaries[randi() % legendaries.size()] if legendaries.size() > 0 else "berserker_axe"
				_add_item(player_id, item)
				print("[RestLootHandler] Treasure Search JACKPOT: got Legendary %s" % item)
				EventNotifier.show_message("JACKPOT! Found Legendary: %s!" % item, Color.GOLD)
				var am = get_node_or_null("/root/AudioManager")
				if am != null: am.play_sfx("reveal_legendary")
			_snapshot_or_save(player, player_id)
				
		3: # CURSED ITEM REMOVAL (Option D: purge cursed item, no healing/resources)
			print("[RestLootHandler] P%d selected Cursed Item Removal." % player_id)
			var cursed_removed = false
			if InventoryManager != null and ItemRegistry != null:
				var items = InventoryManager.get_player_items(player_id)
				for item_id in items:
					var item_data = ItemRegistry.get_item(item_id)
					if not item_data.is_empty() and item_data.get("rarity") == ItemRegistry.Rarity.CURSED:
						InventoryManager.remove_item(player_id, item_id)
						print("[RestLootHandler] Removed cursed item %s from P%d." % [item_id, player_id])
						EventNotifier.show_message("Cursed Item Removed: %s purged!" % item_id, Color.PURPLE)
						var am = get_node_or_null("/root/AudioManager")
						if am != null: am.play_sfx("ui_cancel")
						cursed_removed = true
						break
			elif RunManager != null and ItemRegistry != null:
				var items = RunManager.get_player_state(player_id).get("items", [])
				for item_id in items:
					var item_data = ItemRegistry.get_item(str(item_id))
					if not item_data.is_empty() and item_data.get("rarity") == ItemRegistry.Rarity.CURSED:
						RunManager.remove_run_item(player_id, str(item_id), false)
						cursed_removed = true
						break
			if not cursed_removed:
				print("[RestLootHandler] No cursed items found to remove.")
				EventNotifier.show_message("No Cursed Items found in inventory.", Color.GRAY)
				var am = get_node_or_null("/root/AudioManager")
				if am != null: am.play_sfx("ui_error")
			_snapshot_or_save(player, player_id)

# ── LOOT MINIGAME ────────────────────────────────────────────────────────────

func start_loot_minigame() -> void:
	print("[RestLootHandler] Starting Loot Minigame (3-Card Monte)...")
	EventNotifier.show_message("Loot Minigame Started!", Color.WHITE)

func resolve_loot_minigame(player_id: int, choice_index: int, correct_index: int) -> void:
	if choice_index == correct_index:
		print("[RestLootHandler] P%d won the minigame! Legendary Reward!" % player_id)
		_add_item(player_id, "berserker_axe")
		EventNotifier.show_message("Minigame Won! P%d got Legendary Item", Color.GOLD)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_legendary")
	else:
		print("[RestLootHandler] P%d lost the minigame! Common Reward." % player_id)
		_add_item(player_id, "potion_small")
		EventNotifier.show_message("Minigame Lost... P%d got Potion", Color.GRAY)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_error")
