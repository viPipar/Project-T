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
	# Sembunyikan angka saat awal
	number_label.hide()
	# Ambil data ukuran layar dan posisi tengahnya
	_viewport_rect = get_viewport_rect()
	_central_pos = _viewport_rect.get_center()

func start_roll(result: int, dice_type: String = "custom", roll_duration: float = 2.5) -> void:
	_final_result = result
	number_label.hide()
	
	# --- PASANG GAMBAR SESUAI TIPE DADU ---
	if dice_texture_map.has(dice_type):
		dice_sprite.texture = dice_texture_map[dice_type]
	else:
		dice_sprite.texture = dice_texture_map["custom"]
		
	# --- RESET POSISI DAN ROTASI AWAL ---
	dice_sprite.rotation = 0
	# Dadu muncul agak besar sedikit lalu mengecil (efek dilempar ke kamera)
	dice_sprite.scale = Vector2(1.5, 1.5)
	
	# Set posisi awal dadu (misal muncul dari pojok kiri bawah)
	global_position = Vector2(_viewport_rect.position.x - 100, _viewport_rect.end.y + 100)
	
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
	var chaos_duration = roll_duration * 0.7
	var bounce_count = 3 # Jumlah memantul di pinggir
	var time_per_bounce = chaos_duration / (bounce_count + 1)
	
	# Fase 1: Gerakan Lempar Pertama ke salah satu ujung layar
	move_tween.tween_property(self, "global_position", _get_random_screen_point(), time_per_bounce)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Fase 2: Memantul-mantul random di ujung layar
	for i in range(bounce_count):
		move_tween.tween_property(self, "global_position", _get_random_screen_point(true), time_per_bounce)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			
	# Fase 3: Kembali ke Rumah (Kembali ke Tengah Layar)
	# Gunakan TRANS_BACK agar ada efek mendarat memantul dikit di tengah
	move_tween.tween_property(self, "global_position", _central_pos, roll_duration * 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 4. Kalau semua gerakan sudah selesai mendarat di tengah, panggil show_result
	move_tween.tween_callback(show_result)

# Fungsi pembantu untuk mencari koordinat random di dalam layar
func _get_random_screen_point(use_edges: bool = false) -> Vector2:
	var padding = 80.0 # Agar dadu tidak terlalu mepet ke ujung
	var target_rect = _viewport_rect.grow(-padding) # Mengecilkan area area aman
	
	if use_edges:
		# Cari titik di pinggiran area aman (efek mantul di ujung)
		var edge_area = 150.0 # Lebar area pinggiran
		var x: float
		var y: float
		
		# Pilih acak: mau mantul di kiri/kanan atau atas/bawah
		if randf() > 0.5: # Mantul di kiri/kanan
			x = target_rect.position.x + (randf() * edge_area) if randf() > 0.5 else target_rect.end.x - (randf() * edge_area)
			y = randf_range(target_rect.position.y, target_rect.end.y)
		else: # Mantul di atas/bawah
			x = randf_range(target_rect.position.x, target_rect.end.x)
			y = target_rect.position.y + (randf() * edge_area) if randf() > 0.5 else target_rect.end.y - (randf() * edge_area)
		return Vector2(x, y)
	else:
		# Cari titik benar-benar random di seluruh area aman
		return Vector2(randf_range(target_rect.position.x, target_rect.end.x), randf_range(target_rect.position.y, target_rect.end.y))

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
