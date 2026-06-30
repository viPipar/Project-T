extends Polygon2D

var tracking_array: Array = []
var fallback_target: Node = null
var current_velocity: Vector2 = Vector2.ZERO
var speed: float = 2200.0
var max_time: float = 1.2
var timer: float = 0.0

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
		var dir = (target_pos - global_position).normalized()
		
		# Very loose steering for massive sweeping curves
		current_velocity = current_velocity.lerp(dir * speed, delta * 4.5)
		global_position += current_velocity * delta
		
		if global_position.distance_to(target_pos) < 25.0:
			queue_free()
	else:
		global_position += current_velocity * delta
