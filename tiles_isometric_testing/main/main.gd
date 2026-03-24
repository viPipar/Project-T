extends Node2D

@onready var world: Node2D = $World

func _ready() -> void:
	var player_scene := preload("res://entities/player/Player.tscn")
	var cursor_scene := preload("res://world/SelectionCursor.tscn")

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
