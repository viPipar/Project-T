extends Node2D

@onready var world: Node2D = $World
@onready var debug_panel: Control = $DebugUI/Root/DebugPanel
@onready var dice_sandbox: Control = $DebugUI/Root/DiceSandbox
@onready var debug_tooltip: Label = $DebugUI/Root/DebugTooltip
@onready var ui_root: Control = $DebugUI/Root

var _show_debug_panel:  bool = false
var _show_dice_sandbox: bool = false
var _show_debug_grid:   bool = false
var _split_screen: SplitScreenManager = null

func _ready() -> void:
	var player_scene := preload("res://entities/player/Player.tscn")
	var cursor_scene := preload("res://world/SelectionCursor.tscn")

	GridManager.load_walls_for_map(1) # manggil mapping

	# ── Setup Split-Screen SEBELUM spawn player ────────────────────────────────
	_setup_split_screen()

	# ── Spawn Player 1 ────────────────────────────────────────────────────────
	var p1 = world.spawn_entity(player_scene, Vector2i(0, 0), {
		"player_id": 1, "char_name": "Aria"
	})
	p1.place_at(Vector2i(5, 7))

	# ── Spawn Player 2 ────────────────────────────────────────────────────────
	var p2 = world.spawn_entity(player_scene, Vector2i(0, 0), {
		"player_id": 2, "char_name": "Kael"
	})
	p2.place_at(Vector2i(7, 7))

	var p1_class := p1.get_node_or_null("ClassComponent") as ClassComponent
	if p1_class != null:
		p1_class.set_primary_class("slayer")

	var p2_class := p2.get_node_or_null("ClassComponent") as ClassComponent
	if p2_class != null:
		p2_class.set_primary_class("scholar")

	TurnManager.register_player(p1)
	TurnManager.register_player(p2)

	# ── Spawn Selection Cursor ────────────────────────────────────────────────
	var c1 = cursor_scene.instantiate()
	var c2 = cursor_scene.instantiate()
	world.entities.add_child(c1)
	world.entities.add_child(c2)
	c1.bind(p1)
	c2.bind(p2)

	# ── Spawn Keyboard Cursors ────────────────────────────────────────────────
	# Penting: cursor bergerak bebas tapi hanya update hovered tile.
	# Camera yang pan mengikuti arah input (bukan cursor yang bergerak di world)
	var kb_cursor_p1 := Node2D.new()
	kb_cursor_p1.name = "KeyboardTileCursor_P1"
	kb_cursor_p1.set_script(load("res://world/KeyboardTileCursor.gd"))
	kb_cursor_p1.set("player_id", 1)
	world.entities.add_child(kb_cursor_p1)
	kb_cursor_p1.global_position = p1.position
	p1.bind_cursor(kb_cursor_p1)

	var kb_cursor_p2 := Node2D.new()
	kb_cursor_p2.name = "KeyboardTileCursor_P2"
	kb_cursor_p2.set_script(load("res://world/KeyboardTileCursor.gd"))
	kb_cursor_p2.set("player_id", 2)
	world.entities.add_child(kb_cursor_p2)
	kb_cursor_p2.global_position = p2.position
	p2.bind_cursor(kb_cursor_p2)

	# ── Fokus kamera ke posisi spawn masing-masing player ────────────────────
	if _split_screen != null:
		_split_screen.focus_camera(1, p1.position)
		_split_screen.focus_camera(2, p2.position)

	# ── Spawn Enemy Placeholder ───────────────────────────────────────────────
	var enemy_scene := preload("res://entities/enemies/EnemyPlaceholder.tscn")

	var e1 := enemy_scene.instantiate()
	e1.set("enemy_name", "Goblin")
	e1.set("tint_color", Color(0.3, 0.9, 0.3, 1.0))  # hijau
	world.entities.add_child(e1)
	e1.call_deferred("place_at", Vector2i(5, 5))

	var e2 := enemy_scene.instantiate()
	e2.set("enemy_name", "Orc")
	e2.set("tint_color", Color(0.9, 0.4, 0.1, 1.0))  # oranye
	world.entities.add_child(e2)
	e2.call_deferred("place_at", Vector2i(8, 5))

	# ── CombatTestBridge ──────────────────────────────────────────────────────
	var bridge := Node.new()
	bridge.name = "CombatTestBridge"
	bridge.set_script(load("res://combat_core/tests/CombatTestBridge.gd"))
	add_child(bridge)

	TurnManager.start_battle()
	_apply_debug_visibility()


# ── SPLIT-SCREEN SETUP ───────────────────────────────────────────────────────────

func _setup_split_screen() -> void:
	# Nonaktifkan Camera2D lama yang ada di World (single camera mode)
	var old_cam := world.get_node_or_null("Camera2D")
	if old_cam != null:
		old_cam.enabled = false
		old_cam.queue_free()
		print("[Main] Camera2D lama dihapus — digantikan split-screen cameras")

	# Buat dan pasang SplitScreenManager sebagai CanvasLayer di atas DebugUI
	_split_screen = SplitScreenManager.new()
	_split_screen.name = "SplitScreenManager"
	# Tambahkan SEBELUM DebugUI agar debug UI tetap tampil di atas
	add_child(_split_screen)
	move_child(_split_screen, 0)  # Paling bawah z-order canvas

	# Setup split-screen dengan referensi ke World
	_split_screen.setup(world)



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_show_debug_panel = not _show_debug_panel
			KEY_F2:
				_show_dice_sandbox = not _show_dice_sandbox
			KEY_F3:
				_show_debug_grid = not _show_debug_grid
			_:
				return
		_apply_debug_visibility()


func _apply_debug_visibility() -> void:
	if debug_panel != null:
		debug_panel.visible = _show_debug_panel
	if dice_sandbox != null:
		dice_sandbox.visible = _show_dice_sandbox
	if debug_tooltip != null:
		debug_tooltip.visible = true
	if world != null and world.has_method("set_debug_grid_visible"):
		world.set_debug_grid_visible(_show_debug_grid)
	var autoload_debug := get_node_or_null("/root/DebugGrid")
	if autoload_debug != null:
		autoload_debug.visible = _show_debug_grid
