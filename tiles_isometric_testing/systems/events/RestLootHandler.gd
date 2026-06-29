extends Node
class_name RestLootHandler

# Handles logic for Rest nodes and Loot nodes (including minigame).

func _get_player(pid: int) -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		var p_id = p.get("player_id")
		if p_id != null and typeof(p_id) == TYPE_INT and p_id == pid:
			return p
	return null

func handle_rest_choice(player_id: int, option: int) -> void:
	var player = _get_player(player_id)
	if player == null:
		print("[RestLootHandler] Player %d not found!" % player_id)
		return
		
	var hc = player.get_node_or_null("HealthComponent")
	var stats = player.get_node_or_null("StatsComponent")
		
	match option:
		0: # FULL_HEAL
			print("[RestLootHandler] P%d selected Full Heal." % player_id)
			if hc != null:
				hc.heal_to_full() if is_instance_valid(hc) and hc.has_method("heal_to_full") else hc.heal(9999)
			EventNotifier.show_message("P%d Rested: Full HP Restored" % player_id, Color.GREEN)
		1: # PARTIAL_HEAL_BUFF
			print("[RestLootHandler] P%d selected Partial Heal + Buff." % player_id)
			if hc != null:
				var max_hp = hc.get("max_hp") if hc.get("max_hp") != null else 20
				hc.heal(int(max_hp * 0.3))
			if InventoryManager != null:
				InventoryManager.add_item(player_id, "potion_small")
			EventNotifier.show_message("P%d Rested: +30%% HP and Potion" % player_id, Color.YELLOW_GREEN)
		2: # TREASURE
			print("[RestLootHandler] P%d selected Treasure." % player_id)
			if InventoryManager != null:
				var items = ["magic_ring", "berserker_axe"]
				if ItemRegistry != null and ItemRegistry.get("items") != null:
					items = ItemRegistry.items.keys()
				var reward = items[randi() % items.size()]
				InventoryManager.add_item(player_id, reward)
				EventNotifier.show_message("P%d Digs up Treasure: %s!" % [player_id, reward], Color.GOLD)

# ── LOOT MINIGAME ────────────────────────────────────────────────────────────

func start_loot_minigame() -> void:
	print("[RestLootHandler] Starting Loot Minigame (3-Card Monte)...")
	EventNotifier.show_message("Loot Minigame Started!", Color.WHITE)

func resolve_loot_minigame(player_id: int, choice_index: int, correct_index: int) -> void:
	if choice_index == correct_index:
		print("[RestLootHandler] P%d won the minigame! Legendary Reward!" % player_id)
		if InventoryManager != null:
			InventoryManager.add_item(player_id, "berserker_axe")
		EventNotifier.show_message("Minigame Won! P%d got Legendary Item", Color.GOLD)
	else:
		print("[RestLootHandler] P%d lost the minigame! Common Reward." % player_id)
		if InventoryManager != null:
			InventoryManager.add_item(player_id, "potion_small")
		EventNotifier.show_message("Minigame Lost... P%d got Potion", Color.GRAY)
