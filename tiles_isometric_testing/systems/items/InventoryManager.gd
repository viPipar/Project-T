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
