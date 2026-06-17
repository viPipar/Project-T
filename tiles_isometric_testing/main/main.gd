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

var _show_debug_panel: bool = false
var _show_dice_sandbox: bool = false
var _show_debug_grid: bool = false

func _ready() -> void:
	var cursor_scene := preload("res://world/SelectionCursor.tscn")
	

	GridManager.load_walls_for_map(1) #manggil mapping
	
	var p1: Node = _spawn_player_from_json("aria", "Aria", 1, Vector2i(5, 7))
	var p2: Node = _spawn_player_from_json("kael", "Kael", 2, Vector2i(7, 7))

	TurnManager.register_player(p1)
	TurnManager.register_player(p2)

	var c1 = cursor_scene.instantiate()
	var c2 = cursor_scene.instantiate()
	world.entities.add_child(c1)
	world.entities.add_child(c2)
	c1.bind(p1)
	c2.bind(p2)

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

	# ── Spawn enemy placeholder untuk testing combat_core ─────────────────────
	_spawn_enemy_from_json("goblin", "Goblin", Vector2i(5, 5), Color(0.3, 0.9, 0.3, 1.0))
	_spawn_enemy_from_json("orc", "Orc", Vector2i(8, 5), Color(0.9, 0.4, 0.1, 1.0))

	# ── CombatTestBridge: hubungkan combat_core ke scene ini ──────────────────
	var bridge := Node.new()
	bridge.name = "CombatTestBridge"
	bridge.set_script(load("res://combat_core/tests/CombatTestBridge.gd"))
	add_child(bridge)

	TurnManager.start_battle()

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
