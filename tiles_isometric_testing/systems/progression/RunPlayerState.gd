extends RefCounted
class_name RunPlayerState

const DEFAULT_BASE_STATS := {
	"vit": 0,
	"str": 0,
	"int": 0,
	"con": 0,
	"acc": 0,
	"dex": 0,
	"mov": 0,
	"att": 0,
	"lck": 0,
}

const DEFAULT_RESOURCES := {
	"energy": -1,
	"spell_slots": [],
}

const VALID_DURATION_TYPES := [
	"permanent",
	"nodes",
	"battles",
	"turns",
	"until_rest",
	"until_run_end",
]


static func create(player_id: int, base_stats: Dictionary = {}, current_hp: int = -1, coins: int = 0) -> Dictionary:
	var state := {
		"player_id": player_id,
		"base_stats": sanitize_base_stats(base_stats),
		"current_hp": current_hp,
		"max_hp": maxi(1, current_hp),
		"resources": DEFAULT_RESOURCES.duplicate(true),
		"items": [],
		"active_effects": [],
		"coins": maxi(0, coins),
	}
	return state


static func sanitize_state(raw_state: Variant, player_id: int) -> Dictionary:
	var raw: Dictionary = {}
	if raw_state is Dictionary:
		raw = raw_state as Dictionary
	var state := create(player_id)

	state["base_stats"] = sanitize_base_stats(raw.get("base_stats", {}))
	state["current_hp"] = int(raw.get("current_hp", state["current_hp"]))
	state["max_hp"] = maxi(1, int(raw.get("max_hp", state["max_hp"])))
	state["resources"] = sanitize_resources(raw.get("resources", {}))
	state["items"] = sanitize_items(raw.get("items", []))
	state["active_effects"] = sanitize_effects(raw.get("active_effects", []))
	state["coins"] = maxi(0, int(raw.get("coins", 0)))

	return state


static func sanitize_base_stats(raw_stats: Variant) -> Dictionary:
	var clean := DEFAULT_BASE_STATS.duplicate()
	if not (raw_stats is Dictionary):
		return clean

	var source: Dictionary = raw_stats as Dictionary
	for key in source.keys():
		var stat_key := normalize_stat_key(str(key))
		if clean.has(stat_key):
			clean[stat_key] = maxi(0, int(source[key]))
	return clean


static func sanitize_resources(raw_resources: Variant) -> Dictionary:
	var clean := DEFAULT_RESOURCES.duplicate(true)
	if not (raw_resources is Dictionary):
		return clean

	var source: Dictionary = raw_resources as Dictionary
	clean["energy"] = int(source.get("energy", clean["energy"]))

	var spell_slots: Array = []
	var raw_slots: Variant = source.get("spell_slots", [])
	if raw_slots is Array:
		for slot_value in raw_slots:
			spell_slots.append(maxi(0, int(slot_value)))
	clean["spell_slots"] = spell_slots

	return clean


static func sanitize_items(raw_items: Variant) -> Array:
	var clean: Array = []
	if not (raw_items is Array):
		return clean
	for item in raw_items:
		var item_id := str(item).strip_edges()
		if item_id != "":
			clean.append(item_id)
	return clean


static func sanitize_effects(raw_effects: Variant) -> Array:
	var clean: Array = []
	if not (raw_effects is Array):
		return clean
	for effect in raw_effects:
		if effect is Dictionary:
			var normalized := sanitize_effect(effect as Dictionary)
			if not normalized.is_empty():
				clean.append(normalized)
	return clean


static func sanitize_effect(raw_effect: Dictionary) -> Dictionary:
	var kind := str(raw_effect.get("kind", "effect")).strip_edges()
	if kind == "":
		kind = "effect"

	var effect_id := str(raw_effect.get("id", "")).strip_edges()
	var source_id := str(raw_effect.get("source_id", "")).strip_edges()
	if effect_id == "" and source_id != "":
		effect_id = source_id.get_slice(":", 1) if source_id.find(":") != -1 else source_id
	if effect_id == "":
		return {}
	if source_id == "":
		source_id = "%s:%s" % [kind, effect_id]

	var mods := sanitize_mods(_extract_mods(raw_effect))
	var duration_type := str(raw_effect.get("duration_type", "permanent")).strip_edges()
	if not VALID_DURATION_TYPES.has(duration_type):
		duration_type = "permanent"

	return {
		"id": effect_id,
		"kind": kind,
		"source_id": source_id,
		"mods": mods,
		"stacks": maxi(1, int(raw_effect.get("stacks", 1))),
		"duration_type": duration_type,
		"remaining": int(raw_effect.get("remaining", -1)),
	}


static func sanitize_mods(raw_mods: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not (raw_mods is Dictionary):
		return clean

	var source: Dictionary = raw_mods as Dictionary
	for key in source.keys():
		var stat_key := normalize_stat_key(str(key))
		var value := int(source[key])
		if stat_key != "" and value != 0:
			clean[stat_key] = value
	return clean


static func normalize_stat_key(raw_key: String) -> String:
	var key := raw_key.strip_edges()
	match key:
		"str_stat":
			return "str"
		"int_stat":
			return "int"
	return key


static func to_save_dict(state: Dictionary) -> Dictionary:
	var player_id := int(state.get("player_id", 0))
	return sanitize_state(state, player_id)


static func _extract_mods(raw_effect: Dictionary) -> Dictionary:
	for key in ["mods", "stat_mods", "modifiers"]:
		if raw_effect.has(key) and raw_effect[key] is Dictionary:
			return raw_effect[key]
	return {}
