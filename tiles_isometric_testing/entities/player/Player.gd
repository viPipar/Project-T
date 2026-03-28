extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
#  Player
#
#  Owns animation + input reading. Movement logic lives entirely in
#  MovementComponent — this script only calls move_to() / interact_move_to()
#  and reacts to the component's signals.
# ─────────────────────────────────────────────────────────────────────────────

@export var player_id:  int    = 1
@export var char_name:  String = "Player"
@onready var sprite_p1:  AnimatedSprite2D  = $Player1Sprite
@onready var sprite_p2:  AnimatedSprite2D  = $Player2Sprite
@onready var movement:   MovementComponent = $MovementComponent

var anim_sprite: AnimatedSprite2D

var _facing:  String   = "down"
var grid_pos: Vector2i = Vector2i.ZERO
var _cursor:  Node2D   = null

const INSECT1_DIR := "res://assets/characters/insect1_placeholder"
const INSECT2_DIR := "res://assets/characters/insect2_placeholder"


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("players")
	_setup_sprite()
	_apply_idle_frames()
	anim_sprite.play("idle_" + _facing)

	movement.move_finished.connect(_on_move_finished)


func _process(_delta: float) -> void:
	# Update facing from cursor hover, but only when not mid-travel
	if not movement._is_moving and _cursor != null and _cursor.has_method("get_hovered_tile"):
		var hovered: Vector2i = _cursor.get_hovered_tile()
		if hovered.x >= 0:
			_update_facing_towards(hovered)

	anim_sprite.play("idle_" + _facing)
	
	if InputManager.is_confirm_pressed(player_id):
		_on_confirm()
	


# ── Input Handler ────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	if movement._is_moving:
		return  # don't queue new move while animating

	var target: Vector2i = Vector2i(-1, -1)
	if _cursor != null and _cursor.has_method("get_hovered_tile"):
		target = _cursor.get_hovered_tile()
	if target.x < 0:
		return

	var occupant := GridManager.get_entity_at(target)
	var entity_type := GridManager.get_entity_type(target)
	var walkable := GridManager.is_walkable(target)

	if occupant != null:
		match entity_type:
			GridManager.EntityType.ENEMY:
				print("Player ", player_id, " menyerang musuh: ", occupant.name)
				var shot = ProjectileLine.cast(grid_pos, target)
				match shot.result:
					"hit_entity":
						if player_id == 1:
							AttackCam.play(true, false)
						elif player_id == 2:
							AttackCam.play(false, true)
						print("Hit entity at ", shot.tile)
					"hit_wall":
						print("Blocked by wall at ", shot.tile)
					"miss":
						print("Nothing in the way — projectile flies through")

			GridManager.EntityType.NPC:
				print("Player ", player_id, " bicara dengan NPC: ", occupant.name)
				# TODO: tampilkan dialog NPC

			GridManager.EntityType.PLAYER:
				print("Player ", player_id, " Interaksi Player : ", occupant.player_id)
				var shot = ProjectileLine.cast(grid_pos, target)
				match shot.result:
					"hit_entity":
						if player_id == 1:
							AttackCam.play(true, false)
						elif player_id == 2:
							AttackCam.play(false, true)
						print("Hit entity at ", shot.tile)
					"hit_wall":
						print("Blocked by wall at ", shot.tile)
					"miss":
						print("Nothing in the way — projectile flies through")
				# TODO: co-op / pass turn
	elif not walkable:
		movement.interact_move_to(target)
	else:
		movement.move_to(target)

# ── Signal Callbacks ──────────────────────────────────────────────────────────

func _on_move_finished(_from: Vector2i, to: Vector2i) -> void:
	_update_facing_towards(to)


# ── Public API ────────────────────────────────────────────────────────────────

func get_grid_pos() -> Vector2i:
	return grid_pos

func get_player_id() -> int:
	return player_id

func get_movement_left() -> int:
	return movement.movement_left

func bind_cursor(cursor: Node2D) -> void:
	_cursor = cursor

func place_at(pos: Vector2i) -> void:
	if grid_pos != Vector2i.ZERO:
		GridManager.unregister_entity(grid_pos)

	grid_pos = pos
	GridManager.register_entity(pos, self, GridManager.EntityType.PLAYER)
	position = IsoUtils.world_to_iso(pos)
	z_index  = IsoUtils.get_depth(pos)


# ── Internal ──────────────────────────────────────────────────────────────────

func _setup_sprite() -> void:
	if player_id == 1:
		sprite_p1.visible = true
		sprite_p2.visible = false
		anim_sprite = sprite_p1
	elif player_id == 2:
		sprite_p1.visible = false
		sprite_p2.visible = true
		anim_sprite = sprite_p2


func _apply_idle_frames() -> void:
	var dir_path := INSECT1_DIR if player_id == 1 else INSECT2_DIR
	var frames := _load_frames_from_dir(dir_path)
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

	anim_sprite.sprite_frames = sprite_frames


func _load_frames_from_dir(dir_path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Player: tidak bisa buka folder sprite: %s" % dir_path)
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


func _update_facing_towards(target: Vector2i) -> void:
	var delta := target - grid_pos
	if delta == Vector2i.ZERO:
		return
	if abs(delta.x) > abs(delta.y):
		_facing = "right" if delta.x > 0 else "left"
	else:
		_facing = "down" if delta.y > 0 else "up"
