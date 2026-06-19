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
	var item = StatDataDB.get_item_data(item_id)
	if item.is_empty():
		return
		
	var on_use = item.get("on_use", {})
	if on_use.has("heal"):
		print("[ItemEffectApplier] Healing P%d for %d HP" % [player_id, on_use.get("heal", 0)])
		if player_node != null and player_node.has_node("HealthComponent"):
			var hc = player_node.get_node("HealthComponent")
			if hc.has_method("heal"):
				hc.heal(on_use.get("heal", 0))

func recalculate_player_stats(player_node: Node, player_id: int) -> void:
	var stats = player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
		
	# Clear previous item modifiers
	stats.clear_mod_sources("item:")
	
	var items = InventoryManager.get_player_items(player_id)
	for i in range(items.size()):
		var item_id = items[i]
		
		# Menggunakan StatDataDB (Arsitektur Resmi Candra)
		var item_data: Dictionary = StatDataDB.get_item_data(item_id)
		if item_data.is_empty():
			continue
			
		var stat_mods = item_data.get("stat_mods", {})
		if stat_mods.is_empty():
			continue
			
		var source_id: String = str(item_data.get("source_id", "item:%s" % item_id))
		# Tambahkan index agar item kembar (stack) tidak saling menimpa
		source_id = "%s_%d" % [source_id, i]
		
		StatDataDB.apply_stat_mod(player_node, source_id, stat_mods)

func _on_turn_started(entity: Node, player_id: int) -> void:
	if player_id < 1:
		return # Not a player
		
	# Apply turn-based passive effects (e.g., Cursed Amulet, Berserker Axe)
	var items = InventoryManager.get_player_items(player_id)
	for item_id in items:
		var item = StatDataDB.get_item_data(item_id)
		if item.is_empty():
			continue
			
		var on_turn = item.get("on_turn", {})
		
		# Handle negative passive (Curse)
		if on_turn.has("damage_per_turn"):
			print("[ItemEffectApplier] P%d takes %d damage from %s" % [player_id, on_turn.get("damage_per_turn", 0), item.get("display_name", "")])
			if entity.has_node("HealthComponent"):
				var hc = entity.get_node("HealthComponent")
				if hc.has_method("take_damage"):
					hc.take_damage(on_turn.get("damage_per_turn", 0), null, "true_damage")
