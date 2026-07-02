extends AnimatedSprite2D

signal impacted

var element: String = ""
var tracking_array: Array = []
var fallback_target: Node = null
var max_time: float = 3.0 # Fallback safety max time
var timer: float = 0.0

var _is_impacting: bool = false
var _phase: int = 0 # 0=spawned, 1=spread, 2=homing
var active_target_node: Node = null

func _ready() -> void:
	var tex_path := ""
	match element.to_lower():
		"fire": tex_path = "res://assets/ui_assets/projectiles/Fire Wizard_frames.tres"
		"water": tex_path = "res://assets/ui_assets/projectiles/Water Wizard_frames.tres"
		"earth": tex_path = "res://assets/ui_assets/projectiles/Earth Wizard_frames.tres"
		"air", "wind": tex_path = "res://assets/ui_assets/projectiles/Wind Wizard_frames.tres"
		"enemy": tex_path = "res://assets/ui_assets/projectiles/Medium Enemy_frames.tres"
		_: tex_path = "res://assets/ui_assets/projectiles/Fighter_frames.tres"

	if ResourceLoader.exists(tex_path):
		sprite_frames = load(tex_path)
		scale = Vector2(0.12, 0.12)
		play("entry")
		animation_finished.connect(_on_animation_finished)
	else:
		push_warning("[HomingProjectile] Frames not found: %s" % tex_path)

func _on_animation_finished() -> void:
	if animation == "entry":
		play("loop")
	elif animation == "impact":
		queue_free()

func spread_out(center_pos: Vector2, target: Node = null) -> void:
	_phase = 1
	active_target_node = target
	# Spread upwards in a 90 degree cone (-135 to -45 degrees)
	var angle = randf_range(-PI * 0.75, -PI * 0.25)
	var distance = randf_range(240.0, 400.0)
	var spread_pos = center_pos + Vector2(cos(angle), sin(angle)) * distance
	
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", spread_pos, 0.4)

func launch_at(target: Node) -> void:
	_phase = 2
	fallback_target = target
	active_target_node = target
	
	var active_target = target
	if tracking_array.size() > 0 and is_instance_valid(tracking_array[0]) and not tracking_array[0].is_queued_for_deletion():
		if tracking_array[0].has_method("is_dead") and not tracking_array[0].is_dead():
			active_target = tracking_array[0]
		elif not tracking_array[0].has_method("is_dead"):
			active_target = tracking_array[0]
			
	var target_pos = global_position
	if is_instance_valid(active_target):
		target_pos = active_target.global_position + Vector2(0, -32)
		active_target_node = active_target
		
	var dist = global_position.distance_to(target_pos)
	var travel_speed = randf_range(900.0, 1400.0) # Slower than before!
	var travel_time = dist / travel_speed
	
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", target_pos, travel_time)
	tw.finished.connect(_start_impact)

func _start_impact() -> void:
	if _is_impacting: return
	_is_impacting = true
	impacted.emit()
	if sprite_frames and sprite_frames.has_animation("impact"):
		play("impact")
	else:
		queue_free()

func _process(delta: float) -> void:
	timer += delta
	if timer > max_time and not _is_impacting:
		_start_impact()
		
	if not _is_impacting and is_instance_valid(active_target_node):
		var t_pos = active_target_node.global_position + Vector2(0, -32)
		# Add PI/4 (45 degrees) offset because the original sprite is drawn pointing top-right
		rotation = (t_pos - global_position).angle() + PI / 4.0
