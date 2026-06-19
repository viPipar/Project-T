extends Node
class_name WinLoseHandler

# Handles post-battle win/lose states and rewards.

func handle_win(battle_type: String) -> void:
	print("[WinLoseHandler] Processing Win State for %s battle..." % battle_type)
	EventNotifier.show_message("Battle Won!", Color.GOLD)
	
	# 1. Distribute Coins (Mocking global economy if needed, skipping for now)
	# 2. Distribute Items
	var rewards = []
	if ItemRegistry != null and ItemRegistry.get("items") != null:
		var items = ItemRegistry.items.keys()
		rewards.append(items[randi() % items.size()])
		rewards.append(items[randi() % items.size()])
	else:
		rewards = ["potion_small", "iron_sword"]
	
	if InventoryManager != null:
		InventoryManager.add_item(1, rewards[0])
		InventoryManager.add_item(2, rewards[1])
	print("[WinLoseHandler] Win Rewards distributed: %s" % str(rewards))
	EventNotifier.show_message("Loot Acquired: " + str(rewards), Color.AQUAMARINE)
	
	# 3. Heal
	if battle_type == "boss":
		print("[WinLoseHandler] Boss Defeated! Full Heal applied.")
		EventNotifier.show_message("Boss Defeated! Full Heal!", Color.GREEN)
		for p in get_tree().get_nodes_in_group("players"):
			var hc = p.get_node_or_null("HealthComponent")
			if hc and hc.has_method("heal"):
				hc.heal(9999, null)

func handle_lose() -> void:
	print("[WinLoseHandler] Processing Lose State...")
	print("[WinLoseHandler] Applying -50% HP Penalty and Cursed Item.")
	EventNotifier.show_message("Party Defeated... -50% HP", Color.RED)
	EventNotifier.show_message("Received Cursed Amulet", Color.PURPLE)
	
	for p in get_tree().get_nodes_in_group("players"):
		var hc = p.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			var max_hp = hc.get("max_hp") if hc.get("max_hp") != null else 20
			hc.take_damage(int(max_hp * 0.5), null, "true_damage")
		
		var pid = p.get("player_id")
		if pid != null and typeof(pid) == TYPE_INT and InventoryManager != null:
			InventoryManager.add_item(pid, "cursed_amulet")
