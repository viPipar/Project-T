extends Control

const FALLBACK_CONTENT_SIZE = Vector2(1280, 2050)
const EDGE_PADDING = 120.0
const NODE_SIZE = Vector2(82, 82)
const MAP_HEIGHT_RATIO = 1.4
const MIN_CONTENT_HEIGHT = 2050.0
const LANE_LEFT_RATIO = 0.16
const LANE_RIGHT_RATIO = 0.84
const SCROLL_START_SPEED = 150.0
const SCROLL_MAX_SPEED = 620.0
const SCROLL_ACCEL_SECONDS = 1.8
const BACKGROUND_PATH = "res://assets/roguelike/node_map/backgrounds/swamp_path_22x33_map_public.jpg"
const BACKGROUND_SATURATION = 0.22
const BACKGROUND_DARKEN = 0.70
const MAP_SCREEN_PATH = "res://ui/roguelike/MapScreen.tscn"
const TRANSITION_SCENE_PATH = "res://ui/roguelike/RoguelikeTransition.tscn"
const LOADING_SCREEN_PATH = "res://ui/roguelike/RoguelikeLoadingScreen.tscn"
const ICON_PATHS = {
	0: "res://assets/roguelike/node_map/node_icons/battle.png",
	1: "res://assets/roguelike/node_map/node_icons/elite.png",
	2: "res://assets/roguelike/node_map/node_icons/last_boss.png",
	3: "res://assets/roguelike/node_map/node_icons/luck_event.png",
	4: "res://assets/roguelike/node_map/node_icons/rest.png",
	5: "res://assets/roguelike/node_map/node_icons/shop.png",
	6: "res://assets/roguelike/node_map/node_icons/loot.png",
}

@onready var view_p1: Control = $ViewP1
@onready var view_p2: Control = $ViewP2
@onready var map_content_p1: Control = $ViewP1/MapContentP1
@onready var map_content_p2: Control = $ViewP2/MapContentP2

var graph: NodeGraph
var path_handler: PathHandler
var content_size := FALLBACK_CONTENT_SIZE
var node_positions: Dictionary = {}
var node_buttons_p1: Dictionary = {}
var node_buttons_p2: Dictionary = {}
var path_renderer_p1: MapPathRenderer
var path_renderer_p2: MapPathRenderer
var fog_overlay_p1: MapFogOverlay
var fog_overlay_p2: MapFogOverlay
var selected_node_id: int = -1
var confirm_overlay: Control
var confirm_label: Label
var seed_label: Label
var is_confirming := false
var scroll_hold_seconds := 0.0
var scroll_hold_direction := 0.0
var _debug_grid_previous_visible := false
var _active_loading_screen: Control = null

func _ready() -> void:
	_hide_debug_grid()
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		content_size = FALLBACK_CONTENT_SIZE
	else:
		var content_height = maxf(maxf(viewport_size.y, viewport_size.x * MAP_HEIGHT_RATIO), MIN_CONTENT_HEIGHT)
		content_size = Vector2(viewport_size.x, content_height)

	if RunManager != null:
		RunManager.ensure_node_map()
		graph = RunManager.get_node_graph()
		path_handler = RunManager.get_path_handler()
	else:
		graph = NodeGraph.new()
		graph.generate()
		path_handler = PathHandler.new()
		path_handler.init(graph)

	node_positions = _calculate_node_positions()
	path_renderer_p1 = _build_map_view(map_content_p1, node_buttons_p1, true)
	path_renderer_p2 = _build_map_view(map_content_p2, node_buttons_p2, false)
	_setup_seed_label()
	_setup_confirm_modal()
	_scroll_to_start()
	_select_first_unlocked()
	if path_handler.current_node_id != -1 and selected_node_id != -1:
		_center_on_node(selected_node_id)
	_update_node_visuals()

func _exit_tree() -> void:
	_restore_debug_grid()

func _process(delta: float) -> void:
	_update_scroll_hold(delta)

func _update_scroll_hold(delta: float) -> void:
	if is_confirming:
		_reset_scroll_hold()
		return

	var direction := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		direction += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction -= 1.0

	if direction == 0.0:
		_reset_scroll_hold()
		return

	if direction != scroll_hold_direction:
		scroll_hold_seconds = 0.0
		scroll_hold_direction = direction

	scroll_hold_seconds += delta
	var accel_ratio = clampf(scroll_hold_seconds / SCROLL_ACCEL_SECONDS, 0.0, 1.0)
	var eased_ratio = accel_ratio * accel_ratio
	var scroll_speed = lerpf(SCROLL_START_SPEED, SCROLL_MAX_SPEED, eased_ratio)
	_move_map(Vector2(0.0, direction * scroll_speed * delta))

func _reset_scroll_hold() -> void:
	scroll_hold_seconds = 0.0
	scroll_hold_direction = 0.0

func _hide_debug_grid() -> void:
	var debug_grid = get_node_or_null("/root/DebugGrid")
	if debug_grid != null:
		_debug_grid_previous_visible = debug_grid.visible
		debug_grid.visible = false

func _restore_debug_grid() -> void:
	var debug_grid = get_node_or_null("/root/DebugGrid")
	if debug_grid != null:
		debug_grid.visible = _debug_grid_previous_visible

func _calculate_node_positions() -> Dictionary:
	var positions := {}
	var y_step = (content_size.y - (EDGE_PADDING * 2.0)) / float(graph.layers.size() - 1)
	var left_x = content_size.x * LANE_LEFT_RATIO
	var right_x = content_size.x * LANE_RIGHT_RATIO
	var lane_step = (right_x - left_x) / 4.0

	for layer_index in range(graph.layers.size()):
		var layer = graph.layers[layer_index]
		var y = content_size.y - EDGE_PADDING - (y_step * layer_index)
		var lane_indices = _get_lane_indices_for_layer(layer, layer_index)
		for i in range(layer.size()):
			var lane_index = lane_indices[i]
			var x = left_x + (lane_step * lane_index)
			positions[layer[i].id] = Vector2(x, y)

	return positions

func _get_lane_indices_for_layer(layer: Array, layer_index: int) -> Array:
	if layer.size() <= 1:
		return [_get_single_node_lane(layer[0], layer_index)]
	if _layer_has_node_type(layer, NodeGraph.NodeType.EVENT) or _layer_has_node_type(layer, NodeGraph.NodeType.LOOT):
		return [0, 2, 4]

	match layer.size():
		2:
			return [1, 3]
		3:
			return [[0, 2, 4], [0, 1, 3], [1, 3, 4]][layer_index % 3]
		4:
			return [[0, 1, 3, 4], [0, 1, 2, 4], [0, 2, 3, 4]][layer_index % 3]
		_:
			return [0, 1, 2, 3, 4]

func _get_single_node_lane(node, layer_index: int) -> int:
	if node.type == NodeGraph.NodeType.BOSS or node.type == NodeGraph.NodeType.ELITE:
		return 2
	var fallback_lanes = [2, 1, 3, 0, 4]
	return fallback_lanes[layer_index % fallback_lanes.size()]

func _layer_has_node_type(layer: Array, node_type: NodeGraph.NodeType) -> bool:
	for node in layer:
		if node.type == node_type:
			return true
	return false

func _build_map_view(parent_content: Control, node_buttons: Dictionary, is_player_one_view: bool) -> MapPathRenderer:
	for child in parent_content.get_children():
		child.queue_free()

	parent_content.custom_minimum_size = content_size
	parent_content.size = content_size
	parent_content.position = Vector2.ZERO

	_add_background(parent_content)

	var path_renderer = MapPathRenderer.new()
	path_renderer.configure(content_size)
	parent_content.add_child(path_renderer)

	for layer in graph.layers:
		for map_node in layer:
			var button = _create_node_button(map_node)
			parent_content.add_child(button)
			node_buttons[map_node.id] = button

	var fog_overlay = MapFogOverlay.new()
	fog_overlay.configure(content_size)
	parent_content.add_child(fog_overlay)
	if is_player_one_view:
		fog_overlay_p1 = fog_overlay
	else:
		fog_overlay_p2 = fog_overlay

	parent_content.move_child(path_renderer, 1)
	return path_renderer

func _redraw_visible_connections(path_renderer: MapPathRenderer, visible_node_ids: Array[int]) -> void:
	if path_renderer == null:
		return
	path_renderer.clear_connections()

	for layer in graph.layers:
		for map_node in layer:
			if not map_node.id in visible_node_ids:
				continue
			var from_pos = node_positions[map_node.id]
			for next_id in map_node.next_nodes:
				if not node_positions.has(next_id) or not next_id in visible_node_ids:
					continue
				path_renderer.add_connection(from_pos, node_positions[next_id])

	path_renderer.redraw_connections()

func _add_background(parent_content: Control) -> void:
	var background = TextureRect.new()
	background.name = "Background"
	background.texture = load(BACKGROUND_PATH)
	background.custom_minimum_size = content_size
	background.size = content_size
	background.expand_mode = 1
	background.stretch_mode = 6
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.material = _get_background_material()
	background.modulate = Color(0.64, 0.64, 0.64, 1.0)
	parent_content.add_child(background)

func _get_background_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float saturation = 0.22;
uniform float darken = 0.70;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(vec3(gray), color.rgb, saturation) * darken;
	COLOR = color;
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("saturation", BACKGROUND_SATURATION)
	material.set_shader_parameter("darken", BACKGROUND_DARKEN)
	return material

func _create_node_button(map_node) -> Button:
	var button = Button.new()
	button.name = "Node_%02d_%s" % [map_node.depth, NodeGraph.NodeType.keys()[map_node.type]]
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	button.position = node_positions[map_node.id] - (NODE_SIZE * 0.5)
	button.pivot_offset = NODE_SIZE * 0.5
	button.tooltip_text = "Depth %d - %s" % [map_node.depth, NodeGraph.NodeType.keys()[map_node.type]]
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.text = ""
	button.icon = _get_icon_texture(map_node.type)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", int(NODE_SIZE.x - 4.0))
	button.add_theme_stylebox_override("normal", _get_node_stylebox(Color(0, 0, 0, 0.55)))
	button.add_theme_stylebox_override("hover", _get_node_stylebox(Color(1, 1, 1, 0.24)))
	button.add_theme_stylebox_override("pressed", _get_node_stylebox(Color(1, 0.78, 0.18, 0.32)))
	button.add_theme_stylebox_override("disabled", _get_node_stylebox(Color(0, 0, 0, 0.45)))
	return button

func _get_node_stylebox(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0, 0, 0, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 8
	style.shadow_offset = Vector2(3, 4)
	return style

func _setup_confirm_modal() -> void:
	confirm_overlay = Control.new()
	confirm_overlay.name = "ConfirmOverlay"
	confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_overlay.visible = false
	add_child(confirm_overlay)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.48)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_overlay.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 190)
	panel.add_theme_stylebox_override("panel", _get_node_stylebox(Color(0.04, 0.04, 0.04, 0.94)))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	confirm_label = Label.new()
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.add_theme_font_size_override("font_size", 24)
	confirm_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(confirm_label)

	var hint = Label.new()
	hint.text = "F: confirm    X: cancel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1.0, 0.82, 0.24))
	vbox.add_child(hint)

func _setup_seed_label() -> void:
	var panel = PanelContainer.new()
	panel.name = "SeedPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -310.0
	panel.offset_top = -48.0
	panel.offset_right = -18.0
	panel.offset_bottom = -16.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _get_seed_panel_stylebox())
	add_child(panel)

	seed_label = Label.new()
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_size_override("font_size", 16)
	seed_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 1.0))
	seed_label.text = "Seed: %d" % _get_current_seed_value()
	panel.add_child(seed_label)

func _get_seed_panel_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.58)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.78, 0.18, 0.82)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _get_current_seed_value() -> int:
	if RunManager != null:
		return RunManager.get_node_map_seed()
	if graph != null:
		return graph.seed_value
	return -1

func _get_icon_texture(node_type: NodeGraph.NodeType) -> Texture2D:
	var path = ICON_PATHS.get(node_type, "")
	if path == "":
		return null
	return load(path)

func _update_node_visuals() -> void:
	_ensure_selected_is_valid()
	var unlocked = path_handler.get_unlocked_nodes()
	var completed = path_handler.get_completed_nodes()
	var visible_node_ids = _get_visible_node_ids()
	var reveal_until_depth = _get_reveal_until_depth()

	for node_id in node_buttons_p1.keys():
		_apply_node_state(node_buttons_p1[node_id], node_id, unlocked, completed, visible_node_ids)
	for node_id in node_buttons_p2.keys():
		_apply_node_state(node_buttons_p2[node_id], node_id, unlocked, completed, visible_node_ids)

	_redraw_visible_connections(path_renderer_p1, visible_node_ids)
	_redraw_visible_connections(path_renderer_p2, visible_node_ids)
	_update_fog_overlay(fog_overlay_p1, reveal_until_depth)
	_update_fog_overlay(fog_overlay_p2, reveal_until_depth)

func _get_reveal_until_depth() -> int:
	var reveal_until_depth = 2
	if path_handler.current_node_id != -1:
		var current_node = graph.get_node_by_id(path_handler.current_node_id)
		if current_node != null:
			reveal_until_depth = current_node.depth + 2
	return mini(reveal_until_depth, graph.get_total_depth())

func _get_visible_node_ids() -> Array[int]:
	var reveal_until_depth = _get_reveal_until_depth()
	var visible_node_ids: Array[int] = []
	for layer in graph.layers:
		for node in layer:
			if node.depth <= reveal_until_depth:
				visible_node_ids.append(node.id)
	return visible_node_ids

func _update_fog_overlay(fog_overlay: MapFogOverlay, reveal_until_depth: int) -> void:
	if fog_overlay == null:
		return
	if reveal_until_depth >= graph.get_total_depth():
		fog_overlay.set_fog_start_y(0.0)
		return

	var visible_layer_index = reveal_until_depth - 1
	var hidden_layer_index = reveal_until_depth
	var visible_y = node_positions[graph.layers[visible_layer_index][0].id].y
	var hidden_y = node_positions[graph.layers[hidden_layer_index][0].id].y
	var layer_gap = visible_y - hidden_y
	var fog_boundary = hidden_y + minf(layer_gap * 0.22, NODE_SIZE.y * 0.35)
	fog_overlay.set_fog_start_y(fog_boundary)

func _apply_node_state(button: Button, node_id: int, unlocked: Array[int], completed: Array[int], visible_node_ids: Array[int]) -> void:
	button.visible = node_id in visible_node_ids
	if not button.visible:
		return

	button.disabled = false
	button.scale = Vector2.ONE

	if node_id in completed:
		button.modulate = Color(1.0, 0.18, 0.14, 1.0)
	elif node_id == path_handler.current_node_id:
		button.modulate = Color(1.0, 0.78, 0.18, 1.0)
	elif node_id == selected_node_id and node_id in unlocked:
		button.modulate = Color(0.38, 0.96, 1.0, 1.0)
		button.scale = Vector2(1.18, 1.18)
	elif node_id in unlocked:
		button.modulate = Color.WHITE
	else:
		button.modulate = Color(0.18, 0.18, 0.18, 0.65)

func _ensure_selected_is_valid() -> void:
	var unlocked = path_handler.get_unlocked_nodes()
	if unlocked.is_empty():
		selected_node_id = -1
		return
	if not selected_node_id in unlocked:
		selected_node_id = unlocked[0]

func _select_first_unlocked() -> void:
	var unlocked = path_handler.get_unlocked_nodes()
	selected_node_id = unlocked[0] if not unlocked.is_empty() else -1

func _move_selection(direction: Vector2) -> void:
	var unlocked = path_handler.get_unlocked_nodes()
	if unlocked.is_empty():
		return
	if selected_node_id == -1 or not selected_node_id in unlocked:
		selected_node_id = unlocked[0]
		_update_node_visuals()
		return

	var current_pos = node_positions.get(selected_node_id, Vector2.ZERO)
	var best_id = -1
	var best_score = -999999.0
	for node_id in unlocked:
		if node_id == selected_node_id:
			continue
		var offset = node_positions[node_id] - current_pos
		if offset.length() <= 0.0:
			continue
		var normalized = offset.normalized()
		var dot = normalized.dot(direction)
		if dot <= 0.2:
			continue
		var score = (dot * 1000.0) - offset.length()
		if score > best_score:
			best_score = score
			best_id = node_id

	if best_id == -1:
		best_id = _cycle_selection(unlocked, direction)
	if best_id != -1:
		selected_node_id = best_id
		_center_on_node(selected_node_id)
		_update_node_visuals()

func _cycle_selection(unlocked: Array[int], direction: Vector2) -> int:
	if unlocked.size() <= 1:
		return selected_node_id

	var sorted = unlocked.duplicate()
	if abs(direction.x) >= abs(direction.y):
		sorted.sort_custom(func(a, b): return node_positions[a].x < node_positions[b].x)
	else:
		sorted.sort_custom(func(a, b): return node_positions[a].y < node_positions[b].y)

	var index = sorted.find(selected_node_id)
	if index == -1:
		return sorted[0]
	if direction.x > 0.0 or direction.y > 0.0:
		index = (index + 1) % sorted.size()
	else:
		index = (index - 1 + sorted.size()) % sorted.size()
	return sorted[index]

func _open_confirm_modal() -> void:
	if selected_node_id == -1:
		return
	var node = graph.get_node_by_id(selected_node_id)
	if node == null:
		return
	is_confirming = true
	confirm_label.text = "Choose Depth %d - %s?" % [node.depth, NodeGraph.NodeType.keys()[node.type]]
	confirm_overlay.visible = true

func _close_confirm_modal() -> void:
	is_confirming = false
	confirm_overlay.visible = false

func _confirm_selected_node() -> void:
	var node_id = selected_node_id
	_close_confirm_modal()
	if node_id == -1:
		return

	var traveled = false
	if RunManager != null:
		traveled = RunManager.travel_to_node(node_id)
		graph = RunManager.get_node_graph()
		path_handler = RunManager.get_path_handler()
	else:
		traveled = path_handler.travel_to(node_id)
	if not traveled:
		return

	var node = graph.get_node_by_id(node_id)
	if node == null:
		return

	if graph.is_final_node(node_id):
		print("[MapScreen] Final boss node reached. Double transition only for now.")
	else:
		print("[MapScreen] Node advanced to depth %d: %s. Double transition only for now." % [node.depth, NodeGraph.NodeType.keys()[node.type]])

	_select_first_unlocked()
	if selected_node_id != -1:
		_center_on_node(selected_node_id)
	_update_node_visuals()
	_play_map_return_transition()

func _play_map_return_transition() -> void:
	set_process(false)
	set_process_input(false)

	var shell = _find_roguelike_shell()
	if shell == null:
		_play_local_map_return_transition()
		return
	if shell.has_method("transition_to_map"):
		shell.transition_to_map()
	elif shell.has_method("show_screen_after_double_transition"):
		shell.show_screen_after_double_transition(MAP_SCREEN_PATH)
	elif shell.has_method("show_screen_with_transition"):
		shell.show_screen_with_transition(MAP_SCREEN_PATH)
	elif shell.has_method("show_screen"):
		shell.show_screen(MAP_SCREEN_PATH)

func _play_local_map_return_transition() -> void:
	var scene = load(TRANSITION_SCENE_PATH)
	if scene == null:
		set_process(true)
		set_process_input(true)
		return

	var transition = scene.instantiate()
	get_tree().root.add_child(transition)
	var show_loading := func() -> void:
		_show_local_loading_for_transition()
	var show_target := func() -> void:
		_show_local_map_after_transition()
	transition.play_loading_route(show_loading, show_target)

func _show_local_loading_for_transition() -> void:
	visible = false
	_clear_local_loading_screen()
	_active_loading_screen = _show_local_loading_screen()

func _show_local_map_after_transition() -> void:
	_clear_local_loading_screen()
	visible = true
	set_process(true)
	set_process_input(true)

func _clear_local_loading_screen() -> void:
	if is_instance_valid(_active_loading_screen):
		_active_loading_screen.queue_free()
	_active_loading_screen = null

func _show_local_loading_screen() -> Control:
	var scene = load(LOADING_SCREEN_PATH)
	if scene == null:
		return null
	var loading_screen = scene.instantiate() as Control
	if loading_screen == null:
		return null
	get_tree().root.add_child(loading_screen)
	return loading_screen

func _play_local_transition(midpoint_callback: Callable = Callable(), finished_callback: Callable = Callable()) -> void:
	var scene = load(TRANSITION_SCENE_PATH)
	if scene == null:
		if midpoint_callback.is_valid():
			midpoint_callback.call()
		if finished_callback.is_valid():
			finished_callback.call()
		return

	var transition = scene.instantiate()
	get_tree().root.add_child(transition)
	if finished_callback.is_valid():
		transition.finished.connect(finished_callback, CONNECT_ONE_SHOT)
	transition.play(midpoint_callback)

func _find_roguelike_shell():
	var current = get_parent()
	while current and current != get_tree().get_root():
		if current.has_method("show_screen"):
			return current
		current = current.get_parent()
	return null

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed:
		return

	var key = event.physical_keycode
	if is_confirming:
		if event.echo:
			return
		if key == KEY_F or key == KEY_ENTER:
			_confirm_selected_node()
		elif key == KEY_X or key == KEY_ESCAPE:
			_close_confirm_modal()
		return

	if event.echo:
		return

	match key:
		KEY_A:
			_move_selection(Vector2(-1, 0))
		KEY_D:
			_move_selection(Vector2(1, 0))
		KEY_F, KEY_ENTER:
			_open_confirm_modal()

func _move_map(delta: Vector2) -> void:
	map_content_p1.position += delta
	map_content_p2.position += delta
	_clamp_map_position()

func _scroll_to_start() -> void:
	var viewport_size = get_viewport_rect().size
	var start_y = min(0.0, viewport_size.y - content_size.y)
	map_content_p1.position = Vector2(0.0, start_y)
	map_content_p2.position = Vector2(0.0, start_y)

func _clamp_map_position() -> void:
	var viewport_size = get_viewport_rect().size
	var min_y = min(0.0, viewport_size.y - content_size.y)
	var max_y = 0.0
	map_content_p1.position.x = 0.0
	map_content_p2.position.x = 0.0
	map_content_p1.position.y = clampf(map_content_p1.position.y, min_y, max_y)
	map_content_p2.position.y = clampf(map_content_p2.position.y, min_y, max_y)

func _center_on_node(node_id: int) -> void:
	if not node_positions.has(node_id):
		return
	var viewport_size = get_viewport_rect().size
	var target_y = (viewport_size.y * 0.5) - node_positions[node_id].y
	_move_map(Vector2(0.0, target_y - map_content_p1.position.y))
