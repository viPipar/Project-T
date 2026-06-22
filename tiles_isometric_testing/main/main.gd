# main/main.gd
# Tanggung jawab:
#   Entry scene utama untuk spawn player/enemy, cursor, debug UI, dan combat bridge.
#   Base stat entity sekarang dibaca dari StatDataDB JSON.
#
# Cara pakai:
#   Jalankan Main.tscn.
#   Ubah data aktif di res://data/stat_module/entity_base_stats/*.json.
#
# Cara evaluasi:
#   1. Ubah vit/str/acc Aria atau Goblin di JSON.
#   2. Jalankan ulang Main.tscn.
#   3. Tekan F1 dan pastikan debug stats mengikuti JSON.
extends Node2D

@onready var world: Node2D = $World
@onready var debug_panel: Control = $DebugUI/Root/DebugPanel
@onready var dice_sandbox: Control = $DebugUI/Root/DiceSandbox
@onready var debug_tooltip: Label = $DebugUI/Root/DebugTooltip
@onready var ui_root: Control = $DebugUI/Root

var _show_debug_panel:  bool = false
var _show_dice_sandbox: bool = false
var _show_debug_grid:   bool = false
var _show_f3_debug:     bool = true
var _split_screen: SplitScreenManager = null
var _stat_debug_panel: StatDebugPanel = null  # Debug stat manipulator (F1)
var roguelike_ui_shell: CanvasLayer = null
var _action_wheel_test_overlay: Control = null

func _ready() -> void:
	# Bersihkan memory/state sisa dari scene sebelumnya
	if TurnManager != null and TurnManager.has_method("clear_state"):
		TurnManager.clear_state()
	if GridManager != null and GridManager.has_method("clear_state"):
		GridManager.clear_state()
		
	var cursor_scene := preload("res://world/SelectionCursor.tscn")
	# (Dihapus: MapScreen kini dipanggil secara penuh lewat RunManager/Scene terpisah, bukan overlay)

	# --- Tombol Debug Return to Map ---
	var debug_map_layer = CanvasLayer.new()
	debug_map_layer.name = "DebugMapLayer"
	debug_map_layer.layer = 128
	var btn_return_map = Button.new()
	btn_return_map.text = "🔙 Return to Map"
	btn_return_map.add_theme_font_size_override("font_size", 24)
	btn_return_map.position = Vector2(20, 150)
	btn_return_map.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_return_map.pressed.connect(func():
		if has_node("RoguelikeUIShell"): return
		var shell_scene = load("res://ui/roguelike/RoguelikeUIShell.tscn")
		var shell_node = shell_scene.instantiate()
		shell_node.name = "RoguelikeUIShell"
		add_child(shell_node)
		shell_node.visible = true
		shell_node.show_screen("res://ui/roguelike/MapScreen.tscn")
		debug_map_layer.visible = false
	)
	debug_map_layer.add_child(btn_return_map)
	add_child(debug_map_layer)

	# ── Load Component-Based Map ──────────────────────────────────────────────
	var map_id = GridManager.current_map_id if GridManager.current_map_id > 0 else 1
	var map_path = "res://world/maps/Map_%d.tscn" % map_id
	
	if ResourceLoader.exists(map_path):
		var map_scene = load(map_path)
		var map_node = map_scene.instantiate()
		# Taruh di urutan pertama agar dirender di bawah karakter
		world.add_child(map_node)
		world.move_child(map_node, 0)
	else:
		push_error("[Main] Map scene tidak ditemukan di %s!" % map_path)

	# ── Setup Split-Screen ────────────────────────────────────────────────────
	_setup_split_screen()

	# ── Spawn Player 1 ────────────────────────────────────────────────────────
	var p1_pos = _get_valid_spawn_pos(Vector2i(5, 7))
	var p1: Node = _spawn_player_from_json("aria", "Aria", 1, p1_pos)

	# ── Spawn Player 2 ────────────────────────────────────────────────────────
	var p2_pos = _get_valid_spawn_pos(Vector2i(7, 7))
	var p2: Node = _spawn_player_from_json("kael", "Kael", 2, p2_pos)


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

	# ── Fokus kamera ke posisi spawn + bind camera_ref ke cursor ────────────
	if _split_screen != null:
		_split_screen.focus_camera(1, p1.position)
		_split_screen.focus_camera(2, p2.position)
		# Bind camera ke cursor agar cursor selalu terkunci di tengah viewport
		kb_cursor_p1.set("camera_ref", _split_screen.cam_p1)
		kb_cursor_p2.set("camera_ref", _split_screen.cam_p2)

	# ── Spawn enemy placeholder untuk testing combat_core ─────────────────────
	_spawn_enemy_from_json("goblin", "Goblin", Vector2i(5, 5), Color(0.3, 0.9, 0.3, 1.0))
	_spawn_enemy_from_json("orc", "Orc", Vector2i(8, 5), Color(0.9, 0.4, 0.1, 1.0))

	# ── CombatTestBridge ──────────────────────────────────────────────────────
	var bridge := Node.new()
	bridge.name = "CombatTestBridge"
	bridge.set_script(load("res://combat_core/tests/CombatTestBridge.gd"))
	add_child(bridge)

	TurnManager.start_battle()

	# ── Floating Text Manager (damage/heal/miss popups) ───────────────────────
	_spawn_floating_text_manager()

	# ── Stat Debug Panel ─────────────────────────────────────────────────────
	_spawn_stat_debug_panel()

	# ── Action Wheel Test Overlay ────────────────────────────────────────────
	_spawn_action_wheel_test_overlay()

	_apply_debug_visibility()


func _spawn_player_from_json(
	entity_id: String,
	fallback_name: String,
	fallback_player_id: int,
	fallback_pos: Vector2i
) -> Node:
	var data: Dictionary = StatDataDB.get_player_data(entity_id)
	var scene: PackedScene = StatDataDB.load_entity_scene(data, "res://entities/player/Player.tscn")
	var display_name: String = str(data.get("display_name", fallback_name))
	var player_id: int = int(data.get("player_id", fallback_player_id))
	var player: Node = world.spawn_entity(scene, Vector2i.ZERO, {
		"player_id": player_id,
		"char_name": display_name
	})
	StatDataDB.apply_entity_data(player, data)
	player.place_at(StatDataDB.get_spawn_grid_pos(data, fallback_pos))
	return player


func _spawn_enemy_from_json(
	entity_id: String,
	fallback_name: String,
	fallback_pos: Vector2i,
	tint_color: Color
) -> Node:
	var data: Dictionary = StatDataDB.get_enemy_data(entity_id)
	var scene: PackedScene = StatDataDB.load_entity_scene(data, "res://entities/enemies/EnemyPlaceholder.tscn")
	var enemy: Node = scene.instantiate()
	enemy.set("enemy_name", str(data.get("display_name", fallback_name)))
	enemy.set("tint_color", tint_color)
	world.entities.add_child(enemy)
	StatDataDB.apply_entity_data(enemy, data)
	enemy.call_deferred("place_at", StatDataDB.get_spawn_grid_pos(data, fallback_pos))
	return enemy


func _spawn_stat_debug_panel() -> void:
	var panel_scene := load("res://combat_core/debug/StatDebugPanel.tscn")
	if panel_scene == null:
		push_warning("[Main] StatDebugPanel.tscn tidak ditemukan!")
		return
	_stat_debug_panel = panel_scene.instantiate() as StatDebugPanel
	_stat_debug_panel.name = "StatDebugPanel"
	# Tambah ke DebugUI/Root agar ikut layer yang benar
	if ui_root != null:
		ui_root.add_child(_stat_debug_panel)
	else:
		add_child(_stat_debug_panel)
	_stat_debug_panel.visible = false
	print("[Main] StatDebugPanel siap — tekan F1 untuk toggle ✅")


func _spawn_floating_text_manager() -> void:
	var ftm_script := load("res://ui/shared/FloatingTextManager.gd")
	if ftm_script == null:
		push_warning("[Main] FloatingTextManager.gd tidak ditemukan!")
		return
	var ftm := Node.new()
	ftm.name = "FloatingTextManager"
	ftm.set_script(ftm_script)
	add_child(ftm)
	print("[Main] FloatingTextManager siap — damage popups aktif ✅")



func _spawn_action_wheel_test_overlay() -> void:
	var test_scene := load("res://ui/action_wheel/testing.tscn")
	if test_scene == null:
		push_warning("[Main] ActionWheel testing.tscn tidak ditemukan!")
		return
	_action_wheel_test_overlay = test_scene.instantiate() as Control
	_action_wheel_test_overlay.name = "ActionWheelTestOverlay"
	
	# Masukkan ke dalam CanvasLayer agar berada di atas UI lainnya
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "ActionWheelCanvas"
	canvas.add_child(_action_wheel_test_overlay)
	add_child(canvas)
	
	_action_wheel_test_overlay.visible = true
	print("[Main] ActionWheel Test Overlay siap — use Q/E (P1) or U/O (P2) to toggle ✅")


# ── SPLIT-SCREEN SETUP ───────────────────────────────────────────────────────

func _setup_split_screen() -> void:
	# Nonaktifkan Camera2D lama di World
	var old_cam := world.get_node_or_null("Camera2D")
	if old_cam != null:
		(old_cam as Camera2D).enabled = false
		print("[Main] Camera2D lama dinonaktifkan — split-screen akan handle rendering")

	# Buat SplitScreenManager (extends CanvasLayer)
	_split_screen = SplitScreenManager.new()
	_split_screen.name = "SplitScreenManager"

	# Simpan world ref SEBELUM add_child — _ready() SplitScreenManager
	# akan build layout saat is_inside_tree() = true
	_split_screen.setup(world)   # simpan ref
	add_child(_split_screen)     # trigger _ready() → _build_layout() + _attach_cameras()

	# Hapus Camera2D lama setelah split-screen siap
	if old_cam != null and is_instance_valid(old_cam):
		old_cam.queue_free()
		print("[Main] Camera2D lama dihapus ✅")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_show_debug_panel = not _show_debug_panel
				debug_panel.visible = _show_debug_panel
			KEY_F2:
				_show_dice_sandbox = not _show_dice_sandbox
			KEY_F3:
				_show_f3_debug = not _show_f3_debug
				_apply_debug_visibility()
			KEY_F4:
				if _stat_debug_panel != null:
					_stat_debug_panel.visible = not _stat_debug_panel.visible
			KEY_T:
				print("--- 'T' KEY DETECTED ---")
				_run_all_tests()
			_:
				return
		_apply_debug_visibility()

func _run_all_tests() -> void:
	print("\n\n>>> RUNNING ALL SYSTEM TESTS FROM DEBUG MENU <<<")
	
	# Roguelike Tests
	var roguelike_tester = load("res://testing/RoguelikeTester.gd").new()
	if roguelike_tester.has_method("run_all_tests"):
		roguelike_tester.run_all_tests()
	
	# Combat Tests
	var ae_test = load("res://combat_core/tests/test_action_economy.gd").new()
	ae_test.name = "TestAE"
	add_child(ae_test)
	
	var dr_test = load("res://combat_core/tests/test_dice_roller.gd").new()
	dr_test.name = "TestDR"
	add_child(dr_test)
	
	var pm_test = load("res://combat_core/tests/test_phase_manager.gd").new()
	pm_test.name = "TestPM"
	add_child(pm_test)
	
	print(">>> ALL TESTS TRIGGERED <<<\n")


func _apply_debug_visibility() -> void:
	if debug_panel != null:
		debug_panel.visible = _show_debug_panel
	if dice_sandbox != null:
		dice_sandbox.visible = _show_dice_sandbox
	if debug_tooltip != null:
		debug_tooltip.visible = true
	if _stat_debug_panel != null:
		pass
	if world != null and world.has_method("set_debug_grid_visible"):
		world.set_debug_grid_visible(_show_debug_grid)
	var autoload_debug := get_node_or_null("/root/DebugGrid")
	if autoload_debug != null:
		autoload_debug.visible = _show_debug_grid

func _get_valid_spawn_pos(desired: Vector2i) -> Vector2i:
	if GridManager.is_walkable(desired):
		return desired
	
	# Spiral search for the nearest walkable tile
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				# Only check the perimeter of the radius
				if abs(dx) == r or abs(dy) == r:
					var p = desired + Vector2i(dx, dy)
					if GridManager.is_walkable(p):
						return p
	return desired
