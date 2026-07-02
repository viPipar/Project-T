extends Node2D
class_name MagicCircleVFX

const ELEMENT_COLORS := {
	"fire": Color(1, 0.3, 0.1),
	"water": Color(0.2, 0.5, 1),
	"ice": Color(0.4, 0.8, 1),
	"wind": Color(0.3, 1, 0.4),
	"air": Color(0.3, 1, 0.4),
	"electric": Color(1, 0.9, 0.1),
	"lightning": Color(1, 0.9, 0.1),
	"earth": Color(0.6, 0.4, 0.15),
	"arcane": Color(0.8, 0.3, 1),
	"shadow": Color(0.6, 0.1, 0.6),
	"holy": Color(1, 0.9, 0.6),
	"poison": Color(0.3, 0.8, 0.2),
	"enemy": Color(1, 0.2, 0.2),
}

func setup(element_tag: String, global_pos: Vector2, scale_factor: float = 1.0) -> void:
	var color = ELEMENT_COLORS.get(element_tag.to_lower(), Color(0.8, 0.8, 1))
	global_position = global_pos
	z_index = 1500

	var circle_tex = preload("res://assets/brackeys_vfx_bundle/particles/alpha/circle_01_a.png")
	if not circle_tex:
		queue_free()
		return

	var ring := Sprite2D.new()
	ring.texture = circle_tex
	ring.self_modulate = color
	ring.scale = Vector2.ZERO
	ring.z_index = 0
	add_child(ring)

	var glow := Sprite2D.new()
	glow.texture = circle_tex
	glow.self_modulate = Color(color.r, color.g, color.b, 0.3)
	glow.scale = Vector2.ZERO
	glow.material = _make_additive_material()
	glow.z_index = -1
	add_child(glow)

	var particle_root := Node2D.new()
	particle_root.z_index = 1
	add_child(particle_root)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(scale_factor, scale_factor), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow, "scale", Vector2(scale_factor * 1.3, scale_factor * 1.3), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow, "self_modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.tween_property(ring, "self_modulate:a", 0.0, 0.25).set_delay(0.45)

	for _i in range(12):
		var dot := ColorRect.new()
		dot.color = color
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size = Vector2(6, 6)
		dot.material = _make_additive_material()
		dot.position = Vector2.ZERO
		particle_root.add_child(dot)

		var angle = randf_range(0, TAU)
		var dist = randf_range(30, 70)
		var dur = randf_range(0.3, 0.6)
		var target_pos = Vector2(cos(angle), sin(angle)) * dist

		tw.tween_property(dot, "position", target_pos, dur).set_delay(0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(dot, "modulate:a", 0.0, dur * 0.5).set_delay(0.1 + dur * 0.5)

	tw.tween_callback(func(): queue_free()).set_delay(0.9)

func _make_additive_material() -> Material:
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat
