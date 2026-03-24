extends Node2D

@onready var world: Node2D = $World

func _ready() -> void:
	var player_scene := preload("res://entities/player/Player.tscn")
	var cursor_scene := preload("res://world/SelectionCursor.tscn")

	GridManager.load_walls_for_map(1) #manggil mapping
	
	var p1 = world.spawn_entity(player_scene, Vector2i(0, 0), {
		"player_id": 1, "char_name": "Aria"
	})
	p1.place_at(Vector2i(5, 7))

	var p2 = world.spawn_entity(player_scene, Vector2i(0, 0), {
		"player_id": 2, "char_name": "Kael"
	})
	p2.place_at(Vector2i(7, 7))

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
