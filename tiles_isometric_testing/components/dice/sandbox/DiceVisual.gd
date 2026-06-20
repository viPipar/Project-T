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

# Kamus/List Asset D20
var d20_static: Texture2D = preload("res://assets/dice/d20/d20_static.png")
var d20_rolls: Array[Texture2D] = [
	preload("res://assets/dice/d20/d20_roll1.png"),
	preload("res://assets/dice/d20/d20_roll2.png"),
	preload("res://assets/dice/d20/d20_roll3.png")
]

func _ready() -> void:
	# Sembunyikan angka dan sprite saat awal
	number_label.hide()
	dice_sprite.visible = false
	# Perkecil ukuran keseluruhan dadu (karena asetnya terlalu besar)
	self.scale = Vector2(0.6, 0.6)
	
	# Ambil data ukuran layar dan posisi tengahnya
	_viewport_rect = get_viewport_rect()
	_central_pos = _viewport_rect.get_center()

func _process(delta: float) -> void:
	if _is_rolling:
		_roll_timer += delta
		# Ganti frame setiap 0.05 detik untuk efek blur
		if _roll_timer > 0.05:
			_roll_timer = 0.0
			_roll_frame_idx = (_roll_frame_idx + 1) % d20_rolls.size()
			dice_sprite.texture = d20_rolls[_roll_frame_idx]


func start_roll(result: int, dice_type: String = "custom", roll_duration: float = 1.8, target_pos: Vector2 = Vector2.ZERO, p_id: int = 0) -> void:
	_final_result = result
	number_label.hide()
	dice_sprite.visible = true
	
	# Mulai efek blur
	_is_rolling = true
	_roll_timer = 0.0
	_roll_frame_idx = 0
	dice_sprite.texture = d20_rolls[0]
		
	# --- RESET POSISI DAN ROTASI AWAL ---
	dice_sprite.rotation = 0
	dice_sprite.scale = Vector2(0.5, 0.5) # Mulai dari kecil
	
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
		
	# 2. Animasi Memantul (Scale): Besar - Kecil - Besar - Normal (Multiple Bounces)
	var scale_tween = create_tween()
	var t1 = roll_duration * 0.35
	var t2 = roll_duration * 0.30
	var t3 = roll_duration * 0.20
	var t4 = roll_duration * 0.15
	
	# Pantulan 1 (Paling tinggi)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(2.2, 2.2), t1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(0.7, 0.7), t2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Pantulan 2 (Sedang)
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.3, 1.3), t3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Mendarat
	scale_tween.tween_property(dice_sprite, "scale", Vector2(1.0, 1.0), t4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# 3. Animasi Putaran (Rotation)
	tween.tween_property(dice_sprite, "rotation", 4 * TAU, roll_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 4. Selesai
	# Kita tunggu tween posisi utama selesai, lalu panggil show_result
	tween.chain().tween_callback(show_result)



func show_result() -> void:
	# Matikan efek blur dan ubah ke frame static
	_is_rolling = false
	dice_sprite.texture = d20_static
	dice_sprite.rotation = 0
	
	# Tampilkan angka
	number_label.text = str(_final_result)
	number_label.show()
	
	# --- EFEK JUICY REVEAL ---
	var base_scale = Vector2(0.6, 0.6) # Ukuran dadu normal yang sudah kita set di _ready
	var pop_scale = Vector2(1.2, 1.2)  # Ukuran saat meledak besar (Zoom In)
	
	self.scale = base_scale
	number_label.scale = Vector2(1.0, 1.0) # Reset scale angka
	
	var reveal_tween = create_tween()
	
	# 1. Diam sejenak (Suspense / Anticipation) selama 0.15 detik
	reveal_tween.tween_interval(0.15)
	
	# 2. POP membesar dengan tajam (Zoom in dramatis)
	reveal_tween.tween_property(self, "scale", pop_scale, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# 3. Membal / Kembali ke ukuran semula dengan ayunan (Elastic/Back)
	reveal_tween.tween_property(self, "scale", base_scale, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 4. Beri jeda sedikit lagi agar pemain bisa membaca hasilnya sebelum combat lanjut
	reveal_tween.tween_interval(0.2)
	
	# 5. Emit sinyal roll selesai setelah semua drama selesai
	reveal_tween.tween_callback(func(): roll_finished.emit(_final_result))
