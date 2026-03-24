extends Node2D

@onready var world: Node2D = $World
	
func _ready() -> void:
	# Spawn 2 player di posisi berbeda
	var player_scene := preload("res://entities/player/Player.tscn")

	var p1 = world.spawn_entity(player_scene, Vector2i(0, 0), {
	"player_id": 1,
	"char_name": "Aria"
	})
	p1.place_at(Vector2i(5, 7))

	var p2 = world.spawn_entity(player_scene, Vector2i(7, 7), {
	"player_id": 2,
	"char_name": "Kael"
	})
	p2.place_at(Vector2i(7, 7))
