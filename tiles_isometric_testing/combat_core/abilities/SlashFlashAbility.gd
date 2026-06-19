class_name SlashFlashAbility
extends "res://tiles_isometric_testing/combat_core/abilities/BaseAbility.gd"

func execute(caster: Node, targets: Array) -> void:
	# Custom logic: Dash to adjacent tile before executing the normal attack.
	for target in targets:
		if not is_instance_valid(target):
			continue
			
		# Assume target has grid_pos and caster has grid_pos
		var c_pos = caster.get("grid_pos")
		var t_pos = target.get("grid_pos")
		
		if c_pos != null and t_pos != null:
			# Find adjacent tile
			var diff = c_pos - t_pos
			var dash_pos = t_pos
			if abs(diff.x) > abs(diff.y):
				dash_pos.x += sign(diff.x)
			else:
				dash_pos.y += sign(diff.y)
				
			# TODO (Candra): Verify with GridManager if dash_pos is walkable.
			# If occupied or wall, we might need to fallback to another adjacent tile.
			print("[SlashFlash] Dashing caster from ", c_pos, " to ", dash_pos)
			caster.set("grid_pos", dash_pos)
			EventBus.player_moved.emit(caster, c_pos, dash_pos)
	
	# Proceed with base hit/miss and damage resolution
	super.execute(caster, targets)
