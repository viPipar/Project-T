extends Node

# Manages the meta-loop of a Roguelike run.
# Handles Run Start, Game Over, and transitioning back to a fresh state.

signal run_started()
signal run_ended(victory: bool)
signal layer_advanced(new_depth: int)

var is_run_active: bool = false
var current_depth: int = 1
var max_depth: int = 3 # Let's say 3 floors/layers per run

# References to other systems that need resetting
# (Will be populated once other systems are implemented)
# var inventory_manager
# var coin_economy
var node_graph: NodeGraph
var path_handler: PathHandler
var current_seed: String

func start_or_reload_run(seed_text: String) -> void:
	current_seed = seed_text
	var seed_num = seed_text.hash() if seed_text != "" else randi()
	seed(seed_num)
	print("[RunManager] Generating Map with seed: ", seed_text, " (Hash: ", seed_num, ")")
	
	node_graph = NodeGraph.new()
	node_graph.generate()
	
	path_handler = PathHandler.new()
	path_handler.init(node_graph)
	
	is_run_active = true
	current_depth = 1

func _ready() -> void:
	# Add self to autoloads conceptually, or instantiate in main scene
	pass

func start_run() -> void:
	if is_run_active:
		push_warning("RunManager: Attempted to start a run while one is already active.")
		return
	
	print("[RunManager] --- NEW RUN STARTED ---")
	is_run_active = true
	current_depth = 1
	
	# 1. Reset Players (HP, AP, Stats, Buffs)
	# EventBus.emit_signal("reset_players")
	
	# 2. Reset Inventory and Economy
	# InventoryManager.reset()
	# CoinEconomy.reset()
	
	# 3. Generate New Map (Layer 1)
	# NodeGraph.generate(current_depth)
	
	run_started.emit()

func end_run(victory: bool) -> void:
	if not is_run_active:
		return
		
	is_run_active = false
	if victory:
		print("[RunManager] 🏆 VICTORY! Run Completed Successfully.")
	else:
		print("[RunManager] 💀 GAME OVER! Run Failed.")
		
	run_ended.emit(victory)
	
	# Transition back to main menu or show summary screen
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
		# Generate new map for the next layer
		# NodeGraph.generate(current_depth)
		layer_advanced.emit(current_depth)

# Handle Permadeath
func _on_player_died(_player_id: int) -> void:
	# In a co-op game, does one death end the run, or both?
	# Assuming one death means failure for now.
	end_run(false)
