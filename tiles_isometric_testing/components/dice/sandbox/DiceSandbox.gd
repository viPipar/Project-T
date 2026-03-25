extends Control

@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var formula_input: LineEdit = $VBoxContainer/HBoxContainer/FormulaInput
@onready var dice_visual: Node2D = $DiceVisual

# Variabel pembantu untuk mengingat dadu apa yang sedang berputar
var _last_roll_type: String = ""
var _last_damage_result = null

func _ready() -> void:
	# Dengarkan saat animasi dadu selesai
	dice_visual.roll_finished.connect(_on_dice_roll_finished)
	formula_input.placeholder_text = "Contoh: 2d6+3"

# ── FUNGSI PINTAS UNTUK DADU SINGLE ──
func _do_single_roll(sides: int) -> void:
	_last_roll_type = "d" + str(sides)
	result_label.text = "Mengocok " + _last_roll_type + "..."
	
	var hasil = DiceSystem.roll_single(sides)
	
	# PANGGILAN DIUBAH: Masukkan argument `_last_roll_type` (contoh "d20")
	dice_visual.start_roll(hasil, _last_roll_type, 2.0)

# ── KONEKSI TOMBOL ──
func _on_btn_d4_pressed() -> void: _do_single_roll(4)
func _on_btn_d6_pressed() -> void: _do_single_roll(6)
func _on_btn_d8_pressed() -> void: _do_single_roll(8)
func _on_btn_d10_pressed() -> void: _do_single_roll(10)
func _on_btn_d12_pressed() -> void: _do_single_roll(12)
func _on_btn_d20_pressed() -> void: _do_single_roll(20)

func _on_btn_custom_pressed() -> void:
	_last_roll_type = "custom" # Set tipe visual ke custom (default/generic)
	
	var formula = formula_input.text
	if formula == "": formula = "2d6"
		
	result_label.text = "Mengeksekusi: " + formula + "..."
	
	_last_damage_result = DiceSystem.roll_damage(formula, false)
	
	# PANGGILAN DIUBAH: Kirim total damage, gunakan visual "custom"
	dice_visual.start_roll(_last_damage_result.total, "custom", 2.0)

# ── SAAT ANIMASI SELESAI ──
func _on_dice_roll_finished(final_number: int) -> void:
	if _last_roll_type == "custom":
		var teks = "Formula: " + _last_damage_result.formula + "\n"
		teks += "Rincian Dadu: " + str(_last_damage_result.rolls) + "\n"
		teks += "TOTAL DAMAGE: " + str(final_number)
		result_label.text = teks
	else:
		var teks = "Hasil " + _last_roll_type + ": " + str(final_number)
		if _last_roll_type == "d20":
			if final_number == 20: teks += "\n🔥 CRITICAL HIT!!! 🔥"
			elif final_number == 1: teks += "\n💀 CRITICAL FAILURE! 💀"
		result_label.text = teks
