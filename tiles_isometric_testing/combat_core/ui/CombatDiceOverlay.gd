# combat_core/ui/CombatDiceOverlay.gd
# ── Combat dice overlay — clean, no emoji ────────────────────────────────────
class_name CombatDiceOverlay
extends CanvasLayer

signal sequence_finished
## Dipancarkan setiap dadu damage mendarat (index, nilai roll)
## CombatTestBridge mendengarkan ini untuk apply damage satu per satu
signal dice_hit_landed(roll_index: int, roll_value: int)

## 1 = kiri (P1), 2 = kanan (P2)
var player_id: int = 1
var _is_playing: bool = false

# ── Prompt system ─────────────────────────────────────────────────────────────
signal _prompt_confirmed
var _prompt_label   : Label
var _waiting_input  : bool = false

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
# Pindah ke atas layar (dari 265 tengah → 30 atas)
var _panel_y := 30.0


# ── LIFECYCLE ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()

func _exit_tree() -> void:
	# Pastikan time_scale selalu reset jika overlay dihapus paksa
	pass

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
	_dim_bg.offset_top    = _panel_y - 10
	_dim_bg.offset_bottom = _panel_y + PANEL_H + 10
	_root.add_child(_dim_bg)

	# ── DicePanel ─────────────────────────────────────────────────────────────
	_dice_panel = Control.new()
	_dice_panel.size = Vector2(PANEL_W, PANEL_H)
	_root.add_child(_dice_panel)

	# Background dibikin transparan agar tidak mengganggu/menutupi layar
	var pbg := StyleBoxFlat.new()
	pbg.bg_color        = Color(0.0, 0.0, 0.0, 0.0) 
	var pbg_panel := PanelContainer.new()
	pbg_panel.size = Vector2(PANEL_W, PANEL_H)
	pbg_panel.add_theme_stylebox_override("panel", pbg)
	_dice_panel.add_child(pbg_panel)

	# (Garis aksen neon ungu dihapus agar lebih clean)

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

	# ── Prompt label — tengah half-screen player ──────────────────────────────
	_prompt_label = _lbl("", 20, Color(1.0, 1.0, 1.0))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_prompt_label.add_theme_constant_override("outline_size", 6)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt_label.offset_left   = -200
	_prompt_label.offset_right  =  200
	_prompt_label.offset_top    =  -50
	_prompt_label.offset_bottom =   50
	_prompt_label.modulate.a = 0
	_prompt_label.visible = false
	_root.add_child(_prompt_label)


var _custom_font = preload("res://assets/ui_assets/Bangers-Regular.ttf")

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if _custom_font:
		l.add_theme_font_override("font", _custom_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


# ── INPUT — hanya saat menunggu konfirmasi player ─────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _is_playing:
		return
		
	var confirm_action := "p1_confirm" if player_id == 1 else "p2_confirm"
	if event.is_action_pressed(confirm_action):
		if _waiting_input:
			_waiting_input = false
			_prompt_confirmed.emit()
			get_viewport().set_input_as_handled()
		else:
			if is_instance_valid(_dice_visual) and _dice_visual.has_method("skip_roll"):
				_dice_visual.skip_roll()
			get_viewport().set_input_as_handled()


# ── PROMPT SYSTEM ─────────────────────────────────────────────────────────────

func show_roll_prompt(roll_index: int) -> void:
	# roll_index 1 = hit/miss, 2 = damage
	var key_str   := "F" if player_id == 1 else ";"
	var roll_type := "Hit / Miss Roll" if roll_index == 1 else "Damage Roll"

	# Teks dengan blink-pulse latar gelap semi-transparan
	_prompt_label.text    = "[  Press %s to Roll Dice — P%d  ]\n%s" % [key_str, player_id, roll_type]
	_prompt_label.visible = true
	_prompt_label.modulate.a = 0.0

	# Fade in
	var tw_in := create_tween()
	tw_in.tween_property(_prompt_label, "modulate:a", 1.0, 0.25)
	await tw_in.finished

	# Animasi pulse agar terasa hidup
	var tw_pulse := create_tween().set_loops()
	tw_pulse.tween_property(_prompt_label, "modulate:a", 0.55, 0.55).set_trans(Tween.TRANS_SINE)
	tw_pulse.tween_property(_prompt_label, "modulate:a", 1.0,  0.55).set_trans(Tween.TRANS_SINE)

	# Tunggu input player
	_waiting_input = true
	await _prompt_confirmed

	# Stop pulse + fade out
	tw_pulse.kill()
	var tw_out := create_tween()
	tw_out.tween_property(_prompt_label, "modulate:a", 0.0, 0.15)
	await tw_out.finished
	_prompt_label.visible = false


# ── PUBLIC API ────────────────────────────────────────────────────────────────

func play_attack_sequence(
	attacker    : Node,
	target      : Node,
	hit_result  : Dictionary,
	dmg_rolls   : Array,
	dmg_total   : int,
	dmg_formula : String,
	dmg_mod     : int = 0
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

	# ── Phase 1: Slide panel masuk (cepat) ────────────────────────────────────
	var cx := (vp_size.x - PANEL_W) * 0.5
	_dice_panel.position = Vector2(_offscreen_x(vp_size, false), _panel_y)

	var tw_dim := create_tween()
	tw_dim.tween_property(_dim_bg, "color", Color(0, 0, 0, 0.2), 0.25)

	var tw_in := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw_in.tween_property(_dice_panel, "position:x", cx, 0.3)
	await tw_in.finished

	var target_pos := _dice_panel.global_position + Vector2(72, PANEL_H * 0.52)

	# ── Prompt 1: Tunggu player tekan konfirm untuk D20 ──────────────────────
	await show_roll_prompt(1)

	# ── Phase 2: Roll D20 (2.6 detik sesuai setting DiceVisual) ─────────────
	var outcome := "hit"
	if is_crit: outcome = "crit"
	elif not is_hit: outcome = "miss"

	if is_instance_valid(_dice_visual) and _dice_visual.has_method("start_roll"):
		_dice_visual.start_roll(raw_d20, "d20", 2.6, target_pos, player_id, outcome)
		if _dice_visual.has_signal("roll_finished"):
			await _dice_visual.roll_finished
		else:
			await get_tree().create_timer(2.7).timeout
	else:
		await get_tree().create_timer(0.8).timeout

	# ── Phase 3: Modifier Absorb (Antrian Modifier Tunggal) ───────────────────
	if modifier != 0:
		_mod_label.text = "+%d" % modifier if modifier >= 0 else str(modifier)
		_mod_label.position = Vector2(180, -20) # Muncul agak di atas kanan dadu
		_mod_label.modulate.a = 0.0
		_mod_label.scale = Vector2(1.5, 1.5)
		
		# Muncul dan diam sebentar (Anticipation)
		var tw_mod := create_tween()
		tw_mod.tween_property(_mod_label, "modulate:a", 1.0, 0.2)
		tw_mod.parallel().tween_property(_mod_label, "scale", Vector2(1.0, 1.0), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_mod.tween_interval(0.3) # Tunggu terbaca
		
		# Charge (Lelesatkan) menabrak dadu
		tw_mod.tween_property(_mod_label, "position", _dice_visual.position, 0.2)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
		await tw_mod.finished
		
		# Benturan! Modifier terserap ke dadu
		_mod_label.modulate.a = 0.0
		
		if _dice_visual.has_node("NumberLabel"):
			_dice_visual.get_node("NumberLabel").text = str(total_hit)
			
		# Animasi membal (Scale Bounce) pada dadu karena menyerap angka
		var absorb_tw := create_tween()
		absorb_tw.tween_property(_dice_visual, "scale", Vector2(0.9, 0.9), 0.1)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		absorb_tw.tween_property(_dice_visual, "scale", Vector2(0.6, 0.6), 0.3)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		await absorb_tw.finished
	else:
		if _dice_visual.has_node("NumberLabel"):
			_dice_visual.get_node("NumberLabel").text = str(total_hit)

	# ── Phase 4: (Dilewati, total sudah masuk ke dadu) ────────────────────────
	_total_label.modulate.a = 0.0

	# ── Phase 5: THE CLASH (Roll VS Armor Class) ──────────────────────────────
	_roll_disp.text = str(total_hit)
	_ac_disp.text   = "AC %d" % threshold
	_vs_label.modulate.a = 0.0 # Sembunyikan teks 'vs' polos
	
	var acy := _panel_y + PANEL_H * 0.5 - 25.0
	var vcx := (vp_size.x - 280.0) * 0.5
	_vs_row.position = Vector2(vcx, acy)
	_vs_row.modulate.a = 1.0
	
	# Set start position (Kiri jauh untuk Dadu, Kanan jauh untuk AC)
	var center_roll = 80.0
	var center_ac   = 140.0
	
	_roll_disp.position = Vector2(center_roll - 300, 6)
	_ac_disp.position   = Vector2(center_ac + 300, 6)
	_roll_disp.rotation = 0
	_ac_disp.rotation   = 0
	_roll_disp.scale    = Vector2.ONE
	_ac_disp.scale      = Vector2.ONE
	
	# The Charge (Melesat ke tengah)
	var tw_charge := create_tween().set_parallel(true)
	tw_charge.tween_property(_roll_disp, "position:x", center_roll, 0.25)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw_charge.tween_property(_ac_disp, "position:x", center_ac, 0.25)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
	await tw_charge.finished
	
	# BENTURAN! (Partikel dan Screen Shake)
	_spawn_clash_particles(_vs_row.global_position + Vector2(130, 25))
	
	var tw_shake = create_tween()
	tw_shake.tween_property(_vs_row, "position:y", acy - 10, 0.05)
	tw_shake.tween_property(_vs_row, "position:y", acy + 8, 0.05)
	tw_shake.tween_property(_vs_row, "position:y", acy - 5, 0.05)
	tw_shake.tween_property(_vs_row, "position:y", acy, 0.05)

	# ── Phase 6: Result Resolution ────────────────────────────────────────────
	var col    : Color
	var result : String
	var winner_lbl : Label
	var loser_lbl : Label
	
	if is_crit or is_hit:
		col    = Color(1.0, 0.88, 0.1) if is_crit else Color(0.25, 1.0, 0.45)
		result = "CRITICAL!" if is_crit else "HIT!"
		winner_lbl = _roll_disp
		loser_lbl  = _ac_disp
		_roll_disp.add_theme_color_override("font_color", col)
		
		if is_instance_valid(attacker) and attacker.has_method("activate_haki_aura"):
			attacker.activate_haki_aura()
	else:
		col    = Color(0.85, 0.25, 0.25)
		result = "MISS!"
		winner_lbl = _ac_disp
		loser_lbl  = _roll_disp
		_ac_disp.add_theme_color_override("font_color", col)

	# Animasi Kalah (Terlempar ke bawah)
	var tw_lose = create_tween().set_parallel(true)
	tw_lose.tween_property(loser_lbl, "position:y", 150.0, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_lose.tween_property(loser_lbl, "rotation", randf_range(-1.5, 1.5), 0.4)
	tw_lose.tween_property(loser_lbl, "modulate:a", 0.0, 0.3).set_delay(0.1)
	
	# Animasi Menang (Membesar & Triumphant)
	var tw_win = create_tween().set_parallel(true)
	tw_win.tween_property(winner_lbl, "scale", Vector2(1.5, 1.5), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_win.tween_property(winner_lbl, "rotation", 0.1 if is_hit else -0.1, 0.15)
	
	# Muncul Teks Result Besar
	_result_lbl.text = result
	_result_lbl.add_theme_color_override("font_color", col)
	var tw_res := create_tween().set_ease(Tween.EASE_OUT)
	tw_res.tween_property(_result_lbl, "modulate:a", 1.0, 0.25)
	tw_res.parallel().tween_property(_result_lbl, "scale", Vector2(1.2, 1.2), 0.2)
	tw_res.tween_property(_result_lbl, "scale", Vector2(1.0, 1.0), 0.2)
	
	await get_tree().create_timer(1.2).timeout

	# ── Phase 7: Damage roll ──────────────────────────────────────────────────
	if is_hit and dmg_rolls.size() > 0:
		var tw_hide := create_tween().set_ease(Tween.EASE_IN)
		tw_hide.tween_property(_vs_row,      "modulate:a", 0.0, 0.2)
		tw_hide.parallel().tween_property(_result_lbl, "modulate:a", 0.0, 0.2)
		_mod_label.modulate.a   = 0
		_total_label.modulate.a = 0
		await get_tree().create_timer(0.25).timeout

		# ── Prompt 2: Tunggu player tekan konfirm untuk damage ────────────────
		await show_roll_prompt(2)

		for i in range(dmg_rolls.size()):
			# Semakin banyak jumlah roll, animasi berikutnya akan semakin ngebut!
			# i=0 -> 2.6s | i=1 -> 1.69s | i=2 -> ~1.1s | dst... (minimum 0.6s)
			var current_duration = max(0.6, 2.6 * pow(0.65, i))
			
			_title_label.text = "Damage %d/%d  —  %s" % [i + 1, dmg_rolls.size(), dmg_formula]
			if is_instance_valid(_dice_visual) and _dice_visual.has_method("start_roll"):
				_dice_visual.start_roll(dmg_rolls[i], _formula_dice(dmg_formula), current_duration, target_pos, player_id)
				if _dice_visual.has_signal("roll_finished"):
					await _dice_visual.roll_finished
				else:
					await get_tree().create_timer(current_duration + 0.1).timeout

			# ── ANIMASI MODIFIER MENYATU (Absorb) KE DADU DAMAGE ─────────────
			# Mirip seperti D20: Label "+3" muncul lalu menabrak dadu
			if dmg_mod != 0:
				_mod_label.text = "+%d" % dmg_mod if dmg_mod >= 0 else str(dmg_mod)
				_mod_label.position = Vector2(180, -20)
				_mod_label.modulate.a = 0.0
				_mod_label.scale = Vector2(1.5, 1.5)
				
				var tw_mod := create_tween()
				tw_mod.tween_property(_mod_label, "modulate:a", 1.0, 0.15)
				tw_mod.parallel().tween_property(_mod_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_mod.tween_interval(0.2)
				tw_mod.tween_property(_mod_label, "position", _dice_visual.position, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
				await tw_mod.finished
				
				_mod_label.modulate.a = 0.0
				if _dice_visual.has_node("NumberLabel"):
					_dice_visual.get_node("NumberLabel").text = str(dmg_rolls[i] + dmg_mod)
					
				var absorb_tw := create_tween()
				absorb_tw.tween_property(_dice_visual, "scale", Vector2(0.8, 0.8), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				absorb_tw.tween_property(_dice_visual, "scale", Vector2(0.6, 0.6), 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				await absorb_tw.finished

			# Emit per-die damage agar Bridge bisa menge-track (walau apply damage nya di akhir)
			dice_hit_landed.emit(i, dmg_rolls[i] + dmg_mod)
			
			# Jeda sangat kecil antar lemparan dadu berikutnya
			var pause: float = maxf(0.05, 0.15 * pow(0.65, i))
			await get_tree().create_timer(pause).timeout

		_total_label.text = "%d damage" % dmg_total
		_total_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.2))
		var tw_dmg := create_tween().set_ease(Tween.EASE_OUT)
		tw_dmg.tween_property(_total_label, "modulate:a", 1.0, 0.3)
		await get_tree().create_timer(1.0).timeout

	# ── Phase 8: Slide keluar ─────────────────────────────────────────────────
	if is_instance_valid(attacker) and attacker.has_method("deactivate_haki_aura"):
		attacker.deactivate_haki_aura()

	var vp2    := _get_vp_size()
	var tw_out := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw_out.tween_property(_dice_panel,  "position:x",  _offscreen_x(vp2, false), 0.3)
	tw_out.parallel().tween_property(_dim_bg,       "color",       Color(0, 0, 0, 0),    0.25)
	tw_out.parallel().tween_property(_vs_row,       "modulate:a",  0.0,                  0.2)
	tw_out.parallel().tween_property(_result_lbl,   "modulate:a",  0.0,                  0.2)
	tw_out.parallel().tween_property(_total_label,  "modulate:a",  0.0,                  0.2)
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
	_prompt_label.modulate.a = 0
	_prompt_label.visible    = false
	_waiting_input           = false
	_total_label.remove_theme_color_override("font_color")
	
	_roll_disp.remove_theme_color_override("font_color")
	_roll_disp.modulate.a = 1.0
	
	_ac_disp.remove_theme_color_override("font_color")
	_ac_disp.modulate.a = 1.0


func _formula_dice(formula: String) -> String:
	var low := formula.to_lower()
	var idx := low.find("d")
	if idx < 0: return "d6"
	var sub := low.substr(idx + 1)
	var num_str := ""
	for i in range(sub.length()):
		if sub[i].is_valid_int(): num_str += sub[i]
		else: break
	return "d" + num_str

func _spawn_clash_particles(spawn_pos: Vector2) -> void:
	for i in range(12):
		var p = ColorRect.new()
		p.color = Color(1.0, 1.0, 1.0, 0.8)
		p.size = Vector2(8, 8)
		p.rotation = randf() * TAU
		p.global_position = spawn_pos
		add_child(p)
		
		var tw = create_tween().set_parallel(true)
		var angle = randf() * TAU
		var dist = randf_range(40.0, 100.0)
		var target_p = spawn_pos + Vector2(cos(angle), sin(angle)) * dist
		
		tw.tween_property(p, "global_position", target_p, 0.35)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ZERO, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", p.rotation + randf_range(-3, 3), 0.35)
		tw.chain().tween_callback(p.queue_free)
