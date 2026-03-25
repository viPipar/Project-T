extends Control

@onready var result_label: Label = $VBoxContainer/ResultLabel

func _on_btn_d4_pressed() -> void:
	var hasil = DiceSystem.roll_single(4)
	result_label.text = "Hasil d4: " + str(hasil)

func _on_btn_d6_pressed() -> void:
	var hasil = DiceSystem.roll_single(6)
	result_label.text = "Hasil d6: " + str(hasil)

func _on_btn_d20_pressed() -> void:
	var hasil = DiceSystem.roll_single(20)
	result_label.text = "Hasil d20: " + str(hasil)

func _on_btn_custom_pressed() -> void:
	var formula = "2d6+3"
	var hasil = DiceSystem.roll_damage(formula, false)
	result_label.text = "Total Damage: " + str(hasil.total)
