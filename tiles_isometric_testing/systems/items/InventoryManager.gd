extends Node

signal item_added(player_id: int, item_id: String)
signal item_removed(player_id: int, item_id: String)

var _inventories: Dictionary = {
	1: [], # Player 1 items
	2: []  # Player 2 items
}

func add_item(player_id: int, item_id: String) -> void:
	if not _inventories.has(player_id):
		return
		
	_inventories[player_id].append(item_id)
	print("[InventoryManager] Added %s to P%d inventory." % [item_id, player_id])
	item_added.emit(player_id, item_id)

func remove_item(player_id: int, item_id: String) -> void:
	if not _inventories.has(player_id):
		return
		
	var inv: Array = _inventories[player_id]
	if item_id in inv:
		inv.erase(item_id)
		print("[InventoryManager] Removed %s from P%d inventory." % [item_id, player_id])
		item_removed.emit(player_id, item_id)

func get_player_items(player_id: int) -> Array:
	if not _inventories.has(player_id):
		return []
	return _inventories[player_id].duplicate()

func reset() -> void:
	_inventories[1].clear()
	_inventories[2].clear()
	print("[InventoryManager] Inventories reset.")

# ── CONTESTED PICK SYSTEM (REBUTAN) ───────────────────────────────────────────

func get_player_lck_modifier(player_id: int) -> int:
	var lck = 10 # default
	# Find player node in group "players"
	for p in get_tree().get_nodes_in_group("players"):
		var pid = p.get("player_id")
		if pid != null and typeof(pid) == TYPE_INT and pid == player_id:
			if StatSystem != null:
				lck = StatSystem.get_lck(p)
			elif p.has_node("StatsComponent"):
				lck = p.get_node("StatsComponent").lck
			break
	return floori(lck / 5.0)

func resolve_contested_pick(item_id: String) -> int:
	print("[InventoryManager] Resolve contested pick for item: %s" % item_id)
	
	var item_data = {}
	if ItemRegistry != null:
		item_data = ItemRegistry.get_item(item_id)
	
	var p1_lck_mod = get_player_lck_modifier(1)
	var p2_lck_mod = get_player_lck_modifier(2)
	
	var p1_roll = 0
	var p2_roll = 0
	var attempts = 0
	
	# Loop to handle exact tie re-rolls (no limit, keep until diff)
	while true:
		attempts += 1
		p1_roll = randi_range(1, 20) + p1_lck_mod
		p2_roll = randi_range(1, 20) + p2_lck_mod
		print("[InventoryManager] Contested Pick Roll - Attempt %d: P1 rolled %d vs P2 rolled %d" % [attempts, p1_roll, p2_roll])
		if p1_roll != p2_roll:
			break
			
	var winner_id = 1 if p1_roll > p2_roll else 2
	
	# Emit start signal
	EventBus.contested_pick_started.emit(item_data, p1_roll, p2_roll)
	
	# Add item to the winner
	add_item(winner_id, item_id)
	
	# Emit resolved signal
	EventBus.contested_pick_resolved.emit(winner_id, item_data)
	
	print("[InventoryManager] Contested pick resolved! Winner: P%d with roll %d (after %d attempts)" % [winner_id, p1_roll if winner_id == 1 else p2_roll, attempts])
	return winner_id
