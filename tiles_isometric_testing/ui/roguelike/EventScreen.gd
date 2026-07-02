extends Control

@onready var narrative_text = $Panel/VBox/NarrativeText
@onready var p1_btn_1 = $Panel/VBox/HBoxP1/BtnChoice1
@onready var p1_btn_2 = $Panel/VBox/HBoxP1/BtnChoice2
@onready var p2_btn_1 = $Panel/VBox/HBoxP2/BtnChoice1
@onready var p2_btn_2 = $Panel/VBox/HBoxP2/BtnChoice2
@onready var panel = $Panel

func _ready() -> void:
	# Neobrutalism
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", FantasyStyle.get_panel(FantasyStyle.COLOR_PARCHMENT))
	add_child(bg)
	move_child(bg, 0)
	
	panel.add_theme_stylebox_override("panel", FantasyStyle.get_panel(FantasyStyle.COLOR_PARCHMENT))
	
	FantasyStyle.apply_to_button(p1_btn_1, FantasyStyle.COLOR_BLOOD)
	FantasyStyle.apply_to_button(p1_btn_2, FantasyStyle.COLOR_GOLD)
	FantasyStyle.apply_to_button(p2_btn_1, FantasyStyle.COLOR_SAPPHIRE)
	FantasyStyle.apply_to_button(p2_btn_2, FantasyStyle.COLOR_EMERALD)
	
	_load_mock_event()

func _load_mock_event() -> void:
	narrative_text.text = "You find a glowing chest surrounded by sleeping wolves 🐺. \n\nDo you try to sneak and open it, or leave safely?"
	
	# Reset state
	p1_btn_1.text = "P1: Sneak (D20 > 10)"
	p1_btn_2.text = "P1: Leave"
	p2_btn_1.text = "P2: Sneak (D20 > 10)"
	p2_btn_2.text = "P2: Leave"

# Real implementation would connect to LuckEventHandler.select_choice()
func _on_p1_btn_1_pressed() -> void: print("P1 voted 1")
func _on_p1_btn_2_pressed() -> void: print("P1 voted 2")
func _on_p2_btn_1_pressed() -> void: print("P2 voted 1")
func _on_p2_btn_2_pressed() -> void: print("P2 voted 2")
