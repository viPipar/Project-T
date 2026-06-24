class_name FloatingDamageNumber
extends Node2D

static var _last_spawn_time: int = 0
static var _spawn_count: int = 0

const FONT_PATH = "res://assets/ui_assets/Bangers-Regular.ttf"
var _label: Label

func _ready() -> void:
	z_index = 100
	hide()

func display(value: Variant, type: String = "damage") -> void:
	var font = load(FONT_PATH)
	_label = Label.new()
	if font: _label.add_theme_font_override("font", font)
	
	var text_val := str(value)
	var color := Color.WHITE
	var outline := Color.BLACK
	var outline_sz := 0
	var font_sz := 32
	var has_glow := false
	var glow_color := Color.WHITE
	var is_crit := false
	var is_miss := false
	var is_status := false
	
	if type == "damage" or type == "crit":
		var amt = int(value)
		if type == "crit":
			color = Color("#FF3B1E")
			outline = Color.BLACK
			outline_sz = 3
			font_sz = 56
			text_val = str(amt) + "!!"
			has_glow = true
			glow_color = Color(1.0, 0.5, 0.2, 1.0)
			is_crit = true
			self.skew = deg_to_rad(-15)
		elif amt >= 15:
			color = Color("#FF8C00")
			outline = Color("#6B0000")
			outline_sz = 3
			font_sz = 44
			has_glow = true
			glow_color = Color(1.0, 0.7, 0.2, 1.0)
		else:
			color = Color("#F5C842")
			outline = Color("#3B1F00")
			outline_sz = 2
			font_sz = 34
	elif type == "miss":
		color = Color("#9A8FCC")
		font_sz = 22
		text_val = "miss!"
		is_miss = true
		self.skew = deg_to_rad(-10)
	elif type == "heal":
		color = Color("#4DDD88")
		outline = Color("#1A5C35")
		outline_sz = 2
		font_sz = 32
		text_val = "+" + str(value)
		has_glow = true
		glow_color = Color(0.5, 1.0, 0.6, 1.0)
	else: # status
		is_status = true
		font_sz = 20
		if text_val.to_lower() == "poison": color = Color("#8FE060")
		elif text_val.to_lower() == "burn": color = Color("#FF6030")
		elif text_val.to_lower() == "stun": color = Color("#FFD700")
		else: color = Color.WHITE

	_label.text = text_val
	_label.add_theme_color_override("font_color", color)
	if outline_sz > 0:
		_label.add_theme_color_override("font_outline_color", outline)
		_label.add_theme_constant_override("outline_size", outline_sz)
	_label.add_theme_font_size_override("font_size", font_sz)
	
	add_child(_label)
	
	var now = Time.get_ticks_msec()
	var delay = 0.0
	if now - _last_spawn_time < 200:
		_spawn_count += 1
		delay = _spawn_count * 0.07
	else:
		_spawn_count = 0
	_last_spawn_time = now
	
	if delay > 0:
		await get_tree().create_timer(delay).timeout
		
	# Random horizontal offset
	position.x += randf_range(-30, 30)
	show()
	
	_label.position = Vector2(-_label.size.x / 2.0, -_label.size.y / 2.0)
	
	var total_time = 1.1 if not is_status and not is_miss else 0.8
	var dist = 80.0 if not is_miss else 40.0
	
	if has_glow:
		modulate = glow_color
		var gtw = create_tween()
		gtw.tween_property(self, "modulate", Color.WHITE, 0.1)
		
	var tw = create_tween()
	tw.set_parallel(true)
	
	if is_crit:
		scale = Vector2(1.5, 1.5)
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		scale = Vector2(0.5, 0.5)
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	var ytw = create_tween()
	ytw.tween_property(self, "position:y", position.y - (dist * 0.6), total_time * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ytw.tween_interval(0.15)
	ytw.tween_property(self, "position:y", position.y - dist, total_time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var ftw = create_tween()
	var fade_start = total_time * 0.55 if not is_miss else total_time * 0.4
	ftw.tween_interval(fade_start)
	ftw.tween_property(self, "modulate:a", 0.0, total_time - fade_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await ftw.finished
	queue_free()
