extends Node

# Listens to events and applies item effects to players based on their inventory.

func _ready() -> void:
	if EventBus != null:
		# Connect to TurnManager or EventBus for turn-based effects
		if not EventBus.turn_started.is_connected(_on_turn_started):
			EventBus.turn_started.connect(_on_turn_started)
			
	if InventoryManager != null:
		if not InventoryManager.item_added.is_connected(_on_inventory_changed):
			InventoryManager.item_added.connect(_on_inventory_changed)
		if not InventoryManager.item_removed.is_connected(_on_inventory_changed):
			InventoryManager.item_removed.connect(_on_inventory_changed)

func _on_inventory_changed(player_id: int, _item_id: String) -> void:
	if TurnManager != null and TurnManager.has_method("_get_player_by_id"):
		var player = TurnManager._get_player_by_id(player_id)
		if player != null:
			recalculate_player_stats(player, player_id)

func apply_immediate_effect(player_id: int, item_id: String, player_node: Node = null) -> void:
	var item = ItemRegistry.get_item(item_id)
	if item.is_empty():
		return
		
	var effect = item.get("effect", {})
	if effect.get("type") == "heal":
		print("[ItemEffectApplier] Healing P%d for %d HP" % [player_id, effect.get("amount", 0)])
		if player_node != null and player_node.has_node("HealthComponent"):
			var hc = player_node.get_node("HealthComponent")
			if hc.has_method("heal"):
				hc.heal(effect.get("amount", 0))

func recalculate_player_stats(player_node: Node, player_id: int) -> void:
	var stats = player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
		
	# Clear previous item modifiers
	stats.clear_mod_sources("item:")
	
	var items = InventoryManager.get_player_items(player_id)
	for i in range(items.size()):
		var item_id = items[i]
		var item = ItemRegistry.get_item(item_id)
		if item.is_empty() or not item.has("effect"):
			continue
			
		var effect = item.get("effect", {})
		var type = effect.get("type", "")
		
		# Parse stat_mod or stat_mod_complex
		var stat_dict = {}
		
		if type == "stat_mod":
			var stat_name = effect.get("stat", "")
			var amount = effect.get("amount", 0)
			if stat_name == "damage":
				stat_dict["physical_damage"] = amount
				stat_dict["magical_damage"] = amount
			elif stat_name == "max_spell_slots":
				pass 
			else:
				stat_dict[stat_name] = amount
				
		elif type == "stat_mod_complex" and effect.has("buff"):
			var buff = effect.get("buff", {})
			var stat_name = buff.get("stat", "")
			var amount = buff.get("amount", 0)
			if stat_name == "damage":
				stat_dict["physical_damage"] = amount
				stat_dict["magical_damage"] = amount
			else:
				stat_dict[stat_name] = amount
				
		if not stat_dict.is_empty():
			stats.set_mod_source("item:%s_%d" % [item_id, i], stat_dict)

func _on_turn_started(entity: Node, player_id: int) -> void:
	if player_id < 1:
		return # Not a player
		
	# Apply turn-based passive effects (e.g., Cursed Amulet, Berserker Axe)
	var items = InventoryManager.get_player_items(player_id)
	for item_id in items:
		var item = ItemRegistry.get_item(item_id)
		if item.is_empty():
			continue
			
		var effect = item.get("effect", {})
		
		# Example: Handle negative passive (Curse)
		if effect.get("type") == "stat_mod_complex":
			var curse = effect.get("curse", {})
			if curse.get("type") == "damage_per_turn":
				print("[ItemEffectApplier] P%d takes %d damage from %s" % [player_id, curse.get("amount", 0), item["name"]])
				if entity.has_node("HealthComponent"):
					var hc = entity.get_node("HealthComponent")
					if hc.has_method("take_damage"):
						hc.take_damage(curse.get("amount", 0), null, "true_damage")
