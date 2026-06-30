extends Node2D

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var entities: Node2D       = $Entities
# Camera2D bisa dihapus oleh SplitScreenManager — gunakan get_node_or_null di _ready()
var camera: Camera2D = null

# Referensi ke semua player hidup — diisi oleh Main.gd saat spawn
var players: Array[Node] = []
var _debug_grid: Node2D = null

func _ready() -> void:
	# Ambil Camera2D jika ada (single-camera mode). Null = split-screen mode aktif.
	camera = get_node_or_null("Camera2D")
	GridManager.setup_grid(16, 16)
	_draw_debug_grid()

func _process(_delta: float) -> void:
	# Kamera lama (single-camera mode) tidak dipakai saat split-screen aktif.
	# SplitScreenManager menghapus Camera2D dari scene — cek dulu sebelum pakai.
	if camera != null and is_instance_valid(camera) and camera.enabled:
		var target_pos = get_party_centroid()
		camera.position = camera.position.lerp(target_pos, 0.04)

func get_party_centroid() -> Vector2:
	if players.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in players:
		sum += p.position
	return sum / players.size()

func spawn_entity(scene: PackedScene, grid_pos: Vector2i, data := {}) -> Node:
	var entity = scene.instantiate()
	for key in data:
		entity.set(key, data[key])
	entities.add_child(entity)
	entity.position = IsoUtils.world_to_iso(grid_pos)
	entity.z_index  = IsoUtils.get_depth(grid_pos)
	GridManager.register_entity(grid_pos, entity)

	var tw = create_tween()
	tw.tween_property(entity, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(entity, "scale", Vector2.ONE, 0.2).set_delay(0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	if entity.is_in_group("players"):
		players.append(entity)
	return entity

func despawn_entity(entity: Node) -> void:
	if is_instance_valid(entity) and entity.has_method("get_grid_pos"):
		GridManager.unregister_entity(entity.get_grid_pos())
	entity.queue_free()

# DEBUG: gambar outline tile grid saat development
func _draw_debug_grid() -> void:
	var debug := Node2D.new()
	debug.name = "DebugGrid"
	entities.add_child(debug)
	debug.set_script(load("res://world/DebugGrid.gd") if ResourceLoader.exists("res://world/DebugGrid.gd") else null)
	_debug_grid = debug


func set_debug_grid_visible(is_visible: bool) -> void:
	if _debug_grid != null:
		_debug_grid.visible = is_visible
