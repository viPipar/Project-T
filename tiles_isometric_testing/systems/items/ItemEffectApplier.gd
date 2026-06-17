extends Node
class_name ItemEffectApplier

# Listens to events and applies item effects to players based on their inventory.

var inventory_manager: InventoryManager
var item_registry: ItemRegistry

func init(_inventory: InventoryManager, _registry: ItemRegistry) -> void:
	self.inventory_manager = _inventory
	self.item_registry = _registry
	
	if EventBus != null:
		# Connect to TurnManager or EventBus for turn-based effects
		if not EventBus.turn_started.is_connected(_on_turn_started):
			EventBus.turn_started.connect(_on_turn_started)

func apply_immediate_effect(player_id: int, item_id: String) -> void:
	var item = item_registry.get_item(item_id)
	if item.is_empty():
		return
		
	var effect = item.get("effect", {})
	if effect.get("type") == "heal":
		# e.g., call Candra's HP system
		print("[ItemEffectApplier] Healing P%d for %d HP" % [player_id, effect.get("amount", 0)])

func _on_turn_started(entity: Node, player_id: int) -> void:
	if player_id < 1:
		return # Not a player
		
	# Apply turn-based passive effects (e.g., Cursed Amulet, Berserker Axe)
	var items = inventory_manager.get_player_items(player_id)
	for item_id in items:
		var item = item_registry.get_item(item_id)
		if item.is_empty():
			continue
			
		var effect = item.get("effect", {})
		
		# Example: Handle negative passive (Curse)
		if effect.get("type") == "stat_mod_complex":
			var curse = effect.get("curse", {})
			if curse.get("type") == "damage_per_turn":
				print("[ItemEffectApplier] P%d takes %d damage from %s" % [player_id, curse.get("amount", 0), item["name"]])
				# Call Candra's damage system here
