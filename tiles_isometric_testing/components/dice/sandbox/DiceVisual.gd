extends Node2D

# Sinyal saat animasi lemparan benar-benar selesai mendarat
signal roll_finished(final_number: int)

# --- KONFIGURASI PATH ASSET ---
# Ganti ini jika foldermu berbeda (wajib diakhiri dengan /)
const SPRITE_FOLDER_PATH = "res://components/dice/sandbox/sprites/"

# --- KONEKSI NODE ---
@onready var dice_sprite: Sprite2D = $DiceSprite
@onready var number_label: Label = $NumberLabel

# --- VARIABEL ---
var _final_result: int = 0
var _viewport_rect: Rect2 # Untuk menyimpan ukuran layar
var _central_pos: Vector2 # Posisi tengah layar tempat mendarat

# --- VARIABEL BARU ---
var _is_rolling: bool = false
var _roll_timer: float = 0.0
var _roll_frame_idx: int = 0
var _current_roll_duration: float = 2.6
var _outcome: String = "hit"
var _player_id: int = 0
var _base_scale: Vector2 = Vector2(0.6, 0.6)

# Cache Asset Dadu
var _dice_cache_static: Dictionary = {}
var _dice_cache_rolls: Dictionary = {}

var _current_rolls: Array[Texture2D] = []
var _current_static: Texture2D = null

var _orbital_particles: Array[Dictionary] = []




var _roll_tween: Tween
var _scale_tween: Tween
var _reveal_tween: Tween

func skip_roll() -> void:
	if not _is_rolling: return
	_is_rolling = false
	if _roll_tween and _roll_tween.is_valid():
		_roll_tween.custom_step(10.0)
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.custom_step(10.0)

func _get_dice_static(type: String) -> Texture2D:
	if not _dice_cache_static.has(type):
		var path = "res://assets/dice/%s/%s_static.png" % [type, type]
		if not ResourceLoader.exists(path): type = "d20"; path = "res://assets/dice/d20/d20_static.png"
		_dice_cache_static[type] = load(path)
	return _dice_cache_static[type]

func _get_dice_rolls(type: String) -> Array[Texture2D]:
	if not _dice_cache_rolls.has(type):
		var arr: Array[Texture2D] = []
		if not ResourceLoader.exists("res://assets/dice/%s/%s_roll_1.png" % [type, type]): type = "d20"
		arr.append(load("res://assets/dice/%s/%s_roll_1.png" % [type, type]))
		arr.append(load("res://assets/dice/%s/%s_roll_2.png" % [type, type]))
		arr.append(load("res://assets/dice/%s/%s_roll_3.png" % [type, type]))
		_dice_cache_rolls[type] = arr
	return _dice_cache_rolls[type]

func _ready() -> void:

	# Sembunyikan angka dan sprite saat awal
	number_label.hide()
	dice_sprite.visible = false
	# Perkecil ukuran keseluruhan dadu (karena asetnya terlalu besar)
	self.scale = Vector2(0.6, 0.6)
	
	# --- PERBAIKAN TEKS / LABEL ---
	# Set ukuran kotak label cukup besar agar teks muat
	var custom_font = load("res://assets/ui_assets/MedievalSharp-Regular.ttf")
	if custom_font:
		number_label.add_theme_font_override("font", custom_font)

	number_label.size = Vector2(240, 160)
	# Set pivot ke tengah label agar animasi pop-up meledak dari tengah
	number_label.pivot_offset = Vector2(120, 80)
	number_label.position = Vector2(-120, -80 + 20)
	# Perbesar ukuran font-nya secara signifikan agar crisp saat diskala turun ke 0.2
	number_label.add_theme_font_size_override("font_size", 140)
	number_label.add_theme_constant_override("outline_size", 8)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Ambil data ukuran layar dan posisi tengahnya
	_viewport_rect = get_viewport_rect()
	_central_pos = _viewport_rect.get_center()

func _process(delta: float) -> void:

	if _is_rolling:
		_roll_timer += delta
		# Ganti frame setiap 0.05 detik untuk efek blur
		if _roll_timer > 0.05:
			_roll_timer = 0.0
			if _current_rolls.size() > 0:
				_roll_frame_idx = (_roll_frame_idx + 1) % _current_rolls.size()
				dice_sprite.texture = _current_rolls[_roll_frame_idx]

	# Update orbital particles secara manual agar tidak bug di tween_method Godot 4
	for i in range(_orbital_particles.size() - 1, -1, -1):
		var data = _orbital_particles[i]
		if not is_instance_valid(data.node):
			_orbital_particles.remove_at(i)
			continue
			
		data.time += delta
		var t = clamp(data.time / data.dur, 0.0, 1.0)
		
		# Smoothstep untuk pacing putaran yang juicy (cepat -> lambat melayang -> cepat)
		var angle_t = t * t * (3.0 - 2.0 * t)
		var current_ang = lerp(data.start_ang, data.end_ang, angle_t)
		
		var r_mult = 0.0
		if t < 0.3:
			# Meledak memutar ke luar (Ease Out)
			var nt = t / 0.3
			r_mult = 1.0 - pow(1.0 - nt, 3.0)
		elif t <= 0.75:
			# Hang time
			r_mult = 1.0
		else:
			# Tersedot ke tengah kilat (Ease In)
			var nt = (t - 0.75) / 0.25
			r_mult = 1.0 - pow(nt, 3.0)
			
		var current_pos = data.center + Vector2(cos(current_ang) * data.rx * r_mult, sin(current_ang) * data.ry * r_mult)
		data.node.global_position = current_pos
		
		# Rotasi memanjang (stretching) menunjuk ke arah velocity
		var vel = current_pos - data.last_pos
		if vel.length_squared() > 0.01:
			data.node.rotation = vel.angle()
		elif t < 0.05:
			# Rotasi awal jika belum bergerak
			data.node.rotation = data.start_ang + (PI/2.0 if data.end_ang > data.start_ang else -PI/2.0)
			
		data.last_pos = current_pos
		
		# Opacity Fading (Juicy trail fade)
		if t < 0.1:
			data.node.modulate.a = t / 0.1
		elif t > 0.8:
			data.node.modulate.a = 1.0 - ((t - 0.8) / 0.2)
		else:
			data.node.modulate.a = 1.0
		
		if data.time >= data.dur:
			if is_instance_valid(data.node):
				data.node.queue_free()
			_orbital_particles.remove_at(i)


func start_roll(result: int, dice_type: String = "custom", roll_duration: float = 2.6, target_pos: Vector2 = Vector2.ZERO, p_id: int = 0, outcome: String = "hit", in_place: bool = false, base_scale_override: Vector2 = Vector2(0.6, 0.6)) -> void:
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
	self.modulate.a = 1.0
	
	# Bersihkan partikel dari roll sebelumnya
	for data in _orbital_particles:
		if is_instance_valid(data.node):
			data.node.queue_free()
	_orbital_particles.clear()
	
	for child in get_children():
		if child.is_in_group("landing_vfx"):
			child.queue_free()
			
	_final_result = result
	_outcome = outcome
	_player_id = p_id
	
	number_label.hide()
	
	dice_sprite.visible = true
	
	# --- PILIH TIPE DADU ---
	if dice_type == "custom" or dice_type == "":
		dice_type = "d20"
	
	_current_rolls = _get_dice_rolls(dice_type)
	_current_static = _get_dice_static(dice_type)
	
	# Mulai efek blur
	_is_rolling = true
	_roll_timer = 0.0
	_roll_frame_idx = 0
	if _current_rolls.size() > 0:
		dice_sprite.texture = _current_rolls[0]
		
	# --- RESET POSISI DAN ROTASI AWAL ---
	dice_sprite.rotation = 0
	dice_sprite.scale = Vector2(0.5, 0.5) # Mulai dari kecil
	_base_scale = base_scale_override
	self.scale = _base_scale # Pastikan base scale reset jika terpotong
	_current_roll_duration = roll_duration
	
	_viewport_rect = get_viewport_rect()
	var screen_w := _viewport_rect.size.x
	var screen_h := _viewport_rect.size.y
	
	# Tentukan target pendaratan (central_pos)
	if target_pos != Vector2.ZERO:
		_central_pos = target_pos
	else:
		_central_pos = _viewport_rect.get_center()
		
	if in_place:
		# Just pop up slightly above the target
		global_position = _central_pos
	else:
		# Set posisi awal dadu (P1 dari kiri jauh, P2 dari kanan jauh)
		var start_y = _central_pos.y + 100 # Agak ke bawah sedikit agar melengkung ke atas
		if p_id == 2:
			global_position = Vector2(screen_w + 150, start_y)
		else:
			global_position = Vector2(-150, start_y)
	
	# --- TWEEN TERARAH (Directed Trajectory) ---
	var tween = create_tween()
	_roll_tween = tween
	tween.set_parallel(true)
	
	if not in_place:
		# 1. Animasi Terbang (Position): Melengkung ke target
		tween.tween_property(self, "global_position", _central_pos, roll_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 2. Animasi Memantul (Scale)
	var scale_tween = create_tween()
	_scale_tween = scale_tween
	
	var b1_up = roll_duration * 0.20
	var b1_dn = roll_duration * 0.18
	var b2_up = roll_duration * 0.16
	var b2_dn = roll_duration * 0.14
	var b3_up = roll_duration * 0.10
	var b3_dn = roll_duration * 0.10
	var b4_up = roll_duration * 0.06
	var b4_dn = roll_duration * 0.06
	
	# Full bouncy animation regardless of in_place
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.6, 1.6), b1_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(0.7, 0.7), b1_dn).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(1.0))
		
	# Pantulan 2 
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.3, 1.3), b2_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(0.8, 0.8), b2_dn).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(0.75))
		
	# Pantulan 3
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.15, 1.15), b3_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(0.9, 0.9), b3_dn).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(0.5))
		
	# Pantulan 4 (Mendarat)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.08, 1.08), b4_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.0, 1.0), b4_dn).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(0.3))
		
	# 4. Selesai
	# Kita tunggu scale_tween selesai (karena in_place gak pakai pos tween)
	scale_tween.chain().tween_callback(show_result)



func show_result() -> void:
	# Matikan efek blur dan ubah ke frame static
	_is_rolling = false
	dice_sprite.texture = _current_static
	dice_sprite.rotation = 0
	dice_sprite.modulate = Color.WHITE
	
	# Tampilkan angka
	number_label.text = str(_final_result)
	number_label.show()
	
	# Trigger landing VFX
	_play_landing_vfx(_outcome)
	
	# --- OUTCOME VARIANTS ---
	var base_scale = _base_scale
	self.scale = base_scale
	number_label.scale = Vector2(1.0, 1.0)
	_reveal_tween = create_tween()
	var spd_mult = clamp(_current_roll_duration / 2.6, 0.15, 1.0)
	
	_reveal_tween.tween_property(self, "scale", base_scale * 1.5, 0.1 * spd_mult)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "scale", base_scale, 0.2 * spd_mult)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	number_label.scale = Vector2.ZERO
	number_label.modulate.a = 1.0
	
	_reveal_tween.tween_property(number_label, "scale", Vector2(1.5, 1.5), 0.15 * spd_mult)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(number_label, "scale", Vector2(1.0, 1.0), 0.15 * spd_mult)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	
	if _outcome == "crit":
		# Freeze frame briefly
		# Screen shake horizontal only
		spd_mult = 1.2
		_apply_camera_shake(_player_id, 0.2, 6.0)
		# Teks meledak: Dark Crimson border
		number_label.add_theme_color_override("font_color", Color("#FFE23D"))
		number_label.add_theme_color_override("font_outline_color", Color("#8B0000"))
		number_label.add_theme_constant_override("outline_size", 3)
		# Glow flash
		dice_sprite.modulate = Color(1, 1, 0.5, 1)
		var glow_tw = create_tween()
		glow_tw.tween_property(dice_sprite, "modulate", Color.WHITE, 0.3)
		
	elif _outcome == "miss":
		# Screen shake horizontal only
		_apply_camera_shake(_player_id, 0.18, 4.0, true)
		# Modulate reddish then back
		dice_sprite.modulate = Color(0.8, 0.4, 0.4, 1)
		var glow_tw = create_tween()
		glow_tw.tween_property(dice_sprite, "modulate", Color.WHITE, 0.3)
		# Muted grey-purple text, no stroke
		number_label.add_theme_color_override("font_color", Color("#F5EAD8"))
		number_label.add_theme_color_override("font_outline_color", Color("#1A1030"))
		number_label.add_theme_constant_override("outline_size", 2)
		# Slight shrink
		_reveal_tween.tween_property(self, "scale", base_scale * 0.85, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_reveal_tween.tween_property(self, "scale", base_scale, 0.15)
		
	else: # normal hit
		# Scale punch 1.15x -> 1.0x
		_reveal_tween.tween_property(self, "scale", base_scale * 1.15, 0.1 * spd_mult).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_reveal_tween.tween_property(self, "scale", base_scale, 0.1 * spd_mult)
		# Warm parchment text, dark ink stroke
		number_label.add_theme_color_override("font_color", Color("#F5EAD8"))
		number_label.add_theme_color_override("font_outline_color", Color("#1A1030"))
		number_label.add_theme_constant_override("outline_size", 2)
	
	# Beri jeda secukupnya agar orbit sempat menyedot ke tengah (1 detik)
	_reveal_tween.tween_interval(1.0 * spd_mult)
	_reveal_tween.tween_callback(func(): roll_finished.emit(_final_result))
	
	# HANYA FADE OUT, JANGAN QUEUE_FREE KARENA REUSABLE
	_reveal_tween.tween_interval(1.0)
	_reveal_tween.tween_property(self, "modulate:a", 0.0, 0.3)

func _apply_camera_shake(p_id: int, duration: float, amp: float, horizontal_only: bool = false) -> void:
	if not get_tree() or not get_tree().current_scene: return
	var main = get_tree().current_scene
	if main.has_node("SplitScreenManager"):
		var ssm = main.get_node("SplitScreenManager")
		if is_instance_valid(ssm) and ssm.has_method("shake_camera"):
			ssm.shake_camera(p_id, duration, amp, horizontal_only)
	elif main.has_node("World/Camera2D"):
		var cam = main.get_node("World/Camera2D")
		if is_instance_valid(cam) and cam.has_method("shake"):
			cam.shake(duration, amp, horizontal_only)






func _spawn_ripple(size_mult: float = 1.0) -> void:
	var ripple = Sprite2D.new()
	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	
	var grad = Gradient.new()
	# Setup gradient for a ring (transparent center, solid edge, transparent outer)
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_offset(0, 0.0)
	
	grad.add_point(0.75, Color(1, 1, 1, 0))
	grad.add_point(0.85, Color(1, 1, 1, 0.75)) # Outer border ring
	
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.set_offset(1, 1.0)
	
	grad_tex.gradient = grad
	grad_tex.width = 500
	grad_tex.height = 500
	
	ripple.texture = grad_tex
	ripple.z_index = -1 # Gambar di bawah dadu
	ripple.add_to_group("landing_vfx")
	ripple.top_level = true
	
	add_child(ripple)
	# Posisi di bawah dadu menggunakan global_position agar tidak ikut terscale
	ripple.global_position = dice_sprite.global_position + Vector2(0, 30)
	ripple.scale = Vector2(0.3, 0.3) # Bulat penuh
	
	var tw = create_tween()
	tw.set_parallel(true)
	# Expand the ring
	tw.tween_property(ripple, "scale", Vector2(2.0 * size_mult, 2.0 * size_mult), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade out
	tw.tween_property(ripple, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(ripple.queue_free)

# --- VFX LANDING (BG3 STYLE) ---

func _get_vfx_colors(outcome: String) -> Dictionary:
	if _player_id == 2:
		# Player 2: Putih dan Kuning Suci
		if outcome == "crit":
			return {"main": Color("#FFFFFF"), "sec": Color("#FFEA00")} # Putih murni, Kuning terang
		elif outcome == "miss":
			return {"main": Color("#D6D6D6"), "sec": Color("#FDFD96")} # Abu-abu terang, Kuning pastel
		else: # hit
			return {"main": Color("#FFFFFF"), "sec": Color("#FFD700")} # Putih, Emas/Kuning Suci
	else:
		# Player 1: Merah Vermilion/Gelap dan Hitam
		if outcome == "crit":
			return {"main": Color("#FF3C28"), "sec": Color("#8B0000")} # Vermilion menyala, Merah Gelap
		elif outcome == "miss":
			return {"main": Color("#1A1A1A"), "sec": Color("#000000")} # Abu-abu sangat gelap, Hitam
		else: # hit
			return {"main": Color("#E34234"), "sec": Color("#111111")} # Vermilion, Hitam pekat

func _play_landing_vfx(outcome: String) -> void:
	# Gunakan global_position agar partikel tidak terpengaruh scale bouncing dadu
	var center = dice_sprite.global_position
	_spawn_impact_burst(outcome, center)
	_spawn_orbital_swirl(outcome, center)
	
	# Delay for dust
	get_tree().create_timer(0.05).timeout.connect(func(): _spawn_ground_dust(outcome, center))
	
	if outcome == "crit":
		_white_flash()
		_spawn_ripple(2.5) # Extra large ring for critical

func _white_flash() -> void:
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.size = Vector2(3000, 3000)
	flash.position = -flash.size / 2.0
	flash.z_index = 100
	flash.add_to_group("landing_vfx")
	add_child(flash)
	
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(flash.queue_free)

var _shared_circle_tex: GradientTexture2D = null

func _get_circle_texture() -> GradientTexture2D:
	if _shared_circle_tex == null:
		var grad_tex = GradientTexture2D.new()
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		grad_tex.fill_from = Vector2(0.5, 0.5)
		grad_tex.fill_to = Vector2(1.0, 0.5)
		var grad = Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.set_offset(0, 0.0)
		grad.add_point(0.85, Color.WHITE)
		grad.add_point(0.9, Color(1, 1, 1, 0))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.set_offset(1, 1.0)
		grad_tex.gradient = grad
		grad_tex.width = 16
		grad_tex.height = 16
		_shared_circle_tex = grad_tex
	return _shared_circle_tex

func _spawn_impact_burst(outcome: String, center: Vector2) -> void:
	var colors = _get_vfx_colors(outcome)
	var count = 10
	var dist_min = 40.0
	var dist_max = 100.0
	var dur = 0.4
	
	if outcome == "crit":
		count = 24
		dist_max = 180.0
		dur = 0.6
	elif outcome == "miss":
		count = 6
		dist_max = 80.0
	
	for i in range(count):
		var p = Sprite2D.new()
		p.texture = _get_circle_texture()
		p.modulate = colors.main if randf() > 0.3 else colors.sec
		# Kurangi sedikit agar tidak menutupi wisp
		var s = randf_range(0.4, 0.9)
		p.scale = Vector2(s, s)
		p.top_level = true
		p.global_position = center
		p.z_index = 10
		p.add_to_group("landing_vfx")
		add_child(p)
		
		var angle = randf() * TAU
		var dist = randf_range(dist_min, dist_max)
		var target_pos = center + Vector2(cos(angle), sin(angle)) * dist
		
		var tw = create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target_pos, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ZERO, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(p.queue_free)

func _spawn_orbital_swirl(outcome: String, center: Vector2) -> void:
	var colors = _get_vfx_colors(outcome)
	var count = 15 # Lebih sedikit agar tidak terlalu ramai, tapi diperbagus bentuknya
	var dur = 1.0
	if outcome == "crit":
		count = 25
		dur = 1.2
	elif outcome == "miss":
		count = 8
		dur = 0.8
		
	for i in range(count):
		var p = Sprite2D.new()
		p.texture = _get_circle_texture()
		p.modulate = colors.sec if randf() > 0.5 else colors.main
		
		# Wisp Stretching: Skala X jauh lebih panjang dari Y untuk efek motion blur/jejak cahaya
		var s_x = randf_range(1.0, 2.5)
		var s_y = randf_range(0.15, 0.35)
		p.scale = Vector2(s_x, s_y)
		
		p.top_level = true
		p.z_index = 5
		p.global_position = center 
		p.add_to_group("landing_vfx")
		add_child(p)
		
		var start_angle = randf() * TAU
		
		# Putaran lebih lambat (tidak terburu-buru) agar hang-time terlihat elegan
		var rotations = randf_range(0.75, 1.5)
		var angle_diff = TAU * rotations
		if randf() > 0.5:
			angle_diff = -angle_diff 
			
		var end_angle = start_angle + angle_diff
		
		var dist_mult = randf_range(0.6, 1.5)
		var rx = randf_range(50.0, 80.0) * dist_mult 
		var ry = randf_range(25.0, 50.0) * dist_mult
		
		if outcome == "crit":
			rx = randf_range(60.0, 100.0) * dist_mult
			ry = randf_range(35.0, 65.0) * dist_mult
			
		_orbital_particles.append({
			"node": p,
			"time": 0.0,
			"dur": dur,
			"start_ang": start_angle,
			"end_ang": end_angle,
			"rx": rx,
			"ry": ry,
			"center": center,
			"last_pos": center
		})
		
		# Note: Tween scale kita buang karena kita fade-out dan fade-in alpha-nya via _process.
		# Membiarkan scale wisp tetap panjang hingga tersedot habis!

func _spawn_ground_dust(outcome: String, center: Vector2) -> void:
	var colors = _get_vfx_colors(outcome)
	var count = 8
	for i in range(count):
		var p = Sprite2D.new()
		p.texture = _get_circle_texture()
		p.modulate = colors.main if randf() > 0.5 else colors.sec
		p.modulate.a = 0.6
		var s = randf_range(0.2, 0.4)
		p.scale = Vector2(s, s)
		p.top_level = true
		p.global_position = center + Vector2(0, 25)
		p.z_index = -2
		p.add_to_group("landing_vfx")
		add_child(p)
		
		var target_x = p.global_position.x + randf_range(-70.0, 70.0)
		var target_y = p.global_position.y + randf_range(0.0, 20.0)
		var dur = 0.3 + randf() * 0.2
		
		var tw = create_tween().set_parallel(true)
		tw.tween_property(p, "global_position:x", target_x, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "global_position:y", target_y, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.chain().tween_callback(p.queue_free)
