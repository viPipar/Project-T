extends Sprite2D

var element: String = ""
var tracking_array: Array = []
var fallback_target: Node = null
var current_velocity: Vector2 = Vector2.ZERO
var speed: float = 2200.0
var max_time: float = 1.2
var timer: float = 0.0
var steer_force_base: float = 15000.0

var _total_frames: int = 1
var _fps: float = 24.0

func _ready() -> void:
	speed = randf_range(1800.0, 2800.0)
	steer_force_base = randf_range(8000.0, 24000.0)
	
	var tex_path := ""
	var h := 6
	var v := 3
	
	match element.to_lower():
		"fire":
			tex_path = "res://assets/ui_assets/projectiles/Fire Wizard.png"
			h = 5
		"water":
			tex_path = "res://assets/ui_assets/projectiles/Water Wizard.png"
			h = 6
		"earth":
			tex_path = "res://assets/ui_assets/projectiles/Earth Wizard.png"
			h = 5
		"air", "wind":
			tex_path = "res://assets/ui_assets/projectiles/Wind Wizard.png"
			h = 7
		"enemy":
			tex_path = "res://assets/ui_assets/projectiles/Medium Enemy.png"
			h = 6
		_:
			tex_path = "res://assets/ui_assets/projectiles/Fighter.png"
			h = 6

	if ResourceLoader.exists(tex_path):
		texture = load(tex_path)
		hframes = h
		vframes = v
		_total_frames = h * v
		scale = Vector2(0.12, 0.12)
	else:
		push_warning("[HomingProjectile] Texture not found: %s" % tex_path)

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
		
		var steer_force = steer_force_base * delta
		if steering.length() > steer_force:
			steering = steering.normalized() * steer_force
			
		current_velocity += steering
		
		if current_velocity.length() > speed:
			current_velocity = current_velocity.normalized() * speed
		global_position += current_velocity * delta
		
		if global_position.distance_to(target_pos) < 25.0:
			queue_free()
	else:
		global_position += current_velocity * delta

	# Animate frame
	if texture != null and _total_frames > 1:
		frame = int(timer * _fps) % _total_frames

	# Rotate towards velocity direction
	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()
