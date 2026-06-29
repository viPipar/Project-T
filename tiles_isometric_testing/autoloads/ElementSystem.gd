extends Node

## Combos Dictionary
## Format: "element1_element2": { "combo_name": String, "consume": bool, "effect_type": String }
## effect_type = "status" or "instant"
var combos = {
	"fire_earth": { "name": "magma", "type": "status" },
	"earth_fire": { "name": "magma", "type": "status" },
	"earth_water": { "name": "mud", "type": "status" },
	"water_earth": { "name": "mud", "type": "status" },
	"air_water": { "name": "mist", "type": "status" },
	"water_air": { "name": "mist", "type": "status" },
	"air_earth": { "name": "erosion", "type": "status" },
	"earth_air": { "name": "erosion", "type": "status" },
	"fire_water": { "name": "vapor", "type": "instant" },
	"water_fire": { "name": "vapor", "type": "instant" },
	"fire_air": { "name": "conflagration", "type": "instant" },
	"air_fire": { "name": "conflagration", "type": "instant" }
}

var base_elements = ["fire", "water", "air", "earth"]

func get_damage_multiplier(target: Node, incoming_element: String) -> float:
	var inc = incoming_element.to_lower()
	if inc == "physical" or inc == "":
		return 1.0
		
	var cond_comp = target.get_node_or_null("ConditionComponent")
	if not cond_comp:
		return 1.0
		
	for base in base_elements:
		if cond_comp.has_condition(base):
			var pair = base + "_" + inc
			if combos.has(pair) and combos[pair]["name"] == "vapor":
				return 1.2 # Vapor gives +20% damage
	
	return 1.0


func resolve_elemental_hit(target: Node, incoming_element: String, original_damage: int = 0) -> void:
	var inc = incoming_element.to_lower()
	if inc == "physical" or inc == "":
		return
		
	var cond_comp = target.get_node_or_null("ConditionComponent")
	if not cond_comp:
		return
		
	# Check if target already has a base element tag
	var combo_triggered = false
	
	for base in base_elements:
		if cond_comp.has_condition(base):
			# Potential combo
			var pair = base + "_" + inc
			if combos.has(pair):
				var combo = combos[pair]
				
				print("[ElementSystem] %s + %s = %s Triggered!" % [base.to_upper(), inc.to_upper(), combo["name"].to_upper()])
				
				# Consume the base element tag
				cond_comp.remove_condition(base)
				combo_triggered = true
				
				if EventBus != null and EventBus.has_signal("elemental_combo_triggered"):
					EventBus.elemental_combo_triggered.emit(target, combo["name"], combo["type"])
				
				# Apply effects
				if combo["type"] == "status":
					cond_comp.add_condition(combo["name"], 2, 1) # Default 2 duration
				elif combo["type"] == "instant":
					if combo["name"] == "conflagration":
						_trigger_conflagration(target, original_damage)
				
				break # Only trigger one combo per hit

	if not combo_triggered:
		# If no combo triggered, apply the incoming element as a primer tag
		cond_comp.add_condition(inc, 2, 1)


func _trigger_conflagration(target: Node, original_damage: int) -> void:
	# Instantly deal 50% of the original hit damage to adjacent tiles
	var aoe_dmg = floori(original_damage * 0.5)
	if aoe_dmg <= 0:
		return
		
	print("[ElementSystem] Conflagration spreading %d damage!" % aoe_dmg)
	
	var grid = target.get_node_or_null("/root/Main/GridManager") # Adjust path if needed
	if not grid:
		grid = target.get_tree().get_first_node_in_group("grid_manager")
		
	if grid and grid.has_method("get_adjacent_entities"):
		var targets = grid.get_adjacent_entities(target)
		for t in targets:
			if is_instance_valid(t) and t.has_method("get_node"):
				var health = t.get_node_or_null("HealthComponent")
				if health:
					var applied = health.take_damage(aoe_dmg, null, "fire")
					if EventBus != null:
						EventBus.damage_dealt.emit(t, applied, "fire", false, null)
