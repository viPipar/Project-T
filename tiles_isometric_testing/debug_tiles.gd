extends SceneTree

func _init() -> void:
	var path = "c:/Project-T/tiles_isometric_testing/debug_tiles_output.txt"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("Failed to open file: ", FileAccess.get_open_error())
		quit()
		return
		
	var map_scene = load("res://world/maps/Map_2.tscn")
	var map_node = map_scene.instantiate()
	var tilemap = map_node.get_node("TileMapLayer")
	
	file.store_line("CHECKING CELLS IN MAP 2")
	var used = tilemap.get_used_cells()
	file.store_line("TOTAL CELLS: " + str(used.size()))
	
	for p in [Vector2i(3,6), Vector2i(4,6), Vector2i(5,6), Vector2i(6,6), Vector2i(3,5), Vector2i(4,5), Vector2i(5,5), Vector2i(6,5)]:
		var data = tilemap.get_cell_tile_data(p)
		var s_id = tilemap.get_cell_source_id(p)
		var atlas_coords = tilemap.get_cell_atlas_coords(p)
		if data:
			var is_blocked = data.get_custom_data("Blocked")
			file.store_line("Cell " + str(p) + " -> Source: " + str(s_id) + ", Atlas: " + str(atlas_coords) + ", Blocked=" + str(is_blocked))
		else:
			file.store_line("Cell " + str(p) + " -> NO TILE DATA! (Source: " + str(s_id) + ")")

	file.close()
	quit()
