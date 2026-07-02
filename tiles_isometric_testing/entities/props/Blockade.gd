extends Node2D

var grid_pos: Vector2i = Vector2i(-1, -1)
var hp: int = 15
var max_hp: int = 15
var armor: int = 10
var element_tag: String = "earth"
var is_dead: bool = false
var enemy_name: String = "Rock Blockade"

# Fake node reference for stat system
@onready var health_component = self

func _ready() -> void:
	add_to_group("enemies") # Need to be targetable by players and enemies
	add_to_group("skip_turn") # But should not take turns
	if grid_pos.x >= 0:
		GridManager.register_entity(grid_pos, self, GridManager.EntityType.NPC) # NPC or ENEMY to block path
		
	# Appear animation
	scale = Vector2.ZERO
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.3)

func get_armor() -> int:
	return armor

func take_damage(amount: int, _attacker: Node = null, _damage_type: String = "physical") -> int:
	if is_dead: return 0
	
	hp -= amount
	if hp <= 0:
		hp = 0
		_die()
		
	return amount

func _die() -> void:
	is_dead = true
	GridManager.unregister_entity(grid_pos)
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2(2.4, 2.4), 0.2)
	await tw.finished
	queue_free()

# Dummy methods to prevent crashes from status effects or components
func play_attack(_ability_id: String) -> void:
	pass
func get_damage_modifier() -> int:
	return 0
func has_condition(_cond: String) -> bool:
	return false
