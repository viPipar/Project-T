# main/main.gd
# Tanggung jawab:
#   Entry scene utama — orchestrator roguelike loop.
#   Handles MAP → COMBAT → LOOT → MAP flow.
extends Node2D

enum GameState { MAP, COMBAT, LOOT, GAME_OVER }

@onready var world: Node2D = $World
@onready var debug_panel: Control = $DebugUI/Root/DebugPanel
@onready var dice_sandbox: Control = $DebugUI/Root/DiceSandbox
@onready var debug_tooltip: Label = $DebugUI/Root/DebugTooltip
@onready var ui_root: Control = $DebugUI/Root

var _game_state: int = GameState.MAP
var _show_debug_panel:  bool = false
var _show_dice_sandbox: bool = false
var _show_debug_grid:   bool = false
var _show_f3_debug:     bool = false
var _show_squiggles:    bool = false
var _squiggle_noise:    NoiseTexture2D = null
var _split_screen: SplitScreenManager = null
var _stat_debug_panel: StatDebugPanel = null
var roguelike_ui_shell: CanvasLayer = null
var _action_wheel_overlay: Control = null
var _inspect_overlay: Control = null
var _combat_bridge: Node = null
var _kb_cursor_p1: Node2D = null
var _kb_cursor_p2: Node2D = null
var _pause_menu: CanvasLayer = null

func _ready() -> void:
	var cursor_scene := preload("res://world/SelectionCursor.tscn")

	GridManager.load_walls_for_map(1)

	# ── Roguelike Shell ──────────────────────────────────────────────────────
	var shell_scene = load("res://ui/roguelike/RoguelikeUIShell.tscn")
	if shell_scene:
		roguelike_ui_shell = shell_scene.instantiate()
		add_child(roguelike_ui_shell)

	# ── Setup Split-Screen ────────────────────────────────────────────────────
	_setup_split_screen()

	# ── Spawn Players ─────────────────────────────────────────────────────────
	var bottom_y := GridManager.grid_size.y - 2
	var p1: Node = _spawn_player_from_json("aria", "Fighter", 1, Vector2i(5, bottom_y))
	var p2: Node = _spawn_player_from_json("kael", "Wizard", 2, Vector2i(7, bottom_y))

	var p1_class := p1.get_node_or_null("ClassComponent") as ClassComponent
	if p1_class != null:
		p1_class.set_primary_class("slayer")

	var p2_class := p2.get_node_or_null("ClassComponent") as ClassComponent
	if p2_class != null:
		p2_class.set_primary_class("scholar")

	TurnManager.register_player(p1)
	TurnManager.register_player(p2)

	# ── Selection Cursors ────────────────────────────────────────────────────
	var c1 = cursor_scene.instantiate()
	var c2 = cursor_scene.instantiate()
	world.entities.add_child(c1)
	world.entities.add_child(c2)
	c1.bind(p1)
	c2.bind(p2)

	# ── Keyboard Cursors ─────────────────────────────────────────────────────
	_kb_cursor_p1 = Node2D.new()
	_kb_cursor_p1.name = "KeyboardTileCursor_P1"
	_kb_cursor_p1.set_script(load("res://world/KeyboardTileCursor.gd"))
	_kb_cursor_p1.set("player_id", 1)
	world.entities.add_child(_kb_cursor_p1)
	_kb_cursor_p1.global_position = p1.position
	p1.bind_cursor(_kb_cursor_p1)

	_kb_cursor_p2 = Node2D.new()
	_kb_cursor_p2.name = "KeyboardTileCursor_P2"
	_kb_cursor_p2.set_script(load("res://world/KeyboardTileCursor.gd"))
	_kb_cursor_p2.set("player_id", 2)
	world.entities.add_child(_kb_cursor_p2)
	_kb_cursor_p2.global_position = p2.position
	p2.bind_cursor(_kb_cursor_p2)

	# ── Camera Focus ─────────────────────────────────────────────────────────
	if _split_screen != null:
		_split_screen.focus_camera(1, p1.position)
		_split_screen.focus_camera(2, p2.position)
		_kb_cursor_p1.set("camera_ref", _split_screen.cam_p1)
		_kb_cursor_p2.set("camera_ref", _split_screen.cam_p2)

	# ── Non-visual Overlays ───────────────────────────────────────────────────
	_spawn_floating_text_manager()
	_spawn_stat_debug_panel()
	_spawn_action_wheel_overlay()
	_spawn_inspect_overlay(_kb_cursor_p1, _kb_cursor_p2)

	# ── Pause Menu ───────────────────────────────────────────────────────────
	_pause_menu = load("res://ui/menu/PauseMenu.gd").new()
	add_child(_pause_menu)
	_pause_menu.continue_pressed.connect(_on_pause_continue)
	_pause_menu.quit_pressed.connect(_on_pause_quit)

	_apply_debug_visibility()

	# ── Game Flow Signals ─────────────────────────────────────────────────────
	EventBus.start_combat.connect(_on_start_combat)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.entity_died.connect(_on_entity_died)
	if roguelike_ui_shell:
		roguelike_ui_shell.screen_changed.connect(_on_shell_screen_changed)

	# ── Start Roguelike Run ───────────────────────────────────────────────────
	if RunManager:
		RunManager.start_run()

	# ── Show Map ──────────────────────────────────────────────────────────────
	if roguelike_ui_shell:
		roguelike_ui_shell.show_screen("res://ui/roguelike/MapScreen.tscn")
	_game_state = GameState.MAP
	InputManager.is_in_menu = true

	# ── God rays last — contains await, purely cosmetic ─────────────────────
	_setup_god_rays()


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


# ── GAME FLOW ──────────────────────────────────────────────────────────────────

func _on_start_combat(node_type: int) -> void:
	if _game_state != GameState.MAP:
		return
	_enter_combat_mode(node_type)

func _enter_combat_mode(node_type: int) -> void:
	_game_state = GameState.COMBAT
	InputManager.is_in_menu = false

	if roguelike_ui_shell:
		roguelike_ui_shell.hide_ui()

	_clear_enemies()
	_spawn_enemies_for_node(node_type)

	TurnManager.reset_battle()

	_combat_bridge = Node.new()
	_combat_bridge.name = "CombatTestBridge"
	_combat_bridge.set_script(load("res://combat_core/tests/CombatTestBridge.gd"))
	add_child(_combat_bridge)

	TurnManager.start_battle()

func _on_shell_screen_changed(screen_path: String) -> void:
	if screen_path.contains("MapScreen"):
		_game_state = GameState.MAP
		InputManager.is_in_menu = true
	elif screen_path.contains("LootScreen"):
		_game_state = GameState.LOOT

func _on_combat_ended(result: String) -> void:
	if _game_state == GameState.COMBAT:
		if result == "victory":
			_clear_enemies()
			if _combat_bridge:
				_combat_bridge.queue_free()
				_combat_bridge = null
			TurnManager._battle_finished = true
			if roguelike_ui_shell:
				roguelike_ui_shell.show_screen("res://ui/roguelike/LootScreen.tscn")
		elif result == "defeat":
			_game_state = GameState.GAME_OVER
			_clear_enemies()
			if _combat_bridge:
				_combat_bridge.queue_free()
				_combat_bridge = null
			TurnManager._battle_finished = true
			EventNotifier.show_message("Party Defeated!", Color.RED)
			await get_tree().create_timer(1.5).timeout
			var result_screen = load("res://ui/roguelike/RunResultScreen.gd").new()
			result_screen.set_state(false)
			add_child(result_screen)

func _on_pause_continue() -> void:
	if _pause_menu:
		_pause_menu.hide_pause()

func _on_pause_quit() -> void:
	if _pause_menu:
		_pause_menu.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menu/MainMenu.tscn")

func _on_entity_died(entity: Node, _killer: Node) -> void:
	if _game_state != GameState.COMBAT:
		return
	if entity.is_in_group("enemies"):
		var any_alive := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var alive: Variant = e.get("is_alive")
			if alive == null:
				var hc := e.get_node_or_null("HealthComponent") as HealthComponent
				if hc != null and not hc.is_dead() and not hc.is_downed():
					any_alive = true
					break
			elif bool(alive):
				any_alive = true
				break
		if not any_alive:
			EventBus.combat_ended.emit("victory")

func _spawn_enemies_for_node(node_type: int) -> void:
	var center := 8
	var top := 4
	match node_type:
		NodeGraph.NodeType.BATTLE:
			_spawn_enemy_from_json("goblin", "Goblin", Vector2i(center - 3, top + 2), Color(0.3, 0.9, 0.3, 1.0))
			_spawn_enemy_from_json("orc", "Orc", Vector2i(center + 2, top), Color(0.9, 0.4, 0.1, 1.0))
			_spawn_enemy_from_json("beetle", "Beetle", Vector2i(center + 1, top + 3), Color(0.1, 0.6, 0.9, 1.0))
		NodeGraph.NodeType.ELITE:
			_spawn_enemy_from_json("orc", "Elite Orc", Vector2i(center - 2, top + 1), Color(0.9, 0.2, 0.1, 1.0))
			_spawn_enemy_from_json("beetle", "Elite Beetle", Vector2i(center + 2, top + 2), Color(0.9, 0.4, 0.1, 1.0))
		NodeGraph.NodeType.BOSS:
			_spawn_enemy_from_json("beetle", "Boss Beetle", Vector2i(center, top + 1), Color(0.9, 0.1, 0.1, 1.0))
		_:
			_spawn_enemy_from_json("goblin", "Goblin", Vector2i(center - 2, top + 1), Color(0.3, 0.9, 0.3, 1.0))
			_spawn_enemy_from_json("orc", "Orc", Vector2i(center + 2, top), Color(0.9, 0.4, 0.1, 1.0))

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			if e.has_method("get_grid_pos"):
				var gp = e.get_grid_pos()
				if GridManager.get_entity_at(gp) == e:
					GridManager.unregister_entity(gp)
			e.queue_free()

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
	if event.is_action_pressed("pause_menu") and _game_state != GameState.GAME_OVER:
		if _pause_menu and _pause_menu.visible:
			_pause_menu.hide_pause()
		elif _pause_menu:
			_pause_menu.show_pause()
		return
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
			KEY_M:
				if _game_state == GameState.MAP and roguelike_ui_shell != null:
					roguelike_ui_shell.toggle()
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
