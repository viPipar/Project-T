# entities/enemies/EnemyPlaceholder.gd
# Tanggung jawab:
#   Enemy test sederhana untuk Main.tscn: posisi grid, sprite placeholder, HP, dan AI ringan.
#
# Cara pakai:
#   var enemy := preload("res://entities/enemies/EnemyPlaceholder.tscn").instantiate()
#   enemy.place_at(Vector2i(5, 5))
#   enemy.take_damage(6, player)
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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: StatsComponent = $StatsComponent
@onready var class_comp: ClassComponent = $ClassComponent
@onready var health: HealthComponent = $HealthComponent
@onready var cond: ConditionComponent = $ConditionComponent

var grid_pos: Vector2i = Vector2i.ZERO
var current_hp: int = 30
var is_alive: bool = true
var _death_started: bool = false

const INSECT_DIR := "res://assets/characters/insect1_placeholder"


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	_setup_health()
	_setup_sprite()
	_apply_idle_frames()
	if sprite != null:
		sprite.play("idle_down")
	if start_grid_pos.x >= 0 and start_grid_pos.y >= 0:
		call_deferred("_deferred_place")


func get_grid_pos() -> Vector2i:
	return grid_pos


func place_at(pos: Vector2i) -> void:
	if GridManager.get_entity_at(grid_pos) == self:
		GridManager.unregister_entity(grid_pos)
	grid_pos = pos
	GridManager.register_entity(pos, self, GridManager.EntityType.ENEMY)
	position = IsoUtils.world_to_iso(pos)
	z_index = IsoUtils.get_depth(pos)


func _deferred_place() -> void:
	if health != null:
		health.setup_fixed_max(max_hp, true)
	else:
		current_hp = max_hp
	place_at(start_grid_pos)


# -----------------------------------------------------------------------------
# HP & Damage
# -----------------------------------------------------------------------------

func take_damage(amount: int, attacker: Node = null) -> int:
	if not is_alive:
		return 0
	if health != null:
		return health.take_damage(amount, attacker, "physical")

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


func is_dead() -> bool:
	if health != null:
		return health.is_dead()
	return not is_alive


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


func _on_health_damaged(amount: int) -> void:
	print("[%s] Menerima %d damage. HP: %d/%d" % [enemy_name, amount, current_hp, max_hp])


func _on_health_died(killer: Node) -> void:
	_die(killer, false)


func _die(killer: Node = null, emit_bus: bool = true) -> void:
	if _death_started:
		return
	_death_started = true
	is_alive = false
	current_hp = 0
	print("[%s] Kalah." % enemy_name)
	if emit_bus and EventBus != null:
		EventBus.entity_died.emit(self, killer)
	if sprite != null:
		sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)
	if GridManager.get_entity_at(grid_pos) == self:
		GridManager.unregister_entity(grid_pos)
	remove_from_group("enemies")
	await get_tree().create_timer(0.8).timeout
	queue_free()


# -----------------------------------------------------------------------------
# Simple AI (dipanggil oleh CombatTestBridge saat enemy phase)
# -----------------------------------------------------------------------------

func do_ai_turn() -> void:
	if is_dead():
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
			EventBus.damage_dealt.emit(nearest, applied, "physical", false)
	else:
		print("[%s] Bergerak menuju %s (jarak %d)." % [enemy_name, p_name, near_dist])


func _find_nearest_player() -> Node:
	var nearest: Node = null
	var near_dist: int = 999

	for p in get_tree().get_nodes_in_group("players"):
		var p_health: HealthComponent = p.get_node_or_null("HealthComponent") as HealthComponent
		if p_health != null and p_health.is_dead():
			continue

		var p_pos: Vector2i = p.get("grid_pos") as Vector2i
		var dist: int = GridManager.get_distance(grid_pos, p_pos)
		if dist < near_dist:
			near_dist = dist
			nearest = p

	return nearest


func _setup_sprite() -> void:
	if sprite != null:
		sprite.modulate = tint_color


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
		push_warning("EnemyPlaceholder: tidak bisa buka folder sprite: %s" % dir_path)
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
