@tool
extends SceneTree

func _init():
	var file = FileAccess.open("c:/Project-T/tiles_isometric_testing/walls_dump.txt", FileAccess.WRITE)
	if file == null:
		quit()
		return
	
	file.store_line("Starting walls dump...")
	var map_scene = load("res://world/maps/Map_2.tscn")
	var map_node = map_scene.instantiate()
	var tilemap = map_node.get_node("TileMapLayer")
	
	var walls: Array[Vector2i] = []
	var used_cells = tilemap.get_used_cells()
	
	for pos in used_cells:
		var tile_data = tilemap.get_cell_tile_data(pos)
		if tile_data and tile_data.get_custom_data("Blocked") == true:
			walls.append(pos)
			file.store_line("Wall at: " + str(pos))
			
	file.store_line("Total walls: " + str(walls.size()))
	file.close()
	quit()
