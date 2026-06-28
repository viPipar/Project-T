class_name FloatingDamageNumber
extends Node2D

const FONT_PATH = "res://assets/ui_assets/Bangers-Regular.ttf"
var _label: Label
var _bg_label: Label

func _ready() -> void:
	z_index = 100
	hide()

func display(value: Variant, type: String = "damage", player_id: int = 0) -> void:
	var font = load(FONT_PATH)
	_label = Label.new()
	_bg_label = Label.new()
	
	if font:
		_label.add_theme_font_override("font", font)
		_bg_label.add_theme_font_override("font", font)

	var text_val := str(value)
	var is_crit  := false
	var is_miss  := false
	var is_status := false
	var rot_deg  := 0.0
	var punch_scale := 1.0

	# DEFAULT GENERIC (Enemy / Environmental)
	var fg_color := Color.WHITE
	var outline_color := Color.BLACK
	var font_sz  := 42
	var outline_sz := 8
	var has_glow := true
	
	if type == "damage" or type == "crit":
		var amt := int(value)
		if type == "crit":
			is_crit    = true
			font_sz    = 72
			text_val   = str(amt) + "!!"
			rot_deg    = randf_range(-20.0, -12.0)
			punch_scale = 2.4
			outline_sz = 12
		elif amt >= 15:
			font_sz    = 54
			outline_sz = 10
			rot_deg    = randf_range(-15.0, 15.0)
			punch_scale = 1.8
		else:
			rot_deg    = randf_range(-10.0, 10.0)
			punch_scale = 1.5

		# ── Kustomisasi Player (JUICY) ──────────────────────────
		if player_id == 1:
			fg_color = Color("#111111") # Hitam solid
			outline_color = Color("#E34234") # Vermillion
		elif player_id == 2:
			fg_color = Color.WHITE
			outline_color = Color("#FFD700") # Holy Yellow
			
	elif type == "miss":
		fg_color = Color.WHITE
		outline_color = Color("#9A8FCC")
		font_sz  = 28
		text_val = "miss!"
		is_miss  = true
		rot_deg  = randf_range(-8.0, 8.0)
		punch_scale = 1.2
	elif type == "heal":
		fg_color = Color.WHITE
		outline_color = Color("#4DDD88")
		font_sz    = 42
		text_val   = "+" + str(value)
		rot_deg    = randf_range(-5.0, 5.0)
		punch_scale = 1.4
	else:
		is_status  = true
		font_sz    = 24
		punch_scale = 1.1
		outline_color = Color.BLACK
		if text_val.to_lower() == "poison": fg_color = Color("#8FE060")
		elif text_val.to_lower() == "burn":  fg_color = Color("#FF6030")
		elif text_val.to_lower() == "stun":  fg_color = Color("#FFD700")

	# BG Label (Juicy Drop Shadow & Thick Stroke)
	_bg_label.text = text_val
	_bg_label.add_theme_font_size_override("font_size", font_sz)
	_bg_label.add_theme_color_override("font_color", Color(0,0,0,0.5)) # Shadow
	_bg_label.add_theme_color_override("font_outline_color", outline_color)
	_bg_label.add_theme_constant_override("outline_size", outline_sz)
	_bg_label.position = Vector2(4, 4) if is_crit else Vector2(2, 2)
	add_child(_bg_label)

	# FG Label (Core Text)
	_label.text = text_val
	_label.add_theme_color_override("font_color", fg_color)
	_label.add_theme_color_override("font_outline_color", outline_color.darkened(0.2)) # Inner stroke
	_label.add_theme_constant_override("outline_size", outline_sz / 2)
	_label.add_theme_font_size_override("font_size", font_sz)
	add_child(_label)

	show()
	rotation = deg_to_rad(rot_deg)
	
	await get_tree().process_frame # Wait a frame for sizes to calc properly
	var offset = Vector2(-_label.size.x / 2.0, -_label.size.y / 2.0)
	_bg_label.position += offset
	_label.position += offset

	var total_time := 1.2 if is_crit else (0.8 if is_miss or is_status else 1.0)
	
	# PUNCH IN
	scale = Vector2(punch_scale, punch_scale)
	
	# Hit-Flash Effect (Mata ditipu agar terasa impact keras)
	if has_glow:
		modulate = Color(2.0, 2.0, 2.0, 1.0) # Overbright white
		var ftw = create_tween()
		ftw.tween_property(self, "modulate", Color.WHITE, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	if is_crit:
		var tw_punch := create_tween()
		tw_punch.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		var tw_punch := create_tween()
		tw_punch.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# SPRAY ARC TWEEN
	var dir := 1 if randf() > 0.5 else -1
	var spread_x := randf_range(40.0, 100.0) * dir
	var peak_y := position.y - randf_range(70.0, 120.0)
	var final_y := position.y + randf_range(20.0, 60.0)
	
	var target_x := position.x + spread_x
	
	var tw_x := create_tween()
	tw_x.tween_property(self, "position:x", target_x, total_time).set_trans(Tween.TRANS_LINEAR)
	
	var tw_y := create_tween()
	var up_t := total_time * 0.35
	var down_t := total_time * 0.65
	tw_y.tween_property(self, "position:y", peak_y, up_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_y.tween_property(self, "position:y", final_y, down_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var fade_tw := create_tween()
	fade_tw.tween_interval(up_t + down_t * 0.3)
	fade_tw.tween_property(self, "modulate:a", 0.0, down_t * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await fade_tw.finished
	queue_free()
