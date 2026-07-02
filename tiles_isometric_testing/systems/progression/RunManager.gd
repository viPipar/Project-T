extends Node

# Owns roguelike run state that must survive scene changes.

signal run_started()
signal run_ended(victory: bool)
signal layer_advanced(new_depth: int)
signal node_map_generated(seed_value: int)
signal node_traveled(node_id: int, node_type: int, depth: int)

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

func _ready() -> void:
	if EventBus != null:
		EventBus.combat_ended.connect(_on_combat_ended)

func start_run(new_seed: int = -1) -> void:
	if is_run_active:
		push_warning("RunManager: Attempted to start a run while one is already active.")
		ensure_node_map()
		return

	print("[RunManager] --- NEW RUN STARTED ---")
	is_run_active = true
	current_depth = 1
	p1_saved_energy = -1
	p2_saved_slots.clear()
	pending_node_id = -1
	pending_node_type = -1

	# Reset player, inventory, and economy systems here once their run APIs are final.
	_generate_node_map(new_seed)
	run_started.emit()

func end_run(victory: bool) -> void:
	if not is_run_active:
		return

	is_run_active = false
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

func ensure_node_map(new_seed: int = -1) -> void:
	if not is_run_active:
		start_run(new_seed)
		return
	if node_graph == null or path_handler == null:
		_generate_node_map(new_seed)

func get_node_graph() -> NodeGraph:
	ensure_node_map()
	return node_graph

func get_path_handler() -> PathHandler:
	ensure_node_map()
	return path_handler

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

	return true

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

func _generate_node_map(new_seed: int = -1) -> void:
	node_graph = NodeGraph.new()
	node_graph.generate(new_seed)
	node_map_seed = node_graph.seed_value

	path_handler = PathHandler.new()
	path_handler.init(node_graph)
	max_depth = node_graph.get_total_depth()
	node_map_generated.emit(node_map_seed)

func _clear_node_map_state() -> void:
	node_graph = null
	path_handler = null
	node_map_seed = -1
	pending_node_id = -1
	pending_node_type = -1

func _on_player_died(_player_id: int) -> void:
	end_run(false)

func _on_combat_ended(result: String) -> void:
	print("[RunManager] Combat ended: %s. Saving player resources." % result)
	var bridge = get_tree().root.find_child("CombatTestBridge", true, false)
	if bridge != null:
		var p1_ec = bridge.get("_p1_ec")
		var p2_ss = bridge.get("_p2_ss")
		if p1_ec != null:
			p1_saved_energy = p1_ec.current_charges
			print("[RunManager] Saved P1 Energy: %d" % p1_saved_energy)
		if p2_ss != null:
			p2_saved_slots = p2_ss.current_slots.duplicate()
			print("[RunManager] Saved P2 Slots: %s" % str(p2_saved_slots))
