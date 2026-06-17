# components/StatsComponent.gd
# Tanggung jawab:
#   Menjadi sumber resmi primary stat dan derived stat milik entity.
#   Modifier disimpan per source agar class, item, dan status tidak saling overwrite.
#
# Cara pakai:
#   var stats := entity.get_node("StatsComponent") as StatsComponent
#   stats.set_mod_source("item:ring_str", {"str": 2})
#   var armor := stats.get_armor()
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

const PRIMARY_KEYS: Array[String] = [
	"vit", "str", "int", "con", "acc", "dex", "mov", "att", "lck"
]

const DERIVED_KEYS: Array[String] = [
	"hp", "max_hp", "armor", "resist", "physical_damage", "magical_damage",
	"action_points", "hit_roll", "crit_reduction", "movement_tiles",
	"spell_slots_l1", "spell_slots_l2", "spell_slots_l3", "luck_roll"
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
	return get_base_stat(stat_key) + get_mod_total(stat_key)


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
	return _div(get_stat("str"), 2) + get_mod_total("physical_damage")


func bonus_magical_damage() -> int:
	return _div(get_stat("int"), 2) + get_mod_total("magical_damage")


func bonus_action_points() -> int:
	return _div(get_stat("int"), 10) + _div(get_stat("dex"), 10) + get_mod_total("action_points")


func bonus_armor() -> int:
	return _div(get_stat("con"), 2) + _div(get_stat("dex"), 4) + get_mod_total("armor")


func get_armor() -> int:
	return maxi(0, BASE_ARMOR + bonus_armor())


func hit_roll_bonus() -> int:
	return _div(get_stat("acc"), 2) + get_mod_total("hit_roll")


func crit_roll_reduction() -> int:
	return _div(get_stat("acc"), 10) + get_mod_total("crit_reduction")


func bonus_movement_tiles() -> int:
	return _div(get_stat("mov"), 5) + get_mod_total("movement_tiles")


func bonus_spell_slots_l1() -> int:
	return _div(get_stat("att"), 5) + get_mod_total("spell_slots_l1")


func bonus_spell_slots_l2() -> int:
	return _div(get_stat("att"), 10) + get_mod_total("spell_slots_l2")


func bonus_spell_slots_l3() -> int:
	return _div(get_stat("att"), 15) + get_mod_total("spell_slots_l3")


func get_spell_slots_l1() -> int:
	return maxi(0, 2 + bonus_spell_slots_l1())


func get_spell_slots_l2() -> int:
	return maxi(0, 2 + bonus_spell_slots_l2())


func get_spell_slots_l3() -> int:
	return maxi(0, 1 + bonus_spell_slots_l3())


func bonus_luck_roll() -> int:
	return _div(get_stat("lck"), 5) + get_mod_total("luck_roll")


func get_derived() -> Dictionary:
	return {
		"max_hp": get_max_hp(),
		"armor": get_armor(),
		"resist": get_resist(),
		"bonus_hp": bonus_hp(),
		"bonus_resist": bonus_resist(),
		"bonus_physical_damage": bonus_physical_damage(),
		"bonus_magical_damage": bonus_magical_damage(),
		"bonus_action_points": bonus_action_points(),
		"bonus_armor": bonus_armor(),
		"hit_roll_bonus": hit_roll_bonus(),
		"crit_roll_reduction": crit_roll_reduction(),
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


func _div(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	return int(floor(float(value) / float(divisor)))
