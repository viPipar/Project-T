extends SceneTree

func _init():
	var vp = SubViewport.new()
	var props = vp.get_property_list()
	var has_cull = false
	for p in props:
		if "cull" in p.name.to_lower() or "canvas_cull" in p.name.to_lower():
			print(p.name)
			has_cull = true
	if not has_cull:
		print("No cull property found on SubViewport")
		for p in props:
			if "layer" in p.name.to_lower() or "mask" in p.name.to_lower():
				print(p.name)
	var ci = Node2D.new()
	print("CanvasItem layer/mask:")
	for p in ci.get_property_list():
		if "layer" in p.name.to_lower() or "mask" in p.name.to_lower():
			print(p.name)
	quit()
