extends Control

@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var formula_input: LineEdit = $VBoxContainer/HBoxContainer/FormulaInput
@onready var dice_visual: Node2D = $DiceVisual

var _last_roll_type: String = ""
var _last_damage_result = null

# --- VARIABEL BARU UNTUK SISTEM ANTREAN CUSTOM ROLL ---
var _custom_rolls_queue: Array[int] = []
var _current_custom_index: int = 0
var _custom_dice_type: String = ""
var _custom_summary_text: String = ""

func _ready() -> void:
	dice_visual.roll_finished.connect(_on_dice_roll_finished)
	formula_input.placeholder_text = "Contoh: 2d6+3"

# ── FUNGSI PINTAS UNTUK DADU SINGLE ──
func _do_single_roll(sides: int) -> void:
	_last_roll_type = "d" + str(sides)
	result_label.text = "Mengocok " + _last_roll_type + "..."
	var hasil = DiceSystem.roll_single(sides)
	dice_visual.start_roll(hasil, _last_roll_type, 2.0)

# ── KONEKSI TOMBOL ──
func _on_btn_d4_pressed() -> void: _do_single_roll(4)
func _on_btn_d6_pressed() -> void: _do_single_roll(6)
func _on_btn_d8_pressed() -> void: _do_single_roll(8)
func _on_btn_d10_pressed() -> void: _do_single_roll(10)
func _on_btn_d12_pressed() -> void: _do_single_roll(12)
func _on_btn_d20_pressed() -> void: _do_single_roll(20)

func _on_btn_custom_pressed() -> void:
	_last_roll_type = "custom"
	
	var formula = formula_input.text
	if formula == "": formula = "2d6"
	
	# 1. Ekstrak gambar dadu apa yang harus dipakai (misal dari "2d6+3" jadi "d6")
	_custom_dice_type = _extract_dice_type_from_formula(formula)
	
	# 2. Minta otak menghitung seluruh dadu sekaligus di belakang layar
	_last_damage_result = DiceSystem.roll_damage(formula, false)
	
	# 3. Siapkan Antrean Visual
	_custom_rolls_queue = _last_damage_result.rolls.duplicate()
	_current_custom_index = 0
	_custom_summary_text = "Formula: " + formula + "\n"
	
	if _custom_rolls_queue.size() > 0:
		_roll_next_in_queue()
	else:
		result_label.text = "Error: Formula tidak valid."

# ── FUNGSI PEMBANTU UNTUK ANTREAN ──
func _roll_next_in_queue() -> void:
	# Update teks di layar biar kelihatan dadu ke-berapa yang lagi dilempar
	result_label.text = _custom_summary_text + "\n🎲 Mengocok dadu ke-" + str(_current_custom_index + 1) + "..."
	
	var target_number = _custom_rolls_queue[_current_custom_index]
	
	# Kita percepat dikit jadi 1.2 detik per dadu biar kalau roll 4d6 nggak kelamaan nunggunya
	dice_visual.start_roll(target_number, _custom_dice_type, 1.2)

# Mencari tipe dadu dari teks (Contoh input "2d6+3" -> return "d6")
func _extract_dice_type_from_formula(formula: String) -> String:
	formula = formula.to_lower().replace(" ", "")
	var parts = formula.split("+")
	var base = parts[0]
	if "-" in base: base = base.split("-")[0]
	var split_d = base.split("d")
	if split_d.size() == 2:
		return "d" + split_d[1]
	return "custom" # Fallback kalau gagal parsing

# ── SAAT ANIMASI SELESAI ──
func _on_dice_roll_finished(final_number: int) -> void:
	# JIKA INI ADALAH ANTREAN CUSTOM ROLL
	if _last_roll_type == "custom":
		# 1. Catat hasil dadu ini ke teks riwayat
		_custom_summary_text += "\nLemparan ke-" + str(_current_custom_index + 1) + ": " + str(final_number)
		_current_custom_index += 1 # Maju ke antrean berikutnya
		
		# 2. Cek apakah masih ada dadu yang harus dilempar?
		if _current_custom_index < _custom_rolls_queue.size():
			result_label.text = _custom_summary_text
			# Beri jeda 0.5 detik biar pemain sempat baca angkanya sebelum muter lagi
			await get_tree().create_timer(0.5).timeout
			_roll_next_in_queue()
		
		# 3. Kalau semua dadu sudah dilempar, hitung totalnya
		else:
			_custom_summary_text += "\n\n TOTAL DAMAGE: " + str(_last_damage_result.total) + " "
			result_label.text = _custom_summary_text

	# JIKA INI CUMA ROLL SINGLE BIASA (Tombol d20 dkk)
	else:
		var teks = "Hasil " + _last_roll_type + ": " + str(final_number)
		if _last_roll_type == "d20":
			if final_number == 20: teks += "\n CRITICAL HIT!!! "
			elif final_number == 1: teks += "\n CRITICAL FAILURE! "
		result_label.text = teks
