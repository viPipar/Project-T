extends CharacterBody2D

@export var player_id: int
@export var char_name: String = "Player"

@onready var sprite_p1: AnimatedSprite2D = $Player1Sprite
@onready var sprite_p2: AnimatedSprite2D = $Player2Sprite

var anim_sprite: AnimatedSprite2D

var _facing: String = "down"

var grid_pos: Vector2i = Vector2i.ZERO
var target_pos: Vector2i
var movement_left: int = 2

func _ready() -> void:
	target_pos = grid_pos
	_setup_sprite()
	anim_sprite.play("idle_" + _facing)

func _setup_sprite() -> void:
	if player_id == 1:
		sprite_p1.visible = true
		sprite_p2.visible = false
		anim_sprite = sprite_p1
	elif player_id == 2:
		sprite_p1.visible = false
		sprite_p2.visible = true
		anim_sprite = sprite_p2

func _process(_delta: float) -> void:
	var dir := InputManager.get_movement_dir(player_id)

	# 🟡 gerakin TARGET
	if dir != Vector2i.ZERO:
		target_pos += dir

		# clamp biar nggak keluar grid
		target_pos.x = clamp(target_pos.x, 0, GridManager.grid_size.x - 1)
		target_pos.y = clamp(target_pos.y, 0, GridManager.grid_size.y - 1)

		# update facing
		if dir.y < 0:
			_facing = "up"
		elif dir.y > 0:
			_facing = "down"
		elif dir.x < 0:
			_facing = "left"
		elif dir.x > 0:
			_facing = "right"

		anim_sprite.play("walk_" + _facing)

		print(player_id, " TARGET:", target_pos)
	else:
		anim_sprite.play("idle_" + _facing)

	# 🔵 confirm move
	if InputManager.is_confirm_pressed(player_id):
		_try_move(target_pos)

func _try_move(target: Vector2i) -> void:
	if target == grid_pos:
		return

	var cost := GridManager.get_path_cost(grid_pos, target)

	if cost < 0 or cost > movement_left:
		return

	var from := grid_pos
	GridManager.move_entity(from, target, self)

	grid_pos   = target
	target_pos = grid_pos
	movement_left -= cost

	position = IsoUtils.world_to_iso(grid_pos)
	z_index  = IsoUtils.get_depth(grid_pos)

	EventBus.player_moved.emit(self, from, target)

func get_grid_pos() -> Vector2i:
	return grid_pos

func place_at(pos: Vector2i) -> void:
	if grid_pos != Vector2i.ZERO:
		GridManager.unregister_entity(grid_pos)

	grid_pos   = pos
	target_pos = pos

	GridManager.register_entity(pos, self)

	position = IsoUtils.world_to_iso(pos)
	z_index  = IsoUtils.get_depth(pos)
