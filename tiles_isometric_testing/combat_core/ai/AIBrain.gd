class_name AIBrain
extends Resource

## The Base Class for all Enemy AI Brains.
## To create a new behavior, extend this class and override `decide_and_act`.

func decide_and_act(entity: Node, ai_component: AIComponent) -> void:
	push_error("AIBrain.decide_and_act() must be overridden in a subclass!")
	ai_component.end_turn()


# ── Common Utility Methods for Brains ───────────────────────────────

## Find the closest player entity to this enemy.
func find_closest_player(entity: Node, max_range: int = 99) -> Node:
	var my_pos: Vector2i = entity.get("grid_pos")
	var all_players := entity.get_tree().get_nodes_in_group("players")
	var best: Node = null
	var best_dist := max_range + 1

	for player in all_players:
		var health := player.get_node_or_null("HealthComponent")
		if health and (health.is_dead() or health.is_downed()):
			continue
		
		var p_pos: Vector2i = player.get("grid_pos")
		var dist := GridManager.get_distance(my_pos, p_pos)
		
		if dist <= max_range and dist < best_dist:
			best_dist = dist
			best = player

	return best


## Check if the entity has enough action points and/or mana to use an ability.
func can_afford_ability(entity: Node, ability: BaseAbility) -> bool:
	# Check Action Points
	var class_comp = entity.get_node_or_null("ClassComponent")
	if is_instance_valid(class_comp) and class_comp.has_method("get_current_ap"):
		if class_comp.get_current_ap() < ability.cost_action:
			return false
		
	# Check Mana
	var stats_comp = entity.get_node_or_null("StatsComponent")
	if ability.cost_mana > 0:
		if is_instance_valid(stats_comp) and stats_comp.has_method("get_current_mana"):
			if stats_comp.get_current_mana() < ability.cost_mana:
				return false
				
	return true
