extends Node
class_name EventDropGenerator

# Deterministic pool generator based on battle difficulty
# Normal Battles: 80% Common, 20% Rare.
# Elite Battles: 20% Common, 70% Rare, 10% Legendary.
# Boss Battles: 100% Guaranteed Legendary.

static func generate_drop(battle_type: String) -> String:
	var roll = randf()
	var rarity = ItemRegistry.Rarity.COMMON
	
	if battle_type == "normal" or battle_type == "battle":
		if roll > 0.80:
			rarity = ItemRegistry.Rarity.RARE
		else:
			rarity = ItemRegistry.Rarity.COMMON
			
	elif battle_type == "elite":
		if roll <= 0.20:
			rarity = ItemRegistry.Rarity.COMMON
		elif roll <= 0.90:
			rarity = ItemRegistry.Rarity.RARE
		else:
			rarity = ItemRegistry.Rarity.LEGENDARY
			
	elif battle_type == "boss":
		rarity = ItemRegistry.Rarity.LEGENDARY
	
	# Default fallback
	else:
		rarity = ItemRegistry.Rarity.COMMON
		
	var pool = ItemRegistry.get_items_by_rarity(rarity)
	if pool.size() > 0:
		pool.shuffle()
		return pool[0]
	return "potion_small" # Fallback
