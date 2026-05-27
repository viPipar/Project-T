# combat_core/ui/CombatDiceOverlay.gd
# ── Cinematic dice overlay (half-screen, BG3-style) ───────────────────────────
# Tambahkan ke SubViewport P1/P2 agar otomatis hanya menutupi setengah layar.
#
# FLOW ANIMASI (hit/miss roll):
#   1. DicePanel slide dari sisi → atas tengah viewport
#   2. Dadu bergulir → berhenti di angka
#   3. "+modifier" muncul → merge ke "= total"
#   4. AC musuh slide dari sisi berlawanan
#   5. Tabrakan angka → winner dipertahankan (HIT/MISS/CRIT)
#   6. Damage roll (jika hit)
#   7. Slide keluar
# ──────────────────────────────────────────────────────────────────────────────
class_name CombatDiceOverlay
extends CanvasLayer

signal sequence_finished

## 1 = kiri (P1), 2 = kanan (P2)
var player_id: int = 1
var _is_playing: bool = false

# ── UI Nodes (dibangun di _ready) ─────────────────────────────────────────────
var _root       : Control
var _dim_bg     : ColorRect
var _dice_panel : Control        # panel geser masuk/keluar
var _dice_visual: Node2D         # DiceVisual.tscn
var _mod_label  : Label          # "+5"
var _total_label: Label          # "= 18"
var _title_label: Label          # "P1 → Goblin"
var _ac_row     : Control        # container "18 vs AC 14"
var _roll_disp  : Label          # "18"
var _vs_label   : Label          # "vs"
var _ac_disp    : Label          # "AC 14"
var _result_lbl : Label          # "HIT!" / "MISS!"

const PANEL_W := 300.0
const PANEL_H := 180.0
const PANEL_Y := 16.0           # jarak dari atas viewport


# ── LIFECYCLE ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()


# ── UI BUILDER ────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Root control menutupi setengah layar (kiri untuk P1, kanan untuk P2)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Set anchors berdasarkan player_id
	if player_id == 1:
		_root.anchor_left   = 0.0
		_root.anchor_right  = 0.5
	else:
		_root.anchor_left   = 0.5
		_root.anchor_right  = 1.0
	_root.anchor_top    = 0.0
	_root.anchor_bottom = 1.0

	# Reset offsets agar pas di anchor
	_root.offset_left   = 0
	_root.offset_right  = 0
	_root.offset_top    = 0
	_root.offset_bottom = 0

	# Dim strip di bagian atas
	_dim_bg = ColorRect.new()
	_dim_bg.color = Color(0, 0, 0, 0)
	_dim_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_dim_bg.offset_bottom = PANEL_H + PANEL_Y + 60
	_root.add_child(_dim_bg)

	# ── DicePanel ─────────────────────────────────────────────────────────────
	_dice_panel = Control.new()
	_dice_panel.size = Vector2(PANEL_W, PANEL_H)
	_root.add_child(_dice_panel)

	# Panel BG
	var pbg := ColorRect.new()
	pbg.color = Color(0.06, 0.04, 0.14, 0.93)
	pbg.size = Vector2(PANEL_W, PANEL_H)
	_dice_panel.add_child(pbg)

	# Border atas ungu
	var border := ColorRect.new()
	border.color = Color(0.55, 0.25, 0.95, 0.9)
	border.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	border.offset_bottom = 3
	_dice_panel.add_child(border)

	# DiceVisual — di kiri panel
	var dv_scene := load("res://components/dice/sandbox/DiceVisual.tscn") as PackedScene
	_dice_visual = dv_scene.instantiate() as Node2D
	_dice_visual.position = Vector2(72, PANEL_H * 0.52)
	_dice_panel.add_child(_dice_visual)

	# Title (nama attacker → target)
	_title_label = _lbl("", 13, Color(0.7, 0.7, 0.9))
	_title_label.position = Vector2(8, 8)
	_title_label.size = Vector2(PANEL_W - 16, 20)
	_dice_panel.add_child(_title_label)

	# Modifier label "+5"
	_mod_label = _lbl("+0", 30, Color(0.8, 0.95, 0.5))
	_mod_label.position = Vector2(142, 56)
	_mod_label.modulate.a = 0
	_dice_panel.add_child(_mod_label)

	# Total label "= 18"
	_total_label = _lbl("= ?", 36, Color(1.0, 1.0, 1.0))
	_total_label.position = Vector2(138, 100)
	_total_label.modulate.a = 0
	_dice_panel.add_child(_total_label)

	# ── AC Row ("18 vs AC 14") ─────────────────────────────────────────────────
	_ac_row = Control.new()
	_ac_row.size = Vector2(340, 60)
	_ac_row.modulate.a = 0
	_root.add_child(_ac_row)

	var ac_bg := ColorRect.new()
	ac_bg.color = Color(0.04, 0.04, 0.10, 0.88)
	ac_bg.size = Vector2(340, 60)
	_ac_row.add_child(ac_bg)

	_roll_disp = _lbl("?", 40, Color(0.3, 1.0, 0.5))
	_roll_disp.position = Vector2(12, 8)
	_ac_row.add_child(_roll_disp)

	_vs_label = _lbl("vs", 22, Color(0.6, 0.6, 0.6))
	_vs_label.position = Vector2(90, 16)
	_ac_row.add_child(_vs_label)

	_ac_disp = _lbl("AC ?", 40, Color(0.95, 0.5, 0.2))
	_ac_disp.position = Vector2(148, 8)
	_ac_row.add_child(_ac_disp)

	# ── Result banner ──────────────────────────────────────────────────────────
	_result_lbl = _lbl("", 56, Color.WHITE)
	_result_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result_lbl.offset_left   = -200
	_result_lbl.offset_right  = 200
	_result_lbl.offset_top    = -40
	_result_lbl.offset_bottom = 40
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_result_lbl.modulate.a = 0
	_root.add_child(_result_lbl)


func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


# ── PUBLIC API ────────────────────────────────────────────────────────────────

## Entry utama. Await-able sampai seluruh animasi selesai.
func play_attack_sequence(
	attacker       : Node,
	target         : Node,
	hit_result     : Dictionary,
	dmg_rolls      : Array,
	dmg_total      : int,
	dmg_formula    : String
) -> void:
	if _is_playing:
		return
	_is_playing = true
	visible = true
	_reset_state()

	var vp_size := _get_vp_size()
	var raw_d20  : int  = hit_result.get("raw_roll",  1)
	var total_hit: int  = hit_result.get("roll",       1)
	var threshold: int  = hit_result.get("threshold", 10)
	var is_hit   : bool = hit_result.get("hit",    false)
	var is_crit  : bool = hit_result.get("crit",   false)
	var modifier : int  = total_hit - raw_d20

	var att_name := str(attacker.get("char_name") if attacker.get("char_name") else attacker.name)
	var tgt_name := str(target.get("enemy_name") if target.get("enemy_name") else target.name)
	_title_label.text = "%s → %s" % [att_name, tgt_name]

	# ── Phase 1: Slide DicePanel masuk dari sisi ──────────────────────────────
	var cx := (vp_size.x - PANEL_W) * 0.5
	_dice_panel.position = Vector2(_offscreen_x(vp_size, false), PANEL_Y)

	var tw_dim := create_tween()
	tw_dim.tween_property(_dim_bg, "color", Color(0, 0, 0, 0.55), 0.3)

	var tw_in := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_in.tween_property(_dice_panel, "position:x", cx, 0.5)
	await tw_in.finished

	var target_pos := _dice_panel.global_position + Vector2(72, PANEL_H * 0.52)
	# ── Phase 2: Roll D20 ─────────────────────────────────────────────────────
	if _dice_visual.has_method("start_roll"):
		_dice_visual.start_roll(raw_d20, "d20", 2.0, target_pos, player_id)
		if _dice_visual.has_signal("roll_finished"):
			await _dice_visual.roll_finished
		else:
			await get_tree().create_timer(2.1).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	# ── Phase 3: Modifier muncul ──────────────────────────────────────────────
	_mod_label.text = "+%d" % modifier if modifier >= 0 else str(modifier)
	var tw_mod := create_tween()
	tw_mod.tween_property(_mod_label, "modulate:a", 1.0, 0.25)
	tw_mod.parallel().tween_property(_mod_label, "scale", Vector2(1.25, 1.25), 0.12)
	tw_mod.tween_property(_mod_label, "scale", Vector2(1.0, 1.0), 0.15)
	await get_tree().create_timer(0.5).timeout

	# ── Phase 4: Merge → Total ────────────────────────────────────────────────
	_total_label.text = "= %d" % total_hit
	var tw_tot := create_tween()
	tw_tot.tween_property(_total_label, "modulate:a", 1.0, 0.2)
	tw_tot.parallel().tween_property(_mod_label, "modulate:a", 0.0, 0.2)
	await get_tree().create_timer(0.45).timeout

	# ── Phase 5: AC Row slide masuk dari sisi berlawanan ─────────────────────
	_roll_disp.text = str(total_hit)
	_ac_disp.text   = "AC %d" % threshold
	var acy := PANEL_Y + PANEL_H * 0.5 - 30.0
	_ac_row.position = Vector2(_offscreen_x(vp_size, true), acy)
	_ac_row.modulate.a = 1.0

	var acx := (vp_size.x - 340.0) * 0.5
	var tw_ac := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw_ac.tween_property(_ac_row, "position:x", acx, 0.4)
	await tw_ac.finished
	await get_tree().create_timer(0.35).timeout

	# ── Phase 6: Collision + Result ───────────────────────────────────────────
	var col    : Color
	var result : String
	if is_crit:
		col = Color(1.0, 0.85, 0.0)
		result = "💥 CRIT!"
		_roll_disp.add_theme_color_override("font_color", col)
	elif is_hit:
		col = Color(0.25, 1.0, 0.45)
		result = "✅ HIT!"
		_roll_disp.add_theme_color_override("font_color", col)
	else:
		col = Color(0.85, 0.25, 0.25)
		result = "💨 MISS!"
		_ac_disp.add_theme_color_override("font_color", col)

	_result_lbl.text = result
	_result_lbl.add_theme_color_override("font_color", col)
	var tw_res := create_tween()
	tw_res.tween_property(_result_lbl, "modulate:a", 1.0, 0.18)
	tw_res.parallel().tween_property(_result_lbl, "scale", Vector2(1.3, 1.3), 0.12)
	tw_res.tween_property(_result_lbl, "scale", Vector2(1.0, 1.0), 0.18)
	await get_tree().create_timer(1.2).timeout

	# ── Phase 7: Damage roll (jika hit) ──────────────────────────────────────
	if is_hit and dmg_rolls.size() > 0:
		var tw_hide := create_tween()
		tw_hide.tween_property(_ac_row, "modulate:a", 0.0, 0.2)
		tw_hide.parallel().tween_property(_result_lbl, "modulate:a", 0.0, 0.2)
		_mod_label.modulate.a = 0
		_total_label.modulate.a = 0
		await get_tree().create_timer(0.25).timeout

		for i in range(dmg_rolls.size()):
			_title_label.text = "🎲 Damage %d/%d — %s" % [i + 1, dmg_rolls.size(), dmg_formula]
			if _dice_visual.has_method("start_roll"):
				_dice_visual.start_roll(dmg_rolls[i], _formula_dice(dmg_formula), 1.5, target_pos, player_id)
				if _dice_visual.has_signal("roll_finished"):
					await _dice_visual.roll_finished
				else:
					await get_tree().create_timer(1.6).timeout
			await get_tree().create_timer(0.3).timeout

		_total_label.text = "⚔️ %d dmg" % dmg_total
		_total_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		var tw_dmg := create_tween()
		tw_dmg.tween_property(_total_label, "modulate:a", 1.0, 0.25)
		await get_tree().create_timer(1.6).timeout

	# ── Phase 8: Slide keluar ─────────────────────────────────────────────────
	var vp2 := _get_vp_size()
	var tw_out := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw_out.tween_property(_dice_panel, "position:x", _offscreen_x(vp2, false), 0.38)
	tw_out.parallel().tween_property(_dim_bg, "color", Color(0, 0, 0, 0), 0.38)
	tw_out.parallel().tween_property(_ac_row, "modulate:a", 0.0, 0.25)
	tw_out.parallel().tween_property(_result_lbl, "modulate:a", 0.0, 0.25)
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


## Posisi off-screen: same_side=false → sisi masuk normal, true → sisi berlawanan
func _offscreen_x(vp_size: Vector2, opposite: bool) -> float:
	var from_left := (player_id == 1) != opposite
	return -PANEL_W - 30.0 if from_left else vp_size.x + 30.0


func _reset_state() -> void:
	if _dice_visual != null and _dice_visual.has_node("DiceSprite"):
		_dice_visual.get_node("DiceSprite").visible = false
	if _dice_visual != null and _dice_visual.has_node("NumberLabel"):
		_dice_visual.get_node("NumberLabel").visible = false
	_mod_label.modulate.a   = 0
	_total_label.modulate.a = 0
	_result_lbl.modulate.a  = 0
	_result_lbl.scale       = Vector2.ONE
	_ac_row.modulate.a      = 0
	_total_label.remove_theme_color_override("font_color")
	_roll_disp.remove_theme_color_override("font_color")
	_ac_disp.remove_theme_color_override("font_color")


func _formula_dice(formula: String) -> String:
	# "2D6" → "d6", "1D8" → "d8" dll
	var low := formula.to_lower()
	var idx := low.find("d")
	return "d" + low.substr(idx + 1) if idx >= 0 else "d6"
