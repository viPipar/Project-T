@tool
extends SceneTree

func _init():
	print("STARTING DUMP")
	var path = "c:/Project-T/tiles_isometric_testing/debug_tiles_output.txt"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("FAILED TO OPEN FILE")
		quit()
		return
	
	file.store_line("Opened successfully!")
	var map_scene = load("res://world/maps/Map_2.tscn")
	var map_node = map_scene.instantiate()
	var tilemap = map_node.get_node("TileMapLayer")
	
	var used = tilemap.get_used_cells()
	file.store_line("TOTAL CELLS: " + str(used.size()))
	
	for p in [Vector2i(3,6), Vector2i(4,6), Vector2i(5,6), Vector2i(6,6), Vector2i(3,5), Vector2i(4,5), Vector2i(5,5), Vector2i(6,5)]:
		var s_id = tilemap.get_cell_source_id(p)
		var atlas_coords = tilemap.get_cell_atlas_coords(p)
		var data = tilemap.get_cell_tile_data(p)
		var blocked = false
		if data: blocked = data.get_custom_data("Blocked")
		print("Cell " + str(p) + " -> Blocked: " + str(blocked)); file.store_line("Cell " + str(p) + " -> Source: " + str(s_id) + ", Atlas: " + str(atlas_coords) + ", Blocked: " + str(blocked))
	
	file.flush()
	file.close()
	print("FINISHED DUMP")
	quit()
