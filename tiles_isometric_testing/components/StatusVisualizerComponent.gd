extends Node2D
class_name StatusVisualizerComponent

var condition_comp: ConditionComponent
var target_sprites: Array[Node2D] = []

@onready var p_blood = $BloodParticles
@onready var p_fire = $FireParticles
@onready var p_water = $WaterParticles
@onready var p_earth = $EarthParticles
@onready var p_air = $AirParticles

@onready var original_star_pivot = $StarPivot

var _active_star_pivots: Array[Node2D] = []
var _stun_turns := 0

# Tints
const TINT_STUN = Color(0.6, 0.6, 0.6)
const TINT_WEAKENED = Color(0.8, 0.7, 0.9)
const TINT_VULNERABLE = Color(1.0, 0.5, 0.5)
const TINT_FIRE = Color(1.0, 0.3, 0.1)
const TINT_WATER = Color(0.2, 0.6, 1.0)
const TINT_EARTH = Color(0.7, 0.5, 0.3)
const TINT_AIR = Color(0.7, 1.0, 1.0)
const TINT_MAGMA = Color(1.0, 0.4, 0.1)
const TINT_MUD = Color(0.4, 0.3, 0.2)
const TINT_NORMAL = Color.WHITE

var _tween: Tween

func _ready() -> void:
	if original_star_pivot:
		original_star_pivot.visible = false
		
	# Attempt to find required components
	var parent = get_parent()
	if parent:
		condition_comp = parent.get_node_or_null("ConditionComponent") as ConditionComponent
		
		# Grab all sprites to tint them all (fixes Player having multiple sprites)
		for child in parent.get_children():
			if child is AnimatedSprite2D or child is Sprite2D:
				target_sprites.append(child)
			
		var health_comp = parent.get_node_or_null("HealthComponent") as HealthComponent
		if health_comp:
			health_comp.died.connect(_on_entity_died)
			
	if condition_comp:
		condition_comp.conditions_changed.connect(_on_conditions_changed)

	_disable_all_particles()

var _star_time := 0.0

func _process(delta: float) -> void:
	if _stun_turns > 0 and _active_star_pivots.size() > 0:
		_star_time += delta * 4.0
		var angle_step = TAU / _active_star_pivots.size()
		for i in range(_active_star_pivots.size()):
			var pivot = _active_star_pivots[i]
			var angle = _star_time + (i * angle_step)
			pivot.position = Vector2(cos(angle) * 45.0, -220.0 + sin(angle) * 12.0)

func _on_entity_died(_killer) -> void:
	_disable_all_particles()
	if _tween and _tween.is_valid():
		_tween.kill()
	for s in target_sprites:
		s.modulate = TINT_NORMAL

func _disable_all_particles() -> void:
	if p_blood: p_blood.emitting = false
	if p_fire: p_fire.emitting = false
	if p_water: p_water.emitting = false
	if p_earth: p_earth.emitting = false
	if p_air: p_air.emitting = false
	
	for p in _active_star_pivots:
		if is_instance_valid(p):
			p.queue_free()
	_active_star_pivots.clear()

func _on_conditions_changed() -> void:
	_update_visuals()

func _update_visuals() -> void:
	if not condition_comp: return
	
	var parent = get_parent()
	if parent:
		var hc = parent.get_node_or_null("HealthComponent") as HealthComponent
		if hc and hc.is_dead():
			return
	
	var is_stunned = condition_comp.has_condition("stunned") or condition_comp.has_condition("frozen")
	if is_stunned:
		if condition_comp.has_method("get_condition_turns"):
			_stun_turns = condition_comp.get_condition_turns("stunned")
			if _stun_turns <= 0:
				_stun_turns = condition_comp.get_condition_turns("frozen")
		else:
			_stun_turns = 1
	else:
		_stun_turns = 0
		
	var is_bleeding = condition_comp.has_condition("bleeding")
	var is_lacerated = condition_comp.has_condition("lacerate")
	var is_weakened = condition_comp.has_condition("weakened")
	var is_vulnerable = condition_comp.has_condition("vulnerable")
	
	# Elements
	var is_fire = condition_comp.has_condition("fire")
	var is_water = condition_comp.has_condition("water")
	var is_earth = condition_comp.has_condition("earth")
	var is_air = condition_comp.has_condition("air")
	
	# Combos
	var is_magma = condition_comp.has_condition("magma")
	var is_mud = condition_comp.has_condition("mud")
	var _is_vapor = condition_comp.has_condition("vapor")
	var is_mist = condition_comp.has_condition("mist")
	var is_erosion = condition_comp.has_condition("erosion")
	var is_conflagration = condition_comp.has_condition("conflagration")
	
	# Determine highest priority tint
	var target_color = TINT_NORMAL
	var do_pulse = false
	
	if is_vulnerable:
		target_color = TINT_VULNERABLE
		do_pulse = true
	elif is_magma:
		target_color = TINT_MAGMA
		do_pulse = true
	elif is_conflagration:
		target_color = TINT_FIRE
		do_pulse = true
	elif is_stunned:
		target_color = TINT_STUN
	elif is_mud:
		target_color = TINT_MUD
	elif is_weakened or is_erosion:
		target_color = TINT_WEAKENED
	elif is_mist:
		target_color = TINT_WATER # Can also set modulate alpha later
	elif is_fire:
		target_color = TINT_FIRE
	elif is_water:
		target_color = TINT_WATER
	elif is_earth:
		target_color = TINT_EARTH
	elif is_air:
		target_color = TINT_AIR
		
	_apply_tint(target_color, do_pulse)
	
	# Particles stack
	if p_blood: p_blood.emitting = is_bleeding or is_lacerated
	if p_blood and is_lacerated:
		p_blood.amount = 8 # More blood
	if p_blood:
		p_blood.amount = 3
		
	if is_stunned and _active_star_pivots.size() != _stun_turns:
		# Clear old stars
		for p in _active_star_pivots:
			if is_instance_valid(p):
				p.queue_free()
		_active_star_pivots.clear()
		
		# Spawn new stars based on turns
		for i in range(_stun_turns):
			if original_star_pivot:
				var new_pivot = original_star_pivot.duplicate()
				add_child(new_pivot)
				new_pivot.visible = true
				if new_pivot.has_node("StarParticles"):
					new_pivot.get_node("StarParticles").emitting = true
				_active_star_pivots.append(new_pivot)
	elif not is_stunned and _active_star_pivots.size() > 0:
		for p in _active_star_pivots:
			if is_instance_valid(p):
				p.queue_free()
		_active_star_pivots.clear()
	
	if p_fire: p_fire.emitting = is_fire or is_magma or is_conflagration
	if p_fire and is_conflagration:
		p_fire.amount = 15
	elif p_fire:
		p_fire.amount = 5
		
	if p_water: p_water.emitting = is_water or is_mud or is_mist
	if p_earth: p_earth.emitting = is_earth or is_magma or is_mud or is_erosion
	if p_air: p_air.emitting = is_air or is_conflagration or is_mist or is_erosion

func _apply_tint(color: Color, pulse: bool) -> void:
	if target_sprites.is_empty(): return
	
	if _tween and _tween.is_valid():
		_tween.kill()
		
	if pulse:
		_tween = create_tween().set_loops()
		_tween.set_parallel(true)
		for s in target_sprites:
			_tween.tween_property(s, "modulate", color, 0.5)
		
		_tween.chain().set_parallel(true)
		for s in target_sprites:
			_tween.tween_property(s, "modulate", TINT_NORMAL, 0.5)
	else:
		_tween = create_tween()
		_tween.set_parallel(true)
		for s in target_sprites:
			_tween.tween_property(s, "modulate", color, 0.3)
