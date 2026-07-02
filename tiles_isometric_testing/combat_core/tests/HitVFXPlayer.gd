extends Sprite2D
class_name HitVFXPlayer

var element: String = "basic"
var fps: float = 24.0

var _total_frames: int = 1
var _timer: float = 0.0

func _ready() -> void:
	var tex_path := ""
	var h := 1
	var v := 1
	var scale_f := 0.7
	
	match element.to_lower():
		"fire":
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/explosion_6x5.png"
			h = 6; v = 5; scale_f = 0.8
		"water", "ice":
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/wavy_blue_6x5.png"
			h = 6; v = 5; scale_f = 0.8
		"earth":
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/big_hit_6x5.png"
			h = 6; v = 5; scale_f = 0.8
		"air", "wind":
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/wavy_purple_6x5.png"
			h = 6; v = 5; scale_f = 0.8
		"electric", "lightning":
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/electric_ring_6x5.png"
			h = 6; v = 5; scale_f = 0.8
		"poison", "acid":
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/blood_impact_6x5.png"
			h = 6; v = 5; scale_f = 0.8
			modulate = Color(0.3, 0.9, 0.1) # Toxic green tint
		"physical", "enemy":
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/big_hit_6x5.png"
			h = 6; v = 5; scale_f = 0.8
		_:
			tex_path = "res://assets/brackeys_vfx_bundle/predrawn/impact_white_6x4.png"
			h = 6; v = 4; scale_f = 0.8

	if ResourceLoader.exists(tex_path):
		texture = load(tex_path)
		hframes = h
		vframes = v
		_total_frames = h * v
		scale = Vector2(scale_f, scale_f)
		z_index = 2000 # Draw above entities
		fps = 30.0 # Snappy hit effect
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
