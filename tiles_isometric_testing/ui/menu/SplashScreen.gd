extends Control

@onready var logo_container: VBoxContainer = $CenterContainer/LogoContainer
@onready var background: ColorRect = $Background

const NEXT_SCENE_PATH = "res://ui/menu/DisclaimerScreen.tscn"

func _ready() -> void:
	# Hide logo initially for fade in
	logo_container.modulate.a = 0.0
	background.color = Color.WHITE
	
	# Start splash animation sequence
	start_splash_sequence()

func _input(event: InputEvent) -> void:
	# Allow skipping with common action keys or mouse click
	if event is InputEventMouseButton and event.pressed:
		skip_splash()
	elif event is InputEventKey and event.pressed:
		skip_splash()

func start_splash_sequence() -> void:
	var tween = create_tween()
	
	# Fade in logo
	tween.tween_property(logo_container, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Wait at full opacity
	tween.tween_interval(1.5)
	
	# Fade out entire screen to white
	tween.tween_property(self, "modulate:a", 0.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	# Transition to next scene
	tween.tween_callback(change_to_next_scene)

func skip_splash() -> void:
	# Instantly transition to the next scene on click/keypress
	change_to_next_scene()

func change_to_next_scene() -> void:
	if ResourceLoader.exists(NEXT_SCENE_PATH):
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	else:
		push_error("[SplashScreen] Next scene path not found: %s" % NEXT_SCENE_PATH)
