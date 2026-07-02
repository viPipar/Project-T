extends Sprite2D
class_name SkillCastVFX

var fps: float = 24.0
var _total_frames: int = 1
var _timer: float = 0.0

func setup(tex_path: String, h: int, v: int = 1, animation_fps: float = 24.0, scale_factor: float = 1.0) -> void:
	if not ResourceLoader.exists(tex_path):
		push_warning("[SkillCastVFX] Texture not found: %s" % tex_path)
		queue_free()
		return
	texture = load(tex_path)
	hframes = h
	vframes = v
	_total_frames = h * v
	fps = animation_fps
	scale = Vector2(scale_factor, scale_factor)
	z_index = 1500

func _process(delta: float) -> void:
	_timer += delta
	var current_frame = int(_timer * fps)
	if current_frame >= _total_frames:
		queue_free()
	else:
		frame = current_frame
