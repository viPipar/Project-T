class_name HakiAura
extends Node2D

# HakiAura v6 - Industry Standard Juicy Aura (Browser-Safe)
# Teknik: Manual Sprite2D per partikel dikontrol via _process()
# - Fake Glow Sprite additive (menggantikan PointLight2D)
# - Screen Flash saat aktivasi (impact frame technique)
# - Ignition Burst one-shot (12 partikel saat ignite)
# - 2-Tier depth layers (inti kecil-cepat + asap besar-lambat)
# - Crown Sparks di titik hisap setiap 0.22 detik
# - Per-player color palettes (P1: Vermillion/Hitam, P2: Putih/Emas)
# 100% browser-safe. No GPU particles. No shaders. No lighting system needed.

@export var suck_y : float = -275.0

const RISE_END       := 0.72
const RISE_TARGET    := 0.90
const SPAWN_INTERVAL := 0.13
const LIFETIME_MIN   := 1.1
const LIFETIME_MAX   := 1.5
const SPAWN_Y_MIN    := 20.0
const SPAWN_Y_MAX    := 52.0
const SPAWN_X_RANGE  := 26.0
const CROWN_INTERVAL := 0.22

var _wisps        : Array            = []
var _spawn_timer  : float            = 0.0
var _crown_timer  : float            = 0.0
var _active       : bool             = false
var _player_id    : int              = 1
var _parent_sprite: AnimatedSprite2D = null

var _wisp_tex    : ImageTexture
var _spark_tex   : ImageTexture
var _glow_sprite : Sprite2D
var _glow_tween  : Tween

var _mat_add     : CanvasItemMaterial
var _mat_mix     : CanvasItemMaterial


func _ready() -> void:
	_wisp_tex  = _make_wisp_texture(12, 28)
	_spark_tex = _make_circle_texture(12)
	_mat_add   = CanvasItemMaterial.new()
	_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mat_mix   = CanvasItemMaterial.new()
	_mat_mix.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_wisp()

	_crown_timer += delta
	if _crown_timer >= CROWN_INTERVAL:
		_crown_timer = 0.0
		_spawn_crown_sparks()

	for i in range(_wisps.size() - 1, -1, -1):
		var d  : Dictionary = _wisps[i]
		var nd : Node       = d["node"]
		if not is_instance_valid(nd):
			_wisps.remove_at(i)
			continue

		d["time"] = float(d["time"]) + delta
		var t     : float = clamp(float(d["time"]) / float(d["dur"]), 0.0, 1.0)
		var new_pos : Vector2

		if t <= RISE_END:
			var rt     : float = t / RISE_END
			var et     : float = rt * rt * (3.0 - 2.0 * rt)
			var y      : float = lerp(float(d["spawn_y"]), suck_y * RISE_TARGET, et)
			var wave_d : float = 1.0 - rt * 0.55
			var x      : float = float(d["start_x"]) \
				+ sin(float(d["time"]) * float(d["wave_freq"]) + float(d["phase"])) \
				* float(d["wave_amp"]) * wave_d
			new_pos = Vector2(x, y)
			d["suck_entry_x"] = new_pos.x
			d["suck_entry_y"] = new_pos.y
		else:
			var st      : float   = (t - RISE_END) / (1.0 - RISE_END)
			var ease_st : float   = st * st * st
			var entry   : Vector2 = Vector2(float(d["suck_entry_x"]), float(d["suck_entry_y"]))
			new_pos = entry.lerp(Vector2(0.0, suck_y), ease_st)

		var vel     : Vector2 = new_pos - Vector2(float(d["cur_x"]), float(d["cur_y"]))
		var speed   : float   = vel.length() / maxf(delta, 0.0001)
		var stretch : float   = clamp(1.0 + speed * 0.0012, 1.0, 3.0)

		if vel.length_squared() > 0.1:
			nd.rotation = vel.angle() + PI * 0.5

		d["cur_x"]  = new_pos.x
		d["cur_y"]  = new_pos.y
		nd.position = new_pos

		var s : float
		if t <= RISE_END:
			var rt  : float = t / RISE_END
			var sm  : float = smoothstep(0.0, 0.15, rt)
			var sm2 : float = smoothstep(0.70, 1.0, rt)
			s = sm * (1.0 - sm2 * 0.3)
		else:
			var st : float = (t - RISE_END) / (1.0 - RISE_END)
			s = 1.0 - st * st
		nd.scale = Vector2(s * float(d["base_scale"]), s * float(d["base_scale"]) * stretch)

		var alpha : float
		if t < 0.15:
			alpha = t / 0.15
		elif t > RISE_END:
			var st : float = (t - RISE_END) / (1.0 - RISE_END)
			alpha = 1.0 - st
		else:
			alpha = 1.0
		nd.modulate.a = alpha * float(d["opacity"])

		if t >= 1.0:
			nd.queue_free()
			_wisps.remove_at(i)


func _get_palette(pid: int) -> Dictionary:
	if pid == 2:
		return {
			"hot"   : Color(1.00, 1.00, 1.00, 1.0),
			"warm"  : Color(1.00, 0.94, 0.40, 1.0),
			"dark"  : Color(0.85, 0.72, 0.18, 1.0),
			"accent": Color(0.95, 0.90, 0.70, 1.0),
			"glow"  : Color(1.00, 0.92, 0.30, 1.0),
		}
	return {
		"hot"   : Color(1.00, 0.30, 0.10, 1.0),
		"warm"  : Color(1.00, 0.55, 0.20, 1.0),
		"dark"  : Color(0.05, 0.00, 0.00, 1.0),
		"accent": Color(0.30, 0.04, 0.01, 1.0),
		"glow"  : Color(1.00, 0.15, 0.05, 1.0),
	}


func _spawn_wisp() -> void:
	var pal      : Dictionary = _get_palette(_player_id)
	var is_tier1 : bool       = randf() < 0.40

	var p       := Sprite2D.new()
	var is_dark : bool = false

	if is_tier1:
		p.modulate = pal["hot"] if randf() > 0.4 else pal["warm"]
		p.material = _mat_add
		p.texture  = _spark_tex if randf() > 0.55 else _wisp_tex
		p.z_index  = 4
	else:
		p.modulate = pal["dark"] if randf() > 0.40 else pal["accent"]
		p.material = _mat_mix
		p.texture  = _wisp_tex
		p.z_index  = 2
		is_dark    = true

	add_child(p)

	var spawn_y : float = randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX)
	var start_x : float = randf_range(-SPAWN_X_RANGE, SPAWN_X_RANGE)
	var base_s  : float
	var dur     : float
	var wave_f  : float
	var wave_a  : float

	if is_tier1:
		base_s = randf_range(0.40, 0.85)
		dur    = randf_range(0.85, 1.15)
		wave_f = randf_range(2.5, 5.0)
		wave_a = randf_range(6.0, 16.0)
	else:
		base_s  = randf_range(0.90, 1.60)
		dur     = randf_range(1.20, 1.60)
		wave_f  = randf_range(1.5, 3.5)
		wave_a  = randf_range(15.0, 32.0)
		start_x *= 1.25

	p.position = Vector2(start_x, spawn_y)
	p.scale    = Vector2.ZERO

	_wisps.append({
		"node"        : p,
		"time"        : 0.0,
		"dur"         : dur,
		"spawn_y"     : spawn_y,
		"start_x"     : start_x,
		"wave_freq"   : wave_f,
		"wave_amp"    : wave_a,
		"phase"       : randf() * TAU,
		"base_scale"  : base_s,
		"opacity"     : randf_range(0.65, 1.00),
		"cur_x"       : start_x,
		"cur_y"       : spawn_y,
		"suck_entry_x": start_x,
		"suck_entry_y": spawn_y * RISE_TARGET,
	})


func _burst_ignite() -> void:
	var pal : Dictionary = _get_palette(_player_id)
	for i in range(12):
		var p       := Sprite2D.new()
		p.modulate   = pal["hot"] if randf() > 0.35 else pal["warm"]
		p.material   = _mat_add
		p.texture    = _spark_tex if randf() > 0.5 else _wisp_tex
		p.z_index    = 6
		p.modulate.a = 0.95

		var spawn_y : float = randf_range(-130.0, 10.0)
		var angle   : float = randf() * TAU
		var s       : float = randf_range(0.4, 1.1)
		p.position  = Vector2(cos(angle) * 8.0, spawn_y)
		p.scale     = Vector2(s, s)
		add_child(p)

		var dist   : float   = randf_range(18.0, 60.0)
		var target : Vector2 = Vector2(cos(angle) * dist, spawn_y + sin(angle) * dist * 0.4)
		var dur    : float   = randf_range(0.25, 0.50)

		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position",   target,       dur)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(p, "modulate:a", 0.0,          dur)\
			.set_ease(Tween.EASE_IN)
		tw.tween_property(p, "scale",      Vector2.ZERO, dur * 0.75)\
			.set_ease(Tween.EASE_IN).set_delay(dur * 0.25)
		tw.chain().tween_callback(p.queue_free)


func _screen_flash() -> void:
	var pal : Dictionary = _get_palette(_player_id)
	var gc  : Color      = pal["glow"]
	var cl  := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)

	var rect     := ColorRect.new()
	rect.color    = Color(gc.r, gc.g, gc.b, 0.0)
	rect.size     = Vector2(6000.0, 6000.0)
	rect.position = Vector2(-3000.0, -3000.0)
	cl.add_child(rect)

	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.28, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "color:a", 0.0,  0.22).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(cl.queue_free)


func _spawn_crown_sparks() -> void:
	var pal   : Dictionary = _get_palette(_player_id)
	var count : int        = randi_range(2, 3)
	for i in range(count):
		var p       := Sprite2D.new()
		p.modulate   = pal["hot"] if randf() > 0.4 else pal["warm"]
		p.material   = _mat_add
		p.texture    = _spark_tex
		p.z_index    = 7
		p.position   = Vector2(0.0, suck_y)
		var s        : float = randf_range(0.25, 0.60)
		p.scale      = Vector2(s, s)
		p.modulate.a = 0.0
		add_child(p)

		var target : Vector2 = Vector2(
			randf_range(-16.0, 16.0),
			suck_y + randf_range(-14.0, 14.0)
		)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "modulate:a", 1.0,    0.06).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "position",   target, 0.14)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.chain().tween_property(p, "modulate:a", 0.0, 0.09)
		tw.chain().tween_callback(p.queue_free)


func _setup_glow_sprite() -> void:
	_glow_sprite          = Sprite2D.new()
	_glow_sprite.texture  = _make_circle_texture(128)
	_glow_sprite.material = _mat_add
	var gc                : Color = _get_palette(_player_id)["glow"]
	_glow_sprite.modulate = Color(gc.r, gc.g, gc.b, 0.0)
	_glow_sprite.scale    = Vector2(4.5, 4.5)
	_glow_sprite.position = Vector2(0.0, -80.0)
	_glow_sprite.z_index  = -2
	add_child(_glow_sprite)

	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_glow_sprite, "modulate:a", 0.55, 0.40)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(_glow_sprite, "modulate:a", 0.20, 0.40)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _make_circle_texture(size: int) -> ImageTexture:
	var img    := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center : Vector2 = Vector2(size * 0.5, size * 0.5)
	var radius : float   = size * 0.5
	for y in range(size):
		for x in range(size):
			var dist  : float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			var t     : float = dist / radius
			var sm    : float = smoothstep(0.0, 1.0, t)
			var alpha : float = clamp(1.0 - sm, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _make_wisp_texture(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx  : float = w * 0.5
	var cy  : float = h * 0.5
	for y in range(h):
		for x in range(w):
			var nx    : float = (x + 0.5 - cx) / (w * 0.5)
			var ny    : float = (y + 0.5 - cy) / (h * 0.5)
			var dist  : float = sqrt(nx * nx + ny * ny * 0.18)
			var alpha : float = clamp(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 1.4)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func activate(parent_sprite: AnimatedSprite2D = null, p_id: int = 1) -> void:
	if _active:
		return
	_active        = true
	_player_id     = p_id
	_parent_sprite = parent_sprite
	_spawn_timer   = SPAWN_INTERVAL
	_crown_timer   = 0.0

	_setup_glow_sprite()
	_screen_flash()
	_burst_ignite()

	set_process(true)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	set_process(false)

	for d in _wisps:
		var nd : Node = d["node"]
		if is_instance_valid(nd):
			var tw := create_tween()
			tw.tween_property(nd, "modulate:a", 0.0, 0.25)
			tw.chain().tween_callback(nd.queue_free)
	_wisps.clear()

	if is_instance_valid(_glow_sprite):
		if _glow_tween:
			_glow_tween.kill()
			_glow_tween = null
		var tw := create_tween()
		tw.tween_property(_glow_sprite, "modulate:a", 0.0, 0.40).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(_glow_sprite.queue_free)

	await get_tree().create_timer(0.40).timeout
	_parent_sprite = null
