# combat_core/ui/CombatDiceOverlay.gd
# ── Combat dice overlay — clean, no emoji ────────────────────────────────────
class_name CombatDiceOverlay
extends CanvasLayer

signal sequence_finished

## 1 = kiri (P1), 2 = kanan (P2)
var player_id: int = 1
var _is_playing: bool = false

# ── UI Nodes ──────────────────────────────────────────────────────────────────
var _root        : Control
var _dim_bg      : ColorRect
var _dice_panel  : Control
var _dice_visual : Node2D
var _mod_label   : Label     # "+5"
var _total_label : Label     # "= 18"
var _title_label : Label     # "Fighter → Goblin"
var _vs_row      : Control   # container "18  vs  AC 14"
var _roll_disp   : Label     # "18"
var _vs_label    : Label     # "vs"
var _ac_disp     : Label     # "AC 14"
var _result_lbl  : Label     # "HIT" / "MISS" / "CRITICAL"

const PANEL_W := 300.0
const PANEL_H := 190.0
const PANEL_Y := 20.0


# ── LIFECYCLE ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()


# ── UI BUILDER ────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	if player_id == 1:
		_root.anchor_left  = 0.0
		_root.anchor_right = 0.5
	else:
		_root.anchor_left  = 0.5
		_root.anchor_right = 1.0
	_root.anchor_top    = 0.0
	_root.anchor_bottom = 1.0
	_root.offset_left   = 0
	_root.offset_right  = 0
	_root.offset_top    = 0
	_root.offset_bottom = 0

	# Dim strip — hanya di belakang panel
	_dim_bg = ColorRect.new()
	_dim_bg.color = Color(0, 0, 0, 0)
	_dim_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_dim_bg.offset_bottom = PANEL_H + PANEL_Y + 40
	_root.add_child(_dim_bg)

	# ── DicePanel ─────────────────────────────────────────────────────────────
	_dice_panel = Control.new()
	_dice_panel.size = Vector2(PANEL_W, PANEL_H)
	_root.add_child(_dice_panel)

	# Background gelap solid, tanpa border aneh
	var pbg := StyleBoxFlat.new()
	pbg.bg_color        = Color(0.06, 0.04, 0.14, 0.96)
	pbg.set_corner_radius_all(8)
	var pbg_panel := PanelContainer.new()
	pbg_panel.size = Vector2(PANEL_W, PANEL_H)
	pbg_panel.add_theme_stylebox_override("panel", pbg)
	_dice_panel.add_child(pbg_panel)

	# Aksen garis tipis di atas (bukan border kotak)
	var accent := ColorRect.new()
	accent.color = Color(0.55, 0.25, 0.95, 0.85)
	accent.size  = Vector2(PANEL_W, 2)
	accent.position = Vector2(0, 0)
	_dice_panel.add_child(accent)

	# DiceVisual — di kiri panel
	var dv_scene := load("res://components/dice/sandbox/DiceVisual.tscn") as PackedScene
	_dice_visual = dv_scene.instantiate() as Node2D
	_dice_visual.position = Vector2(72, PANEL_H * 0.52)
	_dice_panel.add_child(_dice_visual)

	# Title
	_title_label = _lbl("", 12, Color(0.65, 0.65, 0.85))
	_title_label.position = Vector2(8, 8)
	_title_label.size = Vector2(PANEL_W - 16, 20)
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dice_panel.add_child(_title_label)

	# Modifier label "+5"
	_mod_label = _lbl("+0", 28, Color(0.75, 0.95, 0.4))
	_mod_label.position = Vector2(148, 58)
	_mod_label.modulate.a = 0
	_dice_panel.add_child(_mod_label)

	# Total label "= 18"
	_total_label = _lbl("= ?", 34, Color(1.0, 1.0, 1.0))
	_total_label.position = Vector2(144, 102)
	_total_label.modulate.a = 0
	_dice_panel.add_child(_total_label)

	# ── VS Row (tidak pakai ColorRect ekstra, cukup label saja) ──────────────
	_vs_row = Control.new()
	_vs_row.size = Vector2(280, 50)
	_vs_row.modulate.a = 0
	_root.add_child(_vs_row)

	_roll_disp = _lbl("?", 36, Color(0.3, 1.0, 0.5))
	_roll_disp.position = Vector2(10, 6)
	_vs_row.add_child(_roll_disp)

	_vs_label = _lbl("vs", 18, Color(0.5, 0.5, 0.55))
	_vs_label.position = Vector2(80, 14)
	_vs_row.add_child(_vs_label)

	_ac_disp = _lbl("AC ?", 36, Color(0.9, 0.55, 0.2))
	_ac_disp.position = Vector2(122, 6)
	_vs_row.add_child(_ac_disp)

	# ── Result text ──────────────────────────────────────────────────────────
	_result_lbl = _lbl("", 52, Color.WHITE)
	_result_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result_lbl.offset_left   = -180
	_result_lbl.offset_right  = 180
	_result_lbl.offset_top    = -36
	_result_lbl.offset_bottom = 36
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_result_lbl.modulate.a = 0
	_root.add_child(_result_lbl)


func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


# ── PUBLIC API ────────────────────────────────────────────────────────────────

func play_attack_sequence(
	attacker    : Node,
	target      : Node,
	hit_result  : Dictionary,
	dmg_rolls   : Array,
	dmg_total   : int,
	dmg_formula : String
) -> void:
	if _is_playing:
		return
	_is_playing = true
	visible = true
	_reset_state()

	var vp_size   := _get_vp_size()
	var raw_d20   : int  = hit_result.get("raw_roll",  1)
	var total_hit : int  = hit_result.get("roll",       1)
	var threshold : int  = hit_result.get("threshold", 10)
	var is_hit    : bool = hit_result.get("hit",    false)
	var is_crit   : bool = hit_result.get("crit",   false)
	var modifier  : int  = total_hit - raw_d20

	var _att_raw: Variant = attacker.get("char_name")
	var _tgt_raw: Variant = target.get("enemy_name")
	var att_name: String = str(_att_raw) if _att_raw != null else attacker.name
	var tgt_name: String = str(_tgt_raw) if _tgt_raw != null else target.name
	_title_label.text = "%s  →  %s" % [att_name, tgt_name]

	# ── Phase 1: Slide panel masuk ─────────────────────────────────────────────
	var cx := (vp_size.x - PANEL_W) * 0.5
	_dice_panel.position = Vector2(_offscreen_x(vp_size, false), PANEL_Y)

	var tw_dim := create_tween()
	tw_dim.tween_property(_dim_bg, "color", Color(0, 0, 0, 0.5), 0.4)

	var tw_in := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw_in.tween_property(_dice_panel, "position:x", cx, 0.5)
	await tw_in.finished

	var target_pos := _dice_panel.global_position + Vector2(72, PANEL_H * 0.52)

	# ── Phase 2: Roll D20 (animasi diperlambat) ─────────────────────────────
	if _dice_visual.has_method("start_roll"):
		_dice_visual.start_roll(raw_d20, "d20", 2.5, target_pos, player_id)
		if _dice_visual.has_signal("roll_finished"):
			await _dice_visual.roll_finished
		else:
			await get_tree().create_timer(2.6).timeout
	else:
		await get_tree().create_timer(1.2).timeout

	# ── Phase 3: Modifier muncul (lebih smooth, lebih lambat) ──────────────
	_mod_label.text = "+%d" % modifier if modifier >= 0 else str(modifier)
	var tw_mod := create_tween().set_ease(Tween.EASE_OUT)
	tw_mod.tween_property(_mod_label, "modulate:a", 1.0, 0.45)
	tw_mod.parallel().tween_property(_mod_label, "scale", Vector2(1.15, 1.15), 0.2)
	tw_mod.tween_property(_mod_label, "scale", Vector2(1.0, 1.0), 0.25)
	await get_tree().create_timer(0.7).timeout

	# ── Phase 4: Total muncul ─────────────────────────────────────────────────
	_total_label.text = "= %d" % total_hit
	var tw_tot := create_tween().set_ease(Tween.EASE_OUT)
	tw_tot.tween_property(_total_label, "modulate:a", 1.0, 0.4)
	tw_tot.parallel().tween_property(_mod_label, "modulate:a", 0.0, 0.35)
	await get_tree().create_timer(0.6).timeout

	# ── Phase 5: VS row slide masuk ───────────────────────────────────────────
	_roll_disp.text = str(total_hit)
	_ac_disp.text   = "AC %d" % threshold
	var acy := PANEL_Y + PANEL_H * 0.5 - 25.0
	_vs_row.position = Vector2(_offscreen_x(vp_size, true), acy)
	_vs_row.modulate.a = 1.0

	var vcx := (vp_size.x - 280.0) * 0.5
	var tw_vs := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw_vs.tween_property(_vs_row, "position:x", vcx, 0.45)
	await tw_vs.finished
	await get_tree().create_timer(0.45).timeout

	# ── Phase 6: Result text ──────────────────────────────────────────────────
	var col    : Color
	var result : String
	if is_crit:
		col    = Color(1.0, 0.88, 0.1)
		result = "CRITICAL"
		_roll_disp.add_theme_color_override("font_color", col)
	elif is_hit:
		col    = Color(0.25, 1.0, 0.45)
		result = "HIT"
		_roll_disp.add_theme_color_override("font_color", col)
	else:
		col    = Color(0.85, 0.25, 0.25)
		result = "MISS"
		_ac_disp.add_theme_color_override("font_color", col)

	_result_lbl.text = result
	_result_lbl.add_theme_color_override("font_color", col)
	var tw_res := create_tween().set_ease(Tween.EASE_OUT)
	tw_res.tween_property(_result_lbl, "modulate:a", 1.0, 0.35)
	tw_res.parallel().tween_property(_result_lbl, "scale", Vector2(1.2, 1.2), 0.25)
	tw_res.tween_property(_result_lbl, "scale", Vector2(1.0, 1.0), 0.3)
	await get_tree().create_timer(1.4).timeout

	# ── Phase 7: Damage roll ─────────────────────────────────────────────────
	if is_hit and dmg_rolls.size() > 0:
		var tw_hide := create_tween().set_ease(Tween.EASE_IN)
		tw_hide.tween_property(_vs_row,      "modulate:a", 0.0, 0.3)
		tw_hide.parallel().tween_property(_result_lbl, "modulate:a", 0.0, 0.3)
		_mod_label.modulate.a   = 0
		_total_label.modulate.a = 0
		await get_tree().create_timer(0.35).timeout

		for i in range(dmg_rolls.size()):
			_title_label.text = "Damage %d/%d  —  %s" % [i + 1, dmg_rolls.size(), dmg_formula]
			if _dice_visual.has_method("start_roll"):
				_dice_visual.start_roll(dmg_rolls[i], _formula_dice(dmg_formula), 2.0, target_pos, player_id)
				if _dice_visual.has_signal("roll_finished"):
					await _dice_visual.roll_finished
				else:
					await get_tree().create_timer(2.1).timeout
			await get_tree().create_timer(0.4).timeout

		_total_label.text = "%d damage" % dmg_total
		_total_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.2))
		var tw_dmg := create_tween().set_ease(Tween.EASE_OUT)
		tw_dmg.tween_property(_total_label, "modulate:a", 1.0, 0.4)
		await get_tree().create_timer(1.8).timeout

	# ── Phase 8: Slide keluar ─────────────────────────────────────────────────
	var vp2    := _get_vp_size()
	var tw_out := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw_out.tween_property(_dice_panel,  "position:x",  _offscreen_x(vp2, false), 0.45)
	tw_out.parallel().tween_property(_dim_bg,       "color",       Color(0, 0, 0, 0),    0.4)
	tw_out.parallel().tween_property(_vs_row,       "modulate:a",  0.0,                  0.3)
	tw_out.parallel().tween_property(_result_lbl,   "modulate:a",  0.0,                  0.3)
	tw_out.parallel().tween_property(_total_label,  "modulate:a",  0.0,                  0.3)
	await tw_out.finished

	visible = false
	_is_playing = false
	sequence_finished.emit()


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _get_vp_size() -> Vector2:
	if _root != null:
		return _root.size
	var s := get_viewport().get_visible_rect().size
	return s if s != Vector2.ZERO else Vector2(640, 720)


func _offscreen_x(vp_size: Vector2, opposite: bool) -> float:
	var from_left := (player_id == 1) != opposite
	return -PANEL_W - 40.0 if from_left else vp_size.x + 40.0


func _reset_state() -> void:
	if _dice_visual != null and _dice_visual.has_node("DiceSprite"):
		_dice_visual.get_node("DiceSprite").visible = false
	if _dice_visual != null and _dice_visual.has_node("NumberLabel"):
		_dice_visual.get_node("NumberLabel").visible = false
	_mod_label.modulate.a   = 0
	_total_label.modulate.a = 0
	_result_lbl.modulate.a  = 0
	_result_lbl.scale       = Vector2.ONE
	_vs_row.modulate.a      = 0
	_total_label.remove_theme_color_override("font_color")
	_roll_disp.remove_theme_color_override("font_color")
	_ac_disp.remove_theme_color_override("font_color")


func _formula_dice(formula: String) -> String:
	var low := formula.to_lower()
	var idx := low.find("d")
	return "d" + low.substr(idx + 1) if idx >= 0 else "d6"
