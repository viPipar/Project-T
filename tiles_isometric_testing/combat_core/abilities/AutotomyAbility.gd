class_name AutotomyAbility
extends "res://combat_core/abilities/BaseAbility.gd"

func execute(caster: Node, targets: Array) -> void:
	# Autotomy only affects the caster (self)
	# Effect: -20% HP (current HP), +4 Armor for 1 turn
	
	print("[Autotomy] Executing custom logic on caster...")
	
	var health_comp = caster.get_node_or_null("HealthComponent")
	if health_comp != null and health_comp.has_method("get_hp"):
		var current_hp = health_comp.get_hp()
		var dmg = floori(current_hp * 0.20)
		if health_comp.has_method("take_damage"):
			var applied = health_comp.take_damage(dmg, caster, "true")
			EventBus.damage_dealt.emit(caster, applied, "true", false, null)
	else:
		# Fallback to stat system
		var stat_sys = caster.get_node_or_null("/root/StatSystem")
		if stat_sys != null and stat_sys.has_method("get_current_hp"):
			var current_hp = stat_sys.get_current_hp(caster)
			var dmg = floori(current_hp * 0.20)
			if stat_sys.has_method("apply_damage"):
				var applied = stat_sys.apply_damage(caster, dmg, caster, "true")
				EventBus.damage_dealt.emit(caster, applied, "true", false, null)
	
	# Apply +4 Armor buff for 1 turn
	# TODO (Gilang): Ensure the Status Effect System listens for "autotomy_armor_buff"
	# and actually applies the +4 armor mathematically to the StatSystem.
	EventBus.on_status_applied.emit(caster, "autotomy_armor_buff", 1, 4)
	
	# General execution signal
	var event_result = {
		"element_tag": element_tag,
		"knockback_tiles": 0,
		"status_effect": "autotomy_armor_buff",
		"is_crit": false
	}
	EventBus.ability_executed.emit(caster, targets, event_result)
