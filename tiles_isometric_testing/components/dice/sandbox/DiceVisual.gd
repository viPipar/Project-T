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

# Cache Asset Dadu
var _dice_cache_static: Dictionary = {}
var _dice_cache_rolls: Dictionary = {}

var _current_rolls: Array[Texture2D] = []
var _current_static: Texture2D = null

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

	number_label.size = Vector2(100, 60)
	# Set pivot ke tengah label agar animasi pop-up meledak dari tengah, bukan dari ujung kiri atas
	number_label.pivot_offset = Vector2(50, 30)
	# Posisikan label agar pusatnya (50,30) berada di (0, 15).
	# Offset Y = 15 ditambahkan karena wajah segitiga tengah D20 posisinya agak ke bawah dari origin
	number_label.position = Vector2(-50, -30 + 15)
	# Perbesar ukuran font-nya agar lebih proporsional dengan D20
	number_label.add_theme_font_size_override("font_size", 48)
	number_label.add_theme_constant_override("outline_size", 2)
	
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


func start_roll(result: int, dice_type: String = "custom", roll_duration: float = 2.6, target_pos: Vector2 = Vector2.ZERO, p_id: int = 0, outcome: String = "hit") -> void:
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
	self.scale = Vector2(0.6, 0.6) # Pastikan base scale reset jika terpotong
	_current_roll_duration = roll_duration
	
	_viewport_rect = get_viewport_rect()
	var screen_w := _viewport_rect.size.x
	var screen_h := _viewport_rect.size.y
	
	# Tentukan target pendaratan (central_pos)
	if target_pos != Vector2.ZERO:
		_central_pos = target_pos
	else:
		_central_pos = _viewport_rect.get_center()
	
	# Set posisi awal dadu (P1 dari kiri jauh, P2 dari kanan jauh)
	var start_y = _central_pos.y + 100 # Agak ke bawah sedikit agar melengkung ke atas
	if p_id == 2:
		global_position = Vector2(screen_w + 150, start_y)
	else:
		global_position = Vector2(-150, start_y)
	
	# --- TWEEN TERARAH (Directed Trajectory) ---
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. Animasi Terbang (Position): Melengkung ke target
	tween.tween_property(self, "global_position", _central_pos, roll_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 2. Animasi Memantul (Scale): 4 Kali Pantulan (Lebih banyak)
	var scale_tween = create_tween()
	
	# Distribusi waktu berdasarkan persentase roll_duration (Total 100%)
	var b1_up = roll_duration * 0.20
	var b1_dn = roll_duration * 0.18
	var b2_up = roll_duration * 0.16
	var b2_dn = roll_duration * 0.14
	var b3_up = roll_duration * 0.10
	var b3_dn = roll_duration * 0.10
	var b4_up = roll_duration * 0.06
	var b4_dn = roll_duration * 0.06
	
	# Pantulan 1 (Paling tinggi)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(2.5, 2.5), b1_up)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(0.5, 0.5), b1_dn)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(1.0))
		
	# Pantulan 2 
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.8, 1.8), b2_up)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(0.7, 0.7), b2_dn)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(0.75))
		
	# Pantulan 3
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.4, 1.4), b3_up)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(0.85, 0.85), b3_dn)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(0.5))
		
	# Pantulan 4 (Mendarat)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.15, 1.15), b4_up)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.0, 1.0), b4_dn)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	scale_tween.tween_callback(func(): _spawn_ripple(0.3))
		
	# 3. Animasi Putaran (Rotation) - Dinonaktifkan sesuai permintaan
	# tween.tween_property(dice_sprite, "rotation", 4 * TAU, roll_duration)\
	# 	.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 4. Selesai
	# Kita tunggu tween posisi utama selesai, lalu panggil show_result
	tween.chain().tween_callback(show_result)



func show_result() -> void:
	# Matikan efek blur dan ubah ke frame static
	_is_rolling = false
	dice_sprite.texture = _current_static
	dice_sprite.rotation = 0
	dice_sprite.modulate = Color.WHITE
	
	# Tampilkan angka
	number_label.text = str(_final_result)
	number_label.show()
	
	# --- OUTCOME VARIANTS ---
	var base_scale = Vector2(0.6, 0.6) # Ukuran dadu normal
	self.scale = base_scale
	number_label.scale = Vector2(1.0, 1.0) # Reset scale angka
	var reveal_tween = create_tween()
	var spd_mult = clamp(_current_roll_duration / 2.6, 0.15, 1.0)
	
	if _outcome == "crit":
		# Freeze frame briefly
		reveal_tween.tween_interval(0.1)
		# Punch to 1.4 -> 1.0
		reveal_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.35 * spd_mult).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		# Number style: bright gold, dark red stroke
		number_label.add_theme_color_override("font_color", Color("#FFD700"))
		number_label.add_theme_color_override("font_outline_color", Color("#8B0000"))
		number_label.add_theme_constant_override("outline_size", 3)
		# Glow flash
		dice_sprite.modulate = Color(1, 1, 0.5, 1)
		var glow_tw = create_tween()
		glow_tw.tween_property(dice_sprite, "modulate", Color.WHITE, 0.3)
		
		# Screen shake via camera
		_apply_camera_shake(_player_id, 0.2, 6.0)
		
	elif _outcome == "miss":
		# Screen shake horizontal only
		_apply_camera_shake(_player_id, 0.18, 4.0, true)
		# Modulate reddish then back
		dice_sprite.modulate = Color(0.8, 0.4, 0.4, 1)
		var glow_tw = create_tween()
		glow_tw.tween_property(dice_sprite, "modulate", Color.WHITE, 0.3)
		# Muted grey-purple text, no stroke
		number_label.add_theme_color_override("font_color", Color("#9A8FCC"))
		number_label.add_theme_constant_override("outline_size", 0)
		# Slight shrink
		reveal_tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(self, "scale", base_scale, 0.15)
		
	else: # normal hit
		# Scale punch 1.15 -> 1.0
		reveal_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1 * spd_mult).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(self, "scale", base_scale, 0.1 * spd_mult)
		# Warm parchment text, dark ink stroke
		number_label.add_theme_color_override("font_color", Color("#F5EAD8"))
		number_label.add_theme_color_override("font_outline_color", Color("#1A1030"))
		number_label.add_theme_constant_override("outline_size", 2)
	
	reveal_tween.tween_interval(0.2 * spd_mult)
	reveal_tween.tween_callback(func(): roll_finished.emit(_final_result))

func _apply_camera_shake(p_id: int, duration: float, amp: float, horizontal_only: bool = false) -> void:
	if not get_tree() or not get_tree().current_scene: return
	var main = get_tree().current_scene
	if main.has_node("SplitScreenManager"):
		var ssm = main.get_node("SplitScreenManager")
		if ssm.has_method("shake_camera"):
			ssm.shake_camera(p_id, duration, amp, horizontal_only)
	elif main.has_node("World/Camera2D"):
		var cam = main.get_node("World/Camera2D")
		if cam.has_method("shake"):
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
	
	add_child(ripple)
	# Posisi di bawah dadu
	ripple.position = dice_sprite.position + Vector2(0, 30)
	ripple.scale = Vector2(0.3, 0.3) # Bulat penuh
	
	var tw = create_tween()
	tw.set_parallel(true)
	# Expand the ring
	tw.tween_property(ripple, "scale", Vector2(2.0 * size_mult, 2.0 * size_mult), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade out
	tw.tween_property(ripple, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(ripple.queue_free)



