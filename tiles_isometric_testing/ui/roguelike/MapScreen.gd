extends Control

@onready var view_p1 = $ViewP1
@onready var view_p2 = $ViewP2
@onready var map_content_p1 = $ViewP1/MapContentP1
@onready var map_content_p2 = $ViewP2/MapContentP2
@onready var separator = $Separator

var node_buttons_p1: Dictionary = {}
var node_buttons_p2: Dictionary = {}
var path_handler: PathHandler

func _ready() -> void:
	# Add a quick debug close button so we aren't trapped!
	var btn_close = Button.new()
	btn_close.text = "✖ Close Map"
	btn_close.add_theme_font_size_override("font_size", 24)
	btn_close.position = Vector2(20, 20)
	btn_close.pressed.connect(func():
		# Walk up the tree to find the shell, bypassing any dynamic renaming issues
		var current = get_parent()
		var found_shell = null
		while current and current != get_tree().get_root():
			if "RoguelikeUIShell" in current.name or current.has_method("show_screen"):
				found_shell = current
				break
			current = current.get_parent()
			
		if found_shell:
			found_shell.queue_free()
		else:
			queue_free()
			
		# Restore Debug Menu
		var debug_panel = get_tree().get_root().find_child("DebugPanel", true, false)
		if debug_panel:
			debug_panel.visible = true
	)
	add_child(btn_close)

	var graph = NodeGraph.new()
	graph.generate()
	
	path_handler = PathHandler.new()
	path_handler.init(graph)
	
	# Precalculate positions so both maps look identical
	var node_positions: Dictionary = {}
	var layer_height = 200
	var current_y = 1800
	for layer in graph.layers:
		var node_count = layer.size()
		var spacing_x = 1920 / (node_count + 1)
		var is_boss_layer = (layer[0].type == NodeGraph.NodeType.BOSS)
		
		for i in range(node_count):
			var center_x = spacing_x * (i + 1)
			var jitter_x = randf_range(-40.0, 40.0) if not is_boss_layer else 0.0
			var jitter_y = randf_range(-30.0, 30.0) if not is_boss_layer else 0.0
			node_positions[layer[i].id] = Vector2(center_x + jitter_x, current_y + jitter_y)
		current_y -= layer_height
		
	_generate_map_ui(map_content_p1, graph, node_positions, node_buttons_p1)
	_generate_map_ui(map_content_p2, graph, node_positions, node_buttons_p2)
	
	_update_node_visuals()

func _update_node_visuals() -> void:
	var unlocked = path_handler.get_unlocked_nodes()
	for dict in [node_buttons_p1, node_buttons_p2]:
		for node_id in dict:
			var btn = dict[node_id]
			if node_id in unlocked:
				btn.modulate.a = 1.0
				btn.disabled = false
			elif node_id == path_handler.current_node_id:
				btn.modulate.a = 0.8
				btn.disabled = true
			else:
				btn.modulate.a = 0.3
				btn.disabled = true

func _get_icon_for_type(type: NodeGraph.NodeType) -> String:
	match type:
		NodeGraph.NodeType.BATTLE: return "⚔️"
		NodeGraph.NodeType.ELITE: return "💀"
		NodeGraph.NodeType.BOSS: return "👹"
		NodeGraph.NodeType.REST: return "🔥"
		NodeGraph.NodeType.SHOP: return "💰"
		NodeGraph.NodeType.EVENT: return "❓"
		NodeGraph.NodeType.LOOT: return "🎁"
		_: return "?"

func _generate_map_ui(parent_content: Control, graph: NodeGraph, positions: Dictionary, dict: Dictionary) -> void:
	var path_renderer = MapPathRenderer.new()
	parent_content.add_child(path_renderer)
	
	for layer in graph.layers:
		for map_node in layer:
			var btn = Button.new()
			
			var type_name = NodeGraph.NodeType.keys()[map_node.type]
			btn.text = _get_icon_for_type(map_node.type)
			btn.tooltip_text = type_name
			
			btn.custom_minimum_size = Vector2(80, 80)
			btn.pivot_offset = btn.custom_minimum_size / 2.0
			
			var node_color = NeobrutalStyle.COLOR_CYAN
			match map_node.type:
				NodeGraph.NodeType.ELITE: node_color = NeobrutalStyle.COLOR_RED
				NodeGraph.NodeType.BOSS: node_color = NeobrutalStyle.COLOR_PURPLE
				NodeGraph.NodeType.SHOP: node_color = NeobrutalStyle.COLOR_YELLOW
				NodeGraph.NodeType.REST: node_color = NeobrutalStyle.COLOR_GREEN
				NodeGraph.NodeType.EVENT: node_color = NeobrutalStyle.COLOR_PINK
				NodeGraph.NodeType.LOOT: node_color = NeobrutalStyle.COLOR_YELLOW
				
			NeobrutalStyle.apply_to_button(btn, node_color)
			
			# Apply precalculated position (centered)
			var pos = positions[map_node.id]
			btn.position = Vector2(pos.x - (btn.custom_minimum_size.x / 2.0), pos.y)
			
			parent_content.add_child(btn)
			dict[map_node.id] = btn
			btn.pressed.connect(_on_node_clicked.bind(map_node.id, map_node.type))
			
	# Draw lines
	path_renderer.clear_connections()
	for layer in graph.layers:
		for map_node in layer:
			var btn_from = dict.get(map_node.id)
			if not btn_from: continue
			for next_id in map_node.next_nodes:
				var btn_to = dict.get(next_id)
				if not btn_to: continue
				
				var from_pos = btn_from.position + (btn_from.custom_minimum_size / 2)
				var to_pos = btn_to.position + (btn_to.custom_minimum_size / 2)
				path_renderer.add_connection(from_pos, to_pos)
	
	path_renderer.queue_redraw()
	parent_content.move_child(path_renderer, 0)

func _on_node_clicked(node_id: int, node_type: NodeGraph.NodeType) -> void:
	# TEMPORARY DEBUG CHEAT: Bypassing map path restrictions completely.
	# We force the path_handler to accept the teleport so you can test any node without holding SHIFT!
	path_handler.current_node_id = node_id
	
	print("[MapScreen] Traveled to Node ID: ", node_id)
	_update_node_visuals()
	
	if node_type in [NodeGraph.NodeType.BATTLE, NodeGraph.NodeType.ELITE, NodeGraph.NodeType.BOSS]:
		print("[MapScreen] Initiating combat for node type: ", node_type)
		# Freeze map screen
		set_process_input(false)
		set_process_unhandled_input(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Disable all buttons
		for dict in [node_buttons_p1, node_buttons_p2]:
			for key in dict:
				dict[key].disabled = true
				
		if EventBus != null:
			EventBus.start_combat.emit(node_type)
	else:
		print("[MapScreen] Node clicked: %s. (UI Switch Logic needed here)" % NodeGraph.NodeType.keys()[node_type])
		# TODO: Notify RoguelikeUIShell to switch screen based on node_type

# ── CAMERA / SCROLLING LOGIC ──────────────────────────────────────────────────

var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				_is_dragging = true
				_last_mouse_pos = event.global_position
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_map(60)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_map(-60)
			
	elif event is InputEventMouseMotion and _is_dragging:
		var drag_delta = event.global_position - _last_mouse_pos
		_scroll_map(drag_delta.y)
		_last_mouse_pos = event.global_position

func _scroll_map(amount: float) -> void:
	# Move the content containers so the nodes appear to scroll
	map_content_p1.position.y += amount
	map_content_p2.position.y += amount
