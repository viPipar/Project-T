extends Node

# Owns roguelike run state that must survive scene changes.

signal run_started()
signal run_ended(victory: bool)
signal layer_advanced(new_depth: int)
signal node_map_generated(seed_value: int)
signal node_traveled(node_id: int, node_type: int, depth: int)
signal run_saved(save_path: String)
signal run_loaded(save_path: String)
signal player_state_changed(player_id: int)

const RunPlayerStateHelper = preload("res://systems/progression/RunPlayerState.gd")

const SAVE_VERSION := 1
const SAVE_PATH := "user://run_save.json"
const RANDOM_NODE_MAP_SEED := -1
const PLAYER_IDS := [1, 2]
const PLAYER_ENTITY_IDS := {
	1: "aria",
	2: "kael",
}

var is_run_active: bool = false
var current_depth: int = 1
var max_depth: int = NodeGraph.TOTAL_LAYERS

var p1_saved_energy: int = -1
var p2_saved_slots: Array = []

var node_graph: NodeGraph = null
var path_handler: PathHandler = null
var node_map_seed: int = -1
var pending_node_id: int = -1
var pending_node_type: int = -1
var configured_node_map_seed: int = RANDOM_NODE_MAP_SEED

var run_id: String = ""
var players: Dictionary = {}

var _syncing_inventory: bool = false
var _syncing_coins: bool = false


func _ready() -> void:
	if EventBus != null and not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)
	_connect_external_state()
	call_deferred("_connect_external_state")


func start_run(new_seed: int = RANDOM_NODE_MAP_SEED) -> void:
	if is_run_active:
		push_warning("RunManager: Attempted to start a run while one is already active.")
		ensure_node_map()
		return

	print("[RunManager] --- NEW RUN STARTED ---")
	is_run_active = true
	current_depth = 1
	run_id = _make_run_id()
	pending_node_id = -1
	pending_node_type = -1

	_init_players_from_defaults()
	_sync_inventory_to_runtime()
	_sync_coins_to_runtime()
	_sync_legacy_resources_from_players()

	_generate_node_map(_resolve_node_map_seed(new_seed))
	run_started.emit()
	save_run_to_disk()


func end_run(victory: bool) -> void:
	if not is_run_active:
		return

	is_run_active = false
	save_run_to_disk()
	_clear_node_map_state()
	if victory:
		print("[RunManager] VICTORY! Run completed successfully.")
	else:
		print("[RunManager] GAME OVER! Run failed.")

	run_ended.emit(victory)

	var result_screen = load("res://ui/roguelike/RunResultScreen.gd").new()
	result_screen.set_state(victory)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(result_screen)


func advance_layer() -> void:
	if not is_run_active:
		return

	current_depth += 1
	print("[RunManager] Advancing to Depth Layer: %d" % current_depth)

	if current_depth > max_depth:
		end_run(true)
	else:
		layer_advanced.emit(current_depth)
		save_run_to_disk()


func ensure_node_map(new_seed: int = RANDOM_NODE_MAP_SEED) -> void:
	if not is_run_active:
		start_run(new_seed)
		return
	if node_graph == null or path_handler == null:
		_generate_node_map(_resolve_node_map_seed(new_seed))
		save_run_to_disk()


func get_node_graph() -> NodeGraph:
	ensure_node_map()
	return node_graph


func get_path_handler() -> PathHandler:
	ensure_node_map()
	return path_handler


func get_node_map_seed() -> int:
	ensure_node_map()
	return node_map_seed


func set_configured_node_map_seed(seed_value: int) -> void:
	configured_node_map_seed = seed_value


func use_random_node_map_seed() -> void:
	configured_node_map_seed = RANDOM_NODE_MAP_SEED


func get_configured_node_map_seed() -> int:
	return configured_node_map_seed


func get_current_map_node():
	if node_graph == null or path_handler == null or path_handler.current_node_id == -1:
		return null
	return node_graph.get_node_by_id(path_handler.current_node_id)


func get_pending_node():
	if node_graph == null or pending_node_id == -1:
		return null
	return node_graph.get_node_by_id(pending_node_id)


func clear_pending_node() -> void:
	pending_node_id = -1
	pending_node_type = -1
	save_run_to_disk()


func travel_to_node(node_id: int) -> bool:
	ensure_node_map()
	if node_graph == null or path_handler == null:
		return false

	if not path_handler.travel_to(node_id):
		return false

	var node = node_graph.get_node_by_id(node_id)
	if node == null:
		return false

	current_depth = node.depth
	pending_node_id = node_id
	pending_node_type = node.type
	node_traveled.emit(node_id, node.type, node.depth)

	if node_graph.is_final_node(node_id):
		print("[RunManager] Final boss node selected.")

	save_run_to_disk()
	return true


func complete_pending_node(duration_trigger: String = "node_completed") -> void:
	if pending_node_id == -1:
		save_run_to_disk()
		return

	if path_handler != null and path_handler.current_node_id != -1:
		if not path_handler.completed_node_ids.has(path_handler.current_node_id):
			path_handler.completed_node_ids.append(path_handler.current_node_id)

	tick_effects(duration_trigger)
	pending_node_id = -1
	pending_node_type = -1
	save_run_to_disk()


func get_node_map_state() -> Dictionary:
	ensure_node_map()
	return {
		"seed": node_map_seed,
		"current_depth": current_depth,
		"pending_node_id": pending_node_id,
		"pending_node_type": pending_node_type,
		"path": path_handler.get_progress_state() if path_handler != null else {},
	}


func restore_node_map_state(state: Dictionary) -> void:
	var restored_seed = int(state.get("seed", -1))
	is_run_active = true

	if restored_seed == -1:
		_generate_node_map(-1)
		return

	_generate_node_map(restored_seed)
	var path_state = state.get("path", {})
	if path_state is Dictionary and path_handler != null:
		path_handler.restore_progress(
			node_graph,
			int(path_state.get("current_node_id", -1)),
			path_state.get("completed_node_ids", [])
		)

	current_depth = int(state.get("current_depth", current_depth))
	pending_node_id = int(state.get("pending_node_id", -1))
	pending_node_type = int(state.get("pending_node_type", -1))
	save_run_to_disk()


func get_player_state(player_id: int) -> Dictionary:
	return _get_mutable_player_state(player_id).duplicate(true)


func get_all_player_states() -> Dictionary:
	var result: Dictionary = {}
	for player_id in players.keys():
		result[int(player_id)] = get_player_state(int(player_id))
	return result


func add_run_item(player_id: int, item_id: String, mirror_inventory: bool = true) -> bool:
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		return false

	if mirror_inventory and not _syncing_inventory and InventoryManager != null and InventoryManager.has_method("add_item"):
		_syncing_inventory = true
		var added = InventoryManager.add_item(player_id, clean_item_id)
		_syncing_inventory = false
		if typeof(added) == TYPE_BOOL and not added:
			return false

	var state := _get_mutable_player_state(player_id)
	var items: Array = state.get("items", [])
	if items.size() >= _get_inventory_max_items():
		return false
	items.append(clean_item_id)
	state["items"] = items
	player_state_changed.emit(player_id)
	save_run_to_disk()
	return true


func remove_run_item(player_id: int, item_id: String, mirror_inventory: bool = true) -> bool:
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		return false

	if mirror_inventory and not _syncing_inventory and InventoryManager != null and InventoryManager.has_method("remove_item"):
		_syncing_inventory = true
		var removed = InventoryManager.remove_item(player_id, clean_item_id)
		_syncing_inventory = false
		if typeof(removed) == TYPE_BOOL and not removed:
			return false

	var state := _get_mutable_player_state(player_id)
	var items: Array = state.get("items", [])
	if not items.has(clean_item_id):
		return false
	items.erase(clean_item_id)
	state["items"] = items
	player_state_changed.emit(player_id)
	save_run_to_disk()
	return true


func set_run_base_stat(player_id: int, stat_key: String, value: int) -> bool:
	var normalized_key := RunPlayerStateHelper.normalize_stat_key(stat_key)
	var state := _get_mutable_player_state(player_id)
	var base_stats: Dictionary = state.get("base_stats", {})
	if not base_stats.has(normalized_key):
		return false

	base_stats[normalized_key] = maxi(0, value)
	state["base_stats"] = base_stats
	state["max_hp"] = _estimate_max_hp_from_base_stats(base_stats)
	state["current_hp"] = clampi(int(state.get("current_hp", state["max_hp"])), 0, int(state["max_hp"]))

	var live_player := _find_player_node(player_id)
	if live_player != null:
		var stats := live_player.get_node_or_null("StatsComponent") as StatsComponent
		if stats != null:
			stats.set_base_stat(normalized_key, int(base_stats[normalized_key]))
		var health := live_player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.refresh_max_hp(false)
			health.set_hp(int(state["current_hp"]))

	player_state_changed.emit(player_id)
	save_run_to_disk()
	return true


func add_run_base_stat(player_id: int, stat_key: String, amount: int) -> bool:
	var state := _get_mutable_player_state(player_id)
	var base_stats: Dictionary = state.get("base_stats", {})
	var normalized_key := RunPlayerStateHelper.normalize_stat_key(stat_key)
	return set_run_base_stat(player_id, normalized_key, int(base_stats.get(normalized_key, 0)) + amount)


func set_run_current_hp(player_id: int, current_hp: int) -> void:
	var state := _get_mutable_player_state(player_id)
	var max_hp := _get_state_max_hp(state)
	state["current_hp"] = clampi(current_hp, 0, max_hp)
	state["max_hp"] = max_hp

	var live_player := _find_player_node(player_id)
	if live_player != null:
		var health := live_player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.set_hp(int(state["current_hp"]))

	player_state_changed.emit(player_id)
	save_run_to_disk()


func heal_run_player(player_id: int, amount: int) -> void:
	var state := _get_mutable_player_state(player_id)
	set_run_current_hp(player_id, int(state.get("current_hp", _get_state_max_hp(state))) + maxi(0, amount))


func damage_run_player(player_id: int, amount: int) -> void:
	var state := _get_mutable_player_state(player_id)
	set_run_current_hp(player_id, int(state.get("current_hp", _get_state_max_hp(state))) - maxi(0, amount))


func get_run_max_hp(player_id: int) -> int:
	return _get_state_max_hp(_get_mutable_player_state(player_id))


func set_run_resource(player_id: int, resource_key: String, value: Variant) -> void:
	var state := _get_mutable_player_state(player_id)
	var resources: Dictionary = RunPlayerStateHelper.sanitize_resources(state.get("resources", {}))
	match resource_key:
		"energy":
			resources["energy"] = int(value)
			if player_id == 1:
				p1_saved_energy = int(value)
		"spell_slots":
			var slots: Array = []
			if value is Array:
				for slot in value:
					slots.append(maxi(0, int(slot)))
			resources["spell_slots"] = slots
			if player_id == 2:
				p2_saved_slots = slots.duplicate()
		_:
			return

	state["resources"] = resources
	_apply_resources_to_bridge(player_id)
	player_state_changed.emit(player_id)
	save_run_to_disk()


func set_run_coins(player_id: int, coins: int, mirror_wallet: bool = true) -> void:
	var state := _get_mutable_player_state(player_id)
	state["coins"] = maxi(0, coins)

	if mirror_wallet and not _syncing_coins and CoinEconomy != null and CoinEconomy.has_method("set_balance"):
		_syncing_coins = true
		CoinEconomy.set_balance(player_id, int(state["coins"]))
		_syncing_coins = false

	player_state_changed.emit(player_id)
	save_run_to_disk()


func add_run_coins(player_id: int, amount: int, mirror_wallet: bool = true) -> void:
	var state := _get_mutable_player_state(player_id)
	set_run_coins(player_id, int(state.get("coins", 0)) + amount, mirror_wallet)


func apply_run_effect(player_id: int, effect_data: Dictionary) -> bool:
	var effect := RunPlayerStateHelper.sanitize_effect(effect_data)
	if effect.is_empty():
		return false

	var state := _get_mutable_player_state(player_id)
	var effects: Array = state.get("active_effects", [])
	var source_id := str(effect["source_id"])
	var replaced := false
	for i in range(effects.size()):
		var existing = effects[i]
		if existing is Dictionary and str(existing.get("source_id", "")) == source_id:
			effects[i] = effect
			replaced = true
			break
	if not replaced:
		effects.append(effect)

	state["active_effects"] = effects
	_apply_effect_to_live_player(player_id, effect)
	player_state_changed.emit(player_id)
	save_run_to_disk()
	return true


func remove_run_effect(player_id: int, source_id: String) -> bool:
	var state := _get_mutable_player_state(player_id)
	var effects: Array = state.get("active_effects", [])
	var kept: Array = []
	var removed := false

	for effect in effects:
		if effect is Dictionary and str(effect.get("source_id", "")) == source_id:
			removed = true
			continue
		kept.append(effect)

	if not removed:
		return false

	state["active_effects"] = kept
	_remove_effect_from_live_player(player_id, source_id)
	player_state_changed.emit(player_id)
	save_run_to_disk()
	return true


func remove_run_effects_by_duration(player_id: int, duration_type: String) -> bool:
	var state := _get_mutable_player_state(player_id)
	var effects: Array = state.get("active_effects", [])
	var kept: Array = []
	var removed := false

	for effect in effects:
		if effect is Dictionary and str(effect.get("duration_type", "")) == duration_type:
			_remove_effect_from_live_player(player_id, str(effect.get("source_id", "")))
			removed = true
			continue
		kept.append(effect)

	if not removed:
		return false

	state["active_effects"] = kept
	player_state_changed.emit(player_id)
	save_run_to_disk()
	return true


func tick_effects(trigger_type: String) -> bool:
	var changed := false
	for player_id in players.keys():
		var state := _get_mutable_player_state(int(player_id))
		var effects: Array = state.get("active_effects", [])
		var kept: Array = []

		for raw_effect in effects:
			if not (raw_effect is Dictionary):
				continue
			var effect := RunPlayerStateHelper.sanitize_effect(raw_effect as Dictionary)
			if effect.is_empty():
				continue

			var source_id := str(effect["source_id"])
			var expired := false
			var duration_type := str(effect.get("duration_type", "permanent"))
			if _should_tick_duration(duration_type, trigger_type):
				effect["remaining"] = int(effect.get("remaining", -1)) - 1
				changed = true
				if int(effect["remaining"]) <= 0:
					expired = true
			elif duration_type == "until_rest" and trigger_type in ["rest_completed", "rest"]:
				expired = true
				changed = true

			if expired:
				_remove_effect_from_live_player(int(player_id), source_id)
			else:
				kept.append(effect)

		state["active_effects"] = kept

	if changed:
		save_run_to_disk()
	return changed


func snapshot_player_from_node(player_node: Node, should_save: bool = true) -> bool:
	if player_node == null:
		return false

	var player_id := _get_player_id_from_node(player_node)
	if player_id <= 0:
		return false

	var state := _get_mutable_player_state(player_id)
	var stats := player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		var base_stats: Dictionary = {}
		for key in StatsComponent.PRIMARY_KEYS:
			base_stats[key] = stats.get_base_stat(key)
		state["base_stats"] = base_stats

	var health := player_node.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		state["current_hp"] = health.get_hp()
		state["max_hp"] = health.get_max_hp()
	elif stats != null:
		state["max_hp"] = stats.get_max_hp()
		state["current_hp"] = clampi(int(state.get("current_hp", state["max_hp"])), 0, int(state["max_hp"]))

	if InventoryManager != null and InventoryManager.has_method("get_player_items"):
		state["items"] = InventoryManager.get_player_items(player_id)

	if CoinEconomy != null and CoinEconomy.has_method("get_balance"):
		state["coins"] = CoinEconomy.get_balance(player_id)

	_snapshot_resources_from_bridge(player_id)
	_sync_legacy_resources_from_players()
	player_state_changed.emit(player_id)

	if should_save:
		save_run_to_disk()
	return true


func snapshot_all_players(should_save: bool = true) -> void:
	if is_inside_tree():
		for player in get_tree().get_nodes_in_group("players"):
			snapshot_player_from_node(player, false)
	_snapshot_resources_from_bridge(1)
	_snapshot_resources_from_bridge(2)
	_sync_legacy_resources_from_players()
	if should_save:
		save_run_to_disk()


func hydrate_player_node(player_node: Node, player_id: int = -1) -> bool:
	if player_node == null:
		return false

	var resolved_player_id := player_id
	if resolved_player_id <= 0:
		resolved_player_id = _get_player_id_from_node(player_node)
	if resolved_player_id <= 0:
		return false

	var state := _get_mutable_player_state(resolved_player_id)
	var stats := player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		var base_stats: Dictionary = state.get("base_stats", {})
		for key in StatsComponent.PRIMARY_KEYS:
			stats.set_base_stat(key, int(base_stats.get(key, stats.get_base_stat(key))))
		stats.clear_mod_sources("item:")
		stats.clear_mod_sources("buff:")
		stats.clear_mod_sources("debuff:")
		stats.clear_mod_sources("effect:")
		stats.clear_mod_sources("condition:")

	_sync_inventory_to_runtime_player(resolved_player_id)
	_apply_inventory_effects_to_player(player_node, resolved_player_id)

	for raw_effect in state.get("active_effects", []):
		if raw_effect is Dictionary:
			_apply_effect_to_player_node(player_node, raw_effect as Dictionary)

	var health := player_node.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		if stats != null:
			health.setup_from_stats(stats, false)
		var max_hp := health.get_max_hp()
		state["max_hp"] = max_hp
		var saved_hp := int(state.get("current_hp", max_hp))
		if saved_hp < 0:
			saved_hp = max_hp
		health.set_hp(clampi(saved_hp, 0, max_hp))
		state["current_hp"] = health.get_hp()

	_apply_resources_to_bridge(resolved_player_id)
	_sync_coins_to_runtime_player(resolved_player_id)
	player_state_changed.emit(resolved_player_id)
	return true


func get_run_save_state() -> Dictionary:
	var path_state := {}
	if path_handler != null:
		path_state = path_handler.get_progress_state()

	return {
		"version": SAVE_VERSION,
		"run_id": run_id,
		"is_run_active": is_run_active,
		"node_map_seed": node_map_seed,
		"current_depth": current_depth,
		"pending_node_id": pending_node_id,
		"pending_node_type": pending_node_type,
		"path": path_state,
		"players": _serialize_players_for_save(),
	}


func restore_run_save_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false

	var version := int(state.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("[RunManager] Save version %d is newer than supported %d." % [version, SAVE_VERSION])
		return false

	run_id = str(state.get("run_id", _make_run_id()))
	is_run_active = bool(state.get("is_run_active", true))
	current_depth = int(state.get("current_depth", 1))
	pending_node_id = int(state.get("pending_node_id", -1))
	pending_node_type = int(state.get("pending_node_type", -1))

	var restored_seed := int(state.get("node_map_seed", state.get("seed", RANDOM_NODE_MAP_SEED)))
	_generate_node_map(restored_seed)

	var path_state = state.get("path", {})
	if path_state is Dictionary and path_handler != null:
		path_handler.restore_progress(
			node_graph,
			int(path_state.get("current_node_id", -1)),
			path_state.get("completed_node_ids", [])
		)

	_restore_players_from_save(state.get("players", {}))
	_sync_legacy_resources_from_players()
	_sync_inventory_to_runtime()
	_sync_coins_to_runtime()

	run_loaded.emit(SAVE_PATH)
	return true


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save_file() -> bool:
	if not has_save_file():
		return true
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	return dir.remove("run_save.json") == OK


func save_run_to_disk() -> bool:
	if run_id == "":
		run_id = _make_run_id()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[RunManager] Failed to write save: %s" % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(get_run_save_state(), "\t"))
	run_saved.emit(SAVE_PATH)
	return true


func load_run_from_disk() -> bool:
	if not has_save_file():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[RunManager] Failed to open save: %s" % SAVE_PATH)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("[RunManager] Save file is corrupt. Starting run is still safe.")
		return false

	return restore_run_save_state(parsed)


func _generate_node_map(new_seed: int = RANDOM_NODE_MAP_SEED) -> void:
	node_graph = NodeGraph.new()
	node_graph.generate(new_seed)
	node_map_seed = node_graph.seed_value

	path_handler = PathHandler.new()
	path_handler.init(node_graph)
	max_depth = node_graph.get_total_depth()
	node_map_generated.emit(node_map_seed)


func _resolve_node_map_seed(requested_seed: int) -> int:
	if requested_seed != RANDOM_NODE_MAP_SEED:
		return requested_seed
	return configured_node_map_seed


func _clear_node_map_state() -> void:
	node_graph = null
	path_handler = null
	node_map_seed = -1
	pending_node_id = -1
	pending_node_type = -1


func _on_player_died(_player_id: int) -> void:
	end_run(false)


func _on_combat_ended(result: String) -> void:
	print("[RunManager] Combat ended: %s. Saving player run state." % result)
	snapshot_all_players(false)
	tick_effects("battle_completed")
	save_run_to_disk()


func _connect_external_state() -> void:
	if InventoryManager != null:
		if not InventoryManager.item_added.is_connected(_on_inventory_item_added):
			InventoryManager.item_added.connect(_on_inventory_item_added)
		if not InventoryManager.item_removed.is_connected(_on_inventory_item_removed):
			InventoryManager.item_removed.connect(_on_inventory_item_removed)

	if CoinEconomy != null and not CoinEconomy.balance_changed.is_connected(_on_coin_balance_changed):
		CoinEconomy.balance_changed.connect(_on_coin_balance_changed)


func _on_inventory_item_added(player_id: int, item_id: String) -> void:
	if _syncing_inventory or not is_run_active:
		return
	add_run_item(player_id, item_id, false)


func _on_inventory_item_removed(player_id: int, item_id: String) -> void:
	if _syncing_inventory or not is_run_active:
		return
	remove_run_item(player_id, item_id, false)


func _on_coin_balance_changed(player_id: int, new_balance: int) -> void:
	if _syncing_coins or not is_run_active:
		return
	set_run_coins(player_id, new_balance, false)


func _init_players_from_defaults() -> void:
	players.clear()
	for player_id in PLAYER_IDS:
		var base_stats: Dictionary = {}
		if StatDataDB != null:
			var data: Dictionary = StatDataDB.get_player_data(str(PLAYER_ENTITY_IDS.get(player_id, "")))
			var raw_stats = data.get("base_stats", {})
			if raw_stats is Dictionary:
				base_stats = raw_stats as Dictionary

		var max_hp := _estimate_max_hp_from_base_stats(base_stats)
		var coins := 9999
		players[player_id] = RunPlayerStateHelper.create(player_id, base_stats, max_hp, coins)
		players[player_id]["max_hp"] = max_hp


func _restore_players_from_save(raw_players: Variant) -> void:
	players.clear()
	var source: Dictionary = {}
	if raw_players is Dictionary:
		source = raw_players as Dictionary
	for player_id in PLAYER_IDS:
		var raw_state = source.get(str(player_id), source.get(player_id, {}))
		var restored := RunPlayerStateHelper.sanitize_state(raw_state, player_id)
		if int(restored.get("max_hp", 0)) <= 1:
			restored["max_hp"] = _estimate_max_hp_from_base_stats(restored.get("base_stats", {}))
		if int(restored.get("current_hp", -1)) < 0:
			restored["current_hp"] = int(restored["max_hp"])
		players[player_id] = restored


func _get_mutable_player_state(player_id: int) -> Dictionary:
	if not players.has(player_id):
		var base_stats: Dictionary = {}
		var max_hp := _estimate_max_hp_from_base_stats(base_stats)
		players[player_id] = RunPlayerStateHelper.create(player_id, base_stats, max_hp, 0)
	var sanitized := RunPlayerStateHelper.sanitize_state(players[player_id], player_id)
	players[player_id] = sanitized
	return players[player_id]


func _serialize_players_for_save() -> Dictionary:
	var result: Dictionary = {}
	for player_id in PLAYER_IDS:
		result[str(player_id)] = RunPlayerStateHelper.to_save_dict(_get_mutable_player_state(player_id))
	return result


func _sync_inventory_to_runtime() -> void:
	if InventoryManager == null or not InventoryManager.has_method("set_player_items"):
		return

	_syncing_inventory = true
	for player_id in PLAYER_IDS:
		InventoryManager.set_player_items(player_id, _get_mutable_player_state(player_id).get("items", []), false)
	_syncing_inventory = false


func _sync_inventory_to_runtime_player(player_id: int) -> void:
	if InventoryManager == null or not InventoryManager.has_method("set_player_items"):
		return
	_syncing_inventory = true
	InventoryManager.set_player_items(player_id, _get_mutable_player_state(player_id).get("items", []), false)
	_syncing_inventory = false


func _sync_coins_to_runtime() -> void:
	if CoinEconomy == null or not CoinEconomy.has_method("set_balance"):
		return

	_syncing_coins = true
	for player_id in PLAYER_IDS:
		CoinEconomy.set_balance(player_id, int(_get_mutable_player_state(player_id).get("coins", 0)))
	_syncing_coins = false


func _sync_coins_to_runtime_player(player_id: int) -> void:
	if CoinEconomy == null or not CoinEconomy.has_method("set_balance"):
		return
	_syncing_coins = true
	CoinEconomy.set_balance(player_id, int(_get_mutable_player_state(player_id).get("coins", 0)))
	_syncing_coins = false


func _sync_legacy_resources_from_players() -> void:
	var p1_resources: Dictionary = _get_mutable_player_state(1).get("resources", {})
	var p2_resources: Dictionary = _get_mutable_player_state(2).get("resources", {})
	p1_saved_energy = int(p1_resources.get("energy", -1))
	p2_saved_slots = []
	var slots = p2_resources.get("spell_slots", [])
	if slots is Array:
		for slot in slots:
			p2_saved_slots.append(maxi(0, int(slot)))


func _snapshot_resources_from_bridge(player_id: int) -> void:
	var bridge = get_tree().root.find_child("CombatTestBridge", true, false) if is_inside_tree() else null
	if bridge == null:
		return

	if player_id == 1:
		var p1_ec = bridge.get("_p1_ec")
		if p1_ec != null:
			set_run_resource(1, "energy", int(p1_ec.current_charges))
			print("[RunManager] Saved P1 Energy: %d" % p1_saved_energy)
	elif player_id == 2:
		var p2_ss = bridge.get("_p2_ss")
		if p2_ss != null:
			set_run_resource(2, "spell_slots", p2_ss.current_slots.duplicate())
			print("[RunManager] Saved P2 Slots: %s" % str(p2_saved_slots))


func _apply_resources_to_bridge(player_id: int) -> void:
	var bridge = get_tree().root.find_child("CombatTestBridge", true, false) if is_inside_tree() else null
	if bridge == null:
		return

	var state := _get_mutable_player_state(player_id)
	var resources: Dictionary = state.get("resources", {})
	if player_id == 1:
		var p1_ec = bridge.get("_p1_ec")
		if p1_ec != null:
			var energy := int(resources.get("energy", -1))
			if energy != -1:
				p1_ec.current_charges = clampi(energy, 0, int(p1_ec.max_charges))
				p1_ec.charge_changed.emit(p1_ec.current_charges, p1_ec.max_charges)
	elif player_id == 2:
		var p2_ss = bridge.get("_p2_ss")
		var slots = resources.get("spell_slots", [])
		if p2_ss != null and slots is Array and slots.size() == p2_ss.current_slots.size():
			for i in range(slots.size()):
				p2_ss.current_slots[i] = clampi(int(slots[i]), 0, int(p2_ss.max_slots[i]))
				p2_ss.slots_changed.emit(i + 1, p2_ss.current_slots[i], p2_ss.max_slots[i])


func _apply_inventory_effects_to_player(player_node: Node, player_id: int) -> void:
	if ItemEffectApplier != null and ItemEffectApplier.has_method("recalculate_player_stats"):
		ItemEffectApplier.recalculate_player_stats(player_node, player_id)
		return

	var stats := player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null or StatDataDB == null:
		return
	var items: Array = _get_mutable_player_state(player_id).get("items", [])
	for i in range(items.size()):
		var item_id := str(items[i])
		var item_data: Dictionary = StatDataDB.get_item_data(item_id)
		var stat_mods: Dictionary = {}
		var raw_mods = item_data.get("stat_mods", {})
		if raw_mods is Dictionary:
			stat_mods = raw_mods as Dictionary
		if stat_mods.is_empty():
			continue
		var source_id := str(item_data.get("source_id", "item:%s" % item_id))
		StatDataDB.apply_stat_mod(player_node, "%s_%d" % [source_id, i], stat_mods)


func _apply_effect_to_live_player(player_id: int, effect: Dictionary) -> void:
	var live_player := _find_player_node(player_id)
	if live_player != null:
		_apply_effect_to_player_node(live_player, effect)


func _apply_effect_to_player_node(player_node: Node, effect_data: Dictionary) -> void:
	var effect := RunPlayerStateHelper.sanitize_effect(effect_data)
	if effect.is_empty():
		return
	var stats := player_node.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		stats.set_mod_source(str(effect["source_id"]), effect.get("mods", {}))


func _remove_effect_from_live_player(player_id: int, source_id: String) -> void:
	var live_player := _find_player_node(player_id)
	if live_player == null:
		return
	var stats := live_player.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		stats.remove_mod_source(source_id)


func _should_tick_duration(duration_type: String, trigger_type: String) -> bool:
	match duration_type:
		"nodes":
			return trigger_type in ["node", "node_completed"]
		"battles":
			return trigger_type in ["battle", "battle_completed", "combat_ended"]
		"turns":
			return trigger_type in ["turn", "turn_completed", "turn_ended"]
	return false


func _find_player_node(player_id: int) -> Node:
	if not is_inside_tree():
		return null
	for player in get_tree().get_nodes_in_group("players"):
		if _get_player_id_from_node(player) == player_id:
			return player
	return null


func _get_player_id_from_node(player_node: Node) -> int:
	if player_node == null:
		return -1
	var raw_id = player_node.get("player_id")
	if raw_id == null:
		return -1
	return int(raw_id)


func _get_inventory_max_items() -> int:
	return 6


func _estimate_max_hp_from_base_stats(base_stats: Dictionary) -> int:
	var clean := RunPlayerStateHelper.sanitize_base_stats(base_stats)
	return maxi(1, StatsComponent.BASE_MAX_HP + int(floor(float(clean.get("vit", 0)) / 2.0)) + int(floor(float(clean.get("str", 0)) / 4.0)))


func _get_state_max_hp(state: Dictionary) -> int:
	var max_hp := int(state.get("max_hp", 0))
	if max_hp <= 0:
		max_hp = _estimate_max_hp_from_base_stats(state.get("base_stats", {}))
	return maxi(1, max_hp)


func _make_run_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s-%08x" % [Time.get_datetime_string_from_system(false, true), rng.randi()]
