# ui/hud/CombatHUDBar.gd
# ─────────────────────────────────────────────────────────────────────────────
# Combat HUD Bottom Bar (per-player)
# ─────────────────────────────────────────────────────────────────────────────
class_name CombatHUDBar
extends Control

@export var player_id: int = 1

# ── Manager references (bound via signal) ────────────────────────────────────
var _ap_mgr  : ActionPointManager    = null
var _mov_mgr : MovementPointManager  = null
var _ec_mgr  : EnergyChargeManager   = null  # P1 only
var _ss_mgr  : SpellSlotManager      = null  # P2 only

# ── Cached display values ────────────────────────────────────────────────────
var _ap:  int = 0
var _bap: int = 0
var _max_ap:  int = 0
var _max_bap: int = 0
var _mov_current: int = 0
var _mov_max:     int = 0
var _ec_current:  int = 0
var _ec_max:      int = 0
var _ss_current: Array[int] = [0, 0, 0, 0]
var _ss_max:     Array[int] = [0, 0, 0, 0]

# ── Animation state ──────────────────────────────────────────────────────────
var _pulse_timers: Dictionary = {}
const PULSE_DURATION := 0.45

var _blink_keys: Dictionary = {}
var _blink_phase: float = 0.0
var _action_wheel_visible: bool = false

# ── Layout constants ─────────────────────────────────────────────────────────
const LABEL_FONT_SIZE := 20
const SMALL_FONT_SIZE := 12

# ── Colors ───────────────────────────────────────────────────────────────────
var COLOR_PANEL_BG   := Color(0.85, 0.85, 0.85, 1.0)
var COLOR_BOX_BG     := Color(0.40, 0.40, 0.40, 1.0)
var COLOR_AP_GREEN   := Color(0.5, 0.9, 0.2, 1.0)
var COLOR_BAP_YELLOW := Color(0.9, 0.8, 0.2, 1.0)
var COLOR_MOV_BLACK  := Color(0.1, 0.1, 0.1, 1.0)
var COLOR_EC_RED     := Color(0.85, 0.2, 0.15, 1.0)
var COLOR_SS_BLUE    := Color(0.2, 0.4, 0.9, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.combat_hud_ready.connect(_on_combat_hud_ready)
	EventBus.inventory_toggled.connect(_on_inventory_toggled)
	
	if EventBus.has_signal("resource_blink_requested"):
		EventBus.resource_blink_requested.connect(_on_resource_blink_requested)
	if EventBus.has_signal("attackcam_started"):
		EventBus.attackcam_started.connect(func(_a, _b, _c): _blink_keys.clear())
	if EventBus.has_signal("action_wheel_visibility_changed"):
		EventBus.action_wheel_visibility_changed.connect(_on_action_wheel_visibility_changed)


func _on_combat_hud_ready(pid: int, ap_mgr: Node, mov_mgr: Node, resource_mgr: Node) -> void:
	if pid != player_id:
		return

	_ap_mgr = ap_mgr as ActionPointManager
	_mov_mgr = mov_mgr as MovementPointManager

	if resource_mgr is EnergyChargeManager:
		_ec_mgr = resource_mgr as EnergyChargeManager
	elif resource_mgr is SpellSlotManager:
		_ss_mgr = resource_mgr as SpellSlotManager

	if _ap_mgr != null:
		_ap_mgr.ap_changed.connect(_on_ap_changed)
		_ap_mgr.bap_changed.connect(_on_bap_changed)
		_ap = _ap_mgr.current_ap
		_max_ap = _ap_mgr.max_ap
		_bap = _ap_mgr.current_bap
		_max_bap = _ap_mgr.max_bap

	if _mov_mgr != null:
		_mov_mgr.movement_changed.connect(_on_mov_changed)
		_mov_current = _mov_mgr.current_tiles
		_mov_max = _mov_mgr.max_tiles

	if _ec_mgr != null:
		_ec_mgr.charge_changed.connect(_on_ec_changed)
		_ec_current = _ec_mgr.current_charges
		_ec_max = _ec_mgr.max_charges

	if _ss_mgr != null:
		_ss_mgr.slots_changed.connect(_on_ss_changed)
		for i in range(4):
			_ss_current[i] = _ss_mgr.current_slots[i]
			_ss_max[i] = _ss_mgr.max_slots[i]

	queue_redraw()


func _on_ap_changed(current: int, max_ap: int) -> void:
	if current != _ap: _start_pulse("ap")
	_ap = current; _max_ap = max_ap; queue_redraw()

func _on_bap_changed(current: int, max_bap: int) -> void:
	if current != _bap: _start_pulse("bap")
	_bap = current; _max_bap = max_bap; queue_redraw()

func _on_mov_changed(current: int, max_tiles: int) -> void:
	if current != _mov_current: _start_pulse("mov")
	_mov_current = current; _mov_max = max_tiles; queue_redraw()

func _on_ec_changed(current: int, max_charges: int) -> void:
	if current != _ec_current: _start_pulse("ec")
	_ec_current = current; _ec_max = max_charges; queue_redraw()

func _on_ss_changed(level: int, current: int, max_slots: int) -> void:
	var idx := level - 1
	if idx >= 0 and idx < 4:
		if current != _ss_current[idx]: _start_pulse("ss_%d" % level)
		_ss_current[idx] = current; _ss_max[idx] = max_slots
	queue_redraw()

func _on_inventory_toggled() -> void:
	if player_id == 1:
		print("inventory kebuka")


func _on_resource_blink_requested(pid: int, res_type: String) -> void:
	if pid != player_id: return
	match res_type:
		"stop_all":      _blink_keys.clear()
		"ap":            _blink_keys["ap"] = true
		"bap":           _blink_keys["bap"] = true
		"energy_charge": _blink_keys["ec"] = true
		"spell_slot":    _blink_keys["ss"] = true
		"movement":      _blink_keys["mov"] = true


func _on_action_wheel_visibility_changed(pid: int, is_visible: bool) -> void:
	if pid != player_id:
		return
	_action_wheel_visible = is_visible
	queue_redraw()


# ── Pulse animation ─────────────────────────────────────────────────────────

func _start_pulse(key: String) -> void:
	_pulse_timers[key] = PULSE_DURATION

func _get_pulse_alpha(key: String) -> float:
	if not _pulse_timers.has(key): return 0.0
	return clampf(_pulse_timers[key] / PULSE_DURATION, 0.0, 1.0)

func _process(delta: float) -> void:
	var any_active := false
	var keys_to_remove: Array[String] = []
	for key: String in _pulse_timers.keys():
		_pulse_timers[key] -= delta
		if _pulse_timers[key] <= 0.0:
			keys_to_remove.append(key)
		else:
			any_active = true
	for key: String in keys_to_remove:
		_pulse_timers.erase(key)
		
	_blink_phase = fmod(_blink_phase + delta * 4.0, TAU)
	
	if any_active or not keys_to_remove.is_empty() or not _blink_keys.is_empty():
		queue_redraw()


func _get_blink_alpha(key: String) -> float:
	if not _blink_keys.has(key): return 0.0
	return sin(_blink_phase) * 0.5 + 0.5


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var items = []
	items.append({"type": "ap", "width": 64})
	items.append({"type": "bap", "width": 64})
	items.append({"type": "mov", "width": 86})
	if _ec_mgr != null:
		items.append({"type": "ec", "width": 72})
	elif _ss_mgr != null:
		items.append({"type": "ss", "width": 72})
		
	var padding := 4.0
	var gap := 2.0
	var total_box_width := 0.0
	for item in items:
		total_box_width += item.width
		
	var panel_w := total_box_width + gap * (items.size() - 1) + padding * 2
	var panel_h := 38.0 + padding * 2
	
	var start_x := (size.x - panel_w) / 2.0
	var label_space := 8.0 if _action_wheel_visible else 45.0
	var start_y := size.y - panel_h - label_space
	
	var panel_rect := Rect2(start_x, start_y, panel_w, panel_h)
	draw_rect(panel_rect, COLOR_PANEL_BG)
	
	var cursor_x := start_x + padding
	var box_y := start_y + padding
	var box_h := 38.0
	
	for item in items:
		var box_rect := Rect2(cursor_x, box_y, item.width, box_h)
		draw_rect(box_rect, COLOR_BOX_BG)
		
		# Draw the content of the box
		match item.type:
			"ap": _draw_ap_box(box_rect)
			"bap": _draw_bap_box(box_rect)
			"mov": _draw_mov_box(box_rect)
			"ec": _draw_ec_box(box_rect)
			"ss": _draw_ss_box(box_rect)
			
		cursor_x += item.width + gap

func _draw_text_and_label(rect: Rect2, val_text: String, label_text: String, icon_w: float) -> void:
	var font := ThemeDB.fallback_font
	# Draw value inside box
	var val_size := font.get_string_size(val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var val_pos := Vector2(rect.position.x + icon_w + 4, rect.position.y + rect.size.y * 0.5 + val_size.y * 0.3)
	draw_string(font, val_pos, val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)
	
	if not _action_wheel_visible:
		var lbl_y := rect.position.y + rect.size.y + 12
		draw_multiline_string(font, Vector2(rect.position.x, lbl_y), label_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, SMALL_FONT_SIZE, -1, Color.BLACK)


func _draw_ap_box(rect: Rect2) -> void:
	var center := Vector2(rect.position.x + 18, rect.position.y + rect.size.y * 0.5)
	var r := 10.0
	var color := COLOR_AP_GREEN if _ap > 0 else Color(0.3, 0.3, 0.3)
	draw_circle(center, r, color)
	
	var pulse := _get_pulse_alpha("ap")
	if pulse > 0.0:
		draw_arc(center, r + 2, 0, TAU, 16, Color(color, pulse * 0.7), 2.0)
		
	var blink := _get_blink_alpha("ap")
	if blink > 0.01:
		draw_rect(rect, Color(color, blink * 0.8), false, 2.0)
		draw_rect(rect, Color(color, blink * 0.15), true)
		
	_draw_text_and_label(rect, str(_ap), "Action\nPoint", 30)


func _draw_bap_box(rect: Rect2) -> void:
	var center := Vector2(rect.position.x + 18, rect.position.y + rect.size.y * 0.5)
	var half := 10.0
	var color := COLOR_BAP_YELLOW if _bap > 0 else Color(0.3, 0.3, 0.3)
	
	var pts := PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(-half, half),
		center + Vector2(half, half),
	])
	draw_colored_polygon(pts, color)
	
	var pulse := _get_pulse_alpha("bap")
	if pulse > 0.0:
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(color, pulse * 0.7), 2.0)
		
	var blink := _get_blink_alpha("bap")
	if blink > 0.01:
		draw_rect(rect, Color(color, blink * 0.8), false, 2.0)
		draw_rect(rect, Color(color, blink * 0.15), true)
		
	_draw_text_and_label(rect, str(_bap), "Bonus\nAction\nPoint", 30)


func _draw_mov_box(rect: Rect2) -> void:
	var center := Vector2(rect.position.x + 18, rect.position.y + rect.size.y * 0.5)
	var half := 10.0
	var color := COLOR_MOV_BLACK if _mov_current > 0 else Color(0.3, 0.3, 0.3)
	
	var aw := 5.0
	var ah := 7.0
	# Arrow pointing UP
	draw_line(Vector2(center.x, center.y + half), Vector2(center.x, center.y - half + ah), color, 4.0)
	var head_pts := PackedVector2Array([
		Vector2(center.x, center.y - half),
		Vector2(center.x - aw, center.y - half + ah),
		Vector2(center.x + aw, center.y - half + ah),
	])
	draw_colored_polygon(head_pts, color)
	
	var pulse := _get_pulse_alpha("mov")
	if pulse > 0.0:
		draw_circle(center, half + 2, Color(1,1,1, pulse * 0.4))
		
	var blink := _get_blink_alpha("mov")
	if blink > 0.01:
		draw_rect(rect, Color(Color.WHITE, blink * 0.8), false, 2.0)
		draw_rect(rect, Color(Color.WHITE, blink * 0.15), true)
		
	var val_text := "%.1f" % (_mov_current * 5.0)
	_draw_text_and_label(rect, val_text, "Movement", 24)


func _draw_ec_box(rect: Rect2) -> void:
	var center := Vector2(rect.position.x + 18, rect.position.y + rect.size.y * 0.5)
	var half := 10.0
	var color := COLOR_EC_RED if _ec_current > 0 else Color(0.3, 0.3, 0.3)
	
	# Flame polygon
	var pts := PackedVector2Array([
		Vector2(center.x, center.y - half),
		Vector2(center.x - half*0.8, center.y + half*0.3),
		Vector2(center.x - half*0.4, center.y + half),
		Vector2(center.x + half*0.4, center.y + half),
		Vector2(center.x + half*0.8, center.y + half*0.3),
		Vector2(center.x + half*0.2, center.y - half*0.2), # inner dip
	])
	draw_colored_polygon(pts, color)
	
	var pulse := _get_pulse_alpha("ec")
	if pulse > 0.0:
		draw_circle(center, half + 2, Color(color, pulse * 0.5))
		
	var blink := _get_blink_alpha("ec")
	if blink > 0.01:
		draw_rect(rect, Color(color, blink * 0.8), false, 2.0)
		draw_rect(rect, Color(color, blink * 0.15), true)
		
	_draw_text_and_label(rect, str(_ec_current), "Energy\nCharge", 30)


func _draw_ss_box(rect: Rect2) -> void:
	var center := Vector2(rect.position.x + 18, rect.position.y + rect.size.y * 0.5)
	var half := 8.0
	
	# Count total slots for simplicity in the redesigned compact box
	var total_slots := 0
	for i in range(4):
		total_slots += _ss_current[i]
		
	var color := COLOR_SS_BLUE if total_slots > 0 else Color(0.3, 0.3, 0.3)
	
	# Blue squares stacked slightly
	draw_rect(Rect2(center.x - half, center.y - half, half*1.5, half*1.5), color)
	draw_rect(Rect2(center.x - half + 4, center.y - half + 4, half*1.5, half*1.5), Color(0.3, 0.5, 1.0))
	
	var blink := _get_blink_alpha("ss")
	if blink > 0.01:
		draw_rect(rect, Color(COLOR_SS_BLUE, blink * 0.8), false, 2.0)
		draw_rect(rect, Color(COLOR_SS_BLUE, blink * 0.15), true)
	
	_draw_text_and_label(rect, str(total_slots), "Spell\nSlots", 30)
