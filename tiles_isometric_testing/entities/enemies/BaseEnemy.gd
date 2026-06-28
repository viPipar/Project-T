# entities/enemies/BaseEnemy.gd
# Tanggung jawab:
#   Base scene untuk enemy berbasis komponen: stats, health, movement, combat, condition, AI.
#
# Cara pakai:
#   var enemy := preload("res://entities/enemies/BaseEnemy.tscn").instantiate()
#   enemy.enemy_data = some_enemy_data
#   enemy.place_at(Vector2i(8, 5))
#
# Cara evaluasi:
#   1. Buka BaseEnemy.tscn dan pastikan child component lengkap.
#   2. Jalankan scene test yang memakai BaseEnemy.
#   3. Pastikan enemy bisa menerima damage, mati, dan dilepas dari GridManager.
extends CharacterBody2D

@export var enemy_data: Resource

var grid_pos: Vector2i = Vector2i.ZERO
var char_name: String = "Enemy"

@onready var health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var stats: StatsComponent = get_node_or_null("StatsComponent") as StatsComponent
@onready var movement: MovementComponent = get_node_or_null("MovementComponent") as MovementComponent
@onready var combat: CombatComponent = get_node_or_null("CombatComponent") as CombatComponent
@onready var cond: ConditionComponent = get_node_or_null("ConditionComponent") as ConditionComponent
@onready var ai: AIComponent = get_node_or_null("AIComponent") as AIComponent


func _ready() -> void:
	add_to_group("enemies")
	_apply_data()
	if health != null and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)


# -----------------------------------------------------------------------------
# Data Application
# -----------------------------------------------------------------------------

func _apply_data() -> void:
	if enemy_data == null:
		return

	char_name = str(_data_value("enemy_name", char_name))

	if stats != null:
		stats.vit = _data_int("vit", _data_int("constitution", stats.vit))
		stats.str_stat = _data_int("str", _data_int("strength", stats.str_stat))
		stats.int_stat = _data_int("int", _data_int("intelligence", stats.int_stat))
		stats.con = _data_int("con", _data_int("constitution", stats.con))
		stats.acc = _data_int("acc", stats.acc)
		stats.dex = _data_int("dex", _data_int("dexterity", stats.dex))
		stats.mov = _data_int("mov", _data_int("movement_speed", stats.mov))
		stats.att = _data_int("att", stats.att)
		stats.lck = _data_int("lck", stats.lck)
		if _data_value("base_armor_class", null) != null:
			stats.set_mod_source("enemy_data", {"armor": _data_int("base_armor_class", 10) - 10})
		stats.emit_changed()

	if health != null:
		if _data_value("max_hp", null) != null:
			health.setup_fixed_max(_data_int("max_hp", health.max_hp), true)
		else:
			health.setup_from_stats(stats, true)

	if movement != null:
		var movement_speed := _data_int("movement_speed", stats.get_stat("mov") if stats != null else movement.base_movement)
		movement.base_movement = movement_speed
		movement.movement_left = movement_speed

	if combat != null:
		combat.attack_dice = str(_data_value("attack_dice", combat.attack_dice))
		combat.attack_range = _data_int("attack_range", combat.attack_range)

	if ai != null:
		ai.behavior = _data_int("ai_behavior", ai.behavior)
		ai.detection_range = _data_int("detection_range", ai.detection_range)
		ai.preferred_range = _data_int("attack_range", ai.preferred_range)


# -----------------------------------------------------------------------------
# Grid Positioning
# -----------------------------------------------------------------------------

func get_grid_pos() -> Vector2i:
	return grid_pos


func place_at(pos: Vector2i) -> void:
	if GridManager.get_entity_at(grid_pos) == self:
		GridManager.unregister_entity(grid_pos)
	grid_pos = pos
	GridManager.register_entity(pos, self, GridManager.EntityType.ENEMY)
	position = IsoUtils.world_to_iso(pos)
	z_index = IsoUtils.get_depth(pos)


# -----------------------------------------------------------------------------
# HP API
# -----------------------------------------------------------------------------

func take_damage(amount: int, attacker: Node = null, damage_type: String = "physical") -> int:
	if health == null:
		return 0
	return health.take_damage(amount, attacker, damage_type)


func heal(amount: int) -> int:
	if health == null:
		return 0
	return health.heal(amount, self)


func get_hp() -> int:
	return health.get_hp() if health != null else 0


func get_max_hp() -> int:
	return health.get_max_hp() if health != null else 0


func sub_hp(amount: int, attacker: Node = null, damage_type: String = "true") -> int:
	if health == null:
		return 0
	return health.sub_hp(amount, attacker, damage_type)


func add_hp(amount: int) -> int:
	if health == null:
		return 0
	return health.add_hp(amount)


func get_armor() -> int:
	return stats.get_armor() if stats != null else 0


func get_resist() -> int:
	return stats.get_resist() if stats != null else 0


func get_stat(stat_key: String) -> int:
	return stats.get_stat(stat_key) if stats != null else 0


func add_stat(stat_key: String, amount: int) -> bool:
	return stats.add_base_stat(stat_key, amount) if stats != null else false


func sub_stat(stat_key: String, amount: int) -> bool:
	return stats.sub_base_stat(stat_key, amount) if stats != null else false


func is_dead() -> bool:
	return health != null and health.is_dead()


func is_downed() -> bool:
	return health != null and health.is_downed()


func _on_died(_killer: Node) -> void:
	if GridManager.get_entity_at(grid_pos) == self:
		GridManager.unregister_entity(grid_pos)
	remove_from_group("enemies")
	set_process(false)
	await get_tree().create_timer(0.6).timeout
	queue_free()


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _data_value(property_name: String, fallback) -> Variant:
	if enemy_data == null:
		return fallback
	var value = enemy_data.get(property_name)
	return fallback if value == null else value


func _data_int(property_name: String, fallback: int) -> int:
	return int(_data_value(property_name, fallback))
