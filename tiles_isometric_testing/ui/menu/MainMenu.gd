extends Control

@onready var main_buttons_container: VBoxContainer = $MarginContainer/HBoxContainer/MenuButtons
@onready var how_to_play_panel: PanelContainer = $Overlays/HowToPlayPanel
@onready var settings_panel: PanelContainer = $Overlays/SettingsPanel
@onready var credits_panel: PanelContainer = $Overlays/CreditsPanel
@onready var fade_overlay: ColorRect = $FadeOverlay

# Settings panel fields
@onready var master_slider: HSlider = $Overlays/SettingsPanel/MarginContainer/VBox/VolumeSettings/MasterContainer/MasterSlider
@onready var fullscreen_checkbox: CheckButton = $Overlays/SettingsPanel/MarginContainer/VBox/DisplaySettings/FullscreenCheckbox

const GAMEPLAY_SCENE_PATH = "res://main/Main.tscn"

func _ready() -> void:
	# Hide all overlay panels
	how_to_play_panel.visible = false
	settings_panel.visible = false
	credits_panel.visible = false
	
	# Start with transparent fade overlay, fade in main menu if needed
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 1)
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.5)
	tween.tween_callback(func(): fade_overlay.visible = false)
	
	# Initialize Settings values
	_setup_settings_ui()

func _setup_settings_ui() -> void:
	# Check if Master bus exists
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx != -1:
		var db_val = AudioServer.get_bus_volume_db(master_bus_idx)
		master_slider.value = db_to_linear(db_val)
		master_slider.value_changed.connect(_on_master_slider_changed)
	
	# Check current window mode
	var current_mode = DisplayServer.window_get_mode()
	fullscreen_checkbox.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)

# --- Main Button Signals ---
func _on_start_game_pressed() -> void:
	# Play transition sound and fade to black
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.6)
	tween.tween_callback(func():
		if ResourceLoader.exists(GAMEPLAY_SCENE_PATH):
			get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
		else:
			push_error("[MainMenu] Gameplay scene not found: %s" % GAMEPLAY_SCENE_PATH)
	)

func _on_how_to_play_pressed() -> void:
	_show_overlay(how_to_play_panel)

func _on_settings_pressed() -> void:
	_show_overlay(settings_panel)

func _on_credits_pressed() -> void:
	_show_overlay(credits_panel)

func _on_exit_pressed() -> void:
	get_tree().quit()

# --- Overlay Control ---
func _show_overlay(panel: PanelContainer) -> void:
	# Play open panel sound if needed (AudioManager handles generic buttons automatically, but we can do custom open)
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size / 2.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_overlay(panel: PanelContainer) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.2)
	tween.chain().tween_callback(func():
		panel.visible = false
	)

func _on_how_to_play_close_pressed() -> void:
	_close_overlay(how_to_play_panel)

func _on_settings_close_pressed() -> void:
	_close_overlay(settings_panel)

func _on_credits_close_pressed() -> void:
	_close_overlay(credits_panel)

# --- Settings Event Handlers ---
func _on_master_slider_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_fullscreen_toggled(is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
