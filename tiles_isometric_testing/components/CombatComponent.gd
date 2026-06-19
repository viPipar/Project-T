# components/CombatComponent.gd
# Tanggung jawab:
#   Menyediakan aksi serang sederhana untuk entity runtime awal.
#   AIComponent memakai can_attack() dan attack() dari komponen ini.
#
# Cara pakai:
#   var combat := enemy.get_node("CombatComponent") as CombatComponent
#   if combat.can_attack(player):
#       combat.attack(player)
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Pastikan enemy dengan AIComponent bisa mengecek jarak target tanpa error.
#   3. Saat attack() terpanggil, target yang punya HealthComponent harus berkurang HP-nya.
extends Node
class_name CombatComponent

signal attack_resolved(attacker: Node, target: Node, result: Dictionary)

@export var attack_dice: String = "1D6"
@export var attack_range: int = 1
@export var is_magical: bool = false

var _dice: DiceRoller


func _ready() -> void:
	_dice = DiceRoller.new()
	add_child(_dice)


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

func can_attack(target: Node) -> bool:
	if owner == null or target == null:
		return false
	if _is_dead(owner) or _is_dead(target):
		return false

	var my_pos: Vector2i = owner.get("grid_pos") as Vector2i
	var target_pos: Vector2i = target.get("grid_pos") as Vector2i
	var distance: int = GridManager.get_distance(my_pos, target_pos)
	return distance <= maxi(1, attack_range)


func attack(target: Node) -> Dictionary:
	var result: Dictionary = {
		"hit": false,
		"crit": false,
		"damage": 0,
		"raw_roll": 0,
		"roll": 0,
		"threshold": 0,
	}

	if not can_attack(target):
		attack_resolved.emit(owner, target, result)
		return result

	var raw_roll: int = randi_range(1, 20)
	var acc: int = StatSystem.get_acc(owner)
	var modifier: int = floori(acc / 2.0)
	var roll: int = raw_roll + modifier
	var threshold: int = StatSystem.get_resist(target) if is_magical else StatSystem.get_armor(target)
	var crit_threshold: int = 20 - floori(acc / 10.0)
	var crit: bool = raw_roll >= crit_threshold
	var hit: bool = roll >= threshold or crit

	result["raw_roll"] = raw_roll
	result["roll"] = roll
	result["threshold"] = threshold
	result["crit"] = crit
	result["hit"] = hit

	if not hit:
		# TODO (Team): migrated from miss_occurred to on_miss
		EventBus.on_miss.emit(owner, target)
		attack_resolved.emit(owner, target, result)
		return result

	var damage: int = _dice.roll_crit(attack_dice) if crit else _dice.roll_from_string(attack_dice)
	var applied: int = StatSystem.apply_damage(target, damage, owner, "magical" if is_magical else "physical")
	result["damage"] = applied

	EventBus.damage_dealt.emit(target, applied, "magical" if is_magical else "physical", crit)
	attack_resolved.emit(owner, target, result)
	return result


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _is_dead(entity: Node) -> bool:
	var health := entity.get_node_or_null("HealthComponent") as HealthComponent
	return health != null and health.is_dead()
