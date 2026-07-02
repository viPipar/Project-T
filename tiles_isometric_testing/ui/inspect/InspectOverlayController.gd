class_name InspectOverlayController
extends Control

# These will be set by main.gd
var cursor_p1: Node2D
var cursor_p2: Node2D

var _inspect_p1: InspectWindow
var _inspect_p2: InspectWindow

var _left_side: Control
var _right_side: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# ── Left Side (P1) ──────────────────────────────────────────────
	_left_side = Control.new()
	_left_side.name = "LeftSide"
	_left_side.clip_contents = true
	_left_side.anchor_left = 0.0
	_left_side.anchor_right = 0.5
	_left_side.anchor_top = 0.0
	_left_side.anchor_bottom = 1.0
	_left_side.offset_right = -6.0
	_left_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_side)
	
	_inspect_p1 = InspectWindow.new()
	_inspect_p1.name = "InspectWindowP1"
	_left_side.add_child(_inspect_p1)
	
	# ── Right Side (P2) ─────────────────────────────────────────────
	_right_side = Control.new()
	_right_side.name = "RightSide"
	_right_side.clip_contents = true
	_right_side.anchor_left = 0.5
	_right_side.anchor_right = 1.0
	_right_side.anchor_top = 0.0
	_right_side.anchor_bottom = 1.0
	_right_side.offset_left = 6.0
	_right_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right_side)
	
	_inspect_p2 = InspectWindow.new()
	_inspect_p2.name = "InspectWindowP2"
	_right_side.add_child(_inspect_p2)


func _process(_delta: float) -> void:
	if InputManager != null:
		_handle_input(1, _inspect_p1, cursor_p1, _left_side)
		_handle_input(2, _inspect_p2, cursor_p2, _right_side)


func _handle_input(player_id: int, window: InspectWindow, cursor: Node2D, side: Control) -> void:
	if not is_instance_valid(cursor): return
	
	# Toggle window on inspect button press
	if InputManager.has_method("is_inspect_pressed") and InputManager.is_inspect_pressed(player_id):
		if window._is_visible:
			window.hide_window()
		else:
			var hovered = cursor.get_hovered_tile()
			var entity = GridManager.get_entity_at(hovered)
			if entity != null:
				# Center in the player's half of the screen
				var center = Vector2(side.size.x / 2.0, side.size.y / 2.0)
				window.show_for_entity(entity, 0, center)
				if get_node_or_null("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_click")
