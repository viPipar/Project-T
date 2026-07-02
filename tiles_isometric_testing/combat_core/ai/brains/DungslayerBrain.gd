class_name DungslayerBrain
extends AIBrain

@export var boss_great_bash_ability: BaseAbility
@export var boss_blockade_ability: BaseAbility
@export var boss_cleave_ability: BaseAbility

@export var detection_range: int = 15

func decide_and_act(entity: Node, ai_component: AIComponent) -> void:
	print("[AI:%s] DungslayerBrain is thinking..." % entity.name)
	
	var all_players = _get_alive_players(entity)
	if all_players.size() == 0:
		print("[AI:%s] No valid targets found. Ending turn." % entity.name)
		ai_component.end_turn()
		return
		
	var my_pos: Vector2i = entity.get("grid_pos")
	
	# Check if both players are within 2 tiles
	var players_in_range_2 = 0
	for p in all_players:
		var dist = GridManager.get_distance(my_pos, p.get("grid_pos"))
		if dist <= 2:
			players_in_range_2 += 1
			
	if players_in_range_2 >= 2 and boss_cleave_ability != null:
		print("[AI:%s] Both players are within 2 tiles! Unleashing Boss Cleave!" % entity.name)
		_perform_attack_and_end(entity, ai_component, entity, boss_cleave_ability)
		return
		
	var target = find_closest_player(entity, detection_range)
	if target == null:
		ai_component.end_turn()
		return
		
	var dist_to_target = GridManager.get_distance(my_pos, target.get("grid_pos"))
	
	# If already adjacent, use Great Bash
	if dist_to_target <= 1 and boss_great_bash_ability != null:
		print("[AI:%s] Target is adjacent. Unleashing Boss Great Bash!" % entity.name)
		_perform_attack_and_end(entity, ai_component, target, boss_great_bash_ability)
		return
		
	print("[AI:%s] Target is out of melee range. Attempting to move..." % entity.name)
	var move_comp = entity.get_node_or_null("MovementComponent")
	
	if move_comp != null and move_comp.has_movement():
		var target_pos: Vector2i = target.get("grid_pos")
		if not move_comp.interact_move_to(target_pos):
			print("[AI:%s] Unable to find a path or move. Will try to cast blockade from here." % entity.name)
		else:
			print("[AI:%s] Moving towards target..." % entity.name)
			await move_comp.move_finished
			print("[AI:%s] Movement finished." % entity.name)
			
	# Re-evaluate distance
	my_pos = entity.get("grid_pos")
	dist_to_target = GridManager.get_distance(my_pos, target.get("grid_pos"))
	
	if dist_to_target <= 1:
		print("[AI:%s] Now adjacent! Unleashing Normal Attack!" % entity.name)
		_perform_attack_tag_and_end(entity, ai_component, target, "main_attack")
		return
		
	# Still out of melee range, cast Blockade!
	if boss_blockade_ability != null:
		print("[AI:%s] Target still out of range. Casting Blockade to block Line of Sight!" % entity.name)
		_perform_attack_and_end(entity, ai_component, target, boss_blockade_ability)
		return
		
	print("[AI:%s] Ended turn without attacking." % entity.name)
	ai_component.end_turn()


func _get_alive_players(entity: Node) -> Array:
	var result = []
	var players = entity.get_tree().get_nodes_in_group("players")
	for p in players:
		var health = p.get_node_or_null("HealthComponent")
		if health and not (health.is_dead() or health.is_downed()):
			result.append(p)
	return result


func _perform_attack_and_end(entity: Node, ai_component: AIComponent, target: Node, ability: BaseAbility) -> void:
	# Trigger the attack pipeline!
	EventBus.attackcam_started.emit(entity, target, ability.ability_tag, target.get("grid_pos"))
	
	# Wait for the combat resolution to finish completely
	await EventBus.combat_action_finished
	
	ai_component.end_turn()

func _perform_attack_tag_and_end(entity: Node, ai_component: AIComponent, target: Node, ability_tag: String) -> void:
	EventBus.attackcam_started.emit(entity, target, ability_tag, target.get("grid_pos"))
	await EventBus.combat_action_finished
	ai_component.end_turn()

