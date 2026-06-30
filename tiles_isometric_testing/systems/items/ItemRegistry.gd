extends Node

enum Rarity {
	COMMON,
	RARE,
	LEGENDARY,
	CURSED
}

const ITEM_RARITY_MAP: Dictionary = {
	"ring_str": Rarity.COMMON,
	"iron_armor": Rarity.COMMON,
	"sage_charm": Rarity.RARE,
	"swift_boots": Rarity.RARE,
	"potion_small": Rarity.COMMON,
	"iron_sword": Rarity.COMMON,
	"magic_ring": Rarity.RARE,
	"berserker_axe": Rarity.LEGENDARY,
	"cursed_amulet": Rarity.CURSED
}

var items: Dictionary:
	get:
		var dict = {}
		if StatDataDB != null:
			for id in StatDataDB.get_item_ids():
				dict[id] = get_item(id)
		return dict

func get_item(item_id: String) -> Dictionary:
	if StatDataDB == null:
		return {}
		
	var json_data = StatDataDB.get_item_data(item_id)
	if json_data.is_empty():
		return {}
		
	var item = json_data.duplicate()
	item["id"] = item_id
	item["name"] = json_data.get("display_name", item_id)
	item["type"] = json_data.get("item_type", "equipment")
	
	# Determine rarity
	var rarity = ITEM_RARITY_MAP.get(item_id, Rarity.COMMON)
	item["rarity"] = rarity
	
	# Fallback description
	if not item.has("description"):
		item["description"] = "Modifies stats: " + str(json_data.get("stat_mods", {}))
		
	return item

func get_items_by_rarity(target_rarity: Rarity) -> Array[String]:
	var result: Array[String] = []
	if StatDataDB == null:
		return result
		
	for item_id in StatDataDB.get_item_ids():
		var r = ITEM_RARITY_MAP.get(item_id, Rarity.COMMON)
		if r == target_rarity:
			result.append(item_id)
	return result
