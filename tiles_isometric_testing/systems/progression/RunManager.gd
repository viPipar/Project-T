extends Node

# Manages the meta-loop of a Roguelike run.
# Handles Run Start, Game Over, and transitioning back to a fresh state.

signal run_started()
signal run_ended(victory: bool)
signal layer_advanced(new_depth: int)

var is_run_active: bool = false
var current_depth: int = 1
var max_depth: int = 3 # Let's say 3 floors/layers per run

var p1_saved_energy: int = -1
var p2_saved_slots: Array = []

# References to other systems that need resetting
# (Will be populated once other systems are implemented)
# var inventory_manager
# var node_graph
# var coin_economy

func _ready() -> void:
	if EventBus != null:
		EventBus.combat_ended.connect(_on_combat_ended)

func start_run() -> void:
	if is_run_active:
		push_warning("RunManager: Attempted to start a run while one is already active.")
		return
	
	print("[RunManager] --- NEW RUN STARTED ---")
	is_run_active = true
	current_depth = 1
	p1_saved_energy = -1
	p2_saved_slots.clear()
	
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
