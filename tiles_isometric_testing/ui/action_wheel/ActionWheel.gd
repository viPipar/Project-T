extends Control

signal action_hovered(action_name: String, action_index: int, page_index: int, slot_index: int)
signal action_selected(action_name: String, action_index: int, page_index: int, slot_index: int)
signal page_changed(page_index: int, page_count: int)

const PAGE_SIZE := 4
const DEFAULT_SLOT_KEYS := ["W", "A", "S", "D"]
const SLOT_DIRECTIONS := ["UP", "LEFT", "DOWN", "RIGHT"]
const SLOT_DRAW_ORDER := [0, 3, 2, 1]
const LABEL_OFFSETS := [
	Vector2(0, -132),
	Vector2(-132, 0),
	Vector2(0, 132),
	Vector2(132, 0),
]

@export var actions: PackedStringArray = [
	"Move",
	"Attack",
	"Skill",
	"Guard",
	"Item",
	"Reload",
	"Scan",
	"Wait",
	"Test 8",
	"Test 9",
	"Test 10",
	"Test 11",
]
@export var title_text: String = "Action Wheel"
@export var subtitle_text: String = "WASD pilih arah, Q / E geser wheel"
@export var starts_visible: bool = true
@export var wraps_pages: bool = true
@export var blocks_game_input: bool = true
@export var player_id: int = 1
@export var slot_keys: PackedStringArray = ["W", "A", "S", "D"]
@export var hover_up_key: Key = KEY_W
@export var hover_left_key: Key = KEY_A
@export var hover_down_key: Key = KEY_S
@export var hover_right_key: Key = KEY_D
@export var previous_page_key: Key = KEY_Q
@export var next_page_key: Key = KEY_E

@export var _page_index: int = 0
@export var _hovered_slot: int = 0
@export var _center: Vector2 = Vector2.ZERO
@export var _outer_radius: float = 180.0
@export var _inner_radius: float = 56.0
@export var _hover_time: float = 0.0
@export var _transition_from_page: int = 0
@export var _slide_direction: int = 0
@export var _slide_progress: float = 1.0
var _slide_tween: Tween
@export var _key_state: Dictionary = {
	"w": false,
	"a": false,
	"s": false,
	"d": false,
	"q": false,
	"e": false,
	"enter": false,
	"space": false,
}
const PREVIEW_VISIBLE_RATIO := 0.25

@export var _title_label: Label
@export var _subtitle_label: Label
@export var _page_label: Label
@export var _hint_label: Label
@export var _slot_labels: Array[Label] = []
@export var _slot_key_labels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = starts_visible
	custom_minimum_size = Vector2(540, 430)
	_transition_from_page = _page_index
	_build_ui()
	_normalize_hovered_slot()
	_refresh()
	_sync_menu_state()


func _exit_tree() -> void:
	if blocks_game_input and is_instance_valid(InputManager):
		InputManager.is_in_menu = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center = size * 0.5 + Vector2(0, 18)
		_position_labels()
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_menu_state()
		if visible:
			_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	_hover_time += _delta

	if _consume_action("w", "p%d_move_up" % player_id, hover_up_key):
		_set_hovered_slot(0)
	if _consume_action("a", "p%d_move_left" % player_id, hover_left_key):
		_set_hovered_slot(1)
	if _consume_action("s", "p%d_move_down" % player_id, hover_down_key):
		_set_hovered_slot(2)
	if _consume_action("d", "p%d_move_right" % player_id, hover_right_key):
		_set_hovered_slot(3)
	if _consume_key("q", previous_page_key):
		_shift_page(-1)
	if _consume_key("e", next_page_key):
		_shift_page(1)
	if _consume_key("enter", KEY_ENTER) or _consume_key("space", KEY_SPACE):
		_emit_selected()

	queue_redraw()


func set_actions(new_actions: PackedStringArray) -> void:
	actions = new_actions
	_page_index = clampi(_page_index, 0, _get_page_count() - 1)
	_normalize_hovered_slot()
	_refresh()


func get_hovered_action() -> Dictionary:
	return _get_action_data(_hovered_slot)


func _build_ui() -> void:
	_title_label = _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_title_label.position = Vector2(0, 12)
	add_child(_title_label)

	_subtitle_label = _make_label(14, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle_label.modulate = Color(0.82, 0.86, 0.92, 0.88)
	_subtitle_label.position = Vector2(0, 44)
	add_child(_subtitle_label)

	_page_label = _make_label(15, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_page_label)

	_hint_label = _make_label(13, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.modulate = Color(0.82, 0.86, 0.92, 0.88)
	_hint_label.text = "Q/E pindah page | Enter/Space pilih action"
	add_child(_hint_label)

	for slot_index in range(PAGE_SIZE):
		var key_label := _make_label(14, HORIZONTAL_ALIGNMENT_CENTER)
		key_label.size = Vector2(92, 18)
		add_child(key_label)
		_slot_key_labels.append(key_label)

		var slot_label := _make_label(17, HORIZONTAL_ALIGNMENT_CENTER)
		slot_label.size = Vector2(132, 46)
		slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(slot_label)
		_slot_labels.append(slot_label)

	_center = size * 0.5 + Vector2(0, 18)
	_position_labels()


func _position_labels() -> void:
	if _title_label == null:
		return

	_title_label.size = Vector2(size.x, 32)
	_subtitle_label.size = Vector2(size.x, 24)
	_page_label.position = Vector2(0, size.y - 52)
	_page_label.size = Vector2(size.x, 22)
	_hint_label.position = Vector2(0, size.y - 28)
	_hint_label.size = Vector2(size.x, 20)

	for slot_index in range(PAGE_SIZE):
		var anchor: Vector2 = _center + LABEL_OFFSETS[slot_index]
		_slot_key_labels[slot_index].position = anchor + Vector2(-46, -28)
		_slot_labels[slot_index].position = anchor + Vector2(-66, -8)


func _refresh() -> void:
	if _title_label == null:
		return

	_title_label.text = title_text
	_subtitle_label.text = subtitle_text
	_page_label.text = "Wheel %d / %d" % [_page_index + 1, _get_page_count()]

	for slot_index in range(PAGE_SIZE):
		var action := _get_action_data(slot_index)
		var is_hovered := slot_index == _hovered_slot
		var has_action := action["valid"] as bool

		_slot_key_labels[slot_index].text = "%s  %s" % [_get_slot_key_label(slot_index), SLOT_DIRECTIONS[slot_index]]
		_slot_key_labels[slot_index].modulate = Color(0.12, 0.14, 0.19, 1.0) if is_hovered else Color(0.92, 0.95, 0.99, 0.94)
		_slot_labels[slot_index].text = action["name"] if has_action else "Empty"
		_slot_labels[slot_index].modulate = Color(0.12, 0.14, 0.19, 1.0) if is_hovered else (Color(1, 1, 1, 1) if has_action else Color(0.58, 0.63, 0.71, 0.92))

	queue_redraw()
	_emit_hovered()


func _draw() -> void:
	if _center == Vector2.ZERO:
		return

	var preview_spacing: float = _outer_radius * 2.0 - (_outer_radius * 2.0 * PREVIEW_VISIBLE_RATIO)

	if _is_transitioning():
		var from_center: Vector2 = _center + Vector2(-_slide_direction * _slide_progress * preview_spacing, 0)
		var to_center: Vector2 = _center + Vector2(_slide_direction * (1.0 - _slide_progress) * preview_spacing, 0)

		_draw_wheel(_get_preview_page(_page_index - 1), _center + Vector2(-preview_spacing, 0), 0.24, false, -1)
		_draw_wheel(_get_preview_page(_page_index + 1), _center + Vector2(preview_spacing, 0), 0.24, false, -1)
		_draw_wheel(_transition_from_page, from_center, 0.92, false, -1)
		_draw_wheel(_page_index, to_center, 1.0, true, _hovered_slot)
	else:
		_draw_wheel(_get_preview_page(_page_index - 1), _center + Vector2(-preview_spacing, 0), 0.30, false, -1)
		_draw_wheel(_get_preview_page(_page_index + 1), _center + Vector2(preview_spacing, 0), 0.30, false, -1)
		_draw_wheel(_page_index, _center, 1.0, true, _hovered_slot)


func _draw_wheel(page_index: int, wheel_center: Vector2, alpha: float, is_active: bool, hovered_slot: int) -> void:
	var rim_alpha: float = 0.76 * alpha
	draw_circle(wheel_center, _outer_radius + 20.0, Color(0.03, 0.05, 0.08, rim_alpha))
	draw_circle(wheel_center, _outer_radius, Color(0.08, 0.10, 0.14, 0.94 * alpha))

	for slot_index in range(PAGE_SIZE):
		var action := _get_action_data_for_page(page_index, slot_index)
		var has_action := action["valid"] as bool
		_draw_slice(
			wheel_center,
			slot_index,
			is_active and slot_index == hovered_slot,
			has_action,
			alpha
		)

	draw_circle(wheel_center, _inner_radius + 8.0, Color(0.95, 0.79, 0.37, 0.88 * alpha))
	draw_circle(wheel_center, _inner_radius, Color(0.10, 0.12, 0.18, 0.98 * alpha))

	var page_label := "PAGE"
	var page_value := str(page_index + 1)
	draw_string(get_theme_default_font(), wheel_center + Vector2(-22, -2), page_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.79, 0.83, 0.90, 0.92 * alpha))
	draw_string(get_theme_default_font(), wheel_center + Vector2(-9, 18), page_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.98, 0.94, 0.82, alpha))


func _draw_slice(wheel_center: Vector2, slot_index: int, is_hovered: bool, has_action: bool, alpha: float) -> void:
	var draw_slot_index: int = SLOT_DRAW_ORDER[slot_index]
	var start_angle := -PI * 0.75 + draw_slot_index * (PI * 0.5)
	var end_angle := start_angle + (PI * 0.5)
	var points := PackedVector2Array()
	var step_count := 18
	var hover_radius_offset: float = 0.0
	var hover_inner_offset: float = 0.0

	if is_hovered:
		hover_radius_offset = 6.0 + sin(_hover_time * 7.0) * 4.0
		hover_inner_offset = 2.0

	for step in range(step_count + 1):
		var t := float(step) / float(step_count)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(wheel_center + Vector2.RIGHT.rotated(angle) * (_outer_radius + hover_radius_offset))

	for step in range(step_count, -1, -1):
		var t := float(step) / float(step_count)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(wheel_center + Vector2.RIGHT.rotated(angle) * (_inner_radius - hover_inner_offset))

	var fill := Color(0.17, 0.22, 0.31, 0.95) if has_action else Color(0.11, 0.13, 0.17, 0.86)
	if is_hovered:
		fill = Color(0.97, 0.82, 0.38, 0.98)
	fill.a *= alpha
	draw_colored_polygon(points, fill)

	var border := Color(0.54, 0.67, 0.88, 0.84) if has_action else Color(0.28, 0.32, 0.39, 0.68)
	if is_hovered:
		border = Color(1.0, 0.97, 0.88, 1.0)
	border.a *= alpha
	draw_polyline(points, border, 2.0, true)


func _set_hovered_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= PAGE_SIZE:
		return
	_hovered_slot = slot_index
	_refresh()


func _shift_page(direction: int) -> void:
	var page_count := _get_page_count()
	if page_count <= 1:
		return

	var previous_page: int = _page_index
	_page_index += direction
	if wraps_pages:
		_page_index = posmod(_page_index, page_count)
	else:
		_page_index = clampi(_page_index, 0, page_count - 1)

	_start_slide(previous_page, direction)
	_normalize_hovered_slot()
	_refresh()
	page_changed.emit(_page_index, page_count)


func _normalize_hovered_slot() -> void:
	if _get_action_data(_hovered_slot)["valid"]:
		return

	for slot_index in range(PAGE_SIZE):
		if _get_action_data(slot_index)["valid"]:
			_hovered_slot = slot_index
			return

	_hovered_slot = 0


func _emit_hovered() -> void:
	var action := _get_action_data(_hovered_slot)
	if not (action["valid"] as bool):
		return
	action_hovered.emit(action["name"], action["action_index"], _page_index, _hovered_slot)


func _emit_selected() -> void:
	var action := _get_action_data(_hovered_slot)
	if not (action["valid"] as bool):
		return
	action_selected.emit(action["name"], action["action_index"], _page_index, _hovered_slot)


func _get_action_data(slot_index: int) -> Dictionary:
	return _get_action_data_for_page(_page_index, slot_index)


func _get_action_data_for_page(page_index: int, slot_index: int) -> Dictionary:
	var action_index := page_index * PAGE_SIZE + slot_index
	if action_index < 0 or action_index >= actions.size():
		return {
			"valid": false,
			"name": "",
			"action_index": -1,
		}

	return {
		"valid": true,
		"name": actions[action_index],
		"action_index": action_index,
	}


func _get_page_count() -> int:
	return maxi(1, int(ceil(float(actions.size()) / float(PAGE_SIZE))))


func _get_preview_page(page_index: int) -> int:
	if wraps_pages:
		return posmod(page_index, _get_page_count())
	return clampi(page_index, 0, _get_page_count() - 1)


func _is_transitioning() -> bool:
	return _slide_direction != 0 and _slide_progress < 1.0


func _start_slide(previous_page: int, direction: int) -> void:
	_transition_from_page = previous_page
	_slide_direction = direction
	_slide_progress = 0.0

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_SINE)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(self, "_slide_progress", 1.0, 0.22)
	_slide_tween.finished.connect(func() -> void:
		_slide_direction = 0
		_transition_from_page = _page_index
		queue_redraw()
	)


func _sync_menu_state() -> void:
	if not blocks_game_input:
		return
	if is_instance_valid(InputManager):
		InputManager.is_in_menu = visible


func _consume_key(name: String, keycode: Key) -> bool:
	var is_pressed := Input.is_physical_key_pressed(keycode) or Input.is_key_pressed(keycode)
	var was_pressed: bool = _key_state.get(name, false)
	_key_state[name] = is_pressed
	return is_pressed and not was_pressed


func _consume_action(name: String, action_name: String, fallback_keycode: Key) -> bool:
	var is_pressed := Input.is_action_pressed(action_name) or Input.is_physical_key_pressed(fallback_keycode) or Input.is_key_pressed(fallback_keycode)
	var was_pressed: bool = _key_state.get(name, false)
	_key_state[name] = is_pressed
	return is_pressed and not was_pressed


func _get_slot_key_label(slot_index: int) -> String:
	if slot_index >= 0 and slot_index < slot_keys.size():
		return slot_keys[slot_index]
	return DEFAULT_SLOT_KEYS[slot_index]


func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
