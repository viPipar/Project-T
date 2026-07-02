# components/GridProjectile.gd
# Guide:
#   Normally use ProjectileSystem:
#     ProjectileSystem.fire_grid_projectile(player, target_tile, {"damage": 6})
#
#   Direct use:
#     var p := GridProjectile.new()
#     add_child(p)
#     p.setup(player, target_tile, {"speed": 900, "apply_damage": true})
#
# Emits projectile_finished(result) when it reaches entity/wall/range end.
extends Node2D
class_name GridProjectile

signal projectile_finished(result: Dictionary)
signal projectile_hit_entity(entity: Node, result: Dictionary)
signal projectile_hit_wall(tile: Vector2i, result: Dictionary)

var shooter: Node = null
var target_tile: Vector2i = Vector2i.ZERO
var options: Dictionary = {}
var result: Dictionary = {}

var speed: float = 900.0
var radius: float = 8.0
var color: Color = Color.WHITE

var _tiles: Array[Vector2i] = []
var _tile_index: int = 0
var _finished: bool = false


func setup(p_shooter: Node, p_target_tile: Vector2i, p_options: Dictionary = {}) -> void:
	shooter = p_shooter
	target_tile = p_target_tile
	options = p_options.duplicate(true)
	speed = float(options.get("speed", speed))
	radius = float(options.get("radius", radius))
	var raw_color = options.get("color", color)
	if raw_color is Color:
		color = raw_color

	result = _resolve_projectile(shooter, target_tile, options)
	_tiles = result.get("tiles", [])
	if _tiles.is_empty():
		_finish()
		return

	position = IsoUtils.world_to_iso(_tiles[0])
	_tile_index = 1
	queue_redraw()

	if _tiles.size() <= 1:
		_finish()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)


func _process(delta: float) -> void:
	if _finished or _tile_index >= _tiles.size():
		return

	var next_tile := _tiles[_tile_index]
	var target_pos := IsoUtils.world_to_iso(next_tile)
	var to_target := target_pos - position
	var step := speed * delta

	if to_target.length() <= step:
		position = target_pos
		_tile_index += 1
		if _tile_index >= _tiles.size():
			_finish()
	else:
		position += to_target.normalized() * step


func _finish() -> void:
	if _finished:
		return
	_finished = true

	var hit_kind := str(result.get("result", "miss"))
	if hit_kind == "hit_entity":
		var hit_tile: Vector2i = result.get("tile", target_tile)
		var hit_entity := GridManager.get_entity_at(hit_tile)
		result["hit_entity"] = hit_entity
		if is_instance_valid(hit_entity):
			_apply_damage(hit_entity)
			projectile_hit_entity.emit(hit_entity, result)
	elif hit_kind == "hit_wall":
		projectile_hit_wall.emit(result.get("tile", target_tile), result)

	projectile_finished.emit(result)
	queue_free()


func _apply_damage(target: Node) -> void:
	if not bool(options.get("apply_damage", true)):
		return
	var damage := int(options.get("damage", 0))
	if damage <= 0:
		return
	var damage_type := str(options.get("damage_type", "physical"))
	var source = options.get("source", shooter)
	var applied := 0
	if StatSystem != null and StatSystem.has_method("apply_damage"):
		applied = int(StatSystem.apply_damage(target, damage, source, damage_type))
	elif is_instance_valid(target) and target.has_method("take_damage"):
		applied = int(target.call("take_damage", damage, source, damage_type))
	result["damage"] = damage
	result["applied_damage"] = applied


func _resolve_projectile(p_shooter: Node, p_target_tile: Vector2i, p_options: Dictionary) -> Dictionary:
	var origin := _get_entity_grid_pos(p_shooter)
	var max_range := int(p_options.get("max_range", -1))
	var resolved: Dictionary
	if max_range >= 0:
		resolved = ProjectileLine.cast_ranged(origin, p_target_tile, max_range)
	else:
		resolved = ProjectileLine.cast(origin, p_target_tile)

	resolved["origin"] = origin
	resolved["target"] = p_target_tile
	resolved["max_range"] = max_range
	resolved["hit_entity"] = GridManager.get_entity_at(resolved.get("tile", p_target_tile)) if resolved.get("result", "") == "hit_entity" else null
	return resolved


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
