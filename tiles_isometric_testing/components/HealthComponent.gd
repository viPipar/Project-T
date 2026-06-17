# components/HealthComponent.gd
# Tanggung jawab:
#   Mengelola HP, damage, heal, dan death untuk player/enemy.
#   Max HP bisa dibaca otomatis dari StatsComponent atau di-set manual untuk placeholder.
#
# Cara pakai:
#   var health := entity.get_node("HealthComponent") as HealthComponent
#   health.take_damage(5, attacker, "physical")
#   health.heal(3)
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Serang enemy sampai HP turun.
#   3. Pastikan hp_changed dan died terpanggil, enemy keluar dari grid saat mati.
extends Node
class_name HealthComponent

signal hp_changed(current_hp: int, max_hp: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died(killer: Node)

@export var use_stats_max_hp: bool = true
@export var starts_full: bool = true
@export var max_hp: int = 15
@export var current_hp: int = 0

var _dead: bool = false
var _stats: StatsComponent = null


func _ready() -> void:
	_stats = owner.get_node_or_null("StatsComponent") as StatsComponent
	if _stats != null and not _stats.stats_changed.is_connected(_on_stats_changed):
		_stats.stats_changed.connect(_on_stats_changed)

	if use_stats_max_hp and _stats != null:
		refresh_max_hp(false)
	elif starts_full or current_hp <= 0:
		current_hp = max_hp

	_sync_owner_hp()
	hp_changed.emit(current_hp, max_hp)


# -- Setup --------------------------------------------------------------------

func setup_from_stats(stats: StatsComponent, fill_current: bool = true) -> void:
	_stats = stats
	use_stats_max_hp = true
	refresh_max_hp(not fill_current)
	if fill_current:
		current_hp = max_hp
		_dead = false
	_sync_owner_hp()
	hp_changed.emit(current_hp, max_hp)


func setup_fixed_max(value: int, fill_current: bool = true) -> void:
	use_stats_max_hp = false
	max_hp = maxi(1, value)
	if fill_current:
		current_hp = max_hp
		_dead = false
	else:
		current_hp = clampi(current_hp, 0, max_hp)
	_sync_owner_hp()
	hp_changed.emit(current_hp, max_hp)


func refresh_max_hp(keep_ratio: bool = true) -> void:
	if not use_stats_max_hp:
		return

	var old_max := max_hp
	var ratio := 1.0
	if keep_ratio and old_max > 0:
		ratio = float(current_hp) / float(old_max)

	if _stats == null:
		_stats = owner.get_node_or_null("StatsComponent") as StatsComponent

	max_hp = _stats.get_max_hp() if _stats != null else 15
	if keep_ratio and old_max > 0:
		current_hp = clampi(int(round(max_hp * ratio)), 0, max_hp)
	elif starts_full or current_hp <= 0:
		current_hp = max_hp
	else:
		current_hp = clampi(current_hp, 0, max_hp)

	_dead = current_hp <= 0
	_sync_owner_hp()
	hp_changed.emit(current_hp, max_hp)


# -- Damage / Heal ------------------------------------------------------------

func take_damage(amount: int, attacker: Node = null, damage_type: String = "physical") -> int:
	if amount <= 0 or is_dead():
		return 0

	var applied := mini(amount, current_hp)
	current_hp = maxi(0, current_hp - applied)
	_sync_owner_hp()
	damaged.emit(applied)
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		kill(attacker)

	return applied


func heal(amount: int, source: Node = null) -> int:
	if amount <= 0 or is_dead():
		return 0

	var before := current_hp
	current_hp = mini(max_hp, current_hp + amount)
	var restored := current_hp - before
	_sync_owner_hp()
	healed.emit(restored)
	hp_changed.emit(current_hp, max_hp)
	return restored


func kill(killer: Node = null) -> void:
	if _dead:
		return
	_dead = true
	current_hp = 0
	_sync_owner_hp()
	hp_changed.emit(current_hp, max_hp)
	died.emit(killer)
	if EventBus != null:
		EventBus.entity_died.emit(owner, killer)


func revive(percent: float = 0.2) -> void:
	_dead = false
	current_hp = clampi(int(ceil(max_hp * percent)), 1, max_hp)
	_sync_owner_hp()
	hp_changed.emit(current_hp, max_hp)


func is_dead() -> bool:
	return _dead or current_hp <= 0


# -- Internal -----------------------------------------------------------------

func _on_stats_changed() -> void:
	refresh_max_hp(true)


func _sync_owner_hp() -> void:
	if owner == null:
		return
	if _has_owner_property("max_hp"):
		owner.set("max_hp", max_hp)
	if _has_owner_property("current_hp"):
		owner.set("current_hp", current_hp)
	if _has_owner_property("is_alive"):
		owner.set("is_alive", not is_dead())


func _has_owner_property(prop_name: String) -> bool:
	for info in owner.get_property_list():
		if info.name == prop_name:
			return true
	return false
