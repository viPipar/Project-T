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
var _world_node            : Node2D  # disimpan saat setup() dipanggil

# ── Public API ────────────────────────────────────────────────────────────────
var cam_p1: PlayerCamera2D:
	get:
		return _cam_p1
var cam_p2: PlayerCamera2D:
	get:
		return _cam_p2


func _ready() -> void:
	layer = 0  # Di bawah DebugUI (layer 20) tapi di atas 2D world
	# Jika world_node sudah disimpan sebelum _ready() (dari setup() dini), init sekarang
	if _world_node != null:
		_build_layout()
		_attach_cameras(_world_node)
		print("[SplitScreenManager] Split-screen ready ✅")


## Entry point — boleh dipanggil sebelum atau sesudah add_child
func setup(world_node: Node2D) -> void:
	_world_node = world_node
	# Jika sudah di dalam tree, langsung build. Jika belum, _ready() yang akan build.
	if is_inside_tree():
		_build_layout()
		_attach_cameras(world_node)
		print("[SplitScreenManager] Split-screen ready ✅")


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
	_add_player_label("P1 ◀", 0.01, 0.01)
	_add_player_label("▶ P2", 0.51, 0.01)


func _add_player_label(text: String, anchor_left: float, anchor_top: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	lbl.anchor_left    = anchor_left
	lbl.anchor_top     = anchor_top
	lbl.anchor_right   = anchor_left
	lbl.anchor_bottom  = anchor_top
	lbl.offset_left    = 8
	lbl.offset_top     = 8
	lbl.offset_right   = 200
	lbl.offset_bottom  = 30
	add_child(lbl)


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
