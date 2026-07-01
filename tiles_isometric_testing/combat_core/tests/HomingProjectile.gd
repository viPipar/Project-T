extends Polygon2D

var tracking_array: Array = []
var fallback_target: Node = null
var current_velocity: Vector2 = Vector2.ZERO
var speed: float = 2200.0
var max_time: float = 1.2
var timer: float = 0.0
var steer_force_base: float = 15000.0

func _ready() -> void:
	speed = randf_range(1800.0, 2800.0)
	steer_force_base = randf_range(8000.0, 24000.0)

func _process(delta: float) -> void:
	timer += delta
	if timer >= max_time:
		queue_free()
		return
		
	var active_target = fallback_target
	if tracking_array.size() > 0 and is_instance_valid(tracking_array[0]) and not tracking_array[0].is_queued_for_deletion():
		if tracking_array[0].has_method("is_dead"):
			if not tracking_array[0].is_dead():
				active_target = tracking_array[0]
		else:
			active_target = tracking_array[0]
			
	if is_instance_valid(active_target):
		var target_pos = active_target.global_position + Vector2(0, -32)
		var desired_velocity = (target_pos - global_position).normalized() * speed
		var steering = (desired_velocity - current_velocity)
		
		# Apply a strong steering force
		var steer_force = steer_force_base * delta
		if steering.length() > steer_force:
			steering = steering.normalized() * steer_force
			
		current_velocity += steering
		
		# Clamp to max speed
		if current_velocity.length() > speed:
			current_velocity = current_velocity.normalized() * speed
		global_position += current_velocity * delta
		
		if global_position.distance_to(target_pos) < 25.0:
			queue_free()
	else:
		global_position += current_velocity * delta
