extends Node
class_name DualCursorUI

# Handles P1 and P2 independent UI cursors.

@export var cursor_p1: Control
@export var cursor_p2: Control
@export var root_container: Control

var selectable_nodes: Array[Control] = []
var p1_index: int = 0
var p2_index: int = 0

func _ready() -> void:
	# Scan for buttons or interactable UI elements
	_scan_for_selectables(root_container)
	_update_cursor_positions()

func _scan_for_selectables(node: Node) -> void:
	if node is Button:
		selectable_nodes.append(node)
	for child in node.get_children():
		_scan_for_selectables(child)

func _process(delta: float) -> void:
	if selectable_nodes.is_empty() or not owner.visible:
		return
		
	# Handle P1 Input
	if InputManager.is_just_pressed(1, "move_right") or InputManager.is_just_pressed(1, "move_down"):
		p1_index = (p1_index + 1) % selectable_nodes.size()
		_update_cursor_positions()
	elif InputManager.is_just_pressed(1, "move_left") or InputManager.is_just_pressed(1, "move_up"):
		p1_index = (p1_index - 1 + selectable_nodes.size()) % selectable_nodes.size()
		_update_cursor_positions()
		
	if InputManager.is_confirm_pressed(1):
		_press_node(1, p1_index)

	# Handle P2 Input
	if InputManager.is_just_pressed(2, "move_right") or InputManager.is_just_pressed(2, "move_down"):
		p2_index = (p2_index + 1) % selectable_nodes.size()
		_update_cursor_positions()
	elif InputManager.is_just_pressed(2, "move_left") or InputManager.is_just_pressed(2, "move_up"):
		p2_index = (p2_index - 1 + selectable_nodes.size()) % selectable_nodes.size()
		_update_cursor_positions()

	if InputManager.is_confirm_pressed(2):
		_press_node(2, p2_index)

func _update_cursor_positions() -> void:
	if selectable_nodes.is_empty(): return
	
	if cursor_p1:
		var target1 = selectable_nodes[p1_index]
		cursor_p1.global_position = target1.global_position - Vector2(10, 0)
		
	if cursor_p2:
		var target2 = selectable_nodes[p2_index]
		cursor_p2.global_position = target2.global_position + Vector2(target2.size.x + 10, 0)

func _press_node(player_id: int, index: int) -> void:
	if index < 0 or index >= selectable_nodes.size(): return
	var btn = selectable_nodes[index]
	if btn is Button:
		print("[DualCursorUI] Player %d clicked %s" % [player_id, btn.name])
		btn.pressed.emit()
