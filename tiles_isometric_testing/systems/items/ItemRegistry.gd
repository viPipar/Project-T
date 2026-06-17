extends Node
class_name ItemRegistry

enum Rarity {
	COMMON,
	RARE,
	LEGENDARY,
	CURSED
}

# In a real scenario, this would likely load from JSON or Custom Resources.
# For now, it's defined in code.
var items: Dictionary = {
	"potion_small": {
		"id": "potion_small",
		"name": "Small Potion",
		"type": "consumable",
		"rarity": Rarity.COMMON,
		"description": "Heals 10 HP.",
		"effect": { "type": "heal", "amount": 10 }
	},
	"iron_sword": {
		"id": "iron_sword",
		"name": "Iron Sword",
		"type": "equipment",
		"rarity": Rarity.COMMON,
		"description": "+2 Base Damage.",
		"effect": { "type": "stat_mod", "stat": "damage", "amount": 2 }
	},
	"magic_ring": {
		"id": "magic_ring",
		"name": "Magic Ring",
		"type": "equipment",
		"rarity": Rarity.RARE,
		"description": "+1 Spell Slot max.",
		"effect": { "type": "stat_mod", "stat": "max_spell_slots", "amount": 1 }
	},
	"berserker_axe": {
		"id": "berserker_axe",
		"name": "Berserker Axe",
		"type": "equipment",
		"rarity": Rarity.LEGENDARY,
		"description": "+5 Damage, but take 1 damage per turn.",
		"effect": { "type": "stat_mod_complex", "buff": {"stat": "damage", "amount": 5}, "curse": {"type": "damage_per_turn", "amount": 1} }
	},
	"cursed_amulet": {
		"id": "cursed_amulet",
		"name": "Cursed Amulet",
		"type": "equipment",
		"rarity": Rarity.CURSED,
		"description": "Lose 1 AP per turn.",
		"effect": { "type": "stat_mod", "stat": "ap", "amount": -1 }
	}
}

func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})

func get_items_by_rarity(target_rarity: Rarity) -> Array[String]:
	var result: Array[String] = []
	for item_id in items:
		if items[item_id]["rarity"] == target_rarity:
			result.append(item_id)
	return result
