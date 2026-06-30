class_name CombatVFXController
extends Node

var _bangers_font = preload("res://assets/ui_assets/Bangers-Regular.ttf")

func _make_world_label(text: String, font_size: int, color: Color, outline_color: Color = Color(0, 0, 0, 0.95), outline_size: int = 6) -> Node2D:
	var wrapper := Node2D.new()
	var l := Label.new()
	l.text = text
	if _bangers_font:
		l.add_theme_font_override("font", _bangers_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline_color)
	l.add_theme_constant_override("outline_size", outline_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Force the label to perfectly center itself on the wrapper Node2D
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	wrapper.add_child(l)
	return wrapper

func _apply_camera_shake(p_id: int, duration: float, amp: float, horizontal_only: bool = false) -> void:
	if not get_tree() or not get_tree().current_scene: return
	var main = get_tree().current_scene
	if main.has_node("SplitScreenManager"):
		var ssm = main.get_node("SplitScreenManager")
		if is_instance_valid(ssm) and ssm.has_method("shake_camera"):
			ssm.shake_camera(p_id, duration, amp, horizontal_only)
	elif main.has_node("World/Camera2D"):
		var cam = main.get_node("World/Camera2D")
		if is_instance_valid(cam) and cam.has_method("shake"):
			cam.shake(duration, amp, horizontal_only)

func _play_enemy_dice_sequence(
	attacker: Node, raw_roll: int, total_roll: int, ac: int,
	modifier: int, is_hit: bool, is_crit: bool, p_id: int
) -> void:
	var base_pos : Vector2 = attacker.global_position + Vector2(0, -180)
	
	var container := Node2D.new()
	container.z_index = 4096
	container.global_position = Vector2.ZERO
	if attacker.get_parent():
		attacker.get_parent().add_child(container)
	else:
		get_tree().root.add_child(container)
	
	var dice_scene := load("res://components/dice/sandbox/DiceVisual.tscn") as PackedScene
	if dice_scene == null:
		container.queue_free()
		return
	
	var dice_visual = dice_scene.instantiate()
	dice_visual.z_index = 4096
	container.add_child(dice_visual)
	
	var outcome := "hit"
	if is_crit: outcome = "crit"
	elif not is_hit: outcome = "miss"
	
	if is_instance_valid(dice_visual) and dice_visual.has_method("start_roll"):
		dice_visual.start_roll(raw_roll, "d20enemy", 1.8, base_pos, p_id, outcome, true, Vector2(0.45, 0.45))
		if dice_visual.has_signal("roll_finished"):
			await dice_visual.roll_finished
		else:
			await get_tree().create_timer(1.9).timeout
	
	var dice_landed_pos : Vector2 = dice_visual.global_position
	
	if modifier != 0:
		var mod_text := "+%d" % modifier if modifier > 0 else str(modifier)
		var mod_color := Color(0.75, 0.95, 0.4) if modifier > 0 else Color(1.0, 0.4, 0.4)
		var mod_label := _make_world_label(mod_text, 70, mod_color)
		mod_label.global_position = dice_landed_pos + Vector2(150, -120)
		container.add_child(mod_label)
		mod_label.modulate.a = 0.0
		mod_label.scale = Vector2(1.4, 1.4)
		
		var tw_mod := create_tween()
		tw_mod.tween_property(mod_label, "modulate:a", 1.0, 0.15)
		tw_mod.parallel().tween_property(mod_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_mod.tween_interval(0.3)
		var fly_target = dice_landed_pos
		tw_mod.tween_property(mod_label, "global_position", fly_target, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw_mod.tween_property(mod_label, "modulate:a", 0.0, 0.05)
		await tw_mod.finished
		
		if dice_visual.has_node("NumberLabel"):
			dice_visual.get_node("NumberLabel").text = str(total_roll)
		var absorb_tw := create_tween()
		absorb_tw.tween_property(dice_visual, "scale", dice_visual.scale * 0.85, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		absorb_tw.tween_property(dice_visual, "scale", dice_visual.scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		await absorb_tw.finished
	
	await get_tree().create_timer(0.15).timeout
	
	var roll_color := Color(0.3, 1.0, 0.5) if is_hit else Color(1.0, 0.4, 0.4)
	var roll_lbl := _make_world_label(str(total_roll), 70, roll_color)
	roll_lbl.modulate.a = 1.0
	container.add_child(roll_lbl)
	
	var ac_lbl := _make_world_label("AC %d" % ac, 70, Color(0.9, 0.55, 0.2))
	ac_lbl.modulate.a = 1.0
	container.add_child(ac_lbl)
	
	var result_text := "MISS!"
	var result_color := Color(0.85, 0.25, 0.25)
	var winner_lbl: Node2D
	var loser_lbl: Node2D
	
	if is_crit:
		result_text = "CRITICAL!"
		result_color = Color(1.0, 0.88, 0.1)
		winner_lbl = roll_lbl
		loser_lbl = ac_lbl
	elif is_hit:
		result_text = "HIT!"
		result_color = Color(0.25, 1.0, 0.45)
		winner_lbl = roll_lbl
		loser_lbl = ac_lbl
	else:
		winner_lbl = ac_lbl
		loser_lbl = roll_lbl
	
	winner_lbl.get_child(0).add_theme_color_override("font_color", result_color)
	
	roll_lbl.position = base_pos + Vector2(-300, 40)
	ac_lbl.position = base_pos + Vector2(300, 40)
	
	var center_roll_x := base_pos.x - 30
	var center_ac_x := base_pos.x + 30
	
	var tw_fade_dice := create_tween()
	tw_fade_dice.tween_property(dice_visual, "modulate:a", 0.0, 0.15)
	
	var tw_clash := create_tween().set_parallel(true)
	tw_clash.tween_property(roll_lbl, "position:x", center_roll_x, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw_clash.tween_property(ac_lbl, "position:x", center_ac_x, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw_clash.finished
	
	_apply_camera_shake(p_id, 0.1, 4.0, true)
	
	var fling_dir = -1 if loser_lbl == roll_lbl else 1
	var fling_x = randf_range(250.0, 450.0) * fling_dir
	var fling_y = randf_range(250.0, 350.0)
	var rot_amount = randf_range(3.0, 8.0) * fling_dir
	
	var arc_time = 1.0
	var rise_time = 0.4
	var fall_time = arc_time - rise_time
	
	var tw_lose_x = create_tween().set_parallel(true)
	tw_lose_x.tween_property(loser_lbl, "position:x", fling_x, arc_time).as_relative().set_trans(Tween.TRANS_LINEAR)
	tw_lose_x.tween_property(loser_lbl, "rotation", rot_amount, arc_time).as_relative().set_trans(Tween.TRANS_LINEAR)
	tw_lose_x.tween_property(loser_lbl, "modulate:a", 0.0, 0.3).set_delay(arc_time - 0.3)
	
	var tw_lose_y = create_tween()
	tw_lose_y.tween_property(loser_lbl, "position:y", -fling_y, rise_time).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_lose_y.tween_property(loser_lbl, "position:y", fling_y + 200.0, fall_time).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var tw_win = create_tween().set_parallel(true)
	tw_win.tween_property(winner_lbl, "position:x", base_pos.x, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_win.tween_property(winner_lbl, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_win.tween_property(winner_lbl, "rotation", 0.15 if is_hit else -0.15, 0.1)
	
	var result_lbl := _make_world_label(result_text, 70, result_color)
	result_lbl.position = base_pos + Vector2(0, -60)
	result_lbl.modulate.a = 0.0
	result_lbl.scale = Vector2(0.5, 0.5)
	result_lbl.z_index = -1
	container.add_child(result_lbl)
	
	var tw_result := create_tween()
	tw_result.tween_property(result_lbl, "modulate:a", 1.0, 0.1)
	tw_result.parallel().tween_property(result_lbl, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_result.tween_property(result_lbl, "scale", Vector2(1.0, 1.0), 0.1)
	
	tw_result.parallel().tween_property(winner_lbl, "modulate:a", 0.3, 0.3).set_delay(0.4)
	
	await get_tree().create_timer(1.2).timeout
	
	var tw_out := create_tween().set_parallel(true)
	tw_out.tween_property(container, "modulate:a", 0.0, 0.3)
	await tw_out.finished
	container.queue_free()

func _spawn_magic_projectile(attacker: Node, target: Node, element: String, tracking_array: Array = []) -> void:
	print("[COMBAT] 🌠 Merender efek sihir elemen: %s" % element)
	
	var orb = Polygon2D.new()
	var points = PackedVector2Array()
	var radius = 10.0
	for i in range(16):
		var angle = (i / 16.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	orb.polygon = points
	
	match element:
		"fire": orb.color = Color.ORANGE_RED
		"water": orb.color = Color.DODGER_BLUE
		"air": orb.color = Color.WHITE_SMOKE
		"earth": orb.color = Color.SADDLE_BROWN
		_: orb.color = Color.MEDIUM_PURPLE
		
	var start_pos = attacker.global_position + Vector2(0, -32)
	orb.global_position = start_pos
	
	orb.set_script(preload("res://combat_core/tests/HomingProjectile.gd"))
	orb.set("tracking_array", tracking_array)
	orb.set("fallback_target", target)
	
	if is_instance_valid(target):
		var init_dir = (target.global_position + Vector2(0, -32) - start_pos).normalized()
		# Massive random spread (up to 120 degrees sideways)
		var spread_angle = randf_range(-PI/1.5, PI/1.5) 
		init_dir = init_dir.rotated(spread_angle)
		orb.set("current_velocity", init_dir * randf_range(1200.0, 1800.0))
		
	add_child(orb)
	await orb.tree_exited
