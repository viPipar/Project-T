extends CanvasLayer

@onready var p1_wallet = $Container/Header/P1Wallet
@onready var p2_wallet = $Container/Header/P2Wallet
@onready var screen_container = $Container/ScreenContainer

var current_screen: Control = null
var dual_cursor: DualCursorUI = null

func _ready() -> void:
	# Hide by default
	visible = false
	
	_setup_dual_cursor()
	
	# Hook to CoinEconomy to dynamically update wallets
	if CoinEconomy != null:
		CoinEconomy.balance_changed.connect(func(_p_id, _new_bal): _update_wallets())
		
	_update_wallets()
	_apply_neobrutalism()

func _setup_dual_cursor() -> void:
	dual_cursor = DualCursorUI.new()
	dual_cursor.root_container = screen_container
	
	var c1 = ColorRect.new()
	c1.color = NeobrutalStyle.COLOR_RED
	c1.custom_minimum_size = Vector2(20, 20)
	c1.size = Vector2(20, 20)
	add_child(c1)
	dual_cursor.cursor_p1 = c1
	
	var c2 = ColorRect.new()
	c2.color = NeobrutalStyle.COLOR_CYAN
	c2.custom_minimum_size = Vector2(20, 20)
	c2.size = Vector2(20, 20)
	add_child(c2)
	dual_cursor.cursor_p2 = c2
	
	add_child(dual_cursor)

func _apply_neobrutalism() -> void:
	var bg = $Container/Background
	if bg:
		bg.color = NeobrutalStyle.COLOR_WHITE
		
	var header = $Container/Header
	if header:
		var style = NeobrutalStyle.get_panel(NeobrutalStyle.COLOR_PINK)
		style.border_width_bottom = 6
		style.shadow_offset = Vector2.ZERO # Flush to top
		
		var panel = Panel.new()
		panel.add_theme_stylebox_override("panel", style)
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		header.add_child(panel)
		header.move_child(panel, 0)
		
	# Style text
	p1_wallet.add_theme_color_override("font_color", Color.BLACK)
	p2_wallet.add_theme_color_override("font_color", Color.BLACK)
	$Container/Header/Title.add_theme_color_override("font_color", Color.BLACK)

func show_screen(screen_scene_path: String) -> void:
	visible = true
	var am = get_node_or_null("/root/AudioManager")
	if am != null: am.play_sfx("ui_open")
	
	if current_screen != null:
		current_screen.queue_free()
		
	var scene = load(screen_scene_path)
	if scene:
		current_screen = scene.instantiate()
		screen_container.add_child(current_screen)
		
		# Delay rescan by 1 frame so ready completes
		get_tree().process_frame.connect(func(): if dual_cursor: dual_cursor.rescan(), CONNECT_ONE_SHOT)

func hide_ui() -> void:
	visible = false
	var am = get_node_or_null("/root/AudioManager")
	if am != null: am.play_sfx("ui_cancel")

func _update_wallets() -> void:
	if CoinEconomy != null:
		p1_wallet.text = "P1: %d Coins" % CoinEconomy.get_balance(1)
		p2_wallet.text = "P2: %d Coins" % CoinEconomy.get_balance(2)
	else:
		p1_wallet.text = "P1: 100 Coins"
		p2_wallet.text = "P2: 100 Coins"

# Helper for debug toggle
func toggle() -> void:
	if visible:
		hide_ui()
	else:
		# Default to MapScreen when opening
		show_screen("res://ui/roguelike/MapScreen.tscn")
