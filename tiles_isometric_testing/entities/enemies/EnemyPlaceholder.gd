extends CharacterBody2D

@export var enemy_name: String = "Enemy"
@export var tint_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export var start_grid_pos: Vector2i = Vector2i(-1, -1)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var grid_pos: Vector2i = Vector2i.ZERO

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
	place_at(start_grid_pos)


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
