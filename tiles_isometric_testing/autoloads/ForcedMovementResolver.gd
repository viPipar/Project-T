# autoloads/ForcedMovementResolver.gd
# Tanggung jawab:
#   Menjalankan forced movement seperti knockback, termasuk cek tabrakan grid
#   dan damage true ketika entity mentok wall, stone, out of bound, atau entity.
#
# Cara pakai:
#   ForcedMovementResolver.knockback_from_attack(attacker, target, 2)
#   ForcedMovementResolver.knockback_entity(target, 2, Vector2i.RIGHT, attacker)
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Panggil knockback_from_attack(player, enemy, 1 atau 2) dari ability/test.
#   3. Pastikan target mundur jika tile kosong, atau kena true damage saat mentok.
extends Node

const DEFAULT_COLLISION_DAMAGE := 5
const DEFAULT_DAMAGE_PER_POWER := 2
const DEFAULT_DAMAGE_TYPE := "true_damage"


# -- Public API ---------------------------------------------------------------

func knockback_from_attack(attacker: Node, target: Node, power: int, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = _make_empty_result()
	if attacker == null or target == null:
		result["reason"] = "attacker_or_target_null"
		return result

	var attacker_pos: Vector2i = _get_entity_grid_pos(attacker)
	var target_pos: Vector2i = _get_entity_grid_pos(target)
	var direction: Vector2i = get_direction_from_to(attacker_pos, target_pos)
	return knockback_entity(target, power, direction, attacker, options)


func knockback_entity(entity: Node, power: int, direction: Vector2i, source: Node = null, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = _make_empty_result()
	if entity == null:
		result["reason"] = "entity_null"
		return result
	if power <= 0:
		result["reason"] = "power_zero"
		return result

	var knockback_dir: Vector2i = _normalize_cardinal_direction(direction)
	if knockback_dir == Vector2i.ZERO:
		result["reason"] = "direction_zero"
		return result

	var from_tile: Vector2i = _get_entity_grid_pos(entity)
	var current_tile: Vector2i = from_tile
	var moved_steps: int = 0
	var collided: bool = false
	var collision_tile: Vector2i = current_tile
	var collision_type: String = ""

	result["success"] = true
	result["from"] = from_tile
	result["to"] = current_tile
	result["power"] = power
	result["direction"] = knockback_dir

	if EventBus != null:
		EventBus.forced_movement_started.emit(entity, from_tile, knockback_dir, power)

	for _step_index in range(power):
		var next_tile: Vector2i = current_tile + knockback_dir
		var block_type: String = _get_block_type(next_tile, entity)
		if block_type != "":
			collided = true
			collision_tile = next_tile
			collision_type = block_type
			break

		if not GridManager.move_entity(current_tile, next_tile, entity):
			collided = true
			collision_tile = next_tile
			collision_type = "blocked"
			break

		current_tile = next_tile
		moved_steps += 1

	_sync_entity_position(entity, current_tile)

	var collision_damage: int = 0
	var applied_damage: int = 0
	if collided:
		collision_damage = _get_collision_damage(power, options)
		applied_damage = _apply_collision_damage(entity, collision_damage, source, options)
		if EventBus != null:
			EventBus.forced_movement_collided.emit(entity, collision_tile, applied_damage, collision_type)
		print("[ForcedMovementResolver] Hit %s! %s menerima %d true damage." % [
			collision_type,
			str(entity.name),
			applied_damage
		])

	result["to"] = current_tile
	result["moved_steps"] = moved_steps
	result["collided"] = collided
	result["collision_type"] = collision_type
	result["collision_tile"] = collision_tile
	result["collision_damage"] = applied_damage
	result["raw_collision_damage"] = collision_damage

	if EventBus != null:
		EventBus.forced_movement_finished.emit(entity, from_tile, current_tile, moved_steps)

	return result


func get_direction_from_to(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	var delta: Vector2i = to_tile - from_tile
	return _normalize_cardinal_direction(delta)


# -- Damage -------------------------------------------------------------------

func _get_collision_damage(power: int, options: Dictionary) -> int:
	var base_damage: int = int(options.get("base_collision_damage", DEFAULT_COLLISION_DAMAGE))
	var damage_per_power: int = int(options.get("damage_per_power", DEFAULT_DAMAGE_PER_POWER))
	return maxi(0, base_damage + ((maxi(1, power) - 1) * damage_per_power))


func _apply_collision_damage(entity: Node, amount: int, source: Node, options: Dictionary) -> int:
	if amount <= 0:
		return 0

	var damage_type: String = str(options.get("damage_type", DEFAULT_DAMAGE_TYPE))
	var applied: int = 0
	if is_instance_valid(StatSystem) and StatSystem.has_method("apply_damage"):
		applied = int(StatSystem.apply_damage(entity, amount, source, damage_type))
	else:
		var health: HealthComponent = entity.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			applied = health.take_damage(amount, source, damage_type)
		elif is_instance_valid(entity) and entity.has_method("take_damage"):
			applied = int(entity.call("take_damage", amount, source))

	if applied > 0 and EventBus != null:
		EventBus.damage_dealt.emit(entity, applied, damage_type, false, null)

	return applied


# -- Grid & Collision ---------------------------------------------------------

func _get_block_type(tile: Vector2i, mover: Node) -> String:
	if not _is_in_bounds(tile):
		return "out_of_bounds"
	if not GridManager.is_terrain_walkable(tile):
		return "wall"
	if GridManager.has_entity_at(tile):
		var occupant: Node = GridManager.get_entity_at(tile)
		if occupant != mover:
			return "entity"
	if not GridManager.can_enter_tile(tile, mover):
		return "blocked"
	return ""


func _is_in_bounds(tile: Vector2i) -> bool:
	var size: Vector2i = GridManager.grid_size
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y


func _sync_entity_position(entity: Node, tile: Vector2i) -> void:
	if _has_property(entity, "grid_pos"):
		entity.set("grid_pos", tile)

	var node_2d: Node2D = entity as Node2D
	if node_2d == null:
		return
	node_2d.z_index = IsoUtils.get_depth(tile)
	var end_px = IsoUtils.world_to_iso(tile)
	var tw = node_2d.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node_2d, "position", end_px, 0.15)


func _get_entity_grid_pos(entity: Node) -> Vector2i:
	if is_instance_valid(entity) and entity.has_method("get_grid_pos"):
		var method_value: Variant = entity.call("get_grid_pos")
		if method_value is Vector2i:
			return method_value

	var prop_value: Variant = entity.get("grid_pos")
	if prop_value is Vector2i:
		return prop_value

	return Vector2i.ZERO


func _normalize_cardinal_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.ZERO

	if absi(direction.x) >= absi(direction.y):
		return Vector2i(_sign_int(direction.x), 0)
	return Vector2i(0, _sign_int(direction.y))


func _sign_int(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func _has_property(entity: Node, prop_name: String) -> bool:
	for info in entity.get_property_list():
		var property_name: String = str(info.get("name", ""))
		if property_name == prop_name:
			return true
	return false


func _make_empty_result() -> Dictionary:
	return {
		"success": false,
		"reason": "",
		"from": Vector2i.ZERO,
		"to": Vector2i.ZERO,
		"power": 0,
		"direction": Vector2i.ZERO,
		"moved_steps": 0,
		"collided": false,
		"collision_type": "",
		"collision_tile": Vector2i.ZERO,
		"collision_damage": 0,
		"raw_collision_damage": 0,
	}
