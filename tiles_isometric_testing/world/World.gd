extends Node2D

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var entities: Node2D       = $Entities
@onready var camera: Camera2D       = $Camera2D

# Referensi ke semua player hidup — diisi oleh Main.gd saat spawn
var players: Array[Node] = []

func _ready() -> void:
	GridManager.setup_grid(16, 16)
	_draw_debug_grid()

func _process(delta: float) -> void:
	pass
			
func get_party_centroid() -> Vector2:
	if players.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in players:
		sum += p.position
	return sum / players.size()

# Spawn entity ke Entities node
func spawn_entity(scene: PackedScene, grid_pos: Vector2i, data := {}) -> Node:
	var entity = scene.instantiate()
	# 🔥 SET DATA SEBELUM add_child
	for key in data:
		entity.set(key, data[key])
	entities.add_child(entity)
	entity.position = IsoUtils.world_to_iso(grid_pos)
	entity.z_index  = IsoUtils.get_depth(grid_pos)
	GridManager.register_entity(grid_pos, entity)
	
	if entity.is_in_group("players"):
		players.append(entity)
	return entity

func despawn_entity(entity: Node) -> void:
	if entity.has_method("get_grid_pos"):
		GridManager.unregister_entity(entity.get_grid_pos())
	entity.queue_free()

# DEBUG: gambar outline tile grid saat development
func _draw_debug_grid() -> void:
	var debug := Node2D.new()
	debug.name = "DebugGrid"
	entities.add_child(debug)
	debug.set_script(load("res://world/DebugGrid.gd") if ResourceLoader.exists("res://world/DebugGrid.gd") else null)
