extends Node
class_name DualCursorUI

@export var cursor_p1: Control
@export var cursor_p2: Control
@export var root_container: Control

var selectable_nodes: Array[Control] = []
var cursor_speed: float = 1200.0

var p1_map_pos: Vector2 = Vector2(150, 540 - 80)
var p2_map_pos: Vector2 = Vector2(150, 540 + 80)

var split_mode: bool = false
var split_factor: float = 0.0 # 0.0 = shared, 1.0 = split

var p1_hovered_node: Control = null
var p2_hovered_node: Control = null

func _ready() -> void:
	rescan()

func rescan() -> void:
	selectable_nodes.clear()
	if root_container:
		_scan_for_selectables(root_container)

func _scan_for_selectables(node: Node) -> void:
	if node is Button:
		selectable_nodes.append(node)
	for child in node.get_children():
		_scan_for_selectables(child)

func _process(delta: float) -> void:
	if not get_parent().visible:
		return
		
	var is_map_active = false
	var map_screen = null
	if root_container and root_container.get_child_count() > 0:
		map_screen = root_container.get_child(0)
		if map_screen.has_node("ViewP1"):
			is_map_active = true
			
	var screen_size = get_viewport().get_visible_rect().size
	var map_size = Vector2(2800, 1080)
			
	# Move P1
	if cursor_p1 and not InputManager.is_player_blocked(1):
		var dir1 := Vector2.ZERO
		var prefix1 := "p1_"
		if Input.is_action_pressed(prefix1 + "move_right"): dir1.x += 1.0
		if Input.is_action_pressed(prefix1 + "move_left"):  dir1.x -= 1.0
		if Input.is_action_pressed(prefix1 + "move_down"):  dir1.y += 1.0
		if Input.is_action_pressed(prefix1 + "move_up"):    dir1.y -= 1.0
		
		if dir1 != Vector2.ZERO:
			if is_map_active:
				p1_map_pos += dir1.normalized() * cursor_speed * delta
				p1_map_pos.x = clamp(p1_map_pos.x, 0, map_size.x)
				p1_map_pos.y = clamp(p1_map_pos.y, 0, map_size.y)
			else:
				cursor_p1.global_position += dir1.normalized() * cursor_speed * delta
				cursor_p1.global_position.x = clamp(cursor_p1.global_position.x, 0, screen_size.x)
				cursor_p1.global_position.y = clamp(cursor_p1.global_position.y, 0, screen_size.y)
				p1_map_pos = cursor_p1.global_position # sync for when returning to map
				
		if Input.is_action_just_pressed(prefix1 + "confirm"):
			_click_under_cursor(1, cursor_p1.global_position)

	# Move P2
	if cursor_p2 and not InputManager.is_player_blocked(2):
		var dir2 := Vector2.ZERO
		var prefix2 := "p2_"
		if Input.is_action_pressed(prefix2 + "move_right"): dir2.x += 1.0
		if Input.is_action_pressed(prefix2 + "move_left"):  dir2.x -= 1.0
		if Input.is_action_pressed(prefix2 + "move_down"):  dir2.y += 1.0
		if Input.is_action_pressed(prefix2 + "move_up"):    dir2.y -= 1.0
		
		if dir2 != Vector2.ZERO:
			if is_map_active:
				p2_map_pos += dir2.normalized() * cursor_speed * delta
				p2_map_pos.x = clamp(p2_map_pos.x, 0, map_size.x)
				p2_map_pos.y = clamp(p2_map_pos.y, 0, map_size.y)
			else:
				cursor_p2.global_position += dir2.normalized() * cursor_speed * delta
				cursor_p2.global_position.x = clamp(cursor_p2.global_position.x, 0, screen_size.x)
				cursor_p2.global_position.y = clamp(cursor_p2.global_position.y, 0, screen_size.y)
				p2_map_pos = cursor_p2.global_position
		
		if Input.is_action_just_pressed(prefix2 + "confirm"):
			_click_under_cursor(2, cursor_p2.global_position)

	# Check Split for Map
	if is_map_active:
		var dx = abs(p1_map_pos.x - p2_map_pos.x)
		var dy = abs(p1_map_pos.y - p2_map_pos.y)
		
		if not split_mode and (dx > 800 or dy > 400):
			split_mode = true
		elif split_mode and dx < 600 and dy < 300:
			split_mode = false
			
		split_factor = move_toward(split_factor, 1.0 if split_mode else 0.0, delta * 3.0)
		
		var view_p1 = map_screen.get_node_or_null("ViewP1")
		var view_p2 = map_screen.get_node_or_null("ViewP2")
		var map1 = map_screen.get_node_or_null("ViewP1/MapContentP1")
		var map2 = map_screen.get_node_or_null("ViewP2/MapContentP2")
		var sep = map_screen.get_node_or_null("Separator")
		
		if view_p1 and view_p2 and map1 and map2:
			var full_h = screen_size.y
			var split_h = screen_size.y / 2.0
			var current_v1_h = lerp(full_h, split_h, split_factor)
			var current_v2_h = lerp(0.0, split_h, split_factor)
			
			# Force anchors to top-left to prevent layout engine shifting viewports
			view_p1.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
			view_p2.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
			
			view_p1.position = Vector2(0, 0)
			view_p1.size = Vector2(screen_size.x, current_v1_h)
			
			view_p2.position = Vector2(0, full_h - current_v2_h)
			view_p2.size = Vector2(screen_size.x, current_v2_h)
			
			if sep:
				sep.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
				sep.visible = (split_factor > 0.01)
				sep.modulate.a = split_factor
				sep.size = Vector2(screen_size.x, 6)
				sep.position = Vector2(0, current_v1_h - 3)
				
			var center1 = Vector2(screen_size.x / 2.0, current_v1_h / 2.0)
			var center2 = Vector2(screen_size.x / 2.0, current_v2_h / 2.0)
			
			var shared_cam = (p1_map_pos + p2_map_pos) / 2.0
			var cam1 = shared_cam.lerp(p1_map_pos, split_factor)
			var cam2 = shared_cam.lerp(p2_map_pos, split_factor)
			
			cam1.x = clamp(cam1.x, center1.x, map_size.x - center1.x)
			cam1.y = clamp(cam1.y, center1.y, map_size.y - center1.y)
			
			if current_v2_h > 1.0:
				cam2.x = clamp(cam2.x, center2.x, map_size.x - center2.x)
				cam2.y = clamp(cam2.y, center2.y, map_size.y - center2.y)
			
			map1.position = center1 - cam1
			map2.position = center2 - cam2
			
			if cursor_p1:
				cursor_p1.global_position = view_p1.global_position + map1.position + p1_map_pos
			if cursor_p2:
				var screen_p2_shared = view_p1.global_position + map1.position + p2_map_pos
				var screen_p2_split = view_p2.global_position + map2.position + p2_map_pos
				cursor_p2.global_position = screen_p2_shared.lerp(screen_p2_split, split_factor)
	
	if cursor_p1: _update_hover(1, cursor_p1.global_position)
	if cursor_p2: _update_hover(2, cursor_p2.global_position)

func _update_hover(player_id: int, pos: Vector2) -> void:
	var found_node: Control = null
	for btn in selectable_nodes:
		if is_instance_valid(btn) and btn.is_visible_in_tree():
			if btn.get_global_rect().has_point(pos):
				found_node = btn
				break
				
	var current_hovered = p1_hovered_node if player_id == 1 else p2_hovered_node
	
	if current_hovered != found_node:
		if is_instance_valid(current_hovered):
			var other_hovered = p2_hovered_node if player_id == 1 else p1_hovered_node
			if other_hovered != current_hovered:
				_set_node_hover_state(current_hovered, false)
				
		if found_node:
			var other_hovered = p2_hovered_node if player_id == 1 else p1_hovered_node
			if other_hovered != found_node:
				_set_node_hover_state(found_node, true)
				var am = get_node_or_null("/root/AudioManager")
				if am != null: am.play_sfx("ui_hover")
			
		if player_id == 1:
			p1_hovered_node = found_node
		else:
			p2_hovered_node = found_node

func _set_node_hover_state(node: Control, is_hovered: bool) -> void:
	if not is_instance_valid(node): return
	var tween = create_tween()
	if is_hovered:
		tween.tween_property(node, "scale", Vector2(1.2, 1.2), 0.1)
		node.modulate = Color(1.2, 1.2, 1.2)
	else:
		tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1)
		node.modulate = Color(1.0, 1.0, 1.0)

func _click_under_cursor(player_id: int, pos: Vector2) -> void:
	for btn in selectable_nodes:
		if is_instance_valid(btn) and btn.is_visible_in_tree():
			if btn.get_global_rect().has_point(pos):
				print("[DualCursorUI] P%d clicked %s" % [player_id, btn.name])
				btn.set_meta("last_clicked_by_player", player_id)
				if btn is Button:
					if not btn.disabled:
						btn.pressed.emit()
				else:
					if btn.has_signal("pressed"):
						btn.emit_signal("pressed")
				return
