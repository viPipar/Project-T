# autoloads/StatDataDB.gd
# Tanggung jawab:
#   Membaca JSON stat module dan menerapkan data base stat/modifier ke entity runtime.
#   File aktif ada di res://data/stat_module/, file *.example.json tetap sebagai template.
#
# Cara pakai:
#   var data := StatDataDB.get_player_data("aria")
#   StatDataDB.apply_entity_data(player, data)
#   StatDataDB.apply_item_mod(player, "ring_str")
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Buka debug stats dan pastikan Aria/Kael/Goblin/Orc mengambil angka dari JSON aktif.
#   3. Ubah angka di players.json atau enemies.json, restart scene, lalu cek angka berubah.
extends Node
class_name StatDataDBProvider

const PLAYERS_PATH := "res://data/stat_module/entity_base_stats/players.json"
const ENEMIES_PATH := "res://data/stat_module/entity_base_stats/enemies.json"
const ITEMS_PATH := "res://data/stat_module/item_stat_mods/equipment.json"
const CLASS_BUFFS_PATH := "res://data/stat_module/buff_stat_mods/class_buffs.json"
const CONDITIONS_PATH := "res://data/stat_module/condition_stat_mods/status_effects.json"

var _players: Dictionary = {}
var _enemies: Dictionary = {}
var _items: Dictionary = {}
var _class_buffs: Dictionary = {}
var _temporary_buffs: Dictionary = {}
var _conditions: Dictionary = {}


func _ready() -> void:
	reload()


# -----------------------------------------------------------------------------
# Load / Query
# -----------------------------------------------------------------------------

func reload() -> void:
	var players_root: Dictionary = _load_json(PLAYERS_PATH)
	var enemies_root: Dictionary = _load_json(ENEMIES_PATH)
	var items_root: Dictionary = _load_json(ITEMS_PATH)
	var buffs_root: Dictionary = _load_json(CLASS_BUFFS_PATH)
	var conditions_root: Dictionary = _load_json(CONDITIONS_PATH)

	_players = _get_dictionary(players_root, "players")
	_enemies = _get_dictionary(enemies_root, "enemies")
	_items = _get_dictionary(items_root, "items")
	_class_buffs = _get_dictionary(buffs_root, "classes")
	_temporary_buffs = _get_dictionary(buffs_root, "temporary_buffs")
	_conditions = _get_dictionary(conditions_root, "conditions")

	print("[StatDataDB] JSON stat module loaded. Players:%d Enemies:%d Items:%d Conditions:%d" % [
		_players.size(),
		_enemies.size(),
		_items.size(),
		_conditions.size()
	])


func get_player_data(entity_id: String) -> Dictionary:
	return _get_entry(_players, entity_id)


func get_enemy_data(entity_id: String) -> Dictionary:
	return _get_entry(_enemies, entity_id)


func get_item_data(item_id: String) -> Dictionary:
	return _get_entry(_items, item_id)


func get_condition_data(condition_id: String) -> Dictionary:
	return _get_entry(_conditions, condition_id)


func get_temporary_buff_data(buff_id: String) -> Dictionary:
	return _get_entry(_temporary_buffs, buff_id)


func get_class_data(class_id: String) -> Dictionary:
	return _get_entry(_class_buffs, class_id)


func get_class_buff_data(class_id: String, buff_id: String) -> Dictionary:
	var class_data: Dictionary = _get_entry(_class_buffs, class_id)
	if class_data.is_empty():
		return {}
	var buffs: Dictionary = _get_dictionary(class_data, "buffs")
	return _get_entry(buffs, buff_id)


func get_player_ids() -> Array[String]:
	return _get_keys(_players)


func get_enemy_ids() -> Array[String]:
	return _get_keys(_enemies)


func get_item_ids() -> Array[String]:
	return _get_keys(_items)


# -----------------------------------------------------------------------------
# Apply Entity Data
# -----------------------------------------------------------------------------

func apply_player_data(entity_id: String, entity: Node) -> void:
	apply_entity_data(entity, get_player_data(entity_id))


func apply_enemy_data(entity_id: String, entity: Node) -> void:
	apply_entity_data(entity, get_enemy_data(entity_id))


func apply_entity_data(entity: Node, data: Dictionary) -> void:
	if entity == null or data.is_empty():
		return

	if "raw_data" in entity:
		entity.set("raw_data", data)

	_apply_identity_data(entity, data)
	apply_base_stats(entity, _get_dictionary(data, "base_stats"))
	_apply_class_data(entity, data)
	_apply_movement_data(entity, data)
	_apply_health_data(entity, data)
	_apply_combat_data(entity, data)

	if entity.has_method("apply_custom_data"):
		entity.apply_custom_data(data)


func apply_base_stats(entity: Node, base_stats: Dictionary) -> void:
	if entity == null or base_stats.is_empty():
		return

	var stats: StatsComponent = entity.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		push_warning("[StatDataDB] Entity tidak punya StatsComponent: %s" % str(entity))
		return

	stats.vit = int(base_stats.get("vit", stats.vit))
	stats.str_stat = int(base_stats.get("str", stats.str_stat))
	stats.int_stat = int(base_stats.get("int", stats.int_stat))
	stats.con = int(base_stats.get("con", stats.con))
	stats.acc = int(base_stats.get("acc", stats.acc))
	stats.dex = int(base_stats.get("dex", stats.dex))
	stats.mov = int(base_stats.get("mov", stats.mov))
	stats.att = int(base_stats.get("att", stats.att))
	stats.lck = int(base_stats.get("lck", stats.lck))
	stats.emit_changed()


func apply_item_mod(entity: Node, item_id: String) -> bool:
	var item_data: Dictionary = get_item_data(item_id)
	if item_data.is_empty():
		return false
	var source_id: String = str(item_data.get("source_id", "item:%s" % item_id))
	return apply_stat_mod(entity, source_id, _get_dictionary(item_data, "stat_mods"))


func remove_item_mod(entity: Node, item_id: String) -> void:
	var item_data: Dictionary = get_item_data(item_id)
	var source_id: String = "item:%s" % item_id
	if not item_data.is_empty():
		source_id = str(item_data.get("source_id", source_id))
	remove_stat_mod(entity, source_id)


func apply_condition_mod(entity: Node, condition_id: String) -> bool:
	var condition_data: Dictionary = get_condition_data(condition_id)
	if condition_data.is_empty():
		return false
	var source_id: String = str(condition_data.get("source_id", "condition:%s" % condition_id))
	return apply_stat_mod(entity, source_id, _get_dictionary(condition_data, "stat_mods"))


func remove_condition_mod(entity: Node, condition_id: String) -> void:
	var condition_data: Dictionary = get_condition_data(condition_id)
	var source_id: String = "condition:%s" % condition_id
	if not condition_data.is_empty():
		source_id = str(condition_data.get("source_id", source_id))
	remove_stat_mod(entity, source_id)


func apply_stat_mod(entity: Node, source_id: String, stat_mods: Dictionary) -> bool:
	if entity == null or source_id == "" or stat_mods.is_empty():
		return false

	var stats: StatsComponent = entity.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return false

	stats.set_mod_source(source_id, stat_mods)
	return true


func remove_stat_mod(entity: Node, source_id: String) -> void:
	if entity == null or source_id == "":
		return
	var stats: StatsComponent = entity.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		stats.remove_mod_source(source_id)


# -----------------------------------------------------------------------------
# Scene / Spawn Helpers
# -----------------------------------------------------------------------------

func get_scene_path(data: Dictionary, fallback_path: String) -> String:
	return str(data.get("scene", fallback_path))


func load_entity_scene(data: Dictionary, fallback_path: String) -> PackedScene:
	var scene_path: String = get_scene_path(data, fallback_path)
	var resource: Resource = load(scene_path)
	if resource is PackedScene:
		return resource as PackedScene

	push_warning("[StatDataDB] Scene tidak valid: %s. Fallback: %s" % [scene_path, fallback_path])
	return load(fallback_path) as PackedScene


func get_spawn_grid_pos(data: Dictionary, fallback: Vector2i) -> Vector2i:
	var spawn_data: Dictionary = _get_dictionary(data, "spawn")
	var raw_grid: Variant = spawn_data.get("grid_pos", [])
	if typeof(raw_grid) != TYPE_ARRAY:
		return fallback

	var grid_array: Array = raw_grid as Array
	if grid_array.size() < 2:
		return fallback

	return Vector2i(int(grid_array[0]), int(grid_array[1]))


# -----------------------------------------------------------------------------
# Internal Apply
# -----------------------------------------------------------------------------

func _apply_identity_data(entity: Node, data: Dictionary) -> void:
	var display_name: String = str(data.get("display_name", ""))
	if display_name != "":
		if _has_property(entity, "char_name"):
			entity.set("char_name", display_name)
		if _has_property(entity, "enemy_name"):
			entity.set("enemy_name", display_name)

	if data.has("player_id") and _has_property(entity, "player_id"):
		entity.set("player_id", int(data["player_id"]))


func _apply_class_data(entity: Node, data: Dictionary) -> void:
	var class_comp: ClassComponent = entity.get_node_or_null("ClassComponent") as ClassComponent
	if class_comp == null:
		return

	var class_id: String = str(data.get("class_id", ""))
	if class_id != "":
		class_comp.set_primary_class(class_id)

	var raw_buffs: Variant = data.get("starting_buffs", [])
	if typeof(raw_buffs) != TYPE_ARRAY:
		return

	var starting_buffs: Array = raw_buffs as Array
	for raw_buff in starting_buffs:
		var buff_key: String = str(raw_buff)
		var parts: PackedStringArray = buff_key.split(":")
		if parts.size() != 2:
			push_warning("[StatDataDB] starting_buffs harus format class_id:buff_id, dapat: %s" % buff_key)
			continue
		class_comp.add_buff_from_class(parts[0], parts[1])


func _apply_health_data(entity: Node, data: Dictionary) -> void:
	var health: HealthComponent = entity.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return

	var health_data: Dictionary = _get_dictionary(data, "health")
	var use_stats: bool = bool(health_data.get("use_stats_max_hp", health.use_stats_max_hp))
	if use_stats:
		var stats: StatsComponent = entity.get_node_or_null("StatsComponent") as StatsComponent
		health.setup_from_stats(stats, true)
		return

	var max_hp: int = int(health_data.get("max_hp", health.max_hp))
	health.setup_fixed_max(max_hp, true)


func _apply_movement_data(entity: Node, data: Dictionary) -> void:
	var movement: MovementComponent = entity.get_node_or_null("MovementComponent") as MovementComponent
	if movement == null:
		return

	var movement_data: Dictionary = _get_dictionary(data, "movement")
	if movement_data.has("base_movement"):
		movement.base_movement = int(movement_data["base_movement"])
	movement.reset_movement()


func _apply_combat_data(entity: Node, data: Dictionary) -> void:
	var combat: CombatComponent = entity.get_node_or_null("CombatComponent") as CombatComponent
	if combat == null:
		return

	var combat_data: Dictionary = _get_dictionary(data, "combat")
	if combat_data.is_empty():
		return

	combat.attack_dice = str(combat_data.get("attack_dice", combat.attack_dice))
	combat.attack_range = int(combat_data.get("attack_range", combat.attack_range))
	combat.is_magical = bool(combat_data.get("is_magical", combat.is_magical))


# -----------------------------------------------------------------------------
# Internal Helpers
# -----------------------------------------------------------------------------

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[StatDataDB] JSON tidak ditemukan: %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[StatDataDB] Gagal membuka JSON: %s" % path)
		return {}

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[StatDataDB] JSON bukan Dictionary valid: %s" % path)
		return {}

	return parsed as Dictionary


func _get_dictionary(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _get_entry(source: Dictionary, entry_id: String) -> Dictionary:
	var value: Variant = source.get(entry_id, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _get_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in source.keys():
		result.append(str(key))
	return result


func _has_property(entity: Node, property_name: String) -> bool:
	for info in entity.get_property_list():
		if info.name == property_name:
			return true
	return false
