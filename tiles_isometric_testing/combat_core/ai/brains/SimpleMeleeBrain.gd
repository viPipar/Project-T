class_name SimpleMeleeBrain
extends AIBrain

## Simple Melee Brain
## Prioritizes finding the closest player, moving towards them, and performing a basic attack.

@export var detection_range: int = 6

func decide_and_act(entity: Node, ai_component: AIComponent) -> void:
	print("[AI:%s] SimpleMeleeBrain is thinking..." % entity.name)
	var target = find_closest_player(entity, detection_range)
	
	if target == null:
		print("[AI:%s] No valid targets found in detection range (%d). Ending turn." % [entity.name, detection_range])
		ai_component.end_turn()
		return
		
	print("[AI:%s] Found target: %s at %s" % [entity.name, target.name, str(target.get("grid_pos"))])
		
	var combat = entity.get_node_or_null("CombatComponent")
	
	# If already in attack range, attack directly!
	if combat != null and combat.can_attack(target):
		print("[AI:%s] Target is already in attack range. Attacking!" % entity.name)
		_perform_attack_and_end(entity, ai_component, target)
		return
		
	print("[AI:%s] Target is out of attack range. Attempting to move..." % entity.name)
		
	# Otherwise, try to approach the target
	var move_comp = entity.get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_movement():
		# Use the interact_move_to method which tries to walk adjacent to the target
		var target_pos: Vector2i = target.get("grid_pos")
		
		# If we can't move, just end turn
		if not move_comp.interact_move_to(target_pos):
			print("[AI:%s] Unable to find a path or move towards target. Ending turn." % entity.name)
			ai_component.end_turn()
			return
			
		print("[AI:%s] Moving towards target..." % entity.name)
		# Wait for movement to finish
		await move_comp.move_finished
		print("[AI:%s] Movement finished. Re-evaluating attack range..." % entity.name)
		
		# Check if we are in range to attack now
		if combat != null and combat.can_attack(target):
			print("[AI:%s] Now in range! Attacking!" % entity.name)
			_perform_attack_and_end(entity, ai_component, target)
			return
			
	print("[AI:%s] Ended turn without attacking." % entity.name)
	# If we moved but couldn't attack, end turn
	ai_component.end_turn()


func _perform_attack_and_end(entity: Node, ai_component: AIComponent, target: Node) -> void:
	# Trigger the exact same attack pipeline the Player uses!
	# We use main_attack.tres as the default enemy melee ability.
	EventBus.attackcam_started.emit(entity, target, "main_attack")
	
	# Wait for the combat resolution to finish completely
	await EventBus.combat_action_finished
	
	ai_component.end_turn()
