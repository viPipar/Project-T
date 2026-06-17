extends Control

@onready var map_content = $ScrollContainer/MapContent

var node_buttons: Dictionary = {}

func _ready() -> void:
	# Simulate Graph if empty
	var graph = NodeGraph.new()
	graph.generate()
	
	_draw_map(graph)

func _draw_map(graph: NodeGraph) -> void:
	var layer_height = 200
	var current_y = 1800 # Start from bottom
	
	for layer in graph.layers:
		var node_count = layer.size()
		var spacing_x = 1920 / (node_count + 1)
		
		for i in range(node_count):
			var map_node = layer[i]
			var btn = Button.new()
			
			btn.text = NodeGraph.NodeType.keys()[map_node.type]
			btn.custom_minimum_size = Vector2(100, 60)
			
			var center_x = spacing_x * (i + 1)
			btn.position = Vector2(center_x - 50, current_y)
			
			map_content.add_child(btn)
			node_buttons[map_node.id] = btn
			
			btn.pressed.connect(_on_node_clicked.bind(map_node.id))
			
		current_y -= layer_height
		
	# Draw lines
	_draw_connections(graph)

func _draw_connections(graph: NodeGraph) -> void:
	for layer in graph.layers:
		for map_node in layer:
			if not node_buttons.has(map_node.id): continue
			var btn_from = node_buttons[map_node.id]
			
			for next_id in map_node.next_nodes:
				if not node_buttons.has(next_id): continue
				var btn_to = node_buttons[next_id]
				
				var line = Line2D.new()
				line.width = 4
				line.default_color = Color(0.5, 0.5, 0.5, 0.5)
				line.add_point(btn_from.position + btn_from.custom_minimum_size / 2)
				line.add_point(btn_to.position + btn_to.custom_minimum_size / 2)
				
				map_content.add_child(line)
				# Push line behind buttons
				map_content.move_child(line, 0)

func _on_node_clicked(node_id: int) -> void:
	print("Clicked Node ID: ", node_id)
	# Here we would invoke PathHandler.travel_to(node_id)
