extends CharacterBody2D

@export var player_id: int
@export var char_name: String = "Player"

@onready var sprite_p1: AnimatedSprite2D = $Player1Sprite
@onready var sprite_p2: AnimatedSprite2D = $Player2Sprite

var anim_sprite: AnimatedSprite2D

var _facing: String = "down"

var grid_pos: Vector2i = Vector2i.ZERO
var target_pos: Vector2i
var movement_left: int = 6
var _cursor: Node2D = null

func _ready() -> void:
	add_to_group("players")
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
	# Update target from the player's floating cursor
	if _cursor != null and _cursor.has_method("get_hovered_tile"):
		var hovered: Vector2i = _cursor.get_hovered_tile()
		if hovered.x >= 0:
			target_pos = hovered
			_update_facing_towards(target_pos)

	anim_sprite.play("idle_" + _facing)

	# confirm move
	if InputManager.is_confirm_pressed(player_id):
		if _cursor != null and _cursor.has_method("get_hovered_tile"):
			var hovered_confirm: Vector2i = _cursor.get_hovered_tile()
			if hovered_confirm.x >= 0:
				_try_move(hovered_confirm)
		else:
			_try_move(target_pos)

func get_movement_left() -> int:
	return movement_left
	
func get_player_id() -> int :
	return player_id

func bind_cursor(cursor: Node2D) -> void:
	_cursor = cursor

func _update_facing_towards(target: Vector2i) -> void:
	var delta := target - grid_pos
	if delta == Vector2i.ZERO:
		return
	if abs(delta.x) > abs(delta.y):
		_facing = "right" if delta.x > 0 else "left"
	else:
		_facing = "down" if delta.y > 0 else "up"

func _try_move(target: Vector2i) -> void:
	if target == grid_pos:
		return
	if not GridManager.is_walkable(target):
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
