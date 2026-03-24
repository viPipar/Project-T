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


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("players")
	_setup_sprite()
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

	# If the tile holds an entity → walk adjacent for attack / interaction
	var occupant := GridManager.get_entity_at(target) #occupant melihat apakah ada npc,player dll
	var is_walkable := GridManager.is_walkable(target) #walkable melihat apakah walkable apa enggak
	
	if occupant != null:
		# --- LOGIC INTERAKSI ATAU ATTACK KAMU MASUK SINI ---
		print("Player ", player_id, " berinteraksi dengan: ", occupant.name)
		# Contoh memanggil AttackComponent:
		print("sementara hardcode disini dia nembak")
		var shot = ProjectileLine.cast(grid_pos, target)

		match shot.result:
			"hit_entity":
				print("Hit entity at ", shot.tile)
			"hit_wall":
				print("Blocked by wall at ", shot.tile)
			"miss":
				print("Nothing in the way — projectile flies through")
		# if has_node("AttackComponent"):
		# 	$AttackComponent.execute_attack(occupant) 
	elif not is_walkable :
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
	GridManager.register_entity(pos, self)
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


func _update_facing_towards(target: Vector2i) -> void:
	var delta := target - grid_pos
	if delta == Vector2i.ZERO:
		return
	if abs(delta.x) > abs(delta.y):
		_facing = "right" if delta.x > 0 else "left"
	else:
		_facing = "down" if delta.y > 0 else "up"
