@tool
extends SceneTree

# Run this script to generate the UI scenes: godot --headless -s ui/roguelike/GenerateUI.gd

func _init() -> void:
	print("Generating UI Scenes...")
	
	_generate_shell()
	_generate_map()
	_generate_shop()
	_generate_event()
	
	print("UI Scenes generated successfully!")
	quit()

func _generate_shell() -> void:
	var shell = CanvasLayer.new()
	shell.name = "RoguelikeUIShell"
	shell.layer = 100 # Topmost
	
	var control = Control.new()
	control.name = "Container"
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(control)
	control.owner = shell
	
	var panel = ColorRect.new()
	panel.name = "Background"
	panel.color = Color(0, 0, 0, 0.8)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.add_child(panel)
	panel.owner = shell
	
	var title = Label.new()
	title.name = "Title"
	title.text = "ROGUELIKE MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	control.add_child(title)
	title.owner = shell
	
	_save_scene(shell, "RoguelikeUIShell.tscn")

func _generate_map() -> void:
	var map = Control.new()
	map.name = "MapScreen"
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.add_child(scroll)
	scroll.owner = map
	
	var content = Control.new()
	content.name = "MapContent"
	content.custom_minimum_size = Vector2(1920, 2000)
	scroll.add_child(content)
	content.owner = map
	
	_save_scene(map, "MapScreen.tscn")

func _generate_shop() -> void:
	var shop = Control.new()
	shop.name = "ShopScreen"
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var grid = GridContainer.new()
	grid.name = "ItemGrid"
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_CENTER)
	shop.add_child(grid)
	grid.owner = shop
	
	_save_scene(shop, "ShopScreen.tscn")

func _generate_event() -> void:
	var event = Control.new()
	event.name = "EventScreen"
	event.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var text = RichTextLabel.new()
	text.name = "NarrativeText"
	text.set_anchors_preset(Control.PRESET_CENTER_TOP)
	text.custom_minimum_size = Vector2(800, 300)
	event.add_child(text)
	text.owner = event
	
	_save_scene(event, "EventScreen.tscn")

func _save_scene(node: Node, filename: String) -> void:
	var packed = PackedScene.new()
	packed.pack(node)
	var path = "res://ui/roguelike/" + filename
	ResourceSaver.save(packed, path)
	print("Saved ", path)
	node.queue_free()
