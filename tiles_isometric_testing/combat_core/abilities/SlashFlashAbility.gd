class_name SlashFlashAbility
extends "res://combat_core/abilities/BaseAbility.gd"

func get_dash_destination(caster: Node, target: Node) -> Vector2i:
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return Vector2i(-1, -1)
		
	var c_pos = caster.get("grid_pos")
	var t_pos = target.get("grid_pos")
	
	if c_pos == null or t_pos == null:
		return Vector2i(-1, -1)
		
	var diff = t_pos - c_pos
	var dir = Vector2i.ZERO
	
	if abs(diff.x) > abs(diff.y):
		dir = Vector2i(sign(diff.x), 0)
	else:
		dir = Vector2i(0, sign(diff.y))
		
	# The tile behind the target (where they would be knocked back to)
	var knockback_tile = t_pos + dir
	
	var can_knockback = false
	if is_instance_valid(GridManager):
		# target can be knocked back if terrain is walkable AND no other entity is blocking
		can_knockback = GridManager.can_enter_tile(knockback_tile, target)
		
	if can_knockback:
		# We can dash exactly into the target's tile because they will be displaced
		return t_pos
	else:
		# Target is blocked by a wall or entity, so we stop right before them (n-1)
		return t_pos - dir
