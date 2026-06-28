# components/StatsComponent.gd
# Tanggung jawab:
#   Menjadi sumber resmi primary stat dan derived stat milik entity.
#   Modifier disimpan per source agar class, item, dan status tidak saling overwrite.
#
# Cara pakai:
#   var stats := entity.get_node("StatsComponent") as StatsComponent
#   stats.set_base_stat("str", 8)
#   stats.add_base_stat("vit", 2)
#   stats.sub_base_stat("dex", 1)
#   var str_final := stats.get_stat("str")
#
#   # Modifier item/buff/debuff pakai source agar bisa dilepas lagi.
#   stats.set_mod_source("item:ring_str", {"str": 2})
#   stats.remove_mod_source("item:ring_str")
#
#   # Data JSON/Dictionary fleksibel.
#   stats.equip({"id": "iron_ring", "mods": {"str": 2, "armor": 1}})
#   stats.unequip("iron_ring")
#   stats.apply_debuff({"debuff_id": "weakened", "stat_mods": {"str": -2}})
#   stats.remove_debuff("weakened")
#
#   # Contoh lengkap item. "id" otomatis jadi source "item:iron_ring".
#   var item_data := {
#       "id": "iron_ring",
#       "display_name": "Iron Ring",
#       "mods": {
#           "str": 2,
#           "armor": 1
#       }
#   }
#   stats.equip(item_data)
#   stats.unequip("iron_ring")
#
#   # Contoh lengkap buff. Bisa pakai "mods", "stat_mods", atau "modifiers".
#   var buff_data := {
#       "buff_id": "battle_focus",
#       "duration": 2,
#       "stat_mods": {
#           "acc": 4,
#           "hit_roll": 1
#       }
#   }
#   stats.apply_buff(buff_data)
#   stats.remove_buff("battle_focus")
#
#   # Contoh lengkap debuff. Nilai final stat tetap minimum 0.
#   var debuff_data := {
#       "debuff_id": "weakened",
#       "duration": 3,
#       "modifiers": {
#           "str": -3,
#           "armor": -2
#       }
#   }
#   stats.apply_debuff(debuff_data)
#   stats.remove_debuff("weakened")
#
#   # Kalau butuh source khusus, isi source_id langsung.
#   stats.apply_modifier_data({
#       "source_id": "condition:burning_stack_1",
#       "mods": {"resist": -1}
#   })
#   stats.remove_modifier_data("condition:burning_stack_1")
#
#   # Armor/resist runtime juga lewat modifier source internal.
#   stats.sub_armor(2)
#   stats.reset_armor()
#
#   var armor := stats.get_armor()
#   var phys_mod := stats.get_physical_damage_modifier()
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Tekan F1 lalu centang "Show Stats & Classes".
#   3. Pastikan stat, armor, resist, movement, dan HP berubah saat modifier ditambah/dihapus.
extends Node
class_name StatsComponent

# Primary stats:
# VIT (Vitality)      : 2 VIT = +1 HP, 4 VIT = +1 Resist
# STR (Strength)      : 2 STR = +1 Physical Damage, 4 STR = +1 HP
# INT (Intelligence)  : 2 INT = +1 Magical Damage, 10 INT = +1 Bonus Action Point
# CON (Constitution)  : 2 CON = +1 Armor, 4 CON = +1 Resist
# ACC (Accuracy)      : 2 ACC = +1 Hit Roll, 10 ACC = -1 Natural Crit Roll
# DEX (Dexterity)     : 4 DEX = +1 Armor, 10 DEX = +1 Action Point
# MOV (Movement)      : 5 MOV = +1 Tiles
# ATT (Attunement)    : Spell Slot Lv1/Lv2/Lv3 scaling
# LCK (Luck)          : 5 LCK = +1 Luck Event Roll

signal stats_changed

const BASE_MAX_HP := 15
const BASE_ARMOR := 10
const BASE_RESIST := 5
const LEGACY_SOURCE_ID := "legacy_external"
const ARMOR_RUNTIME_SOURCE_ID := "runtime:armor_adjust"
const RESIST_RUNTIME_SOURCE_ID := "runtime:resist_adjust"

const PRIMARY_KEYS: Array[String] = [
	"vit", "str", "int", "con", "acc", "dex", "mov", "att", "lck"
]

const DERIVED_KEYS: Array[String] = [
	"hp", "max_hp", "armor", "resist", "physical_damage", "magical_damage",
	"action_points", "bonus_action_points", "hit_roll", "crit_reduction",
	"movement_tiles", "spell_slots_l1", "spell_slots_l2", "spell_slots_l3",
	"luck_roll"
]

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

# source_id -> Dictionary stat_key -> int
var _mod_sources: Dictionary = {}


# -- Public API ---------------------------------------------------------------

func emit_changed() -> void:
	stats_changed.emit()
	if EventBus != null:
		EventBus.stats_changed.emit(owner)


## Backward compatible API. Dipertahankan agar caller lama tidak rusak.
func set_external_mods(mods: Dictionary) -> void:
	set_mod_source(LEGACY_SOURCE_ID, mods)


func set_base_stat(stat_key: String, value: int) -> bool:
	var safe_value := maxi(0, value)
	match stat_key:
		"vit":
			vit = safe_value
		"str":
			str_stat = safe_value
		"int":
			int_stat = safe_value
		"con":
			con = safe_value
		"acc":
			acc = safe_value
		"dex":
			dex = safe_value
		"mov":
			mov = safe_value
		"att":
			att = safe_value
		"lck":
			lck = safe_value
		_:
			push_warning("StatsComponent: base stat '%s' tidak dikenal." % stat_key)
			return false

	emit_changed()
	return true


func add_base_stat(stat_key: String, amount: int) -> bool:
	return set_base_stat(stat_key, get_base_stat(stat_key) + amount)


func sub_base_stat(stat_key: String, amount: int) -> bool:
	return add_base_stat(stat_key, -abs(amount))


func add_stat(stat_key: String, amount: int) -> bool:
	return add_base_stat(stat_key, amount)


func sub_stat(stat_key: String, amount: int) -> bool:
	return sub_base_stat(stat_key, amount)


## Tambah / ganti satu sumber modifier.
## Contoh source_id: "class", "item:ring_str", "condition:weakened".
func set_mod_source(source_id: String, mods: Dictionary) -> void:
	if source_id.strip_edges() == "":
		push_warning("StatsComponent: source_id kosong, modifier diabaikan.")
		return

	var clean := _sanitize_mods(mods)
	if clean.is_empty():
		remove_mod_source(source_id)
		return

	_mod_sources[source_id] = clean
	emit_changed()


func remove_mod_source(source_id: String) -> void:
	if not _mod_sources.has(source_id):
		return
	_mod_sources.erase(source_id)
	emit_changed()


## Hapus semua modifier, atau hanya yang prefix-nya cocok.
## Contoh: clear_mod_sources("condition:") menghapus semua status modifier.
func clear_mod_sources(prefix: String = "") -> void:
	if prefix == "":
		if _mod_sources.is_empty():
			return
		_mod_sources.clear()
		emit_changed()
		return

	var changed := false
	for source_id in _mod_sources.keys():
		if str(source_id).begins_with(prefix):
			_mod_sources.erase(source_id)
			changed = true
	if changed:
		emit_changed()


func get_base_stat(stat_key: String) -> int:
	match stat_key:
		"vit": return maxi(0, vit)
		"str": return maxi(0, str_stat)
		"int": return maxi(0, int_stat)
		"con": return maxi(0, con)
		"acc": return maxi(0, acc)
		"dex": return maxi(0, dex)
		"mov": return maxi(0, mov)
		"att": return maxi(0, att)
		"lck": return maxi(0, lck)
	return 0


func get_stat(stat_key: String) -> int:
	return maxi(0, get_base_stat(stat_key) + get_mod_total(stat_key))


func get_mod_total(stat_key: String) -> int:
	var total := 0
	for mods in _mod_sources.values():
		if mods.has(stat_key):
			total += int(mods[stat_key])
	return total


func get_all_mods() -> Dictionary:
	var result: Dictionary = {}
	for mods in _mod_sources.values():
		for key in mods.keys():
			result[key] = int(result.get(key, 0)) + int(mods[key])
	return result


func get_mod_sources() -> Dictionary:
	return _mod_sources.duplicate(true)


func apply_modifier_data(data: Variant, fallback_source_id: String = "") -> String:
	if not (data is Dictionary):
		push_warning("StatsComponent: modifier data harus Dictionary.")
		return ""

	var dict := data as Dictionary
	var source_id := _extract_source_id(dict, fallback_source_id)
	var mods := _extract_mods(dict)
	if source_id == "":
		push_warning("StatsComponent: source_id kosong, modifier data diabaikan.")
		return ""
	set_mod_source(source_id, mods)
	return source_id


func remove_modifier_data(data_or_source_id: Variant) -> void:
	if data_or_source_id is Dictionary:
		var dict := data_or_source_id as Dictionary
		var source_id := _extract_source_id(dict, "")
		if source_id != "":
			remove_mod_source(source_id)
		return
	remove_mod_source(str(data_or_source_id))


func equip(item_data: Dictionary) -> String:
	return apply_modifier_data(item_data, "item")


func unequip(item_id: Variant) -> void:
	remove_mod_source(_normalize_source_id(str(item_id), "item"))


func apply_buff(buff_data: Dictionary) -> String:
	return apply_modifier_data(buff_data, "buff")


func remove_buff(buff_id: Variant) -> void:
	remove_mod_source(_normalize_source_id(str(buff_id), "buff"))


func apply_debuff(debuff_data: Dictionary) -> String:
	return apply_modifier_data(debuff_data, "debuff")


func remove_debuff(debuff_id: Variant) -> void:
	remove_mod_source(_normalize_source_id(str(debuff_id), "debuff"))


# -- Derived Modifiers --------------------------------------------------------

func bonus_hp() -> int:
	return _div(get_stat("vit"), 2) + _div(get_stat("str"), 4) + get_mod_total("hp") + get_mod_total("max_hp")


func get_max_hp() -> int:
	return maxi(1, BASE_MAX_HP + bonus_hp())


func bonus_resist() -> int:
	return _div(get_stat("vit"), 4) + _div(get_stat("con"), 4) + get_mod_total("resist")


func get_resist() -> int:
	return maxi(0, BASE_RESIST + bonus_resist())


func bonus_physical_damage() -> int:
	return maxi(0, _div(get_stat("str"), 2) + get_mod_total("physical_damage"))


func bonus_magical_damage() -> int:
	return maxi(0, _div(get_stat("int"), 2) + get_mod_total("magical_damage"))


func bonus_action_points() -> int:
	return maxi(0, _div(get_stat("dex"), 10) + get_mod_total("action_points"))


func bonus_bonus_action_points() -> int:
	return maxi(0, _div(get_stat("int"), 10) + get_mod_total("bonus_action_points"))


func get_action_points() -> int:
	return maxi(0, 1 + bonus_action_points())


func get_bonus_action_points() -> int:
	return maxi(0, 1 + bonus_bonus_action_points())


func bonus_armor() -> int:
	return _div(get_stat("con"), 2) + _div(get_stat("dex"), 4) + get_mod_total("armor")


func get_armor() -> int:
	return maxi(0, BASE_ARMOR + bonus_armor())


func get_max_armor() -> int:
	return get_armor()


func add_armor(amount: int) -> void:
	_adjust_runtime_mod(ARMOR_RUNTIME_SOURCE_ID, "armor", amount)


func sub_armor(amount: int) -> void:
	add_armor(-abs(amount))


func reset_armor() -> void:
	remove_mod_source(ARMOR_RUNTIME_SOURCE_ID)


func add_resist(amount: int) -> void:
	_adjust_runtime_mod(RESIST_RUNTIME_SOURCE_ID, "resist", amount)


func sub_resist(amount: int) -> void:
	add_resist(-abs(amount))


func reset_resist() -> void:
	remove_mod_source(RESIST_RUNTIME_SOURCE_ID)


func hit_roll_bonus() -> int:
	return maxi(0, _div(get_stat("acc"), 2) + get_mod_total("hit_roll"))


func crit_roll_reduction() -> int:
	return maxi(0, _div(get_stat("acc"), 10) + get_mod_total("crit_reduction"))


func get_natural_crit_requirement() -> int:
	return maxi(1, 20 - crit_roll_reduction())


func get_physical_damage_modifier() -> int:
	return bonus_physical_damage()


func get_magical_damage_modifier() -> int:
	return bonus_magical_damage()


func get_hit_roll_modifier() -> int:
	return hit_roll_bonus()


func bonus_movement_tiles() -> int:
	return maxi(0, _div(get_stat("mov"), 5) + get_mod_total("movement_tiles"))


func bonus_spell_slots_l1() -> int:
	return maxi(0, _div(get_stat("att"), 5) + get_mod_total("spell_slots_l1"))


func bonus_spell_slots_l2() -> int:
	return maxi(0, _div(get_stat("att"), 10) + get_mod_total("spell_slots_l2"))


func bonus_spell_slots_l3() -> int:
	return maxi(0, _div(get_stat("att"), 15) + get_mod_total("spell_slots_l3"))


func get_spell_slots_l1() -> int:
	return maxi(0, 2 + bonus_spell_slots_l1())


func get_spell_slots_l2() -> int:
	return maxi(0, 2 + bonus_spell_slots_l2())


func get_spell_slots_l3() -> int:
	return maxi(0, 1 + bonus_spell_slots_l3())


func bonus_luck_roll() -> int:
	return maxi(0, _div(get_stat("lck"), 5) + get_mod_total("luck_roll"))


func get_luck_roll_modifier() -> int:
	return bonus_luck_roll()


func get_derived() -> Dictionary:
	return {
		"max_hp": get_max_hp(),
		"armor": get_armor(),
		"max_armor": get_max_armor(),
		"resist": get_resist(),
		"bonus_hp": bonus_hp(),
		"bonus_resist": bonus_resist(),
		"bonus_physical_damage": bonus_physical_damage(),
		"bonus_magical_damage": bonus_magical_damage(),
		"action_points": get_action_points(),
		"bonus_action_points": bonus_action_points(),
		"bonus_action_points_total": get_bonus_action_points(),
		"bonus_bonus_action_points": bonus_bonus_action_points(),
		"bonus_armor": bonus_armor(),
		"hit_roll_bonus": hit_roll_bonus(),
		"crit_roll_reduction": crit_roll_reduction(),
		"natural_crit_requirement": get_natural_crit_requirement(),
		"bonus_movement_tiles": bonus_movement_tiles(),
		"spell_slots_l1": get_spell_slots_l1(),
		"spell_slots_l2": get_spell_slots_l2(),
		"spell_slots_l3": get_spell_slots_l3(),
		"bonus_spell_slots_l1": bonus_spell_slots_l1(),
		"bonus_spell_slots_l2": bonus_spell_slots_l2(),
		"bonus_spell_slots_l3": bonus_spell_slots_l3(),
		"bonus_luck_roll": bonus_luck_roll(),
	}


# -- Internal -----------------------------------------------------------------

func _sanitize_mods(mods: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for key in mods.keys():
		var stat_key := str(key)
		if not _is_known_mod_key(stat_key):
			push_warning("StatsComponent: modifier key '%s' tidak dikenal, diabaikan." % stat_key)
			continue
		var value := int(mods[key])
		if value != 0:
			clean[stat_key] = value
	return clean


func _is_known_mod_key(stat_key: String) -> bool:
	return stat_key in PRIMARY_KEYS or stat_key in DERIVED_KEYS


func _extract_source_id(data: Dictionary, fallback_source_id: String) -> String:
	if data.has("source_id"):
		return str(data["source_id"])

	var prefix := fallback_source_id
	if prefix.find(":") != -1:
		prefix = prefix.get_slice(":", 0)
	var raw_id := ""
	for key in ["id", "item_id", "buff_id", "debuff_id"]:
		if data.has(key):
			raw_id = str(data[key])
			break

	if raw_id == "":
		return str(fallback_source_id)
	return _normalize_source_id(raw_id, prefix)


func _normalize_source_id(raw_id: String, prefix: String = "") -> String:
	var source_id := raw_id.strip_edges()
	if source_id == "":
		return ""
	if source_id.find(":") != -1 or prefix == "":
		return source_id
	return "%s:%s" % [prefix, source_id]


func _extract_mods(data: Dictionary) -> Dictionary:
	for key in ["mods", "stat_mods", "modifiers"]:
		if data.has(key) and data[key] is Dictionary:
			return data[key]

	var mods: Dictionary = {}
	for key in data.keys():
		var stat_key := str(key)
		if _is_known_mod_key(stat_key):
			mods[stat_key] = data[key]
	return mods


func _adjust_runtime_mod(source_id: String, stat_key: String, amount: int) -> void:
	if amount == 0:
		return

	var mods: Dictionary = {}
	if _mod_sources.has(source_id):
		var existing = _mod_sources[source_id]
		if existing is Dictionary:
			mods = existing.duplicate()
	mods[stat_key] = int(mods.get(stat_key, 0)) + amount
	set_mod_source(source_id, mods)


func _div(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	return int(floor(float(value) / float(divisor)))
