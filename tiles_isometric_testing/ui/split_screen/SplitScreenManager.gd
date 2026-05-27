# ui/split_screen/SplitScreenManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# SplitScreenManager
#
# Mengelola layout split-screen BG3-style:
#   - Layar dibagi 2: kiri (P1) dan kanan (P2)
#   - Tiap viewport punya SubViewport + Camera2D sendiri
#   - Satu World Node2D yang sama di-render ke kedua viewport
#   - Garis pembatas hitam 2px di tengah layar
#
# Cara pakai:
#   Di main.gd: _split_screen = SplitScreenManager.new()
#               add_child(_split_screen)
#               _split_screen.setup(world_node)
# ─────────────────────────────────────────────────────────────────────────────
class_name SplitScreenManager
extends Control

# ── Node refs ────────────────────────────────────────────────────────────────
var _p1_viewport_container: SubViewportContainer
var _p2_viewport_container: SubViewportContainer
var _p1_viewport:           SubViewport
var _p2_viewport:           SubViewport
var _cam_p1:                PlayerCamera2D
var _cam_p2:                PlayerCamera2D
var _divider:               ColorRect

# ── Public references (dipakai oleh CombatTestBridge dll.) ──────────────────
var cam_p1: PlayerCamera2D:
	get: return _cam_p1
var cam_p2: PlayerCamera2D:
	get: return _cam_p2


func _ready() -> void:
	# Isi layar penuh
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Tidak perlu interaksi mouse di root ini
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Entry point — panggil setelah add_child(SplitScreenManager)
## world_node: Node2D utama yang berisi TileMap, Entities, dll.
func setup(world_node: Node2D) -> void:
	_build_layout()
	_attach_cameras_to_world(world_node)
	_activate_cameras()
	print("[SplitScreenManager] Split-screen ready ✅")


# ─────────────────────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────────────────────

func _build_layout() -> void:
	# HBoxContainer untuk dua viewport berdampingan
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxLayout"
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# ── Viewport Kiri (P1) ──────────────────────────────────────────────────
	_p1_viewport_container = SubViewportContainer.new()
	_p1_viewport_container.name            = "P1ViewportContainer"
	_p1_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p1_viewport_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_p1_viewport_container.stretch         = true
	hbox.add_child(_p1_viewport_container)

	_p1_viewport = SubViewport.new()
	_p1_viewport.name            = "P1Viewport"
	_p1_viewport.transparent_bg  = false
	_p1_viewport.handle_input_locally = false  # Input tetap global
	_p1_viewport_container.add_child(_p1_viewport)

	# ── Viewport Kanan (P2) ─────────────────────────────────────────────────
	_p2_viewport_container = SubViewportContainer.new()
	_p2_viewport_container.name            = "P2ViewportContainer"
	_p2_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p2_viewport_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_p2_viewport_container.stretch         = true
	hbox.add_child(_p2_viewport_container)

	_p2_viewport = SubViewport.new()
	_p2_viewport.name            = "P2Viewport"
	_p2_viewport.transparent_bg  = false
	_p2_viewport.handle_input_locally = false
	_p2_viewport_container.add_child(_p2_viewport)

	# ── Garis Pembatas Tengah ───────────────────────────────────────────────
	_divider = ColorRect.new()
	_divider.name       = "CenterDivider"
	_divider.color      = Color(0.05, 0.05, 0.05, 1.0)  # Hitam sangat gelap
	_divider.custom_minimum_size = Vector2(2, 0)
	_divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Posisi di tengah (di atas hbox)
	_divider.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_divider.anchor_left   = 0.5
	_divider.anchor_right  = 0.5
	_divider.anchor_top    = 0.0
	_divider.anchor_bottom = 1.0
	_divider.offset_left   = -1
	_divider.offset_right  = 1
	_divider.offset_top    = 0
	_divider.offset_bottom = 0
	add_child(_divider)

	# ── Label nama player (overlay tipis di atas viewport) ──────────────────
	_add_player_label(self, "P1", 0.0, 0.5)
	_add_player_label(self, "P2", 0.5, 1.0)


func _add_player_label(parent: Control, text: String, left: float, right: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	label.anchor_left   = left
	label.anchor_right  = right
	label.anchor_top    = 0.0
	label.anchor_bottom = 0.0
	label.offset_left   = 8
	label.offset_right  = 0
	label.offset_top    = 6
	label.offset_bottom = 26
	parent.add_child(label)


func _attach_cameras_to_world(world_node: Node2D) -> void:
	# Buat Camera P1 — tambah ke P1 Viewport
	_cam_p1 = PlayerCamera2D.new()
	_cam_p1.name       = "Camera_P1"
	_cam_p1.player_id  = 1
	_cam_p1.pan_speed  = 600.0
	_cam_p1.zoom       = Vector2(0.5, 0.5)  # Sesuai zoom yang ada sekarang
	_p1_viewport.add_child(_cam_p1)

	# Buat Camera P2 — tambah ke P2 Viewport
	_cam_p2 = PlayerCamera2D.new()
	_cam_p2.name       = "Camera_P2"
	_cam_p2.player_id  = 2
	_cam_p2.pan_speed  = 600.0
	_cam_p2.zoom       = Vector2(0.5, 0.5)
	_p2_viewport.add_child(_cam_p2)

	# Pindahkan World Node ke P1 Viewport
	# Kedua viewport akan merender World yang SAMA via shared scene tree
	# Caranya: World ada di P1 viewport, P2 viewport punya viewport_texture yang sama
	# CATATAN: Cara BG3 sejati butuh World di root scene — kita pakai approach berbeda:
	# World tetap di root, tiap viewport punya kamera sendiri yang merender world root
	# Ini dicapai dengan set_world_2d() pada tiap viewport

	# Buat shared World2D object
	var shared_world := world_node.get_world_2d()
	_p1_viewport.world_2d = shared_world
	_p2_viewport.world_2d = shared_world


func _activate_cameras() -> void:
	# Set posisi awal kamera (tengah map, sama dengan nilai yang ada di Main.tscn)
	var start_pos := Vector2(0, 488)  # Nilai default dari Main.tscn
	_cam_p1.position    = start_pos
	_cam_p1._target_pos = start_pos
	_cam_p1._origin     = start_pos
	_cam_p1.enabled     = true
	_cam_p1.make_current()

	_cam_p2.position    = start_pos
	_cam_p2._target_pos = start_pos
	_cam_p2._origin     = start_pos
	_cam_p2.enabled     = true
	_cam_p2.make_current()

	print("[SplitScreenManager] P1 Cam & P2 Cam aktif, shared World2D ✅")


## Update posisi awal kamera ke posisi spawn player
func focus_camera(player_id: int, world_position: Vector2) -> void:
	if player_id == 1 and _cam_p1 != null:
		_cam_p1.set_target(world_position)
	elif player_id == 2 and _cam_p2 != null:
		_cam_p2.set_target(world_position)
