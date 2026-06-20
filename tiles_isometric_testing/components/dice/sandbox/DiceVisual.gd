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

# Kamus untuk memetakan nama ke file PNG
var dice_texture_map: Dictionary = {
	"d4": preload(SPRITE_FOLDER_PATH + "06_large_dice.png"),
	"d6": preload(SPRITE_FOLDER_PATH + "05_large_dice.png"),
	"d8": preload(SPRITE_FOLDER_PATH + "04_large_dice.png"),
	"d10": preload(SPRITE_FOLDER_PATH + "03_large_dice.png"),
	"d12": preload(SPRITE_FOLDER_PATH + "02_large_dice.png"),
	"d20": preload(SPRITE_FOLDER_PATH + "01_large_dice.png"),
	"custom": preload(SPRITE_FOLDER_PATH + "00_large_dice.png")
}

func _ready() -> void:
	# Sembunyikan angka dan sprite saat awal
	number_label.hide()
	dice_sprite.visible = false
	# Ambil data ukuran layar dan posisi tengahnya
	_viewport_rect = get_viewport_rect()
	_central_pos = _viewport_rect.get_center()

func start_roll(result: int, dice_type: String = "custom", roll_duration: float = 1.2, target_pos: Vector2 = Vector2.ZERO, p_id: int = 0) -> void:
	_final_result = result
	number_label.hide()
	dice_sprite.visible = true
	
	# --- PASANG GAMBAR SESUAI TIPE DADU ---
	if dice_texture_map.has(dice_type):
		dice_sprite.texture = dice_texture_map[dice_type]
	else:
		dice_sprite.texture = dice_texture_map["custom"]
		
	# --- RESET POSISI DAN ROTASI AWAL ---
	dice_sprite.rotation = 0
	# Dadu muncul agak besar sedikit lalu mengecil (efek dilempar ke kamera)
	dice_sprite.scale = Vector2(1.5, 1.5)
	
	_viewport_rect = get_viewport_rect()
	var screen_w := _viewport_rect.size.x
	var screen_h := _viewport_rect.size.y
	
	# Tentukan target pendaratan (central_pos)
	if target_pos != Vector2.ZERO:
		_central_pos = target_pos
	else:
		_central_pos = _viewport_rect.get_center()
	
	# Set posisi awal dadu (P1 muncul dari kiri, P2 muncul dari kanan, default/0 muncul dari kiri)
	if p_id == 2:
		global_position = Vector2(screen_w + 150, randf_range(screen_h * 0.2, screen_h * 0.8))
	else:
		global_position = Vector2(-150, randf_range(screen_h * 0.2, screen_h * 0.8))
	
	# --- BUAT TWEEN MASTER UNTUK GERAKAN CHAOS (Flying & Bouncing) ---
	var tween = create_tween()
	# Jalankan putaran dan pergerakan secara PARALEL/BERSAMAAN
	tween.set_parallel(true)
	
	# 1. Animasi Putar (Spin): Muter sangat kencang selama terbang
	tween.tween_property(dice_sprite, "rotation", 10 * TAU, roll_duration)\
		.set_trans(Tween.TRANS_LINEAR)
		
	# 2. Animasi Mengecil (Zoom Out): Dari besar ke ukuran normal mendarat
	tween.tween_property(dice_sprite, "scale", Vector2(1.0, 1.0), roll_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# ─── BUAT TWEEN CHAIN KHUSUS UNTUK PERGERAKAN (SEQUENTIAL) ───
	# Kita buat Tween kedua yang tidak paralel agar gerakan memantulnya urutan
	var move_tween = create_tween()
	
	# Hitung waktu per gerakan chaos agar totalnya pas sesuai roll_duration
	# (Kita sisakan 30% waktu untuk Fase Kembali ke Rumah)
	var chaos_duration = roll_duration * 0.65
	var bounce_count = 2 # Jumlah memantul di pinggir
	var time_per_bounce = chaos_duration / (bounce_count + 1)
	
	# Fase 1: Gerakan Lempar Pertama ke salah satu ujung layar (sesuai player_id)
	move_tween.tween_property(self, "global_position", _get_player_random_point(p_id), time_per_bounce)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Fase 2: Memantul-mantul random di ujung layar (sesuai player_id)
	for i in range(bounce_count):
		move_tween.tween_property(self, "global_position", _get_player_random_point(p_id, true), time_per_bounce)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			
	# Fase 3: Kembali ke Rumah (Kembali ke Tengah Layar)
	# Gunakan TRANS_BACK agar ada efek mendarat memantul dikit di tengah
	move_tween.tween_property(self, "global_position", _central_pos, roll_duration * 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 4. Kalau semua gerakan sudah selesai mendarat di tengah, panggil show_result
	move_tween.tween_callback(show_result)

# Fungsi pembantu untuk mencari koordinat random di dalam setengah layar player
func _get_player_random_point(p_id: int, use_edges: bool = false) -> Vector2:
	_viewport_rect = get_viewport_rect()
	var screen_w := _viewport_rect.size.x
	var screen_h := _viewport_rect.size.y
	
	var padding = 80.0 # Agar dadu tidak terlalu mepet ke ujung
	
	# Batasi wilayah x berdasarkan player_id
	var x_min: float
	var x_max: float
	if p_id == 1:
		x_min = padding
		x_max = (screen_w * 0.5) - padding
	elif p_id == 2:
		x_min = (screen_w * 0.5) + padding
		x_max = screen_w - padding
	else: # Fullscreen (p_id == 0 atau lainnya)
		x_min = padding
		x_max = screen_w - padding
		
	var y_min = padding
	var y_max = screen_h - padding
	
	if use_edges:
		# Cari titik di pinggiran area aman (efek mantul di ujung)
		var edge_area = 100.0 # Lebar area pinggiran
		var x: float
		var y: float
		
		# Pilih acak: mau mantul di kiri/kanan atau atas/bawah
		if randf() > 0.5: # Mantul di kiri/kanan
			x = x_min + (randf() * edge_area) if randf() > 0.5 else x_max - (randf() * edge_area)
			y = randf_range(y_min, y_max)
		else: # Mantul di atas/bawah
			x = randf_range(x_min, x_max)
			y = y_min + (randf() * edge_area) if randf() > 0.5 else y_max - (randf() * edge_area)
		return Vector2(x, y)
	else:
		# Cari titik benar-benar random di seluruh area aman
		return Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))

func show_result() -> void:
	# Tampilkan angka mendarat di tengah
	number_label.text = str(_final_result)
	number_label.show()
	
	# Efek pop-up teks seperti biasa
	number_label.scale = Vector2(0.2, 0.2)
	var text_tween = create_tween()
	text_tween.tween_property(number_label, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Kasih tau sistem kalau dadu udah beres mendarat
	roll_finished.emit(_final_result)
