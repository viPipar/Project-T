extends CanvasLayer

const MAP_SCREEN_PATH = "res://ui/roguelike/MapScreen.tscn"
const TRANSITION_SCENE_PATH = "res://ui/roguelike/RoguelikeTransition.tscn"
const LOADING_SCREEN_PATH = "res://ui/roguelike/RoguelikeLoadingScreen.tscn"

@onready var p1_wallet = $Container/Header/P1Wallet
@onready var p2_wallet = $Container/Header/P2Wallet
@onready var screen_container = $Container/ScreenContainer

var current_screen: Control = null
var dual_cursor: DualCursorUI = null
var _transition_active := false
var _active_loading_screen: Control = null

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
		current_screen.set_meta("scene_path", screen_scene_path)
		screen_container.add_child(current_screen)
		
		# Delay rescan by 1 frame so ready completes
		get_tree().process_frame.connect(func(): if dual_cursor: dual_cursor.rescan(), CONNECT_ONE_SHOT)

func play_transition(midpoint_callback: Callable = Callable(), finished_callback: Callable = Callable()) -> void:
	if _transition_active:
		if midpoint_callback.is_valid():
			midpoint_callback.call()
		if finished_callback.is_valid():
			finished_callback.call()
		return

	var scene = load(TRANSITION_SCENE_PATH)
	if scene == null:
		if midpoint_callback.is_valid():
			midpoint_callback.call()
		if finished_callback.is_valid():
			finished_callback.call()
		return

	_transition_active = true
	var transition = scene.instantiate()
	get_tree().root.add_child(transition)
	var on_finished := func() -> void:
		_transition_active = false
		if finished_callback.is_valid():
			finished_callback.call()
	transition.finished.connect(on_finished, CONNECT_ONE_SHOT)
	transition.play(midpoint_callback)

func show_screen_with_transition(screen_scene_path: String) -> void:
	play_transition(func(): show_screen(screen_scene_path))

func show_screen_after_double_transition(screen_scene_path: String) -> void:
	transition_to_screen(screen_scene_path)

func transition_to_map() -> void:
	transition_to_screen(MAP_SCREEN_PATH)

func transition_to_choice(choice_screen_path: String) -> void:
	transition_to_screen(choice_screen_path)

func play_transition_route(loading_screen_path: String, target_screen_path: String) -> void:
	transition_to_screen(target_screen_path, loading_screen_path)

func transition_to_screen(target_screen_path: String, loading_screen_path: String = LOADING_SCREEN_PATH) -> void:
	if _transition_active:
		return

	var scene = load(TRANSITION_SCENE_PATH)
	if scene == null:
		show_screen(target_screen_path)
		return

	_transition_active = true
	var transition = scene.instantiate()
	get_tree().root.add_child(transition)
	var on_finished := func() -> void:
		_transition_active = false
	transition.finished.connect(on_finished, CONNECT_ONE_SHOT)
	var show_loading := func() -> void:
		_show_loading_for_transition(loading_screen_path)
	var show_target := func() -> void:
		_show_target_after_transition(target_screen_path)
	transition.play_loading_route(show_loading, show_target)

func _show_loading_for_transition(loading_screen_path: String) -> void:
	if current_screen != null:
		current_screen.visible = false
	_clear_active_loading_screen()
	_active_loading_screen = _show_temporary_loading_screen(loading_screen_path)

func _show_target_after_transition(target_screen_path: String) -> void:
	_clear_active_loading_screen()
	if current_screen != null and _current_screen_matches(target_screen_path):
		current_screen.visible = true
		current_screen.set_process(true)
		current_screen.set_process_input(true)
		if dual_cursor:
			dual_cursor.rescan()
	else:
		show_screen(target_screen_path)

func _current_screen_matches(screen_scene_path: String) -> bool:
	if current_screen == null:
		return false
	return str(current_screen.get_meta("scene_path", "")) == screen_scene_path

func _clear_active_loading_screen() -> void:
	if is_instance_valid(_active_loading_screen):
		_active_loading_screen.queue_free()
	_active_loading_screen = null

func _show_temporary_loading_screen(loading_screen_path: String) -> Control:
	var scene = load(loading_screen_path)
	if scene == null:
		return null
	var loading_screen = scene.instantiate() as Control
	if loading_screen == null:
		return null
	screen_container.add_child(loading_screen)
	return loading_screen

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
		show_screen(MAP_SCREEN_PATH)
