extends TextureRect

@export_group("Idle Animation")
@export var float_enabled: bool = true
@export var float_speed: float = 2.0
@export var float_range: float = 12.0
@export var float_direction: Vector2 = Vector2.UP

@export_group("Wisp Effects")
@export var wisps_enabled: bool = true
@export var spawn_interval: float = 0.06 # Spawn a wisp every 0.06s
@export var wisp_base_size: float = 1.8
@export var gravity: Vector2 = Vector2(350.0, 180.0) # Gravity pulling down-right

@export_group("Wisp Colors")
@export var color_start: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var color_mid: Color = Color(1.0, 0.75, 0.2, 1.0) # Golden-yellow
@export var color_end: Color = Color(0.85, 0.1, 0.1, 0.0) # Transparent Red

@onready var character: TextureRect = $Character

# Animation variables
var _time: float = 0.0
var _char_start_pos: Vector2

# Wisp tracking
var _wisps: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _circle_tex: GradientTexture2D = null

func _ready() -> void:
	if character:
		_char_start_pos = character.position
	_time = randf_range(0.0, 100.0)

func _process(delta: float) -> void:
	# 1. Idle Breathing Animation
	if float_enabled and character:
		_time += delta
		var offset = float_direction * sin(_time * float_speed) * float_range
		character.position = _char_start_pos + offset
		
	# 2. Wisp Spawning and Updating
	if wisps_enabled:
		_update_wisps(delta)

func _update_wisps(delta: float) -> void:
	# Spawn new wisps
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_wisp()
		
	# Update existing wisps
	for i in range(_wisps.size() - 1, -1, -1):
		var wisp = _wisps[i]
		if not is_instance_valid(wisp.node):
			_wisps.remove_at(i)
			continue
			
		wisp.age += delta
		var t = wisp.age / wisp.lifetime
		
		if t >= 1.0:
			wisp.node.queue_free()
			_wisps.remove_at(i)
			continue
			
		# Apply gravity/attraction to velocity
		wisp.velocity += gravity * delta
		
		# Update position
		wisp.pos += wisp.velocity * delta
		wisp.node.position = wisp.pos
		
		# Velocity-based stretching (motion blur tail)
		var speed = wisp.velocity.length()
		# X scale is stretched proportionally to speed, Y scale is kept thin
		var s_x = clamp(speed * 0.003, 0.6, 3.5) * wisp_base_size * wisp.size_mult
		var s_y = clamp(0.25 - (speed * 0.0001), 0.12, 0.3) * wisp_base_size * wisp.size_mult
		wisp.node.scale = Vector2(s_x, s_y)
		
		# Align rotation with velocity vector
		wisp.node.rotation = wisp.velocity.angle()
		
		# Color progression (color_start -> color_mid -> color_end)
		var current_color: Color
		if t < 0.2:
			current_color = color_start.lerp(color_mid, t / 0.2)
		else:
			current_color = color_mid.lerp(color_end, (t - 0.2) / 0.8)
		wisp.node.modulate = current_color

func _spawn_wisp() -> void:
	var sprite = Sprite2D.new()
	sprite.texture = _get_circle_texture()
	
	# Spawn along the left-ish side of the banner (x is near left, y is random)
	var spawn_x = randf_range(20.0, 150.0)
	var spawn_y = randf_range(100.0, 850.0)
	var spawn_pos = Vector2(spawn_x, spawn_y)
	
	sprite.position = spawn_pos
	
	# Initial velocity: shooting to the right and slightly down/up
	var vel_x = randf_range(400.0, 750.0)
	var vel_y = randf_range(-150.0, 150.0)
	var init_vel = Vector2(vel_x, vel_y)
	
	# Base parameters
	var wisp_data = {
		"node": sprite,
		"pos": spawn_pos,
		"velocity": init_vel,
		"age": 0.0,
		"lifetime": randf_range(0.7, 1.2),
		"size_mult": randf_range(0.8, 1.6)
	}
	
	# Add wisp node behind character
	add_child(sprite)
	move_child(sprite, 1) # Positioned between Background and Character
	
	_wisps.append(wisp_data)

func _get_circle_texture() -> GradientTexture2D:
	if _circle_tex == null:
		var grad_tex = GradientTexture2D.new()
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		grad_tex.fill_from = Vector2(0.5, 0.5)
		grad_tex.fill_to = Vector2(1.0, 0.5)
		
		var grad = Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.set_offset(0, 0.0)
		grad.add_point(0.82, Color.WHITE)
		grad.add_point(0.9, Color(1, 1, 1, 0))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.set_offset(1, 1.0)
		
		grad_tex.gradient = grad
		grad_tex.width = 32
		grad_tex.height = 32
		_circle_tex = grad_tex
	return _circle_tex

func _notification(what: int) -> void:
	# Cleanup wisps on exit tree
	if what == NOTIFICATION_EXIT_TREE:
		for w in _wisps:
			if is_instance_valid(w.node):
				w.node.queue_free()
		_wisps.clear()
