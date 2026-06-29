class_name SimpleRangedBrain
extends AIBrain

## Simple Ranged Brain
## Prioritizes kiting. Uses MovementComponent to find a reachable tile that maximizes
## distance from the player, while still being able to hit the player with its ranged ability.

@export var ranged_ability: BaseAbility
@export var detection_range: int = 99

func decide_and_act(entity: Node, ai_component: AIComponent) -> void:
	print("[AI:%s] SimpleRangedBrain is thinking..." % entity.name)
	
	if ranged_ability == null:
		push_error("[AI:%s] SimpleRangedBrain missing ranged_ability!" % entity.name)
		ai_component.end_turn()
		return
		
	var target = find_closest_player(entity, detection_range)
	if target == null:
		print("[AI:%s] No valid targets found. Ending turn." % entity.name)
		ai_component.end_turn()
		return
		
	var move_comp = entity.get_node_or_null("MovementComponent")
	var target_pos: Vector2i = target.get("grid_pos")
	var my_pos: Vector2i = entity.get("grid_pos")
	
	# 1. Gather valid reachable tiles
	var valid_tiles: Array[Vector2i] = []
	if move_comp != null and move_comp.has_movement():
		valid_tiles = move_comp.get_reachable_tiles()
	
	# Important: the current standing tile is always an option!
	if not valid_tiles.has(my_pos):
		valid_tiles.append(my_pos)
		
	var tiles_in_range = []
	var tiles_out_of_range = []
	
	# 2. Evaluate all tiles using the Ability's own targeting logic
	for tile in valid_tiles:
		var dist = GridManager.get_distance(tile, target_pos)
		var valid_targets = ranged_ability.get_target_tiles(tile)
		
		if target_pos in valid_targets:
			tiles_in_range.append({"tile": tile, "dist": dist})
		else:
			tiles_out_of_range.append({"tile": tile, "dist": dist})
			
	var best_tile: Vector2i = my_pos
	var can_attack_after_move: bool = false
	
	if tiles_in_range.size() > 0:
		# Scenario A: We can hit the target from somewhere reachable!
		# Sort by distance DESCENDING (Kiting: pick the tile furthest away)
		tiles_in_range.sort_custom(func(a, b): return a.dist > b.dist)
		best_tile = tiles_in_range[0].tile
		can_attack_after_move = true
		print("[AI:%s] Found kiting spot at %s (Distance: %d)" % [entity.name, best_tile, tiles_in_range[0].dist])
	else:
		# Scenario B: Target is totally out of range.
		if tiles_out_of_range.size() > 0:
			# Sort by distance ASCENDING (Chase: pick the tile closest to the target)
			tiles_out_of_range.sort_custom(func(a, b): return a.dist < b.dist)
			best_tile = tiles_out_of_range[0].tile
			print("[AI:%s] Out of range. Chasing to %s (Distance: %d)" % [entity.name, best_tile, tiles_out_of_range[0].dist])
			
	# 3. Execute Movement
	if best_tile != my_pos and move_comp != null:
		print("[AI:%s] Moving to %s..." % [entity.name, best_tile])
		if move_comp.move_to(best_tile):
			await move_comp.move_finished
		else:
			print("[AI:%s] Path to %s blocked unexpectedly!" % [entity.name, best_tile])
			
	# 4. Attack if possible
	if can_attack_after_move:
		print("[AI:%s] Target is in range. Firing ranged ability!" % entity.name)
		_perform_attack_and_end(entity, ai_component, target)
	else:
		print("[AI:%s] Target is out of range after movement. Ending turn." % entity.name)
		ai_component.end_turn()

func _perform_attack_and_end(entity: Node, ai_component: AIComponent, target: Node) -> void:
	# Trigger the exact same attack pipeline the Player uses!
	EventBus.attackcam_started.emit(entity, target, ranged_ability.ability_tag)
	
	# Wait for the combat resolution to finish completely
	await EventBus.combat_action_finished
	
	ai_component.end_turn()
