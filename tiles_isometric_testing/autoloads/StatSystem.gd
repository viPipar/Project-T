# autoloads/StatSystem.gd
# Tanggung jawab:
#   Adapter global untuk membaca StatsComponent/HealthComponent milik entity.
#   API-nya kompatibel dengan MockStatProvider agar combat_core Tapip bisa langsung swap.
#
# Cara pakai:
#   var armor := StatSystem.get_armor(target)
#   var max_hp := StatSystem.get_max_hp(player)
#   var applied := StatSystem.apply_damage(enemy, 5, player, "physical")
#
# Cara evaluasi:
#   1. Pastikan project.godot mendaftarkan StatSystem sebagai autoload.
#   2. Jalankan Main.tscn, serang enemy, lalu cek output combat.
#   3. Pastikan hit/crit membaca armor dari StatsComponent dan damage masuk ke HealthComponent.
extends Node
class_name StatSystemProvider

const FALLBACK_MAX_HP := 15
const FALLBACK_ARMOR := 10
const FALLBACK_RESIST := 5


# -- Provider API untuk combat_core -------------------------------------------

func get_armor(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats):
		return stats.get_armor()
	return FALLBACK_ARMOR


func get_resist(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats):
		return stats.get_resist()
	return FALLBACK_RESIST


func get_max_armor(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats) and stats.has_method("get_max_armor"):
		return int(stats.get_max_armor())
	return get_armor(entity)


func get_acc(entity: Node) -> int:
	return get_stat(entity, "acc")


func get_lck(entity: Node) -> int:
	return get_stat(entity, "lck")


func get_mov(entity: Node) -> int:
	return get_stat(entity, "mov")


func get_att(entity: Node) -> int:
	return get_stat(entity, "att")


func get_dex(entity: Node) -> int:
	return get_stat(entity, "dex")


func get_int_stat(entity: Node) -> int:
	return get_stat(entity, "int")


func get_str_stat(entity: Node) -> int:
	return get_stat(entity, "str")


func get_physical_damage_modifier(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats) and stats.has_method("get_physical_damage_modifier"):
		return int(stats.get_physical_damage_modifier())
	return int(floor(float(get_str_stat(entity)) / 2.0))


func get_magical_damage_modifier(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats) and stats.has_method("get_magical_damage_modifier"):
		return int(stats.get_magical_damage_modifier())
	return int(floor(float(get_int_stat(entity)) / 2.0))


func get_hit_roll_modifier(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats) and stats.has_method("get_hit_roll_modifier"):
		return int(stats.get_hit_roll_modifier())
	return int(floor(float(get_acc(entity)) / 2.0))


func get_crit_requirement(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats) and stats.has_method("get_natural_crit_requirement"):
		return int(stats.get_natural_crit_requirement())
	return maxi(1, 20 - int(floor(float(get_acc(entity)) / 10.0)))


func get_natural_crit_requirement(entity: Node) -> int:
	return get_crit_requirement(entity)


func get_luck_roll_modifier(entity: Node) -> int:
	var stats := get_stats_component(entity)
	if is_instance_valid(stats) and stats.has_method("get_luck_roll_modifier"):
		return int(stats.get_luck_roll_modifier())
	return int(floor(float(get_lck(entity)) / 5.0))


func get_max_hp(entity: Node) -> int:
	var health := get_health_component(entity)
	if is_instance_valid(health):
		if is_instance_valid(health) and health.has_method("get_max_hp"):
			return int(health.get_max_hp())
		var value = health.get("max_hp")
		if value != null:
			return int(value)

	var stats := get_stats_component(entity)
	if is_instance_valid(stats):
		return stats.get_max_hp()
	return FALLBACK_MAX_HP


func get_current_hp(entity: Node) -> int:
	var health := get_health_component(entity)
	if is_instance_valid(health):
		if is_instance_valid(health) and health.has_method("get_hp"):
			return int(health.get_hp())
		var value = health.get("current_hp")
		if value != null:
			return int(value)
	return get_max_hp(entity)


func get_stat(entity: Node, stat_key: String, fallback: int = 0) -> int:
	var stats := get_stats_component(entity)
	if stats == null:
		return fallback
	return stats.get_stat(stat_key)


func get_stats_component(entity: Node) -> StatsComponent:
	if not is_instance_valid(entity):
		return null
	return entity.get_node_or_null("StatsComponent") as StatsComponent


func get_health_component(entity: Node) -> Node:
	if not is_instance_valid(entity):
		return null
	return entity.get_node_or_null("HealthComponent")


func get_condition_component(entity: Node) -> Node:
	if not is_instance_valid(entity):
		return null
	return entity.get_node_or_null("ConditionComponent")


# -- Helper runtime -----------------------------------------------------------

func apply_damage(target: Node, amount: int, attacker: Node = null, damage_type: String = "physical") -> int:
	var health := get_health_component(target)
	if is_instance_valid(health) and health.has_method("take_damage"):
		return int(health.take_damage(amount, attacker, damage_type))

	if is_instance_valid(target) and target.has_method("sub_hp"):
		return int(target.sub_hp(amount, attacker, damage_type))

	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(amount)
		return maxi(0, amount)

	push_warning("[StatSystem] Target tidak punya HealthComponent/take_damage(): %s" % str(target))
	return 0


func apply_heal(target: Node, amount: int, source: Node = null) -> int:
	var health := get_health_component(target)
	if is_instance_valid(health) and health.has_method("heal"):
		return int(health.heal(amount, source))
	if is_instance_valid(target) and target.has_method("add_hp"):
		return int(target.add_hp(amount))
	if is_instance_valid(target) and target.has_method("heal"):
		target.heal(amount)
		return maxi(0, amount)
	return 0
