# combat_core/_mock/MockEntity.gd
# Dummy entity untuk testing Phase Manager dan RNG Combat
# Gunakan node ini sebagai pengganti Player/Enemy nyata saat testing standalone
class_name MockEntity
extends Node

signal died(entity: Node)

@export var entity_name : String = "DummyEntity"
@export var is_player   : bool   = false
@export var player_id   : int    = -1      # -1 = enemy, 1 = P1, 2 = P2
@export var mock_dex    : int    = 8       # untuk inisiatif sorting di EnemyPhaseManager

var is_alive   : bool = true
var current_hp : int  = 50
var max_hp     : int  = 50

# Tambahkan ke group "enemies" atau "players" agar bisa ditemukan oleh TurnManager
func _ready() -> void:
	if is_player:
		add_to_group("players")
	else:
		add_to_group("enemies")


func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		is_alive   = false
		died.emit(self)
		print("[MockEntity] %s died." % entity_name)


func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)


func is_dead() -> bool:
	return not is_alive


## Placeholder untuk AI turn — EnemyPhaseManager akan memanggil ini
func do_ai_turn() -> void:
	print("[MockEntity] %s does nothing (stub AI turn)." % entity_name)
