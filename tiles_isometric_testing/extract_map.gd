extends SceneTree

func _init() -> void:
	print("Loading Main.tscn...")
	var main_scene = load("res://main/Main.tscn")
	var main_node = main_scene.instantiate()
	
	var world = main_node.get_node("World")
	var tilemap = world.get_node("TileMapLayer")
	
	# Create new Map root
	var map_root = Node2D.new()
	map_root.name = "MapLevel"
	map_root.set_script(load("res://world/maps/MapLevel.gd"))
	
	# Detach tilemap and attach to map_root
	world.remove_child(tilemap)
	map_root.add_child(tilemap)
	tilemap.owner = map_root
	
	# Pack and save
	var packed = PackedScene.new()
	packed.pack(map_root)
	
	DirAccess.make_dir_recursive_absolute("res://world/maps")
	
	var err = ResourceSaver.save(packed, "res://world/maps/Map_1.tscn")
	if err == OK:
		print("Successfully saved Map_1.tscn!")
	else:
		print("Error saving Map_1.tscn: ", err)
		
	# Clean up
	main_node.queue_free()
	map_root.queue_free()
	quit()
