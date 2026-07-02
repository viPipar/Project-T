extends Node

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
	CURSED
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
	
	# Determine rarity from JSON
	var r_str = json_data.get("rarity", "common").to_lower()
	var rarity = Rarity.COMMON
	match r_str:
		"common": rarity = Rarity.COMMON
		"rare": rarity = Rarity.RARE
		"epic": rarity = Rarity.EPIC
		"legendary": rarity = Rarity.LEGENDARY
		"cursed": rarity = Rarity.CURSED
	item["rarity"] = rarity
	
	# Icon path from JSON
	item["icon_path"] = json_data.get("icon_path", "res://assets/ui_assets/placeholder.jpeg")
	
	# Fallback description
	if not item.has("description"):
		item["description"] = "Modifies stats: " + str(json_data.get("stat_mods", {}))
		
	return item

func get_items_by_rarity(target_rarity: Rarity) -> Array[String]:
	var result: Array[String] = []
	if StatDataDB == null:
		return result
		
	for item_id in StatDataDB.get_item_ids():
		var item = get_item(item_id)
		if not item.is_empty() and item.get("rarity") == target_rarity:
			result.append(item_id)
	return result
