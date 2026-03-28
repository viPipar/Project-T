extends Node
class_name StatsComponent

# Primary stats (as requested):
# VIT (Vitality)      : 2 VIT = +1 HP, 4 VIT = +1 Resist
# STR (Strength)      : 2 STR = +1 Physical Damage, 4 STR = +1 HP
# INT (Intelligence)  : 2 INT = +1 Magical Damage, 10 INT = +1 Bonus Action Point
# CON (Constitution)  : 2 CON = +1 Armor, 4 CON = +1 Resist
# ACC (Accuracy)      : 2 ACC = +1 Hit Roll, 10 ACC = -1 Natural Crit Roll
# DEX (Dexterity)     : 4 DEX = +1 Armor, 10 DEX = +1 Action Point
# MOV (Movement)      : 5 MOV = +1 Tiles
# ATT (Attunement)    : 10 ATT = +1 Spell Slot L1, 15 ATT = +1 Spell Slot L2, 20 ATT = +1 Spell Slot L3
# LCK (Luck)          : 5 LCK = +1 Luck Event Roll

signal stats_changed

@export_group("Primary Stats")
@export var vit: int = 0
@export var str_stat: int = 0
@export var int_stat: int = 0
@export var con: int = 0
@export var acc: int = 0
@export var dex: int = 0
@export var mov: int = 0
@export var att: int = 0
@export var lck: int = 0

var _external_mods: Dictionary = {}


func emit_changed() -> void:
	stats_changed.emit()
	EventBus.stats_changed.emit(owner)

func set_external_mods(mods: Dictionary) -> void:
	_external_mods = mods.duplicate()
	stats_changed.emit()
	EventBus.stats_changed.emit(owner)

func get_base_stat(stat_key: String) -> int:
	match stat_key:
		"vit": return vit
		"str": return str_stat
		"int": return int_stat
		"con": return con
		"acc": return acc
		"dex": return dex
		"mov": return mov
		"att": return att
		"lck": return lck
	return 0

func get_stat(stat_key: String) -> int:
	return get_base_stat(stat_key) + int(_external_mods.get(stat_key, 0))


# --- Derived Modifiers ---

func bonus_hp() -> int:
	return _div(get_stat("vit"), 2) + _div(get_stat("str"), 4)


func bonus_resist() -> int:
	return _div(get_stat("vit"), 4) + _div(get_stat("con"), 4)


func bonus_physical_damage() -> int:
	return _div(get_stat("str"), 2)


func bonus_magical_damage() -> int:
	return _div(get_stat("int"), 2)


func bonus_action_points() -> int:
	return _div(get_stat("int"), 10) + _div(get_stat("dex"), 10)


func bonus_armor() -> int:
	return _div(get_stat("con"), 2) + _div(get_stat("dex"), 4)


func hit_roll_bonus() -> int:
	return _div(get_stat("acc"), 2)


func crit_roll_reduction() -> int:
	# Natural crit threshold reduced by this value (e.g., 20 -> 19).
	return _div(get_stat("acc"), 10)


func bonus_movement_tiles() -> int:
	return _div(get_stat("mov"), 5)


func bonus_spell_slots_l1() -> int:
	return _div(get_stat("att"), 10)


func bonus_spell_slots_l2() -> int:
	return _div(get_stat("att"), 15)


func bonus_spell_slots_l3() -> int:
	return _div(get_stat("att"), 20)


func bonus_luck_roll() -> int:
	return _div(get_stat("lck"), 5)


# Convenience: aggregate all derived values for debugging/UI.
func get_derived() -> Dictionary:
	return {
		"bonus_hp": bonus_hp(),
		"bonus_resist": bonus_resist(),
		"bonus_physical_damage": bonus_physical_damage(),
		"bonus_magical_damage": bonus_magical_damage(),
		"bonus_action_points": bonus_action_points(),
		"bonus_armor": bonus_armor(),
		"hit_roll_bonus": hit_roll_bonus(),
		"crit_roll_reduction": crit_roll_reduction(),
		"bonus_movement_tiles": bonus_movement_tiles(),
		"bonus_spell_slots_l1": bonus_spell_slots_l1(),
		"bonus_spell_slots_l2": bonus_spell_slots_l2(),
		"bonus_spell_slots_l3": bonus_spell_slots_l3(),
		"bonus_luck_roll": bonus_luck_roll(),
	}


func _div(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	return int(floor(float(value) / float(divisor)))
