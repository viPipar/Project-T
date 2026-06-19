class_name BaseAbility
extends Resource

enum AbilityType { PHYSICAL, MAGICAL, UTILITY }
enum TargetAlignment { ENEMY_ONLY, ALLY_ONLY, SELF_ONLY, ANY }

@export_group("Identity")
@export var ability_name    : String = "New Ability"
@export_multiline var ability_description: String = ""
@export var ability_tag     : String = "ability_base"
@export var ability_type    : AbilityType = AbilityType.PHYSICAL
@export var element_tag     : String = "physical"

@export_group("Targeting & Range")
@export var target_alignment: TargetAlignment = TargetAlignment.ENEMY_ONLY
@export var ally_targeting_dc : int  = 10 # DC to hit when targeting an ally (bypasses ally armor)
@export var range_type      : String = "adjacent" # "adjacent", "line", "aoe"
@export var range_size      : int    = 1
@export var is_projectile   : bool   = false

@export_group("Output")
@export var damage_dice     : String = "1D6"
@export var is_heal         : bool   = false

@export_group("Effects")
@export var knockback_tiles : int    = 0
@export var status_effect   : String = ""
@export var status_duration : int    = 0
@export var status_stacks   : int    = 1

@export_group("Costs")
@export var cost_action     : int    = 1
@export var cost_bonus_action : int  = 0
@export var cost_mana       : int    = 0


## Returns true if this ability only targets the caster (e.g. Epimorphic, Autotomy).
func is_self_target() -> bool:
	return target_alignment == TargetAlignment.SELF_ONLY


## Compute which grid tiles are valid targets from the caster's position.
## Returns Array[Vector2i].
func get_target_tiles(caster_pos: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	if is_self_target():
		tiles.append(caster_pos)
		return tiles

	match range_type:
		"adjacent":
			# Cardinal neighbors within range_size steps
			for dx in range(-range_size, range_size + 1):
				for dy in range(-range_size, range_size + 1):
					if dx == 0 and dy == 0:
						continue
					# Manhattan distance filter for "adjacent" feel
					if abs(dx) + abs(dy) <= range_size:
						tiles.append(caster_pos + Vector2i(dx, dy))

		"line":
			# Straight lines in 4 cardinal directions, range_size tiles deep
			var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for dir in dirs:
				for step in range(1, range_size + 1):
					tiles.append(caster_pos + dir * step)

		"aoe":
			# NxN box centered on caster (range_size = radius)
			for dx in range(-range_size, range_size + 1):
				for dy in range(-range_size, range_size + 1):
					var tile := caster_pos + Vector2i(dx, dy)
					tiles.append(tile)

		_:
			# Fallback: 4 adjacent tiles
			tiles.append(caster_pos + Vector2i(1, 0))
			tiles.append(caster_pos + Vector2i(-1, 0))
			tiles.append(caster_pos + Vector2i(0, 1))
			tiles.append(caster_pos + Vector2i(0, -1))

	return tiles


## Get the HighlightManager type string for this ability's grid area color.
func get_highlight_type() -> String:
	if is_self_target():
		return "skill"   # green/purple for self
	if range_type == "aoe" and target_alignment == TargetAlignment.ANY:
		return "attack"  # red for AoE
	return "attack"      # yellow/red for targeted


func execute(caster: Node, targets: Array) -> void:
	var dice_roller = DiceRoller.new()
	var hit_miss_resolver = caster.get_node_or_null("/root/HitMissResolver")
	
	for target in targets:
		if not is_instance_valid(target):
			continue
			
		var is_ally = _is_ally(caster, target)
		
		if target_alignment == TargetAlignment.ENEMY_ONLY and is_ally:
			print("[BaseAbility] ⚠️ Friendly fire! Target '%s' is an ally." % target.name)
		elif target_alignment == TargetAlignment.ALLY_ONLY and not is_ally:
			print("[BaseAbility] ⚠️ Healing/Buffing an enemy! Target '%s' is an enemy." % target.name)
		
		var hit_result: Dictionary
		var is_magical = (ability_type == AbilityType.MAGICAL)
		
		if is_ally:
			# Ally Targeting Resolver: Bypass armor, use DC from skill.
			var stat_sys = caster.get_node_or_null("/root/StatSystem")
			var acc_mod = 0
			if stat_sys != null and stat_sys.has_method("get_acc"):
				acc_mod = floori(stat_sys.get_acc(caster) / 2.0)
			
			var raw_d20 = dice_roller.d20()
			var roll = raw_d20 + acc_mod
			var hit = roll >= ally_targeting_dc
			
			hit_result = {
				"hit": hit,
				"roll": roll,
				"raw_d20": raw_d20,
				"modifier": acc_mod,
				"threshold": ally_targeting_dc,
				"is_magical": is_magical
			}
			# Manually emit since we bypassed HitMissResolver
			if not hit:
				EventBus.on_miss.emit(caster, target)
		else:
			if hit_miss_resolver != null and hit_miss_resolver.has_method("resolve"):
				hit_result = hit_miss_resolver.resolve(caster, target, is_magical)
			else:
				# TODO (Tapip): HitMissResolver is currently missing from /root or lacks resolve()
				push_warning("[BaseAbility] HitMissResolver not found or lacks resolve() method!")
				hit_result = {"hit": true, "is_magical": is_magical}

		# General ability_executed signal
		var event_result = {
			"element_tag": element_tag,
			"knockback_tiles": knockback_tiles,
			"status_effect": status_effect,
			"is_crit": false
		}
		EventBus.ability_executed.emit(caster, [target], event_result)

		if hit_result.get("hit", false):
			EventBus.on_hit.emit(caster, target, hit_result)
			
			var output_amount = dice_roller.roll_from_string(damage_dice)
			
			if is_heal:
				_apply_heal(target, output_amount)
			else:
				# TODO (Gilang): Calculate Damage Multipliers here!
				# Query your upcoming Status Effect System to see if the target 
				# is "Vulnerable" or has the "Vapor" (+20%) elemental combo.
				# output_amount = floori(output_amount * status_multiplier)
				_apply_damage(target, output_amount, caster, is_magical)
				
			if knockback_tiles > 0:
				var dir = _get_knockback_dir(caster, target)
				EventBus.on_knockback.emit(target, dir, knockback_tiles)
			if status_effect != "":
				EventBus.on_status_applied.emit(target, status_effect, status_duration, status_stacks)
				
		else:
			# If it's a heal that missed, apply half heal
			if is_heal:
				var half_heal = floori(dice_roller.roll_from_string(damage_dice) / 2.0)
				_apply_heal(target, half_heal)


func _is_ally(caster: Node, target: Node) -> bool:
	var caster_pid = caster.get("player_id")
	var target_pid = target.get("player_id")
	if caster_pid != null and target_pid != null:
		return true
	if caster_pid == null and target_pid == null:
		return true
	return false

func _apply_damage(target: Node, amount: int, attacker: Node, is_magical: bool) -> void:
	var type_str = "magical" if is_magical else "physical"
	var stat_sys = target.get_node_or_null("/root/StatSystem")
	if stat_sys != null and stat_sys.has_method("apply_damage"):
		var applied = stat_sys.apply_damage(target, amount, attacker, type_str)
		EventBus.damage_dealt.emit(target, applied, type_str, false)
	else:
		var health = target.get_node_or_null("HealthComponent")
		if health != null and health.has_method("take_damage"):
			var applied = health.take_damage(amount, attacker, type_str)
			EventBus.damage_dealt.emit(target, applied, type_str, false)
		else:
			# TODO (Candra): Ensure entities have either a StatSystem or HealthComponent
			push_warning("[BaseAbility] Target %s has no known health component!" % target.name)

func _apply_heal(target: Node, amount: int) -> void:
	var stat_sys = target.get_node_or_null("/root/StatSystem")
	if stat_sys != null and stat_sys.has_method("apply_heal"):
		stat_sys.apply_heal(target, amount)
	else:
		var health = target.get_node_or_null("HealthComponent")
		if health != null and health.has_method("heal"):
			health.heal(amount)

func _get_knockback_dir(caster: Node, target: Node) -> Vector2:
	if caster.get("grid_pos") != null and target.get("grid_pos") != null:
		var diff = target.get("grid_pos") - caster.get("grid_pos")
		if diff.length() > 0:
			return Vector2(diff).normalized()
	return Vector2.RIGHT # Fallback
