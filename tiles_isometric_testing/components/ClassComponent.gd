# components/ClassComponent.gd
# Tanggung jawab:
#   Menyimpan class utama entity dan menerapkan buff class ke StatsComponent.
#
# Cara pakai:
#   var class_comp := entity.get_node("ClassComponent") as ClassComponent
#   class_comp.set_primary_class("slayer")
#   class_comp.add_buff_from_class("slayer", "blood_oath")
#
# Cara evaluasi:
#   1. Jalankan Main.tscn dan tekan F1.
#   2. Centang "Show Stats & Classes".
#   3. Pastikan buff class muncul dan stat modifier source "class" tidak menimpa item/status.
extends Node
class_name ClassComponent

signal class_changed(primary_class_id: String)
signal buffs_changed

@export var primary_class_id: String = "slayer"
@export var starting_buffs: Array[String] = [] # format: "class_id:buff_id"

var _owned_buffs: Array[String] = []


func _ready() -> void:
	_owned_buffs = starting_buffs.duplicate()
	set_primary_class(primary_class_id)
	_recompute_mods()


func set_primary_class(class_id: String) -> void:
	if not _has_class_data(class_id):
		push_warning("ClassComponent: class '%s' not found" % class_id)
		return
	primary_class_id = class_id
	class_changed.emit(primary_class_id)
	EventBus.class_changed.emit(owner, primary_class_id)


func get_primary_class() -> Dictionary:
	return _get_class_data(primary_class_id)


func add_buff_from_class(class_id: String, buff_id: String) -> bool:
	if _get_buff_data(class_id, buff_id).is_empty():
		return false
	var key: String = _make_key(class_id, buff_id)
	if _owned_buffs.has(key):
		return false
	_owned_buffs.append(key)
	_recompute_mods()
	return true


func remove_buff_from_class(class_id: String, buff_id: String) -> bool:
	var key: String = _make_key(class_id, buff_id)
	if not _owned_buffs.has(key):
		return false
	_owned_buffs.erase(key)
	_recompute_mods()
	return true


func get_all_buffs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _owned_buffs:
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2:
			continue
		var cls: String = parts[0]
		var buff: String = parts[1]
		var data: Dictionary = _get_buff_data(cls, buff)
		if data.is_empty():
			continue
		var item: Dictionary = data.duplicate()
		item["class_id"] = cls
		item["buff_id"] = buff
		result.append(item)
	return result


func get_total_stat_mods() -> Dictionary:
	var mods: Dictionary = {}
	for buff in get_all_buffs():
		var raw_mods: Variant = buff.get("stat_mods", {})
		if typeof(raw_mods) != TYPE_DICTIONARY:
			continue
		var stat_mods: Dictionary = raw_mods as Dictionary
		for k in stat_mods.keys():
			mods[k] = int(mods.get(k, 0)) + int(stat_mods[k])
	return mods


func _recompute_mods() -> void:
	var stats: StatsComponent = owner.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
	stats.set_mod_source("class", get_total_stat_mods())
	buffs_changed.emit()
	EventBus.buffs_changed.emit(owner)


func _make_key(class_id: String, buff_id: String) -> String:
	return "%s:%s" % [class_id, buff_id]


func _has_class_data(class_id: String) -> bool:
	if OrderDB.has_class(class_id):
		return true
	var data: Dictionary = _get_json_class_data(class_id)
	return not data.is_empty()


func _get_class_data(class_id: String) -> Dictionary:
	if OrderDB.has_class(class_id):
		return OrderDB.get_class_data(class_id)
	var data: Dictionary = _get_json_class_data(class_id)
	if data.is_empty():
		return {}
	var result: Dictionary = data.duplicate(true)
	result["name"] = result.get("name", result.get("display_name", class_id))
	return result


func _get_buff_data(class_id: String, buff_id: String) -> Dictionary:
	if OrderDB.has_buff(class_id, buff_id):
		return OrderDB.get_buff(class_id, buff_id)
	var db: Node = get_node_or_null("/root/StatDataDB")
	if db == null or not db.has_method("get_class_buff_data"):
		return {}
	var result: Variant = db.call("get_class_buff_data", class_id, buff_id)
	if typeof(result) != TYPE_DICTIONARY:
		return {}
	return result as Dictionary


func _get_json_class_data(class_id: String) -> Dictionary:
	var db: Node = get_node_or_null("/root/StatDataDB")
	if db == null or not db.has_method("get_class_data"):
		return {}
	var result: Variant = db.call("get_class_data", class_id)
	if typeof(result) != TYPE_DICTIONARY:
		return {}
	return result as Dictionary
