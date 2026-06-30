extends Node
class_name ShaderEffects

static func teleport(target: CanvasItem, duration: float = 0.6) -> void:
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/teleport_effect.gdshader")
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("noise_desnity", 60.0)
	mat.set_shader_parameter("beam_size", 0.05)
	mat.set_shader_parameter("color", Color(0.0, 1.02, 1.2, 1.0))
	target.material = mat
	var tw = (target.get_tree() as SceneTree).create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("progress", v), 0.0, 1.0, duration).set_ease(Tween.EASE_IN)
	await tw.finished
	target.material = null


static func hit_flash(target: CanvasItem, color: Color = Color.WHITE, duration: float = 0.15) -> void:
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/hit_flash.gdshader")
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash_modifier", 1.0)
	target.material = mat
	var tw = (target.get_tree() as SceneTree).create_tween()
	tw.tween_property(mat, "shader_parameter/flash_modifier", 0.0, duration).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_instance_valid(target) and target.material == mat:
		target.material = null


static func apply_dissolve(target: CanvasItem, noise_tex: NoiseTexture2D = null, duration: float = 1.0, burn_color: Color = Color(1.0, 0.3, 0.0, 1.0)) -> void:
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/2d_dissolve_with_burn_edge.gdshader")
	if noise_tex == null:
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.08
		noise_tex = NoiseTexture2D.new()
		noise_tex.noise = noise
		noise_tex.width = 256
		noise_tex.height = 256
	mat.set_shader_parameter("dissolve_texture", noise_tex)
	mat.set_shader_parameter("dissolve_value", 0.0)
	mat.set_shader_parameter("burn_size", 0.06)
	mat.set_shader_parameter("burn_color", burn_color)
	target.material = mat
	var tw = (target.get_tree() as SceneTree).create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("dissolve_value", v), 0.0, 1.0, duration).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v): mat.set_shader_parameter("burn_color", Color(burn_color.r, burn_color.g, burn_color.b, burn_color.a - v * 0.8)), 0, 1, duration)


static func apply_wind_sway(target: Node, strength_scale: float = 80.0) -> void:
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/2d_wind_sway.gdshader")
	mat.set_shader_parameter("speed", 0.8)
	mat.set_shader_parameter("minStrength", 0.02)
	mat.set_shader_parameter("maxStrength", 0.06)
	mat.set_shader_parameter("strengthScale", strength_scale)
	mat.set_shader_parameter("interval", 4.0)
	mat.set_shader_parameter("detail", 1.5)
	mat.set_shader_parameter("distortion", 0.3)
	mat.set_shader_parameter("heightOffset", 0.0)
	mat.set_shader_parameter("offset", randf() * 10.0)
	if target is CanvasItem:
		target.material = mat
	elif target.has_method("set_material"):
		target.set_material(mat)
	else:
		push_warning("[ShaderEffects] Cannot apply wind sway: %s is not a CanvasItem" % target.name)


static func apply_squigglevision(target: CanvasItem) -> void:
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/squigglevision.gdshader")
	mat.set_shader_parameter("scale", Vector2(1.0, 1.0))
	mat.set_shader_parameter("strength", 1.5)
	mat.set_shader_parameter("fps", 6.0)
	# Need a noise texture for squiggle - use default
	var noise_tex = NoiseTexture2D.new()
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_tex.noise = noise
	noise_tex.width = 64
	noise_tex.height = 64
	mat.set_shader_parameter("noise", noise_tex)
	target.material = mat
