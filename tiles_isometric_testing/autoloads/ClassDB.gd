extends Node

# Data-driven class (order/path) definitions.
# Add new classes or buffs here to scale the system.

const CLASSES := {
	"slayer": {
		"name": "Slayer Order",
		"path": "Fighter",
		"faith": "VENIT / VIGIL",
		"buffs": {
			"blood_oath": {
				"name": "Blood Oath",
				"desc": "Gain ferocity in close combat.",
				"stat_mods": {"str": 2}
			},
			"iron_heart": {
				"name": "Iron Heart",
				"desc": "Endure through pain.",
				"stat_mods": {"vit": 2}
			}
		}
	},
	"hunter": {
		"name": "Hunter Order",
		"path": "Ranger",
		"faith": "EX TENEBRIS / VERITAS",
		"buffs": {
			"eagle_eye": {
				"name": "Eagle Eye",
				"desc": "Sharpen your aim.",
				"stat_mods": {"acc": 2}
			},
			"silent_steps": {
				"name": "Silent Steps",
				"desc": "Move unseen.",
				"stat_mods": {"mov": 5}
			}
		}
	},
	"scholar": {
		"name": "Scholar Order",
		"path": "Wizard",
		"faith": "ASTRA / REGNUM",
		"buffs": {
			"arcane_thesis": {
				"name": "Arcane Thesis",
				"desc": "Deepen magical understanding.",
				"stat_mods": {"int": 2}
			},
			"attuned_mind": {
				"name": "Attuned Mind",
				"desc": "Expand spell capacity.",
				"stat_mods": {"att": 10}
			}
		}
	},
	"soldier": {
		"name": "Soldier Order",
		"path": "Tank",
		"faith": "VIRTUS / INEXORABILIS",
		"buffs": {
			"bulwark": {
				"name": "Bulwark",
				"desc": "Harden your defense.",
				"stat_mods": {"con": 2}
			},
			"steady_guard": {
				"name": "Steady Guard",
				"desc": "Stand firm against force.",
				"stat_mods": {"vit": 2}
			}
		}
	},
	"cleric": {
		"name": "Cleric Order",
		"path": "Healer",
		"faith": "BENEVATIO",
		"buffs": {
			"gentle_light": {
				"name": "Gentle Light",
				"desc": "Restore and protect.",
				"stat_mods": {"vit": 2}
			},
			"sacred_focus": {
				"name": "Sacred Focus",
				"desc": "Channel divine magic.",
				"stat_mods": {"int": 2}
			}
		}
	}
}


func has_class(class_id: String) -> bool:
	return CLASSES.has(class_id)


func get_class_data(class_id: String) -> Dictionary:
	return CLASSES.get(class_id, {})


func list_classes() -> Array[String]:
	var keys: Array[String] = []
	for k in CLASSES.keys():
		keys.append(k)
	return keys


func has_buff(class_id: String, buff_id: String) -> bool:
	var cls := get_class_data(class_id)
	if cls.is_empty():
		return false
	return cls.get("buffs", {}).has(buff_id)


func get_buff(class_id: String, buff_id: String) -> Dictionary:
	var cls := get_class_data(class_id)
	if cls.is_empty():
		return {}
	return cls.get("buffs", {}).get(buff_id, {})
