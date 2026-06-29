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
	if is_instance_valid(TurnManager) and TurnManager.has_method("_get_player_by_id"):
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
			if is_instance_valid(hc) and hc.has_method("heal"):
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
		# Let's try StatDataDB first, then fallback to ItemRegistry
		var on_turn = {}
		var item_name = ""
		
		var item_data = StatDataDB.get_item_data(item_id)
		if not item_data.is_empty():
			on_turn = item_data.get("on_turn", {})
			item_name = item_data.get("display_name", item_id)
		elif ItemRegistry != null:
			var reg_item = ItemRegistry.get_item(item_id)
			if not reg_item.is_empty():
				item_name = reg_item.get("name", item_id)
				var effect = reg_item.get("effect", {})
				if effect.get("type") == "stat_mod_complex" and effect.has("curse"):
					if effect["curse"].get("type") == "damage_per_turn":
						on_turn["damage_per_turn"] = effect["curse"].get("amount", 0)
					if effect["curse"].get("type") == "ap_drain":
						on_turn["ap_drain"] = effect["curse"].get("amount", 0)
				elif effect.get("type") == "stat_mod" and effect.get("stat") == "ap" and effect.get("amount", 0) < 0:
					# Explicitly handle cursed_amulet style
					on_turn["ap_drain"] = abs(effect.get("amount", 0))
		
		if on_turn.is_empty():
			continue
			
		# Handle negative passive (Curse)
		if on_turn.has("damage_per_turn"):
			print("[ItemEffectApplier] P%d takes %d damage from %s" % [player_id, on_turn.get("damage_per_turn", 0), item_name])
			if entity.has_node("HealthComponent"):
				var hc = entity.get_node("HealthComponent")
				if is_instance_valid(hc) and hc.has_method("take_damage"):
					hc.take_damage(on_turn.get("damage_per_turn", 0), null, "true_damage")
					EventNotifier.show_message("Curse! P%d took damage!" % player_id, Color.PURPLE)
					
		if on_turn.has("ap_drain"):
			print("[ItemEffectApplier] P%d loses %d AP from %s" % [player_id, on_turn.get("ap_drain", 0), item_name])
			var bridge = entity.get_tree().get_root().find_child("CombatTestBridge", true, false)
			if bridge:
				var ap_mgr = bridge.get("_p%d_ap" % player_id)
				if ap_mgr and ap_mgr.has_method("spend_ap"):
					ap_mgr.spend_ap(on_turn.get("ap_drain", 0))
					EventNotifier.show_message("Curse! P%d lost AP!" % player_id, Color.PURPLE)
