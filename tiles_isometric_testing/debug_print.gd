@tool
extends SceneTree

func _init():
	push_warning("STARTING DEBUG PRINT")
	var map_scene = load("res://world/maps/Map_2.tscn")
	var map_node = map_scene.instantiate()
	var tilemap = map_node.get_node("TileMapLayer")
	
	var p = Vector2i(4, 6)
	var data = tilemap.get_cell_tile_data(p)
	var blocked = false
	if data:
		blocked = data.get_custom_data("Blocked")
	push_warning("BLOCKED STATUS AT (4, 6): " + str(blocked))
	
	quit()
