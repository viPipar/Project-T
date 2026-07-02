# autoloads/EnvironmentInteractionHandler.gd
# Guide:
#   Register interactable:
#     EnvironmentInteractionHandler.register_interactable(Vector2i(5, 5), chest)
#   Confirm/interact at tile:
#     var result := EnvironmentInteractionHandler.interact_at(player, Vector2i(5, 5))
#     if result.handled: return
#   Trigger tile after movement:
#     EnvironmentInteractionHandler.trigger_tile(player, player.grid_pos)
#
# Interactable objects may implement any of these optional methods:
#   interact(actor, context)
#   on_interact(actor, context)
#   on_entity_entered(entity, context)
#   trigger(entity, context)
#
# Items stored in GridManager item layer are collected with collect_all_items().
# If item has pickup(actor, context) or on_picked_up(actor, context), it is called.
extends Node
class_name EnvironmentInteractionHandlerProvider

var _interactables: Dictionary = {}


func register_interactable(tile: Vector2i, interactable: Node) -> void:
	if not is_instance_valid(interactable):
		return
	if not _interactables.has(tile):
		_interactables[tile] = []
	var list: Array = _interactables[tile]
	if not list.has(interactable):
		list.append(interactable)


func unregister_interactable(tile: Vector2i, interactable: Node = null) -> void:
	if not _interactables.has(tile):
		return
	if interactable == null:
		_interactables.erase(tile)
		return

	var list: Array = _interactables[tile]
	list.erase(interactable)
	if list.is_empty():
		_interactables.erase(tile)


func move_interactable(from_tile: Vector2i, to_tile: Vector2i, interactable: Node) -> void:
	unregister_interactable(from_tile, interactable)
	register_interactable(to_tile, interactable)


func get_interactables_at(tile: Vector2i) -> Array:
	if not _interactables.has(tile):
		return []
	var list: Array = _interactables[tile]
	var clean: Array = []
	for node in list:
		if is_instance_valid(node):
			clean.append(node)
	_interactables[tile] = clean
	if clean.is_empty():
		_interactables.erase(tile)
	return clean.duplicate()


func has_interaction_at(tile: Vector2i) -> bool:
	if not get_interactables_at(tile).is_empty():
		return true
	if GridManager != null and GridManager.has_item_at(tile):
		return true
	var occupant := GridManager.get_entity_at(tile) if GridManager != null else null
	return is_instance_valid(occupant) and (_has_any_method(occupant, ["interact", "on_interact"]))


func interact_at(actor: Node, tile: Vector2i, context: Dictionary = {}) -> Dictionary:
	var result := _make_result("interact", tile)
	var ctx := _with_tile_context(context, tile)

	for node in get_interactables_at(tile):
		if _call_first_existing(node, ["interact", "on_interact"], actor, ctx):
			result["handled"] = true
			result["interactables"].append(node)

	var occupant := GridManager.get_entity_at(tile) if GridManager != null else null
	if is_instance_valid(occupant) and occupant != actor:
		if _call_first_existing(occupant, ["interact", "on_interact"], actor, ctx):
			result["handled"] = true
			result["interactables"].append(occupant)

	_collect_items(actor, tile, ctx, result)
	return result


func trigger_tile(entity: Node, tile: Vector2i, context: Dictionary = {}) -> Dictionary:
	var result := _make_result("trigger", tile)
	var ctx := _with_tile_context(context, tile)

	for node in get_interactables_at(tile):
		if _call_first_existing(node, ["on_entity_entered", "trigger", "on_triggered"], entity, ctx):
			result["handled"] = true
			result["interactables"].append(node)

	_collect_items(entity, tile, ctx, result)
	return result


func _collect_items(actor: Node, tile: Vector2i, context: Dictionary, result: Dictionary) -> void:
	if GridManager == null or not GridManager.has_item_at(tile):
		return

	var items := GridManager.collect_all_items(tile)
	if items.is_empty():
		return

	result["handled"] = true
	for item in items:
		if not is_instance_valid(item):
			continue
		result["items"].append(item)
		var handled_by_item := _call_first_existing(item, ["pickup", "on_picked_up"], actor, context)
		if not handled_by_item:
			_try_add_item_to_inventory(actor, item)
			if is_instance_valid(item) and item.has_method("queue_free"):
				item.queue_free()


func _try_add_item_to_inventory(actor: Node, item: Node) -> void:
	if not is_instance_valid(actor) or InventoryManager == null:
		return
	var player_id := int(actor.get("player_id")) if actor.get("player_id") != null else 0
	if player_id <= 0:
		return

	var item_id := ""
	for key in ["item_id", "id", "item_name"]:
		var value = item.get(key)
		if value != null and str(value) != "":
			item_id = str(value)
			break

	if item_id != "" and InventoryManager.has_method("add_item"):
		InventoryManager.add_item(player_id, item_id)


func _with_tile_context(context: Dictionary, tile: Vector2i) -> Dictionary:
	var ctx := context.duplicate(true)
	ctx["tile"] = tile
	return ctx


func _call_first_existing(target: Node, methods: Array[String], actor: Node, context: Dictionary) -> bool:
	if not is_instance_valid(target):
		return false
	for method_name in methods:
		if target.has_method(method_name):
			var result = _call_with_supported_args(target, method_name, actor, context)
			return result == null or result != false
	return false


func _call_with_supported_args(target: Node, method_name: String, actor: Node, context: Dictionary):
	var argc := _method_arg_count(target, method_name)
	if argc <= 0:
		return target.call(method_name)
	if argc == 1:
		return target.call(method_name, actor)
	return target.call(method_name, actor, context)


func _method_arg_count(target: Node, method_name: String) -> int:
	for info in target.get_method_list():
		if str(info.get("name", "")) == method_name:
			var args: Array = info.get("args", [])
			return args.size()
	return 2


func _has_any_method(target: Node, methods: Array[String]) -> bool:
	if not is_instance_valid(target):
		return false
	for method_name in methods:
		if target.has_method(method_name):
			return true
	return false


func _make_result(kind: String, tile: Vector2i) -> Dictionary:
	return {
		"kind": kind,
		"tile": tile,
		"handled": false,
		"interactables": [],
		"items": [],
	}
