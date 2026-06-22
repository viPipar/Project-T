extends SceneTree

func _init():
	var file = FileAccess.open("res://debug_block.txt", FileAccess.WRITE)
	var map = load("res://world/maps/Map_2.tscn").instantiate()
	var tilemap = map.get_node("TileMapLayer")
	
	var used = tilemap.get_used_cells()
	file.store_line("TOTAL CELLS: " + str(used.size()))
	var blocked_count = 0
	for pos in used:
		var data = tilemap.get_cell_tile_data(pos)
		if data:
			var is_blocked = data.get_custom_data("Blocked")
			if is_blocked:
				blocked_count += 1
				file.store_line("Cell " + str(pos) + " is blocked!")
	
	file.store_line("TOTAL BLOCKED: " + str(blocked_count))
	file.close()
	quit()
