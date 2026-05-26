extends CharacterBody2D

@export var enemy_name: String = "Enemy"
@export var tint_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var start_grid_pos: Vector2i = Vector2i(-1, -1)
@export var max_hp: int = 30

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var grid_pos:   Vector2i = Vector2i.ZERO
var current_hp: int      = 30
var is_alive:   bool     = true

const INSECT_DIR := "res://assets/characters/insect1_placeholder"


func _ready() -> void:
	add_to_group("enemies")
	_setup_sprite()
	_apply_idle_frames()
	if sprite != null:
		sprite.play("idle_down")
	if start_grid_pos.x >= 0 and start_grid_pos.y >= 0:
		call_deferred("_deferred_place")


func get_grid_pos() -> Vector2i:
	return grid_pos


func place_at(pos: Vector2i) -> void:
	if grid_pos != Vector2i.ZERO:
		GridManager.unregister_entity(grid_pos)
	grid_pos = pos
	GridManager.register_entity(pos, self, GridManager.EntityType.ENEMY)
	position = IsoUtils.world_to_iso(pos)
	z_index = IsoUtils.get_depth(pos)


func _deferred_place() -> void:
	current_hp = max_hp
	place_at(start_grid_pos)


# ── HP & Damage ──────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if not is_alive:
		return
	current_hp -= amount
	current_hp  = max(0, current_hp)
	print("[%s] 💢 Menerima %d damage! HP: %d/%d" % [enemy_name, amount, current_hp, max_hp])
	if current_hp <= 0:
		_die()


func _die() -> void:
	is_alive = false
	print("[%s] 💀 Kalah!" % enemy_name)
	if sprite != null:
		sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)  # greyed out
	GridManager.unregister_entity(grid_pos)
	remove_from_group("enemies")
	await get_tree().create_timer(0.8).timeout
	queue_free()


# ── Simple AI (dipanggil oleh CombatTestBridge saat enemy phase) ─────────────

func do_ai_turn() -> void:
	if not is_alive:
		return

	# Cari player terdekat
	var players  := get_tree().get_nodes_in_group("players")
	var nearest  : Node    = null
	var near_pos : Vector2i
	var near_dist: int     = 999

	for p in players:
		var p_pos : Vector2i = p.get("grid_pos")
		var dist  : int      = abs(grid_pos.x - p_pos.x) + abs(grid_pos.y - p_pos.y)
		if dist < near_dist:
			near_dist = dist
			near_pos  = p_pos
			nearest   = p

	if nearest == null:
		print("[%s] Tidak ada target." % enemy_name)
		return

	var p_name : String = nearest.get("char_name") if nearest.get("char_name") != null else nearest.name

	if near_dist <= 1:
		# Adjacent → serang!
		print("[%s] ⚔️  Menyerang %s! (jarak 1)" % [enemy_name, p_name])
		print("[%s]    (Sistem HP player belum ada — damage tidak di-apply)" % enemy_name)
	else:
		print("[%s] 🚶 Bergerak menuju %s (jarak %d)..." % [enemy_name, p_name, near_dist])


func _setup_sprite() -> void:
	if sprite != null:
		sprite.modulate = tint_color


func _apply_idle_frames() -> void:
	var frames := _load_frames_from_dir(INSECT_DIR)
	if frames.is_empty():
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
