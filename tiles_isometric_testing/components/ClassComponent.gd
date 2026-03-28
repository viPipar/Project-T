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
	if not OrderDB.has_class(class_id):
		push_warning("ClassComponent: class '%s' not found" % class_id)
		return
	primary_class_id = class_id
	class_changed.emit(primary_class_id)
	EventBus.class_changed.emit(owner, primary_class_id)


func get_primary_class() -> Dictionary:
	return OrderDB.get_class_data(primary_class_id)


func add_buff_from_class(class_id: String, buff_id: String) -> bool:
	if not OrderDB.has_buff(class_id, buff_id):
		return false
	var key := _make_key(class_id, buff_id)
	if _owned_buffs.has(key):
		return false
	_owned_buffs.append(key)
	_recompute_mods()
	return true


func remove_buff_from_class(class_id: String, buff_id: String) -> bool:
	var key := _make_key(class_id, buff_id)
	if not _owned_buffs.has(key):
		return false
	_owned_buffs.erase(key)
	_recompute_mods()
	return true


func get_all_buffs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _owned_buffs:
		var parts := key.split(":")
		if parts.size() != 2:
			continue
		var cls := parts[0]
		var buff := parts[1]
		var data := OrderDB.get_buff(cls, buff)
		if data.is_empty():
			continue
		var item := data.duplicate()
		item["class_id"] = cls
		item["buff_id"] = buff
		result.append(item)
	return result


func get_total_stat_mods() -> Dictionary:
	var mods: Dictionary = {}
	for buff in get_all_buffs():
		var stat_mods: Dictionary = buff.get("stat_mods", {})
		for k in stat_mods.keys():
			mods[k] = int(mods.get(k, 0)) + int(stat_mods[k])
	return mods


func _recompute_mods() -> void:
	var stats := owner.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
	stats.set_external_mods(get_total_stat_mods())
	buffs_changed.emit()
	EventBus.buffs_changed.emit(owner)


func _make_key(class_id: String, buff_id: String) -> String:
	return "%s:%s" % [class_id, buff_id]
