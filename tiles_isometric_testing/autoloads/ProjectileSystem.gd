# autoloads/ProjectileSystem.gd
# Guide:
#   Instant collision check:
#     var hit := ProjectileSystem.resolve_projectile(player, target_tile, {"max_range": 6})
#
#   Spawn gameplay projectile:
#     var projectile := ProjectileSystem.fire_grid_projectile(player, target_tile, {
#       "damage": 6,
#       "damage_type": "physical",
#       "max_range": 6,
#       "color": Color.ORANGE_RED
#     })
#     await projectile.projectile_finished
#
# This system uses ProjectileLine for grid collision and GridProjectile for
# tile-by-tile movement. It does not replace ability damage formulas.
extends Node
class_name ProjectileSystemProvider

const GridProjectileScene := preload("res://components/GridProjectile.gd")


func resolve_projectile(shooter: Node, target_tile: Vector2i, options: Dictionary = {}) -> Dictionary:
	var origin := _get_entity_grid_pos(shooter)
	var max_range := int(options.get("max_range", -1))
	var result: Dictionary
	if max_range >= 0:
		result = ProjectileLine.cast_ranged(origin, target_tile, max_range)
	else:
		result = ProjectileLine.cast(origin, target_tile)

	result["origin"] = origin
	result["target"] = target_tile
	result["max_range"] = max_range
	result["hit_entity"] = GridManager.get_entity_at(result.get("tile", target_tile)) if result.get("result", "") == "hit_entity" else null
	return result


func fire_grid_projectile(shooter: Node, target_tile: Vector2i, options: Dictionary = {}) -> GridProjectile:
	var projectile := GridProjectileScene.new() as GridProjectile
	var parent := _resolve_parent(shooter, options)
	parent.add_child(projectile)
	projectile.setup(shooter, target_tile, options)
	return projectile


func _resolve_parent(shooter: Node, options: Dictionary) -> Node:
	var requested = options.get("parent", null)
	if requested is Node and is_instance_valid(requested):
		return requested
	if is_instance_valid(shooter) and shooter.get_parent() != null:
		return shooter.get_parent()
	return get_tree().current_scene


func _get_entity_grid_pos(entity: Node) -> Vector2i:
	if is_instance_valid(entity) and entity.has_method("get_grid_pos"):
		var method_value: Variant = entity.call("get_grid_pos")
		if method_value is Vector2i:
			return method_value

	if is_instance_valid(entity):
		var prop_value: Variant = entity.get("grid_pos")
		if prop_value is Vector2i:
			return prop_value

	return Vector2i.ZERO
