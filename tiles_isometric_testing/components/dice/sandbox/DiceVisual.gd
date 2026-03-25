extends Node2D

# Sinyal ini berguna untuk memberi tahu Sandbox/Combat kalau dadu sudah selesai berguling
signal roll_finished(final_number: int)

@onready var anim: AnimatedSprite2D = $Anim
@onready var number_label: Label = $NumberLabel
@onready var roll_timer: Timer = $RollTimer

var _final_result: int = 0

func _ready() -> void:
	# Sembunyikan angka saat pertama kali muncul
	number_label.hide()
	# Sambungkan timer
	roll_timer.timeout.connect(_on_timer_timeout)

# Fungsi ini yang akan dipanggil dari luar untuk memulai animasi
func start_roll(result_number: int, roll_duration: float = 1.0) -> void:
	_final_result = result_number
	number_label.hide()
	
	# Putar animasi (pastikan di SpriteFrames kamu ada animasi bernama "rolling")
	if anim.sprite_frames and anim.sprite_frames.has_animation("rolling"):
		anim.play("rolling")
	
	# Mulai hitung mundur (misal 1 detik)
	roll_timer.start(roll_duration)

func _on_timer_timeout() -> void:
	# Hentikan animasi kocok dadu
	anim.stop()
	
	# Opsional: Jika kamu punya frame spesifik untuk "dadu diam", 
	# kamu bisa set di sini, misalnya: anim.animation = "idle"
	
	# Tampilkan angka hasil dari DiceSystem
	number_label.text = str(_final_result)
	number_label.show()
	
	# Teriakkan ke sistem bahwa dadu sudah selesai memunculkan angka
	roll_finished.emit(_final_result)
