# entities/enemies/EnemyPlaceholder.gd
# Tanggung jawab:
#   Enemy test sederhana untuk Main.tscn: posisi grid, sprite placeholder, HP, dan AI ringan.
#
# Cara pakai:
#   var enemy := preload("res://entities/enemies/EnemyPlaceholder.tscn").instantiate()
#   enemy.place_at(Vector2i(5, 5))
#   enemy.take_damage(6, player)
#   enemy.dash(Vector2i.LEFT, 2)
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Serang enemy dari player.
#   3. Pastikan HealthComponent.current_hp berkurang dan enemy hilang saat HP 0.
extends CharacterBody2D

@export var enemy_name: String = "Enemy"
@export var tint_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var start_grid_pos: Vector2i = Vector2i(-1, -1)
@export var max_hp: int = 30

@export_dir var sprite_folder: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: StatsComponent = $StatsComponent
@onready var class_comp: ClassComponent = $ClassComponent
@onready var health: HealthComponent = $HealthComponent
@onready var cond: ConditionComponent = $ConditionComponent

var grid_pos: Vector2i = Vector2i.ZERO
var current_hp: int = 30
var is_alive: bool = true
var _death_started: bool = false
var _noise_tex: NoiseTexture2D = null
var _hovering_players: Dictionary = {} # int -> bool
var _is_my_turn: bool = false
var raw_data: Dictionary = {}

var base_sprite_scale: Vector2 = Vector2(0.75, 0.75)
var base_sprite_offset: Vector2 = Vector2(14, -113)
var anim_frame_widths: Dictionary = {}

const INSECT_DIR := "res://assets/characters/insect1_placeholder"


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	_setup_health()
	_setup_sprite()
	_apply_idle_frames()
	
	if EventBus != null:
		EventBus.turn_started.connect(_on_turn_started)
		EventBus.turn_ended.connect(_on_turn_ended)
	
	# Spawn tooltip
	var tooltip_script = load("res://ui/shared/EnemyStatTooltip.gd")
	if tooltip_script:
		var tooltip = Node2D.new()
		tooltip.set_script(tooltip_script)
		tooltip.name = "EnemyStatTooltip"
		add_child(tooltip)
		
	if sprite != null:
		_play_anim("idle_down")
	if start_grid_pos.x >= 0 and start_grid_pos.y >= 0:
		_deferred_place()
		
	var move_comp = get_node_or_null("MovementComponent")
	if move_comp != null and move_comp.has_signal("step_started"):
		move_comp.step_started.connect(_on_step_started)

func _on_step_started(from: Vector2i, to: Vector2i) -> void:
	if sprite == null: return
	var delta = to - from
	if delta.x > 0 or delta.y < 0:
		sprite.flip_h = true
	elif delta.x < 0 or delta.y > 0:
		sprite.flip_h = false



func get_grid_pos() -> Vector2i:
	return grid_pos


func place_at(pos: Vector2i) -> void:
	if GridManager.get_entity_at(grid_pos) == self:
		GridManager.unregister_entity(grid_pos)
			
	grid_pos = pos
	GridManager.register_entity(pos, self, GridManager.EntityType.ENEMY)
	position = IsoUtils.world_to_iso(pos)

func dash(direction: Vector2i, distance: int, options: Dictionary = {}) -> Dictionary:
	var move_comp := get_node_or_null("MovementComponent") as MovementComponent
	if move_comp != null and move_comp.has_method("dash"):
		return move_comp.dash(direction, distance, options)
	return ForcedMovementResolver.dash_entity(self, direction, distance, self, options)


func _deferred_place() -> void:
	if health != null:
		health.setup_fixed_max(max_hp, true)
	else:
		current_hp = max_hp
	place_at(start_grid_pos)


# -----------------------------------------------------------------------------
# HP & Damage
# -----------------------------------------------------------------------------

func take_damage(amount: int, attacker: Node = null, damage_type: String = "physical") -> int:
	if not is_alive:
		return 0
	if health != null:
		return health.take_damage(amount, attacker, damage_type)

	var applied: int = maxi(0, amount)
	current_hp = maxi(0, current_hp - applied)
	print("[%s] Menerima %d damage. HP: %d/%d" % [enemy_name, applied, current_hp, max_hp])
	if current_hp <= 0:
		_die(attacker, true)
	return applied


func heal(amount: int) -> int:
	if not is_alive:
		return 0
	if health != null:
		return health.heal(amount, self)

	var applied: int = mini(maxi(0, amount), max_hp - current_hp)
	current_hp += applied
	return applied


func get_hp() -> int:
	return health.get_hp() if health != null else current_hp


func get_max_hp() -> int:
	return health.get_max_hp() if health != null else max_hp


func sub_hp(amount: int, attacker: Node = null, damage_type: String = "true") -> int:
	if health != null:
		return health.sub_hp(amount, attacker, damage_type)
	return take_damage(amount, attacker, damage_type)


func add_hp(amount: int) -> int:
	if health != null:
		return health.add_hp(amount)
	return heal(amount)


func get_armor() -> int:
	return stats.get_armor() if stats != null else 0


func get_resist() -> int:
	return stats.get_resist() if stats != null else 0


func get_stat(stat_key: String) -> int:
	return stats.get_stat(stat_key) if stats != null else 0


func add_stat(stat_key: String, amount: int) -> bool:
	return stats.add_base_stat(stat_key, amount) if stats != null else false


func sub_stat(stat_key: String, amount: int) -> bool:
	return stats.sub_base_stat(stat_key, amount) if stats != null else false


func is_dead() -> bool:
	if health != null:
		return health.is_dead()
	return not is_alive


func is_downed() -> bool:
	return health != null and health.is_downed()


func _setup_health() -> void:
	if health == null:
		return
	health.setup_fixed_max(max_hp, true)
	if not health.hp_changed.is_connected(_on_hp_changed):
		health.hp_changed.connect(_on_hp_changed)
	if not health.damaged.is_connected(_on_health_damaged):
		health.damaged.connect(_on_health_damaged)
	if not health.died.is_connected(_on_health_died):
		health.died.connect(_on_health_died)


func _on_hp_changed(new_hp: int, new_max_hp: int) -> void:
	current_hp = new_hp
	max_hp = new_max_hp
	is_alive = current_hp > 0
	
	var tooltip = get_node_or_null("EnemyStatTooltip")
	if is_instance_valid(tooltip) and tooltip.has_method("update_hp"):
		tooltip.update_hp(current_hp)


func _on_health_damaged(amount: int) -> void:
	print("[%s] Menerima %d damage. HP: %d/%d" % [enemy_name, amount, current_hp, max_hp])
	if sprite != null and sprite.sprite_frames.has_animation("damage") and is_alive:
		_play_anim("damage")
		# Return to idle after a short delay
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_alive and sprite.animation == "damage":
				_play_anim("idle_down")
		)


func _on_health_died(killer: Node) -> void:
	_die(killer, false)


func _die(killer: Node = null, emit_bus: bool = true) -> void:
	if _death_started:
		return
	_death_started = true
	is_alive = false
	current_hp = 0
	
	var tooltip = get_node_or_null("EnemyStatTooltip")
	if is_instance_valid(tooltip) and tooltip.has_method("hide_tooltip"):
		tooltip.hide_tooltip()
		
	print("[%s] Kalah." % enemy_name)
	if emit_bus and EventBus != null:
		EventBus.entity_died.emit(self, killer)
		
	# Unregister footprint
	if GridManager.get_entity_at(grid_pos) == self:
		GridManager.unregister_entity(grid_pos)
			
	remove_from_group("enemies")

	if sprite != null:
		if sprite.sprite_frames.has_animation("mati"):
			_play_anim("mati")
			await sprite.animation_finished
			_play_dissolve_death()
			await get_tree().create_timer(1.2).timeout
		else:
			_play_dissolve_death()
			await get_tree().create_timer(1.2).timeout
	else:
		await get_tree().create_timer(0.4).timeout
	queue_free()


func _play_dissolve_death() -> void:
	if sprite == null:
		return
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/2d_dissolve_with_burn_edge.gdshader")
	
	if _noise_tex == null:
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.08
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.noise = noise
		_noise_tex.width = 256
		_noise_tex.height = 256
	mat.set_shader_parameter("dissolve_texture", _noise_tex)
	mat.set_shader_parameter("dissolve_value", 0.0)
	mat.set_shader_parameter("burn_size", 0.06)
	mat.set_shader_parameter("burn_color", Color(1.0, 0.3, 0.0, 1.0))
	sprite.material = mat
	
	var tw = create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("dissolve_value", v), 0.0, 1.0, 0.9).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v): mat.set_shader_parameter("burn_color", Color(1.0, 0.3, 0.0, 1.0 - v * 0.8)), 0, 1, 0.9)


# -----------------------------------------------------------------------------
# Tooltip Hover Logic
# -----------------------------------------------------------------------------

func add_hover_player(pid: int) -> void:
	_hovering_players[pid] = true
	_update_tooltip_visibility()


func remove_hover_player(pid: int) -> void:
	if _hovering_players.has(pid):
		_hovering_players.erase(pid)
	_update_tooltip_visibility()


func _update_tooltip_visibility() -> void:
	var tooltip = get_node_or_null("EnemyStatTooltip")
	if tooltip == null: return
	
	if _hovering_players.is_empty() and not _is_my_turn:
		tooltip.hide_tooltip()
	else:
		var layer_mask := 0
		if _hovering_players.has(1) or _is_my_turn: layer_mask |= 2 # P1
		if _hovering_players.has(2) or _is_my_turn: layer_mask |= 4 # P2
		
		var armor := 0
		var ap := 0
		var mp := 0
		if stats != null: 
			armor = stats.get_armor()
			ap = stats.get_action_points()
			mp = stats.get_stat("mov")
		tooltip.show_for(enemy_name, current_hp, max_hp, armor, ap, mp, layer_mask)


func apply_wind_sway(strength: float = 60.0) -> void:
	if sprite == null: return
	ShaderEffects.apply_wind_sway(sprite, strength)


func play_attack(ability_id: String) -> void:
	if sprite != null and sprite.sprite_frames.has_animation("attack"):
		_play_anim("attack")
		await sprite.animation_finished
		_play_anim("idle_down")
	elif sprite != null:
		var tw = create_tween()
		tw.tween_property(sprite, "position:y", sprite.position.y + 15, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "position:y", sprite.position.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
	else:
		await get_tree().create_timer(0.2).timeout


# -----------------------------------------------------------------------------
# Simple AI (dipanggil oleh CombatTestBridge saat enemy phase)
# -----------------------------------------------------------------------------

func do_ai_turn() -> void:
	if is_dead():
		return
		
	var ai_comp = get_node_or_null("AIComponent")
	if is_instance_valid(ai_comp) and ai_comp.has_method("take_turn"):
		ai_comp.take_turn()
		return

	if cond != null and (cond.is_stunned() or cond.is_frozen()):
		return

	var nearest: Node = _find_nearest_player()
	if nearest == null:
		print("[%s] Tidak ada target." % enemy_name)
		return

	var p_name: String = str(nearest.get("char_name")) if nearest.get("char_name") != null else str(nearest.name)
	var near_dist: int = GridManager.get_distance(grid_pos, nearest.get("grid_pos") as Vector2i)

	if near_dist <= 1:
		print("[%s] Menyerang %s. (jarak 1)" % [enemy_name, p_name])
		var applied: int = StatSystem.apply_damage(nearest, 2, self, "physical")
		if applied > 0:
			EventBus.damage_dealt.emit(nearest, applied, "physical", false, null)
	else:
		print("[%s] Bergerak menuju %s (jarak %d)." % [enemy_name, p_name, near_dist])


func _find_nearest_player() -> Node:
	var nearest: Node = null
	var near_dist: int = 999

	for p in get_tree().get_nodes_in_group("players"):
		var p_health: HealthComponent = p.get_node_or_null("HealthComponent") as HealthComponent
		if p_health != null and (p_health.is_dead() or p_health.is_downed()):
			continue

		var p_pos: Vector2i = p.get("grid_pos") as Vector2i
		var dist: int = GridManager.get_distance(grid_pos, p_pos)
		if dist < near_dist:
			near_dist = dist
			nearest = p

	return nearest


func _setup_sprite() -> void:
	if sprite != null:
		if sprite_folder == "":
			sprite.modulate = tint_color
		else:
			sprite.modulate = Color.WHITE


func apply_custom_data(data: Dictionary) -> void:
	raw_data = data
	sprite_folder = data.get("sprite_folder", "")
	
	if data.has("sprite_scale"):
		var s = float(data["sprite_scale"])
		base_sprite_scale = Vector2(s, s)
	else:
		base_sprite_scale = Vector2(0.75, 0.75)
		
	if data.has("sprite_offset"):
		var raw_offset = data["sprite_offset"]
		if typeof(raw_offset) == TYPE_ARRAY and raw_offset.size() >= 2:
			base_sprite_offset = Vector2(float(raw_offset[0]), float(raw_offset[1]))
	else:
		base_sprite_offset = Vector2(14, -113)

	if sprite != null:
		sprite.scale = base_sprite_scale
		sprite.position = base_sprite_offset
		
	_setup_sprite()
	
	var anim_config: Dictionary = data.get("sprite_animations", {})
	if not anim_config.is_empty():
		_apply_spritesheet_animations(anim_config)
	else:
		_apply_idle_frames()
		
	if data.has("ai_brain"):
		var brain_path = data["ai_brain"]
		var ai_comp = get_node_or_null("AIComponent")
		if ai_comp != null:
			var loaded_brain = load(brain_path)
			if loaded_brain != null:
				ai_comp.brain = loaded_brain
			else:
				push_warning("BaseEnemy: Failed to load ai_brain from path: %s" % brain_path)
		
	if start_grid_pos.x >= 0 and start_grid_pos.y >= 0:
		place_at(start_grid_pos)


func _apply_spritesheet_animations(anim_config: Dictionary) -> void:
	if sprite == null: return
	
	anim_frame_widths.clear()
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")
	
	var standard_anims = ["idle", "attack", "damage", "mati"]
	
	for anim_key in standard_anims:
		if not anim_config.has(anim_key):
			continue
			
		var cfg: Dictionary = anim_config[anim_key]
		var file_name: String = cfg.get("file", "")
		if file_name == "":
			continue
			
		var full_path = sprite_folder + "/" + file_name
		var fw: int = int(cfg.get("frame_w", 512))
		var fh: int = int(cfg.get("frame_h", 512))
		var cols: int = int(cfg.get("cols", 1))
		var rows: int = int(cfg.get("rows", 1))
		var total_frames: int = int(cfg.get("frames", 1))
		
		anim_frame_widths[anim_key] = fw
		
		var frames := _load_frames_from_spritesheet(full_path, fw, fh, cols, rows, total_frames)
		if frames.is_empty():
			continue
			
		var target_names: Array[String] = []
		if anim_key == "idle":
			target_names = ["idle_down", "idle_left", "idle_right", "idle_up"]
		else:
			target_names = [anim_key]
			
		for target_name in target_names:
			if not sprite_frames.has_animation(target_name):
				sprite_frames.add_animation(target_name)
			sprite_frames.set_animation_speed(target_name, 12.0 if anim_key == "idle" else 15.0)
			sprite_frames.set_animation_loop(target_name, anim_key == "idle")
			for frame in frames:
				sprite_frames.add_frame(target_name, frame)
				
	sprite.sprite_frames = sprite_frames
	_play_anim("idle_down")


func _play_anim(anim_name: String) -> void:
	if sprite == null: return
	
	sprite.play(anim_name)
	
	var anim_key = anim_name
	if anim_name.begins_with("idle"):
		anim_key = "idle"
		
	if anim_frame_widths.has(anim_key) and anim_frame_widths.has("idle"):
		var idle_w = float(anim_frame_widths["idle"])
		var current_w = float(anim_frame_widths[anim_key])
		if current_w > 0:
			var multiplier = idle_w / current_w
			sprite.scale = base_sprite_scale * multiplier


func _load_frames_from_spritesheet(path: String, fw: int, fh: int, cols: int, rows: int, total_frames: int) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var tex = load(path) as Texture2D
	if tex == null:
		push_warning("BaseEnemy: Gagal memuat spritesheet: %s" % path)
		return result
		
	for i in range(total_frames):
		var col = i % cols
		var row = i / cols
		
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(col * fw, row * fh, fw, fh)
		result.append(atlas)
		
	return result


func _apply_idle_frames() -> void:
	var frames := _load_frames_from_dir(INSECT_DIR)
	if frames.is_empty() or sprite == null:
		return

	var sprite_frames := SpriteFrames.new()
	var anims := ["idle_down", "idle_left", "idle_right", "idle_up"]

	for anim_name in anims:
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, 24.0)
		sprite_frames.set_animation_loop(anim_name, true)
		for tex in frames:
			sprite_frames.add_frame(anim_name, tex)

	sprite.sprite_frames = sprite_frames


func _load_frames_from_dir(dir_path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("BaseEnemy: tidak bisa buka folder sprite: %s" % dir_path)
		return result

	var files: Array[String] = []
	for f in dir.get_files():
		if f.to_lower().ends_with(".png"):
			files.append(f)
	files.sort()

	for f in files:
		var tex := load(dir_path + "/" + f) as Texture2D
		if tex != null:
			result.append(tex)
	return result

func _on_turn_started(entity: Node, _pid: int) -> void:
	if entity == self:
		_is_my_turn = true
		_update_tooltip_visibility()

func _on_turn_ended(entity: Node) -> void:
	if entity == self:
		_is_my_turn = false
		_update_tooltip_visibility()
