extends Node
class_name ItemPoolGenerator

# Generates items based on rarity weightings for different battle types.

var item_registry: ItemRegistry
var balancing_data: BalancingData

func init(_registry: ItemRegistry, _balancing: BalancingData) -> void:
	self.item_registry = _registry
	self.balancing_data = _balancing

func roll_item(battle_type: String) -> String:
	# 1. Determine rarity based on balancing data
	var rarity_str = BalancingData.get_item_rarity(battle_type)
	
	var target_rarity = ItemRegistry.Rarity.COMMON
	match rarity_str:
		"common": target_rarity = ItemRegistry.Rarity.COMMON
		"rare": target_rarity = ItemRegistry.Rarity.RARE
		"legendary": target_rarity = ItemRegistry.Rarity.LEGENDARY
	
	# 2. Get items of that rarity
	var pool = item_registry.get_items_by_rarity(target_rarity)
	
	if pool.is_empty():
		return ""
		
	# 3. Pick random item from pool
	return pool[randi() % pool.size()]

func generate_reward_pool(battle_type: String, amount: int) -> Array[String]:
	var rewards: Array[String] = []
	for i in range(amount):
		rewards.append(roll_item(battle_type))
	return rewards
