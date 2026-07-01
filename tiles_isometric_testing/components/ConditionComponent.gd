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
const VULNERABLE := "vulnerable"
const LACERATE := "lacerate"
const AUTOTOMY_ARMOR_BUFF := "autotomy_armor_buff"
const WEAKENED_SOURCE_ID := "condition:weakened"
const AUTOTOMY_SOURCE_ID := "condition:autotomy"

var _conditions: Dictionary = {}
var _status_db: Dictionary = {}

func _ready() -> void:
	_load_status_db()
	if EventBus != null and not EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.connect(_on_turn_started)
	if EventBus != null and not EventBus.on_status_applied.is_connected(_on_status_applied):
		EventBus.on_status_applied.connect(_on_status_applied)
	if EventBus != null and not EventBus.on_status_removed.is_connected(_on_status_removed):
		EventBus.on_status_removed.connect(_on_status_removed)
		
	call_deferred("_inject_visualizer")

func _inject_visualizer() -> void:
	var parent = get_parent()
	if not parent: return
	
	if not parent.has_node("StatusVisualizerComponent"):
		var scene = load("res://components/StatusVisualizerComponent.tscn")
		if scene:
			var viz = scene.instantiate()
			parent.add_child(viz)
			viz.owner = parent

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

	var parent = get_parent()
	var pname = parent.name if parent else "Unknown"
	print("[Condition] %s terkena status: %s (Durasi: %d)" % [pname, id, duration])

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
	elif id == AUTOTOMY_ARMOR_BUFF:
		_clear_autotomy_armor_buff()
	else:
		_clear_dynamic_mod(id)

	var parent = get_parent()
	var pname = parent.name if parent else "Unknown"
	print("[Condition] %s sembuh dari status: %s" % [pname, id])

	condition_removed.emit(id)
	conditions_changed.emit()


func has_condition(condition_id: String) -> bool:
	return _conditions.has(_normalize_id(condition_id))

func get_condition_turns(condition_id: String) -> int:
	var id = _normalize_id(condition_id)
	if _conditions.has(id):
		return int(_conditions[id].get("turns", 0))
	return 0


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

		if timing == "start":
			if id == BLEEDING:
				_apply_bleeding(id)
			elif id == LACERATE:
				_apply_lacerate(id)
			elif _status_db.has(id):
				var db_entry = _status_db[id]
				if db_entry.has("dot") and db_entry["dot"].get("timing", "start") == timing:
					var dot = db_entry["dot"]
					_apply_dynamic_dot(id, int(dot.get("damage", 1)), dot.get("damage_type", "true"))

		var entry: Dictionary = _conditions[id] as Dictionary
		entry["turns"] = int(entry.get("turns", 1)) - 1
		_conditions[id] = entry
		condition_ticked.emit(id, int(entry["turns"]))

		if int(entry["turns"]) <= 0:
			if EventBus != null and EventBus.has_signal("on_status_removed"):
				EventBus.on_status_removed.emit(get_parent(), id)
			else:
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
	elif condition_id == AUTOTOMY_ARMOR_BUFF:
		_apply_autotomy_armor_buff()
	else:
		_apply_dynamic_mod(condition_id)

func _apply_dynamic_mod(id: String) -> void:
	var stats: StatsComponent = _get_stats()
	if stats == null or not _conditions.has(id) or not _status_db.has(id):
		return
	var db_entry = _status_db[id]
	if db_entry.has("stat_mods") and typeof(db_entry["stat_mods"]) == TYPE_DICTIONARY and not db_entry["stat_mods"].is_empty():
		var mods = db_entry["stat_mods"]
		var entry = _conditions[id] as Dictionary
		var stacks: int = int(entry.get("stacks", 1))
		var scaled_mods = {}
		for stat in mods.keys():
			scaled_mods[stat] = mods[stat] * stacks
		stats.set_mod_source("condition:" + id, scaled_mods)

func _clear_dynamic_mod(id: String) -> void:
	if _status_db.has(id):
		var db_entry = _status_db[id]
		if db_entry.has("stat_mods") and typeof(db_entry["stat_mods"]) == TYPE_DICTIONARY and not db_entry["stat_mods"].is_empty():
			var stats: StatsComponent = _get_stats()
			if stats != null:
				stats.remove_mod_source("condition:" + id)

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


func _apply_autotomy_armor_buff() -> void:
	var stats: StatsComponent = _get_stats()
	if stats == null or not _conditions.has(AUTOTOMY_ARMOR_BUFF):
		return

	var entry: Dictionary = _conditions[AUTOTOMY_ARMOR_BUFF] as Dictionary
	var stacks: int = int(entry.get("stacks", 1))
	# AutotomyAbility emits stacks = 4 to mean +4 armor
	stats.set_mod_source(AUTOTOMY_SOURCE_ID, {"armor": stacks})


func _clear_autotomy_armor_buff() -> void:
	var stats: StatsComponent = _get_stats()
	if stats != null:
		stats.remove_mod_source(AUTOTOMY_SOURCE_ID)


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

	var parent = get_parent()
	var pname = parent.name if parent else "Unknown"
	print("[Condition] %s terkena tick DoT (%s): %d damage" % [pname, condition_id, amount])

	var applied: int = health.take_damage(amount, parent, "bleeding")
	if applied > 0:
		condition_damage.emit(condition_id, applied)
		if EventBus != null and EventBus.has_signal("damage_dealt"):
			EventBus.damage_dealt.emit(parent, applied, "bleeding", false, null)

func _apply_lacerate(condition_id: String) -> void:
	if not _conditions.has(condition_id):
		return

	var health: HealthComponent = _get_health()
	if health == null or health.is_dead():
		return

	var entry: Dictionary = _conditions[condition_id] as Dictionary
	var stacks: int = int(entry.get("stacks", 1))
	var data: Dictionary = entry.get("data", {}) as Dictionary
	var per_stack: int = int(data.get("damage", 2)) # Lacerate base dmg
	var amount: int = maxi(0, per_stack * stacks)
	if amount <= 0:
		return

	var parent = get_parent()
	var pname = parent.name if parent else "Unknown"
	print("[Condition] %s terkena tick DoT (%s): %d damage" % [pname, condition_id, amount])

	var applied: int = health.take_damage(amount, parent, "lacerate")
	if applied > 0:
		condition_damage.emit(condition_id, applied)
		if EventBus != null and EventBus.has_signal("damage_dealt"):
			EventBus.damage_dealt.emit(parent, applied, "lacerate", false, null)

func _apply_dynamic_dot(condition_id: String, damage_per_stack: int, damage_type: String) -> void:
	if not _conditions.has(condition_id):
		return

	var entry: Dictionary = _conditions[condition_id] as Dictionary
	var stacks: int = int(entry.get("stacks", 1))
	var total_dmg: int = damage_per_stack * stacks

	var parent = get_parent()
	var pname = parent.name if parent else "Unknown"
	print("[Condition] %s terkena %s DoT: %d damage" % [pname, condition_id, total_dmg])

	var applied := 0
	var health: HealthComponent = _get_health()

	if health != null:
		applied = health.take_damage(total_dmg, null, damage_type)
	else:
		var stat_sys = get_node_or_null("/root/StatSystem")
		if is_instance_valid(stat_sys) and stat_sys.has_method("apply_damage"):
			applied = stat_sys.apply_damage(parent, total_dmg, null, damage_type)

	if EventBus != null and applied > 0:
		EventBus.damage_dealt.emit(parent, applied, damage_type, false, null)

# -----------------------------------------------------------------------------
# Internal
# -----------------------------------------------------------------------------

func _load_status_db() -> void:
	var f = FileAccess.open("res://data/stat_module/condition_stat_mods/status_effects.json", FileAccess.READ)
	if f:
		var txt = f.get_as_text()
		var json = JSON.parse_string(txt)
		if typeof(json) == TYPE_DICTIONARY and json.has("conditions"):
			_status_db = json["conditions"]
		f.close()

func _normalize_id(condition_id: String) -> String:
	return condition_id.strip_edges().to_lower()

func _on_turn_started(entity: Node, _player_id: int) -> void:
	if entity == get_parent():
		tick_turn("start")

func _on_status_applied(entity: Node, status_id: String, duration: int, stacks: int) -> void:
	if entity == get_parent():
		add_condition(status_id, duration, stacks, {})

func _on_status_removed(entity: Node, status_id: String) -> void:
	if entity == get_parent():
		remove_condition(status_id)

func _get_stats() -> StatsComponent:
	var p = get_parent()
	if p == null:
		return null
	return p.get_node_or_null("StatsComponent") as StatsComponent

func _get_health() -> HealthComponent:
	var p = get_parent()
	if p == null:
		return null
	return p.get_node_or_null("HealthComponent") as HealthComponent




func _merge_data(current, incoming: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if typeof(current) == TYPE_DICTIONARY:
		result = current.duplicate(true)
	for key in incoming.keys():
		result[key] = incoming[key]
	return result
