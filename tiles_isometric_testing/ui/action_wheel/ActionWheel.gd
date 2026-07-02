extends Control

signal action_hovered(action_name: String, action_index: int, page_index: int, slot_index: int)
signal action_selected(action_name: String, action_index: int, page_index: int, slot_index: int)
signal page_changed(page_index: int, page_count: int)

const PAGE_SIZE := 4
const DEFAULT_SLOT_KEYS := ["W", "A", "S", "D"]
const SLOT_DIRECTIONS := ["UP", "LEFT", "DOWN", "RIGHT"]
const SLOT_DRAW_ORDER := [0, 3, 2, 1]
const LABEL_OFFSETS = [
	Vector2(0, -200),
	Vector2(-200, 0),
	Vector2(0, 200),
	Vector2(200, 0),
]

@export var actions: PackedStringArray = []
var abilities: Array[BaseAbility] = []
var affordabilities: Array[bool] = []
@export var title_text: String = "Action Wheel"
@export var subtitle_text: String = "WASD arah, Double Tap/Hold A/D geser page, F confirm"
@export var starts_visible: bool = true
@export var wraps_pages: bool = true
@export var blocks_game_input: bool = true
@export var show_page_previews: bool = false
@export var player_id: int = 1
@export var slot_keys: PackedStringArray = ["W", "A", "S", "D"]
@export var hover_up_key: Key = KEY_W
@export var hover_left_key: Key = KEY_A
@export var hover_down_key: Key = KEY_S
@export var hover_right_key: Key = KEY_D
@export var previous_page_key: Key = KEY_Q
@export var next_page_key: Key = KEY_E
@export var confirm_key: Key = KEY_F

@export var _page_index: int = 0
@export var _hovered_slot: int = 0
@export var _center: Vector2 = Vector2.ZERO
@export var _outer_radius: float = 250.0
@export var _inner_radius: float = 130.0
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
	"confirm": false,
}
const PREVIEW_VISIBLE_RATIO := 0.25

var _last_tap_time_left: int = 0
var _last_tap_time_right: int = 0
const DOUBLE_TAP_THRESHOLD: int = 300 # milliseconds

var _hold_time_left: float = 0.0
var _hold_time_right: float = 0.0
const HOLD_DELAY: float = 0.4
const HOLD_INTERVAL: float = 0.25
var _last_synced_visible: bool = false

@export var _title_label: Label
@export var _subtitle_label: Label
var _tooltip_rtlabel: RichTextLabel


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
		InputManager.set_player_menu_blocked(player_id, false)
	if EventBus != null:
		EventBus.action_wheel_visibility_changed.emit(player_id, false)


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
		var now = Time.get_ticks_msec()
		if now - _last_tap_time_left < DOUBLE_TAP_THRESHOLD:
			_shift_page(-1)
			_last_tap_time_left = 0
		else:
			_set_hovered_slot(1)
			_last_tap_time_left = now
			
	if _key_state.get("a", false):
		_hold_time_left += _delta
		if _hold_time_left >= HOLD_DELAY:
			_shift_page(-1)
			_hold_time_left -= HOLD_INTERVAL
	else:
		_hold_time_left = 0.0
			
	if _consume_action("s", "p%d_move_down" % player_id, hover_down_key):
		_set_hovered_slot(2)
		
	if _consume_action("d", "p%d_move_right" % player_id, hover_right_key):
		var now = Time.get_ticks_msec()
		if now - _last_tap_time_right < DOUBLE_TAP_THRESHOLD:
			_shift_page(1)
			_last_tap_time_right = 0
		else:
			_set_hovered_slot(3)
			_last_tap_time_right = now
			
	if _key_state.get("d", false):
		_hold_time_right += _delta
		if _hold_time_right >= HOLD_DELAY:
			_shift_page(1)
			_hold_time_right -= HOLD_INTERVAL
	else:
		_hold_time_right = 0.0
			
	if _consume_key("confirm", confirm_key):
		_emit_selected()

	queue_redraw()


func set_abilities(new_abilities: Array[BaseAbility]) -> void:
	abilities = new_abilities
	affordabilities.resize(abilities.size())
	affordabilities.fill(true)
	_page_index = clampi(_page_index, 0, _get_page_count() - 1)
	_normalize_hovered_slot()
	_refresh()

func set_action_affordable(index: int, affordable: bool) -> void:
	if index >= 0 and index < affordabilities.size():
		if affordabilities[index] != affordable:
			affordabilities[index] = affordable
			queue_redraw()


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

	_tooltip_rtlabel = RichTextLabel.new()
	_tooltip_rtlabel.bbcode_enabled = true
	_tooltip_rtlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_rtlabel.scroll_active = false
	add_child(_tooltip_rtlabel)

	_center = size * 0.5 + Vector2(0, 18)
	_position_labels()


func _position_labels() -> void:
	if _title_label == null:
		return

	_title_label.size = Vector2(size.x, 32)
	_subtitle_label.size = Vector2(size.x, 24)
	
	if _tooltip_rtlabel != null:
		var tooltip_size = Vector2(260, 160)
		_tooltip_rtlabel.size = tooltip_size
		_tooltip_rtlabel.position = _center - Vector2(tooltip_size.x * 0.5, tooltip_size.y * 0.5)


func _refresh() -> void:
	if _title_label == null:
		return

	_title_label.text = title_text
	_subtitle_label.text = subtitle_text

	queue_redraw()
	_update_tooltip()
	_emit_hovered()

func _update_tooltip() -> void:
	if _tooltip_rtlabel == null: return
	
	var action = _get_action_data(_hovered_slot)
	if not action["valid"] or action.get("ability") == null:
		_tooltip_rtlabel.text = ""
		return
		
	var ability: BaseAbility = action["ability"]
	var text = "[center]"
	text += "[font_size=14][b]" + ability.ability_name + "[/b][/font_size]\n"
	
	if ability.damage_dice != "":
		var dice_parts = ability.damage_dice.to_lower().split("d")
		if dice_parts.size() == 2:
			var min_val = int(dice_parts[0])
			var max_val = int(dice_parts[0]) * int(dice_parts[1])
			if ability.is_heal:
				text += "[font_size=12][%s] %d-%d Heal[/font_size]\n" % [ability.damage_dice.to_upper(), min_val, max_val]
			else:
				text += "[font_size=12][%s] %d-%d %s[/font_size]\n" % [ability.damage_dice.to_upper(), min_val, max_val, ability.element_tag.capitalize()]
	
	if ability.ability_description != "":
		text += "[font_size=12]%s[/font_size]\n" % ability.ability_description
		
	var costs = []
	if ability.cost_action > 0: costs.append("[color=#80e633]%d Action[/color]" % ability.cost_action)
	if ability.cost_bonus_action > 0: costs.append("[color=#e6cc33]%d Bonus Action[/color]" % ability.cost_bonus_action)
	if ability.cost_mana > 0:
		if player_id == 1:
			costs.append("[color=#d93326]%d Charge[/color]" % ability.cost_mana)
		else:
			costs.append("[color=#3366e6]%d Spell Slot[/color]" % ability.cost_mana)
	
	if costs.size() > 0:
		text += "[font_size=12]{%s}[/font_size]" % " + ".join(costs)
		
	text += "[/center]"
	_tooltip_rtlabel.text = text
	
	# Perfectly center the tooltip vertically based on the actual height of the text
	_tooltip_rtlabel.position.y = _center.y - (_tooltip_rtlabel.get_content_height() * 0.5)


func _draw() -> void:
	if _center == Vector2.ZERO:
		return

	var preview_spacing: float = _outer_radius * 2.0 - (_outer_radius * 2.0 * PREVIEW_VISIBLE_RATIO)

	if _is_transitioning():
		var offset_x: float = -_slide_direction * _slide_progress * preview_spacing
		
		var old_main_pos: Vector2 = _center + Vector2(offset_x, 0)
		var old_main_alpha: float = lerp(1.0, 0.30, _slide_progress)
		
		var new_main_start_x: float = _slide_direction * preview_spacing
		var new_main_pos: Vector2 = _center + Vector2(new_main_start_x + offset_x, 0)
		var new_main_alpha: float = lerp(0.30, 1.0, _slide_progress)
		
		if show_page_previews:
			var outgoing_preview_start_x: float = -_slide_direction * preview_spacing
			var outgoing_preview_pos: Vector2 = _center + Vector2(outgoing_preview_start_x + offset_x, 0)
			var outgoing_preview_alpha: float = lerp(0.30, 0.0, _slide_progress)

			var incoming_preview_start_x: float = _slide_direction * preview_spacing * 2.0
			var incoming_preview_pos: Vector2 = _center + Vector2(incoming_preview_start_x + offset_x, 0)
			var incoming_preview_alpha: float = lerp(0.0, 0.30, _slide_progress)

			_draw_wheel(_get_preview_page(_transition_from_page - _slide_direction), outgoing_preview_pos, outgoing_preview_alpha, false, -1)
			_draw_wheel(_get_preview_page(_page_index + _slide_direction), incoming_preview_pos, incoming_preview_alpha, false, -1)
		_draw_wheel(_transition_from_page, old_main_pos, old_main_alpha, false, -1)
		_draw_wheel(_page_index, new_main_pos, new_main_alpha, true, _hovered_slot)
	else:
		if show_page_previews:
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
		var is_affordable := action.get("affordable", true) as bool
		_draw_slice(
			wheel_center,
			slot_index,
			is_active and slot_index == hovered_slot,
			has_action,
			is_affordable,
			alpha
		)

	draw_circle(wheel_center, _inner_radius + 8.0, Color(0.95, 0.79, 0.37, 0.88 * alpha))
	draw_circle(wheel_center, _inner_radius, Color(0.10, 0.12, 0.18, 0.98 * alpha))

	# Draw text for each slot
	var font := get_theme_default_font()
	for slot_index in range(PAGE_SIZE):
		var action := _get_action_data_for_page(page_index, slot_index)
		var has_action := action["valid"] as bool
		var is_hovered := is_active and slot_index == hovered_slot
		
		var is_affordable := action.get("affordable", true) as bool
		
		var anchor: Vector2 = wheel_center + LABEL_OFFSETS[slot_index]
		
		var key_text := "%s  %s" % [_get_slot_key_label(slot_index), SLOT_DIRECTIONS[slot_index]]
		var key_color := Color(0.12, 0.14, 0.19, alpha) if is_hovered else Color(0.92, 0.95, 0.99, 0.94 * alpha)
		if not is_affordable: key_color.a *= 0.5
		draw_string(font, anchor + Vector2(-46, -14), key_text, HORIZONTAL_ALIGNMENT_CENTER, 92, 14, key_color)
		
		var has_icon := false
		if has_action and action.get("ability") != null:
			var ability = action["ability"]
			if ability.get("icon") != null and ability.icon is Texture2D:
				has_icon = true
				var icon_tex = ability.icon
				var icon_size = Vector2(80, 80)
				var icon_rect = Rect2(anchor - icon_size / 2.0 + Vector2(0, -10), icon_size)
				
				var icon_color = Color(1, 1, 1, alpha)
				if not is_affordable: icon_color = Color(0.4, 0.4, 0.4, alpha)
				draw_texture_rect(icon_tex, icon_rect, false, icon_color)
		
		if has_icon:
			var action_text := action["name"] as String
			var label_color := Color(0.12, 0.14, 0.19, alpha) if is_hovered else Color(1, 1, 1, alpha)
			if not is_affordable: label_color = Color(0.4, 0.4, 0.4, alpha)
			# Draw text slightly below the icon
			draw_multiline_string(font, anchor + Vector2(-66, 45), action_text, HORIZONTAL_ALIGNMENT_CENTER, 132, 17, -1, label_color)


func _draw_slice(wheel_center: Vector2, slot_index: int, is_hovered: bool, has_action: bool, is_affordable: bool, alpha: float) -> void:
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
	if not is_affordable:
		fill = fill.lerp(Color(0.1, 0.1, 0.1), 0.6)
	fill.a *= alpha
	draw_colored_polygon(points, fill)

	# Create a closed loop of points for a clean outline and glow
	var closed_points = PackedVector2Array(points)
	if points.size() > 0:
		closed_points.append(points[0])

	# Glow effect for hovered slice
	if is_hovered:
		var pulse = sin(_hover_time * 6.0) * 0.5 + 0.5
		var base_glow_opacity = 0.08 + pulse * 0.06
		var glow_color := Color(1.0, 0.85, 0.4, base_glow_opacity * alpha)
		for w in range(1, 6):
			var width = 2.0 + w * (3.0 + pulse * 2.0)
			draw_polyline(closed_points, glow_color, width, true)

	var border := Color(0.54, 0.67, 0.88, 0.84) if has_action else Color(0.28, 0.32, 0.39, 0.68)
	if is_hovered:
		border = Color(1.0, 0.97, 0.88, 1.0)
	border.a *= alpha
	draw_polyline(closed_points, border, 2.0, true)


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
	if not _can_player_select():
		visible = false
		return

	var action := _get_action_data(_hovered_slot)
	if not (action["valid"] as bool):
		return
	if not action.get("affordable", true):
		return
	action_selected.emit(action["name"], action["action_index"], _page_index, _hovered_slot)
	if EventBus != null:
		EventBus.action_wheel_selected.emit(player_id, action["name"])
		
	# Instantly close the wheel so the player can use the skill!
	visible = false


func _can_player_select() -> bool:
	if TurnManager != null and not TurnManager.can_player_act(player_id):
		return false

	for player in get_tree().get_nodes_in_group("players"):
		if player != null and player.get("player_id") == player_id:
			return not (player.has_method("is_downed") and player.is_downed())
	return true


func _get_action_data(slot_index: int) -> Dictionary:
	return _get_action_data_for_page(_page_index, slot_index)


func _get_action_data_for_page(page_index: int, slot_index: int) -> Dictionary:
	var action_index := page_index * PAGE_SIZE + slot_index
	if action_index < 0 or action_index >= abilities.size():
		return {
			"valid": false,
			"ability": null,
			"name": "",
			"action_index": -1,
		}

	var ability = abilities[action_index]
	var is_affordable = affordabilities[action_index] if action_index < affordabilities.size() else true
	return {
		"valid": true,
		"ability": ability,
		"name": ability.ability_name,
		"action_index": action_index,
		"affordable": is_affordable,
	}


func _get_page_count() -> int:
	return maxi(1, int(ceil(float(abilities.size()) / float(PAGE_SIZE))))


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
	var is_visible := is_visible_in_tree()
	if is_instance_valid(InputManager):
		InputManager.set_player_menu_blocked(player_id, is_visible)
	if is_visible != _last_synced_visible:
		_last_synced_visible = is_visible
		if EventBus != null:
			EventBus.action_wheel_visibility_changed.emit(player_id, is_visible)


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
