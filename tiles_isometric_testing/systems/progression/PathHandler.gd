extends Node
class_name PathHandler

# Handles logic for node traversal, tracking the current node, 
# and resolving which nodes are unlocked/clickable.

var current_node_id: int = -1
var node_graph: NodeGraph
var completed_node_ids: Array[int] = []

func init(_graph: NodeGraph) -> void:
	self.node_graph = _graph
	self.current_node_id = -1
	completed_node_ids.clear()
	print("[PathHandler] Initialized with new graph.")

func restore_progress(_graph: NodeGraph, restored_current_node_id: int, restored_completed_node_ids: Array) -> void:
	self.node_graph = _graph
	self.current_node_id = restored_current_node_id
	completed_node_ids.clear()
	for node_id in restored_completed_node_ids:
		completed_node_ids.append(int(node_id))

func get_progress_state() -> Dictionary:
	return {
		"current_node_id": current_node_id,
		"completed_node_ids": completed_node_ids.duplicate(),
	}

func get_unlocked_nodes() -> Array[int]:
	if node_graph == null:
		return []
		
	# If we haven't started, all nodes in Layer 0 are unlocked
	if current_node_id == -1:
		var unlocked: Array[int] = []
		if node_graph.layers.size() > 0:
			for node in node_graph.layers[0]:
				unlocked.append(node.id)
		return unlocked
		
	# Otherwise, unlocked nodes are the next_nodes of the current node
	var current = node_graph.get_node_by_id(current_node_id)
	if current != null:
		return current.next_nodes.duplicate()
		
	return []

func can_travel_to(target_id: int) -> bool:
	return target_id in get_unlocked_nodes()

func travel_to(target_id: int) -> bool:
	if can_travel_to(target_id):
		if current_node_id != -1 and not current_node_id in completed_node_ids:
			completed_node_ids.append(current_node_id)
		current_node_id = target_id
		var node = node_graph.get_node_by_id(target_id)
		print("[PathHandler] Traveled to Node ID: %d, Type: %s" % [target_id, NodeGraph.NodeType.keys()[node.type]])
		return true
	else:
		push_warning("[PathHandler] Attempted to travel to locked node %d" % target_id)
		return false

func get_completed_nodes() -> Array[int]:
	return completed_node_ids.duplicate()

func is_completed(target_id: int) -> bool:
	return target_id in completed_node_ids
