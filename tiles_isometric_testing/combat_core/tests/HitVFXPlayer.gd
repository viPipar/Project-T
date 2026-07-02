extends Sprite2D
class_name HitVFXPlayer

var element: String = "basic"
var fps: float = 24.0

var _total_frames: int = 1
var _timer: float = 0.0

func _ready() -> void:
	var tex_path := ""
	var h := 7
	
	match element.to_lower():
		"fire":
			tex_path = "res://assets/ui_assets/vfx/Fire Wizard.png"
			h = 8
		"water":
			tex_path = "res://assets/ui_assets/vfx/Water Wizard.png"
			h = 6
		"earth":
			tex_path = "res://assets/ui_assets/vfx/Earth Wizard.png"
			h = 6
		"air", "wind":
			tex_path = "res://assets/ui_assets/vfx/Wind Wizard.png"
			h = 7
		"physical":
			tex_path = "res://assets/ui_assets/vfx/Fighter.png"
			h = 9
		_:
			tex_path = "res://assets/ui_assets/vfx/Basic white.png"
			h = 7

	if ResourceLoader.exists(tex_path):
		texture = load(tex_path)
		hframes = h
		vframes = 1
		_total_frames = h
		scale = Vector2(0.2, 0.2) # Scale down 1024x1024 hit frames
		z_index = 2000 # Draw above entities
	else:
		push_warning("[HitVFXPlayer] Hit texture not found: %s" % tex_path)
		queue_free()

func _process(delta: float) -> void:
	_timer += delta
	var current_frame = int(_timer * fps)
	if current_frame >= _total_frames:
		queue_free()
	else:
		frame = current_frame
