extends Control

@onready var content_panel: PanelContainer = $CenterContainer/ContentPanel
const MAIN_MENU_PATH = "res://ui/menu/MainMenu.tscn"

func _ready() -> void:
	# Hide panel initially for fade in
	content_panel.modulate.a = 0.0
	
	# Start entry animation
	var tween = create_tween()
	tween.tween_property(content_panel, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Automatically proceed after 7 seconds if no action is taken
	get_tree().create_timer(7.0).timeout.connect(func():
		if is_inside_tree():
			go_to_main_menu()
	)

func _on_continue_button_pressed() -> void:
	go_to_main_menu()

func go_to_main_menu() -> void:
	# Fade out before transitioning
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if ResourceLoader.exists(MAIN_MENU_PATH):
			get_tree().change_scene_to_file(MAIN_MENU_PATH)
		else:
			push_error("[DisclaimerScreen] Main menu scene path not found: %s" % MAIN_MENU_PATH)
	)
