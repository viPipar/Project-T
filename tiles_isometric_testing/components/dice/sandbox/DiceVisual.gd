extends Node2D

# Sinyal saat animasi muter-muter selesai
signal roll_finished(final_number: int)

# --- KONFIGURASI PATH ASSET ---
# Ganti ini jika foldermu berbeda (wajib diakhiri dengan /)
const SPRITE_FOLDER_PATH = "res://components/dice/sandbox/sprites/"

# --- KONEKSI NODE ---
@onready var dice_sprite: Sprite2D = $DiceSprite
@onready var number_label: Label = $NumberLabel

# --- VARIABEL ---
var _final_result: int = 0

# Kamus untuk memetakan nama "d20" ke file PNG ksatria.
# Berdasarkan idemu: 06=d4, 05=d6, dan seterusnya.
# 00 kita jadikan default kalau format custom aneh-aneh.
var dice_texture_map: Dictionary = {
	"d4": preload(SPRITE_FOLDER_PATH + "06_large_dice.png"),
	"d6": preload(SPRITE_FOLDER_PATH + "05_large_dice.png"),
	"d8": preload(SPRITE_FOLDER_PATH + "04_large_dice.png"),
	"d10": preload(SPRITE_FOLDER_PATH + "03_large_dice.png"),
	"d12": preload(SPRITE_FOLDER_PATH + "02_large_dice.png"),
	"d20": preload(SPRITE_FOLDER_PATH + "01_large_dice.png"),
	"custom": preload(SPRITE_FOLDER_PATH + "00_large_dice.png") # Default/Percentile
}

func _ready() -> void:
	# Sembunyikan angka saat awal
	number_label.hide()

# FUNGSI DIUBAH: Sekarang menerima argument `dice_type` (contoh: "d20")
func start_roll(result: int, dice_type: String = "custom", roll_duration: float = 2.0) -> void:
	_final_result = result
	number_label.hide()
	
	# --- PASANG GAMBAR SESUAI TIPE DADU (Misi Utama Sukses!) ---
	if dice_texture_map.has(dice_type):
		dice_sprite.texture = dice_texture_map[dice_type]
	else:
		dice_sprite.texture = dice_texture_map["custom"] # Fallback kalau tipe aneh
		
	# --- RESET POSISI AWAL UNTUK ANIMASI LEMPAR ---
	# Bikin dadu seolah-olah dilempar (mulai dari ukuran kecil)
	dice_sprite.scale = Vector2(0.3, 0.3)
	dice_sprite.rotation = 0
	
	# Buat Tween untuk mengatur animasi muter-muter
	var tween = create_tween()
	
	# 1. Animasi Putar (Spin): Muter 3 kali putaran penuh (3 * TAU)
	tween.tween_property(dice_sprite, "rotation", 3 * TAU, roll_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 2. Animasi Membesar (Zoom In & Bounce): Jalan bersamaan dengan putaran
	tween.parallel().tween_property(dice_sprite, "scale", Vector2(1.0, 1.0), roll_duration)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 3. Kalau animasinya sudah selesai, panggil fungsi show_result()
	tween.tween_callback(show_result)

func show_result() -> void:
	# Tampilkan angka hasil kocokan DiceSystem
	number_label.text = str(_final_result)
	number_label.show()
	
	# Efek pop-up kecil buat teksnya biar makin taktis!
	number_label.scale = Vector2(0.2, 0.2)
	var text_tween = create_tween()
	text_tween.tween_property(number_label, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Kasih tau sistem kalau dadu udah beres nampilin angka
	roll_finished.emit(_final_result)
