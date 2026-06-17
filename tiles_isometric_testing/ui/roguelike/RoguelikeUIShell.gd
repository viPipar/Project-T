extends CanvasLayer

@onready var p1_wallet = $Container/Header/P1Wallet
@onready var p2_wallet = $Container/Header/P2Wallet
@onready var screen_container = $Container/ScreenContainer

var current_screen: Control = null

func _ready() -> void:
	# Hide by default
	visible = false
	
	# We should hook to CoinEconomy to update wallets, but for now just mock
	_update_wallets()

func show_screen(screen_scene_path: String) -> void:
	visible = true
	
	if current_screen != null:
		current_screen.queue_free()
		
	var scene = load(screen_scene_path)
	if scene:
		current_screen = scene.instantiate()
		screen_container.add_child(current_screen)

func hide_ui() -> void:
	visible = false

func _update_wallets() -> void:
	# Mock
	p1_wallet.text = "P1: 100 Coins"
	p2_wallet.text = "P2: 100 Coins"

# Helper for debug toggle
func toggle() -> void:
	if visible:
		hide_ui()
	else:
		# Default to MapScreen when opening
		show_screen("res://ui/roguelike/MapScreen.tscn")
