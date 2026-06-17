# components/ConditionComponent.gd
# Tanggung jawab:
#   Menyimpan status/debuff sederhana milik entity dan menerapkan efek turn awal.
#   Status awal: stunned, frozen, bleeding, weakened.
#
# Cara pakai:
#   var cond := entity.get_node("ConditionComponent") as ConditionComponent
#   cond.add_condition("weakened", 2, 1, {"armor_penalty": 2})
#   if cond.is_stunned():
#       TurnManager.request_end_turn()
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Tambahkan condition lewat debugger/script, misalnya add_condition("bleeding", 2).
#   3. Pastikan tick_turn() mengurangi durasi, bleeding mengurangi HP, dan weakened mengurangi armor.
extends Node
class_name ConditionComponent

signal condition_added(condition_id: String, stacks: int, turns_remaining: int)
signal condition_removed(condition_id: String)
signal condition_ticked(condition_id: String, turns_remaining: int)
signal condition_damage(condition_id: String, amount: int)
signal conditions_changed

const STUNNED := "stunned"
const FROZEN := "frozen"
const BLEEDING := "bleeding"
const WEAKENED := "weakened"
const WEAKENED_SOURCE_ID := "condition:weakened"

var _conditions: Dictionary = {}


func _ready() -> void:
	if EventBus != null and not EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.connect(_on_turn_started)


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

func add_condition(
	condition_id: String,
	duration: int = 1,
	stacks: int = 1,
	data: Dictionary = {}
) -> void:
	var id: String = _normalize_id(condition_id)
	if id == "":
		return

	duration = maxi(1, duration)
	stacks = maxi(1, stacks)

	if _conditions.has(id):
		var entry: Dictionary = _conditions[id] as Dictionary
		entry["turns"] = maxi(int(entry.get("turns", 0)), duration)
		entry["stacks"] = maxi(int(entry.get("stacks", 1)), stacks)
		entry["data"] = _merge_data(entry.get("data", {}), data)
		_conditions[id] = entry
	else:
		_conditions[id] = {
			"turns": duration,
			"stacks": stacks,
			"data": data.duplicate(true),
		}

	_apply_passive_mods(id)
	var current: Dictionary = _conditions[id] as Dictionary
	condition_added.emit(id, int(current["stacks"]), int(current["turns"]))
	conditions_changed.emit()


func remove_condition(condition_id: String) -> void:
	var id: String = _normalize_id(condition_id)
	if not _conditions.has(id):
		return

	_conditions.erase(id)
	if id == WEAKENED:
		_clear_weakened_mod()

	condition_removed.emit(id)
	conditions_changed.emit()


func has_condition(condition_id: String) -> bool:
	return _conditions.has(_normalize_id(condition_id))


func is_stunned() -> bool:
	return has_condition(STUNNED)


func is_frozen() -> bool:
	return has_condition(FROZEN)


func tick_turn(timing: String = "start") -> void:
	var ids: Array = _conditions.keys()
	for raw_id in ids:
		var id: String = str(raw_id)
		if not _conditions.has(id):
			continue

		if timing == "start" and id == BLEEDING:
			_apply_bleeding(id)

		var entry: Dictionary = _conditions[id] as Dictionary
		entry["turns"] = int(entry.get("turns", 1)) - 1
		_conditions[id] = entry
		condition_ticked.emit(id, int(entry["turns"]))

		if int(entry["turns"]) <= 0:
			remove_condition(id)


func clear_all() -> void:
	var ids: Array = _conditions.keys()
	for raw_id in ids:
		remove_condition(str(raw_id))


func get_conditions() -> Dictionary:
	return _conditions.duplicate(true)


# -----------------------------------------------------------------------------
# Effect Application
# -----------------------------------------------------------------------------

func _apply_passive_mods(condition_id: String) -> void:
	if condition_id == WEAKENED:
		_apply_weakened_mod()


func _apply_weakened_mod() -> void:
	var stats: StatsComponent = _get_stats()
	if stats == null or not _conditions.has(WEAKENED):
		return

	var entry: Dictionary = _conditions[WEAKENED] as Dictionary
	var stacks: int = int(entry.get("stacks", 1))
	var data: Dictionary = entry.get("data", {}) as Dictionary
	var per_stack: int = int(data.get("armor_penalty", 2))
	stats.set_mod_source(WEAKENED_SOURCE_ID, {"armor": -abs(per_stack * stacks)})


func _clear_weakened_mod() -> void:
	var stats: StatsComponent = _get_stats()
	if stats != null:
		stats.remove_mod_source(WEAKENED_SOURCE_ID)


func _apply_bleeding(condition_id: String) -> void:
	if not _conditions.has(condition_id):
		return

	var health: HealthComponent = _get_health()
	if health == null or health.is_dead():
		return

	var entry: Dictionary = _conditions[condition_id] as Dictionary
	var stacks: int = int(entry.get("stacks", 1))
	var data: Dictionary = entry.get("data", {}) as Dictionary
	var per_stack: int = int(data.get("damage", 1))
	var amount: int = maxi(0, per_stack * stacks)
	if amount <= 0:
		return

	var applied: int = health.take_damage(amount, owner, "bleeding")
	if applied > 0:
		condition_damage.emit(condition_id, applied)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _on_turn_started(entity: Node, _player_id: int) -> void:
	if entity == owner:
		tick_turn("start")


func _get_stats() -> StatsComponent:
	if owner == null:
		return null
	return owner.get_node_or_null("StatsComponent") as StatsComponent


func _get_health() -> HealthComponent:
	if owner == null:
		return null
	return owner.get_node_or_null("HealthComponent") as HealthComponent


func _normalize_id(condition_id: String) -> String:
	return condition_id.strip_edges().to_lower()


func _merge_data(current, incoming: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if typeof(current) == TYPE_DICTIONARY:
		result = current.duplicate(true)
	for key in incoming.keys():
		result[key] = incoming[key]
	return result
