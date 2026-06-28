# ui/split_screen/SplitScreenManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# SplitScreenManager (CanvasLayer-based)
#
# Mengelola layout split-screen BG3-style:
#   - Layer CanvasLayer menutup root viewport (yang render world tanpa kamera)
#   - Dua SubViewportContainer side-by-side mengisi layar penuh
#   - Tiap SubViewport berbagi World2D yang sama dari root
#   - Tiap SubViewport punya Camera2D sendiri (P1 kiri, P2 kanan)
# ─────────────────────────────────────────────────────────────────────────────
class_name SplitScreenManager
extends CanvasLayer   # ← PENTING: CanvasLayer, bukan Control

# ── Node refs ────────────────────────────────────────────────────────────────
var _p1_viewport_container : SubViewportContainer
var _p2_viewport_container : SubViewportContainer
var _p1_viewport           : SubViewport
var _p2_viewport           : SubViewport
var _cam_p1                : PlayerCamera2D
var _cam_p2                : PlayerCamera2D
var _world_node            : Node2D

var _f3_hud_p1: Control
var _f3_hud_p2: Control

# ── End-turn overlay per player ───────────────────────────────────────────────
var _p1_end_overlay : ColorRect = null
var _p2_end_overlay : ColorRect = null
var _p1_end_label   : Label    = null
var _p2_end_label   : Label    = null
var _p1_end_tween   : Tween    = null
var _p2_end_tween   : Tween    = null

# ── Public API ────────────────────────────────────────────────────────────────
var cam_p1: PlayerCamera2D:
	get:
		return _cam_p1
var cam_p2: PlayerCamera2D:
	get:
		return _cam_p2


func _ready() -> void:
	layer = 0
	if _world_node != null:
		_build_layout()
		_attach_cameras(_world_node)
		_connect_turn_signals()
		print("[SplitScreenManager] Split-screen ready")


## Entry point — boleh dipanggil sebelum atau sesudah add_child
func setup(world_node: Node2D) -> void:
	_world_node = world_node
	if is_inside_tree():
		_build_layout()
		_attach_cameras(world_node)
		_connect_turn_signals()
		print("[SplitScreenManager] Split-screen ready")


# ─────────────────────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────────────────────

func _build_layout() -> void:
	# ── Background hitam: menutupi root viewport yang render world tanpa kamera ──
	var bg := ColorRect.new()
	bg.name  = "Background"
	bg.color = Color(0.05, 0.05, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── HBoxContainer: dua viewport berdampingan mengisi layar penuh ────────────
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxLayout"
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# ── Viewport Kiri (P1) ──────────────────────────────────────────────────────
	_p1_viewport_container = SubViewportContainer.new()
	_p1_viewport_container.name                   = "P1ViewportContainer"
	_p1_viewport_container.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	_p1_viewport_container.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_p1_viewport_container.stretch                = true
	hbox.add_child(_p1_viewport_container)

	_p1_viewport = SubViewport.new()
	_p1_viewport.name               = "P1Viewport"
	_p1_viewport.transparent_bg     = false
	_p1_viewport.handle_input_locally = false
	_p1_viewport.canvas_cull_mask = 1 | 2 # Layer 1 (Shared) + Layer 2 (P1)
	_p1_viewport_container.add_child(_p1_viewport)

	# ── Viewport Kanan (P2) ─────────────────────────────────────────────────────
	_p2_viewport_container = SubViewportContainer.new()
	_p2_viewport_container.name                   = "P2ViewportContainer"
	_p2_viewport_container.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	_p2_viewport_container.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_p2_viewport_container.stretch                = true
	hbox.add_child(_p2_viewport_container)

	_p2_viewport = SubViewport.new()
	_p2_viewport.name               = "P2Viewport"
	_p2_viewport.transparent_bg     = false
	_p2_viewport.handle_input_locally = false
	_p2_viewport.canvas_cull_mask = 1 | 4 # Layer 1 (Shared) + Layer 3 (P2)
	_p2_viewport_container.add_child(_p2_viewport)

	# ── Garis pembatas 2px di tengah ────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.name         = "CenterDivider"
	divider.color        = Color(0.0, 0.0, 0.0, 1.0)
	divider.anchor_left  = 0.5
	divider.anchor_right = 0.5
	divider.anchor_top   = 0.0
	divider.anchor_bottom = 1.0
	divider.offset_left  = -1
	divider.offset_right = 1
	divider.offset_top   = 0
	divider.offset_bottom = 0
	add_child(divider)

	# ── Label player tipis di pojok masing-masing viewport ──────────────────────
	_add_player_label("P1  Fighter", 0.01, 0.01)
	_add_player_label("P2  Wizard",  0.51, 0.01)

	# ── End-turn overlay (awalnya tersembunyi) ────────────────────────────────
	_p1_end_overlay = _make_end_overlay(0.0, 0.5, 1)  # kiri
	_p2_end_overlay = _make_end_overlay(0.5, 1.0, 2)  # kanan
	_p1_end_label   = _make_end_label(0.0, 0.5)
	_p2_end_label   = _make_end_label(0.5, 1.0)
	add_child(_p1_end_overlay)
	add_child(_p2_end_overlay)
	add_child(_p1_end_label)
	add_child(_p2_end_label)

	# ── Combat HUD bars (bottom of each viewport half) ───────────────────────
	_spawn_combat_hud_bars()
	
	# ── F3 Debug HUDs ────────────────────────────────────────────────────────
	_spawn_f3_huds()


func _spawn_f3_huds() -> void:
	var hud_scene = load("res://ui/debug/PlayerDebugHUD.gd")
	if hud_scene:
		_f3_hud_p1 = MarginContainer.new()
		_f3_hud_p1.set_script(hud_scene)
		_f3_hud_p1.set("player_id", 1)
		_f3_hud_p1.name = "F3DebugHUD_P1"
		_f3_hud_p1.anchor_left = 1.0
		_f3_hud_p1.anchor_right = 1.0
		_f3_hud_p1.anchor_top = 0.0
		_f3_hud_p1.anchor_bottom = 0.0
		_f3_hud_p1.offset_left = -220
		_f3_hud_p1.offset_right = 0
		_f3_hud_p1.offset_top = 0
		_f3_hud_p1.offset_bottom = 150
		_p1_viewport_container.add_child(_f3_hud_p1)
		
		_f3_hud_p2 = MarginContainer.new()
		_f3_hud_p2.set_script(hud_scene)
		_f3_hud_p2.set("player_id", 2)
		_f3_hud_p2.name = "F3DebugHUD_P2"
		_f3_hud_p2.anchor_left = 1.0
		_f3_hud_p2.anchor_right = 1.0
		_f3_hud_p2.anchor_top = 0.0
		_f3_hud_p2.anchor_bottom = 0.0
		_f3_hud_p2.offset_left = -220
		_f3_hud_p2.offset_right = 0
		_f3_hud_p2.offset_top = 0
		_f3_hud_p2.offset_bottom = 150
		_p2_viewport_container.add_child(_f3_hud_p2)


func _add_player_label(text: String, anchor_left: float, anchor_top: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	lbl.anchor_left   = anchor_left
	lbl.anchor_top    = anchor_top
	lbl.anchor_right  = anchor_left
	lbl.anchor_bottom = anchor_top
	lbl.offset_left   = 10
	lbl.offset_top    = 10
	lbl.offset_right  = 200
	lbl.offset_bottom = 30
	add_child(lbl)


func _make_end_overlay(al: float, ar: float, _pid: int) -> ColorRect:
	var r := ColorRect.new()
	r.color       = Color(0, 0, 0, 0)  # mulai transparan
	r.anchor_left  = al
	r.anchor_right = ar
	r.anchor_top   = 0.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _make_end_label(al: float, ar: float) -> Label:
	var lbl := Label.new()
	lbl.text = "WAITING..."
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.anchor_left   = al
	lbl.anchor_right  = ar
	lbl.anchor_top    = 0.5
	lbl.anchor_bottom = 0.5
	lbl.offset_left   = 0
	lbl.offset_right  = 0
	lbl.offset_top    = -20
	lbl.offset_bottom = 20
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.0
	return lbl


func _attach_cameras(world_node: Node2D) -> void:
	# Bagikan World2D dari root agar kedua SubViewport merender objek yang sama
	var shared_world := world_node.get_world_2d()
	_p1_viewport.world_2d = shared_world
	_p2_viewport.world_2d = shared_world

	# Buat Camera P1 — ada di P1 SubViewport
	_cam_p1 = PlayerCamera2D.new()
	_cam_p1.name      = "Camera_P1"
	_cam_p1.player_id = 1
	_cam_p1.pan_speed = 600.0
	_cam_p1.zoom      = Vector2(0.5, 0.5)
	_p1_viewport.add_child(_cam_p1)

	# Buat Camera P2 — ada di P2 SubViewport
	_cam_p2 = PlayerCamera2D.new()
	_cam_p2.name      = "Camera_P2"
	_cam_p2.player_id = 2
	_cam_p2.pan_speed = 600.0
	_cam_p2.zoom      = Vector2(0.5, 0.5)
	_p2_viewport.add_child(_cam_p2)

	# Aktifkan kamera — posisi awal di tengah map (sama dengan Camera2D lama)
	var start_pos := Vector2(0, 488)
	_cam_p1.set_target(start_pos)
	_cam_p1.position = start_pos
	_cam_p1.enabled  = true
	_cam_p1.make_current()

	_cam_p2.set_target(start_pos)
	_cam_p2.position = start_pos
	_cam_p2.enabled  = true
	_cam_p2.make_current()

	print("[SplitScreenManager] Cameras aktif — shared World2D: ", shared_world)


## Fokuskan kamera ke posisi world tertentu (dipanggil setelah spawn player)
func focus_camera(player_id: int, world_position: Vector2) -> void:
	if player_id == 1 and _cam_p1 != null:
		_cam_p1.set_target(world_position)
		_cam_p1.position = world_position
	elif player_id == 2 and _cam_p2 != null:
		_cam_p2.set_target(world_position)
		_cam_p2.position = world_position


# ── END-TURN OVERLAY ──────────────────────────────────────────────────────────

func _connect_turn_signals() -> void:
	if TurnManager == null:
		return
	if not TurnManager.player_end_state_changed.is_connected(_on_player_end_state):
		TurnManager.player_end_state_changed.connect(_on_player_end_state)
	if not TurnManager.turn_state_changed.is_connected(_on_turn_state_changed):
		TurnManager.turn_state_changed.connect(_on_turn_state_changed)


func _on_turn_state_changed(_turn_number: int, _phase: int) -> void:
	_set_end_overlay(1, false)
	_set_end_overlay(2, false)


func _on_player_end_state(player_id: int, ended: bool) -> void:
	_set_end_overlay(player_id, ended)


func _set_end_overlay(player_id: int, ended: bool) -> void:
	var overlay : ColorRect = _p1_end_overlay if player_id == 1 else _p2_end_overlay
	var lbl     : Label    = _p1_end_label   if player_id == 1 else _p2_end_label
	if overlay == null or lbl == null:
		return

	_kill_end_tween(player_id)

	if ended:
		# Darken layar player yang sudah end turn
		var cancel_key := _get_input_key_label("p%d_end_turn" % player_id, "R" if player_id == 1 else "P")
		lbl.text = "End Turn\n[%s] Cancel" % cancel_key
		var tw := create_tween().set_ease(Tween.EASE_OUT)
		_store_end_tween(player_id, tw)
		tw.tween_property(overlay, "color",     Color(0, 0, 0, 0.55), 0.35)
		tw.parallel().tween_property(lbl, "modulate:a", 1.0,           0.35)
	else:
		# Cancel end turn — kembalikan layar normal
		var tw := create_tween().set_ease(Tween.EASE_IN)
		_store_end_tween(player_id, tw)
		tw.tween_property(overlay, "color",     Color(0, 0, 0, 0),    0.25)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0,           0.25)


# ── COMBAT HUD BARS ──────────────────────────────────────────────────────────

func _spawn_combat_hud_bars() -> void:
	# P1 HUD bar — bottom-left half
	var hud_p1 := CombatHUDBar.new()
	hud_p1.name       = "CombatHUD_P1"
	hud_p1.player_id  = 1
	hud_p1.anchor_left   = 0.0
	hud_p1.anchor_right  = 0.5
	hud_p1.anchor_top    = 1.0
	hud_p1.anchor_bottom = 1.0
	hud_p1.offset_top    = -52   # BAR_HEIGHT
	hud_p1.offset_bottom = 0
	hud_p1.offset_left   = 0
	hud_p1.offset_right  = 0
	add_child(hud_p1)

	# P2 HUD bar — bottom-right half
	var hud_p2 := CombatHUDBar.new()
	hud_p2.name       = "CombatHUD_P2"
	hud_p2.player_id  = 2
	hud_p2.anchor_left   = 0.5
	hud_p2.anchor_right  = 1.0
	hud_p2.anchor_top    = 1.0
	hud_p2.anchor_bottom = 1.0
	hud_p2.offset_top    = -52
	hud_p2.offset_bottom = 0
	hud_p2.offset_left   = 0
	hud_p2.offset_right  = 0
	add_child(hud_p2)

	print("[SplitScreenManager] Combat HUD bars spawned ✅")


# ── INVENTORY TOGGLE (TAB KEY) ───────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_inventory") or event.is_action_pressed("p2_inventory"):
		EventBus.inventory_toggled.emit()
		get_viewport().set_input_as_handled()


func _kill_end_tween(player_id: int) -> void:
	var tw: Tween = _p1_end_tween if player_id == 1 else _p2_end_tween
	if tw != null and tw.is_valid():
		tw.kill()


func _store_end_tween(player_id: int, tw: Tween) -> void:
	if player_id == 1:
		_p1_end_tween = tw
	else:
		_p2_end_tween = tw


func _get_input_key_label(action_name: String, fallback: String) -> String:
	if not InputMap.has_action(action_name):
		return fallback
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code := key_event.physical_keycode
			if code == 0:
				code = key_event.keycode
			if code != 0:
				return OS.get_keycode_string(code)
	return fallback
