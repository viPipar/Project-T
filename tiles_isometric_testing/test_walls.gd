extends SceneTree

func _init() -> void:
	var map_scene = load("res://world/maps/Map_2.tscn")
	var map_node = map_scene.instantiate()
	var tilemap = map_node.get_node("TileMapLayer")
	var walls = []
	for pos in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(pos)
		if tile_data and tile_data.get_custom_data("Blocked") == true:
			walls.append(pos)
	print("FOUND WALLS: " + str(walls.size()))
	
	print("CHECKING ROCKS NEAR PLAYER:")
	for p in [Vector2i(3,5), Vector2i(4,5), Vector2i(5,5), Vector2i(4,6), Vector2i(5,6), Vector2i(6,6), Vector2i(4,7), Vector2i(5,7), Vector2i(6,7)]:
		var data = tilemap.get_cell_tile_data(p)
		var s_id = tilemap.get_cell_source_id(p)
		if data:
			print("Cell " + str(p) + " has tile (source: " + str(s_id) + "), Blocked = " + str(data.get_custom_data("Blocked")))
		else:
			print("Cell " + str(p) + " has NO tile_data (source: " + str(s_id) + ")")

	quit()
