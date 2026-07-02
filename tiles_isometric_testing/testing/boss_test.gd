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
var _show_f3_debug:     bool = false
var _show_squiggles:    bool = false
var _squiggle_noise:    NoiseTexture2D = null
var _split_screen: SplitScreenManager = null
var _stat_debug_panel: StatDebugPanel = null  # Debug stat manipulator (F1)
var roguelike_ui_shell: CanvasLayer = null
var _action_wheel_overlay: Control = null
var _inspect_overlay: Control = null

func _ready() -> void:
	var cursor_scene := preload("res://world/SelectionCursor.tscn")
	
	# Instantiate Roguelike UI early
	var shell_scene = load("res://ui/roguelike/RoguelikeUIShell.tscn")
	if shell_scene:
		roguelike_ui_shell = shell_scene.instantiate()
		add_child(roguelike_ui_shell)

	GridManager.load_walls_for_map(1) # manggil mapping

	# ── Setup Split-Screen ────────────────────────────────────────────────────
	_setup_split_screen()

	# ── Spawn Player 1 ────────────────────────────────────────────────────────
	var p1: Node = _spawn_player_from_json("aria", "Fighter", 1, Vector2i(5, 7))

	# ── Spawn Player 2 ────────────────────────────────────────────────────────
	var p2: Node = _spawn_player_from_json("kael", "Wizard", 2, Vector2i(7, 7))

	var p1_class := p1.get_node_or_null("ClassComponent") as ClassComponent
	if p1_class != null:
		p1_class.set_primary_class("slayer")

	var p2_class := p2.get_node_or_null("ClassComponent") as ClassComponent
	if p2_class != null:
		p2_class.set_primary_class("scholar")

	if RunManager != null and RunManager.is_run_active:
		RunManager.hydrate_player_node(p1, 1)
		RunManager.hydrate_player_node(p2, 2)

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
	_spawn_enemy_from_json("boss", "Boss Butterfly", Vector2i(9, 7), Color(1.0, 1.0, 1.0, 1.0))

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

	# ── Battle Action Wheel Overlay ──────────────────────────────────────────
	_spawn_action_wheel_overlay()

	# ── Inspect Window Overlay ───────────────────────────────────────────────
	_spawn_inspect_overlay(kb_cursor_p1, kb_cursor_p2)

	_setup_god_rays()

	_apply_debug_visibility()


func _setup_god_rays() -> void:
	var shader_path := "res://assets/shaders/god_rays.gdshader"
	var shader_res = load(shader_path) as Shader
	if shader_res == null:
		push_warning("[Main] God rays shader not found: %s" % shader_path)
		return
	
	var mat = ShaderMaterial.new()
	mat.shader = shader_res
	mat.set_shader_parameter("angle", -0.25)
	mat.set_shader_parameter("position", -0.3)
	mat.set_shader_parameter("spread", 0.45)
	mat.set_shader_parameter("cutoff", 0.05)
	mat.set_shader_parameter("falloff", 0.35)
	mat.set_shader_parameter("edge_fade", 0.2)
	mat.set_shader_parameter("speed", 0.8)
	mat.set_shader_parameter("ray1_density", 6.0)
	mat.set_shader_parameter("ray2_density", 25.0)
	mat.set_shader_parameter("ray2_intensity", 0.25)
	mat.set_shader_parameter("color", Color(0.9, 0.85, 0.6, 0.5))
	mat.set_shader_parameter("hdr", false)
	mat.set_shader_parameter("seed", 3.0)

	var canvas = CanvasLayer.new()
	canvas.layer = 1
	canvas.name = "EffectsLayer"

	var rect = ColorRect.new()
	rect.name = "GodRays"
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1, 1, 1, 1)
	rect.material = mat
	rect.visible = false

	canvas.add_child(rect)
	add_child(canvas)

	await get_tree().process_frame
	if mat.get_shader_parameter("angle") != null:
		rect.visible = true
		print("[Main] God rays overlay active")
	else:
		push_warning("[Main] God rays shader compile failed — removed")
		rect.queue_free()


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
	var scene: PackedScene = StatDataDB.load_entity_scene(data, "res://entities/enemies/BaseEnemy.tscn")
	var enemy: Node = scene.instantiate()
	enemy.set("enemy_name", str(data.get("display_name", fallback_name)))
	enemy.set("tint_color", tint_color)
	world.entities.add_child(enemy)
	StatDataDB.apply_entity_data(enemy, data)
	enemy.place_at(StatDataDB.get_spawn_grid_pos(data, fallback_pos))
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



func _spawn_action_wheel_overlay() -> void:
	var wheel_scene := load("res://ui/action_wheel/BattleActionWheelOverlay.tscn")
	if wheel_scene == null:
		push_warning("[Main] Action wheel overlay scene tidak ditemukan!")
		return
	_action_wheel_overlay = wheel_scene.instantiate() as Control
	_action_wheel_overlay.name = "ActionWheelOverlay"
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "ActionWheelCanvas"
	canvas.add_child(_action_wheel_overlay)
	add_child(canvas)
	
	_action_wheel_overlay.visible = true
	print("[Main] Action wheel overlay siap")

func _spawn_inspect_overlay(c1: Node2D, c2: Node2D) -> void:
	var inspect_script := load("res://ui/inspect/InspectOverlayController.gd")
	if inspect_script == null:
		push_warning("[Main] InspectOverlayController script tidak ditemukan!")
		return
	_inspect_overlay = inspect_script.new()
	_inspect_overlay.name = "InspectOverlay"
	_inspect_overlay.cursor_p1 = c1
	_inspect_overlay.cursor_p2 = c2
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "InspectCanvas"
	canvas.add_child(_inspect_overlay)
	add_child(canvas)
	
	print("[Main] Inspect overlay siap")


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
			KEY_F5:
				_show_squiggles = not _show_squiggles
				_toggle_squigglevision(_show_squiggles)
			KEY_T:
				print("--- 'T' KEY DETECTED ---")
				_run_all_tests()
			_:
				return
		_apply_debug_visibility()

func _toggle_squigglevision(enabled: bool) -> void:
	var entities := get_tree().get_nodes_in_group("players")
	entities.append_array(get_tree().get_nodes_in_group("enemies"))
	if enabled:
		if _squiggle_noise == null:
			var noise = FastNoiseLite.new()
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			_squiggle_noise = NoiseTexture2D.new()
			_squiggle_noise.noise = noise
			_squiggle_noise.width = 64
			_squiggle_noise.height = 64
		for e in entities:
			var sp = _get_entity_sprite(e)
			if sp:
				var mat = ShaderMaterial.new()
				mat.shader = load("res://assets/shaders/squigglevision.gdshader")
				mat.set_shader_parameter("noise", _squiggle_noise)
				mat.set_shader_parameter("strength", 1.2)
				mat.set_shader_parameter("fps", 6.0)
				sp.material = mat
		print("[Main] Squigglevision ON")
	else:
		for e in entities:
			var sp = _get_entity_sprite(e)
			if sp and sp.material and sp.material is ShaderMaterial and sp.material.shader.resource_path == "res://assets/shaders/squigglevision.gdshader":
				sp.material = null
		print("[Main] Squigglevision OFF")


func _get_entity_sprite(entity: Node) -> CanvasItem:
	if entity.get("anim_sprite"): return entity.get("anim_sprite")
	if entity.get("sprite"): return entity.get("sprite")
	if entity.has_node("AnimatedSprite2D"): return entity.get_node("AnimatedSprite2D")
	if entity.has_node("Sprite2D"): return entity.get_node("Sprite2D")
	return null


func _run_all_tests() -> void:
	print("\n\n>>> RUNNING ALL SYSTEM TESTS FROM DEBUG MENU <<<")
	
	# Roguelike Tests
	var roguelike_tester = load("res://testing/RoguelikeTester.gd").new()
	if is_instance_valid(roguelike_tester) and roguelike_tester.has_method("run_all_tests"):
		roguelike_tester.run_all_tests(self)
	
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
	if is_instance_valid(world) and world.has_method("set_debug_grid_visible"):
		world.set_debug_grid_visible(_show_debug_grid)
	var autoload_debug := get_node_or_null("/root/DebugGrid")
	if autoload_debug != null:
		autoload_debug.visible = _show_debug_grid
