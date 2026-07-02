extends Node
class_name NodeGraph

# Slay the Spire style procedural node graph generator.
# A graph is a list of layers. Each layer contains multiple nodes.
# Nodes connect to nodes in the next layer.

enum NodeType {
	BATTLE,
	ELITE,
	BOSS,
	EVENT,
	REST,
	SHOP,
	LOOT
}

class MapNode:
	var id: int
	var layer: int
	var depth: int
	var type: NodeType
	var next_nodes: Array[int] = [] # IDs of connected nodes in the next layer
	
	func _init(_id: int, _layer: int, _type: NodeType):
		self.id = _id
		self.layer = _layer
		self.depth = _layer + 1
		self.type = _type

var layers: Array = [] # Array of Arrays of MapNodes
var nodes_by_id: Dictionary = {}
var seed_value: int = -1
var rng: RandomNumberGenerator = null

const RANDOM_SEED = -1

const MIN_BATTLE_NODES_PER_LAYER = 3
const MAX_BATTLE_NODES_PER_LAYER = 4
const TOTAL_LAYERS = 15
const FLEXIBLE_LAYERS = [1, 2, 5, 6, 7, 10, 11, 12]
const SAFE_LAYERS = [3, 8, 13]
const ELITE_LAYERS = [4, 9]
const BOSS_LAYER = 14
const MAX_INCOMING_PER_NODE = 2

func generate(new_seed: int = RANDOM_SEED) -> void:
	layers.clear()
	nodes_by_id.clear()
	var current_id = 0
	
	if new_seed == RANDOM_SEED:
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		seed_value = seed_rng.randi()
	else:
		seed_value = new_seed
		
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	print("[NodeGraph] Generating new map graph with seed: %d..." % seed_value)
	var flexible_layers = FLEXIBLE_LAYERS.duplicate()
	var luck_layer = _pick_random_layers(flexible_layers, 1)[0]
	var loot_layers = _pick_random_layers(flexible_layers, 2)
	
	for layer_index in range(TOTAL_LAYERS):
		var layer_nodes: Array[MapNode] = []
		var layer_types = _get_layer_types(layer_index, luck_layer, loot_layers)

		for node_type in layer_types:
			var node = MapNode.new(current_id, layer_index, node_type)
			layer_nodes.append(node)
			nodes_by_id[current_id] = node
			current_id += 1
				
		layers.append(layer_nodes)
	
	_generate_paths()
	print("[NodeGraph] Map generation complete. Nodes: %d, Layers: %d" % [nodes_by_id.size(), TOTAL_LAYERS])

func _pick_random_layers(source: Array, count: int) -> Array:
	var picked: Array = []
	for i in range(count):
		if source.is_empty():
			break
		var index = rng.randi_range(0, source.size() - 1)
		picked.append(source[index])
		source.remove_at(index)
	return picked

func _get_layer_types(layer_index: int, luck_layer: int, loot_layers: Array) -> Array:
	if layer_index == 0:
		return [NodeType.BATTLE, NodeType.BATTLE, NodeType.BATTLE]
	if layer_index == BOSS_LAYER:
		return [NodeType.BOSS]
	if layer_index in ELITE_LAYERS:
		return [NodeType.ELITE]
	if layer_index in SAFE_LAYERS:
		return _get_safe_branch_types()
	if layer_index == luck_layer:
		return _get_special_branch_types(NodeType.EVENT)
	if layer_index in loot_layers:
		return _get_special_branch_types(NodeType.LOOT)

	var node_count = rng.randi_range(MIN_BATTLE_NODES_PER_LAYER, MAX_BATTLE_NODES_PER_LAYER)
	var battle_nodes: Array = []
	for i in range(node_count):
		battle_nodes.append(NodeType.BATTLE)
	return battle_nodes

func _get_special_branch_types(special_type: NodeType) -> Array:
	var node_types = [NodeType.BATTLE, special_type, NodeType.BATTLE]
	var special_index = rng.randi_range(0, node_types.size() - 1)
	node_types[1] = node_types[special_index]
	node_types[special_index] = special_type
	return node_types

func _get_safe_branch_types() -> Array:
	if rng.randf() < 0.5:
		return [NodeType.REST, NodeType.SHOP]
	return [NodeType.SHOP, NodeType.REST]

func _generate_paths() -> void:
	for layer in layers:
		for node in layer:
			node.next_nodes.clear()

	for layer_idx in range(layers.size() - 1):
		_connect_layer_pair(layer_idx, layers[layer_idx], layers[layer_idx + 1])

	for layer_idx in range(layers.size() - 1):
		_ensure_layer_connectivity(layers[layer_idx], layers[layer_idx + 1])
		for node in layers[layer_idx]:
			node.next_nodes.sort()

func _connect_layer_pair(layer_idx: int, current_layer: Array, next_layer: Array) -> void:
	if current_layer.is_empty() or next_layer.is_empty():
		return

	var incoming_counts = _get_incoming_counts(current_layer, next_layer)

	if next_layer.size() == 1:
		for node in current_layer:
			_connect_nodes(node, next_layer[0])
		return

	if current_layer.size() == 1:
		for target in next_layer:
			_connect_nodes_capped(current_layer[0], target, incoming_counts, current_layer, next_layer)
		return

	if layer_idx + 1 in SAFE_LAYERS:
		for i in range(current_layer.size()):
			var node = current_layer[i]
			var target_index = i % next_layer.size()
			_connect_nodes_capped(node, next_layer[target_index], incoming_counts, current_layer, next_layer)
		return

	for i in range(current_layer.size()):
		var node = current_layer[i]
		var primary_index = _scale_index(i, current_layer.size(), next_layer.size())
		if not _connect_nodes_capped(node, next_layer[primary_index], incoming_counts, current_layer, next_layer):
			var fallback_target = _find_best_target_for_source(i, current_layer, next_layer, incoming_counts)
			if fallback_target != null:
				_connect_nodes_capped(node, fallback_target, incoming_counts, current_layer, next_layer)

	for i in range(current_layer.size()):
		var node = current_layer[i]
		var primary_index = _scale_index(i, current_layer.size(), next_layer.size())
		if node.next_nodes.size() >= 2:
			continue

		if next_layer.size() > 1 and rng.randf() < 0.35:
			var side = 1 if rng.randf() < 0.5 else -1
			var branch_index = clampi(primary_index + side, 0, next_layer.size() - 1)
			if branch_index == primary_index:
				branch_index = clampi(primary_index - side, 0, next_layer.size() - 1)
			_connect_nodes_capped(node, next_layer[branch_index], incoming_counts, current_layer, next_layer)

func _ensure_layer_connectivity(current_layer: Array, next_layer: Array) -> void:
	var incoming_counts = _get_incoming_counts(current_layer, next_layer)

	for i in range(current_layer.size()):
		var node = current_layer[i]
		if node.next_nodes.is_empty():
			var target = _find_best_target_for_source(i, current_layer, next_layer, incoming_counts)
			if target != null:
				_connect_nodes_capped(node, target, incoming_counts, current_layer, next_layer)

	for target_index in range(next_layer.size()):
		var target = next_layer[target_index]
		var has_incoming = false
		for node in current_layer:
			if target.id in node.next_nodes:
				has_incoming = true
				break
		if not has_incoming:
			var source_index = _scale_index(target_index, next_layer.size(), current_layer.size())
			_connect_nodes_capped(current_layer[source_index], target, incoming_counts, current_layer, next_layer)

func _connect_nodes(from_node: MapNode, to_node: MapNode) -> void:
	if not to_node.id in from_node.next_nodes:
		from_node.next_nodes.append(to_node.id)

func _connect_nodes_capped(from_node: MapNode, to_node: MapNode, incoming_counts: Dictionary, current_layer: Array, next_layer: Array) -> bool:
	if to_node.id in from_node.next_nodes:
		return true
	if _should_limit_incoming(current_layer, next_layer) and incoming_counts.get(to_node.id, 0) >= MAX_INCOMING_PER_NODE:
		return false

	from_node.next_nodes.append(to_node.id)
	incoming_counts[to_node.id] = incoming_counts.get(to_node.id, 0) + 1
	return true

func _find_best_target_for_source(source_index: int, current_layer: Array, next_layer: Array, incoming_counts: Dictionary):
	var preferred_index = _scale_index(source_index, current_layer.size(), next_layer.size())
	var best_target = null
	var best_score = 999999.0

	for target_index in range(next_layer.size()):
		var target = next_layer[target_index]
		var incoming_count = incoming_counts.get(target.id, 0)
		if _should_limit_incoming(current_layer, next_layer) and incoming_count >= MAX_INCOMING_PER_NODE:
			continue

		var score = abs(target_index - preferred_index) + float(incoming_count) * 0.5
		if score < best_score:
			best_score = score
			best_target = target

	return best_target

func _get_incoming_counts(current_layer: Array, next_layer: Array) -> Dictionary:
	var counts = {}
	for target in next_layer:
		counts[target.id] = 0
	for node in current_layer:
		for next_id in node.next_nodes:
			if counts.has(next_id):
				counts[next_id] += 1
	return counts

func _should_limit_incoming(current_layer: Array, next_layer: Array) -> bool:
	if next_layer.size() <= 1:
		return false
	return current_layer.size() <= next_layer.size() * MAX_INCOMING_PER_NODE

func _scale_index(source_index: int, source_count: int, target_count: int) -> int:
	if target_count <= 1:
		return 0
	if source_count <= 1:
		return int(target_count / 2)
	var ratio = float(source_index) / float(source_count - 1)
	return clampi(int(round(ratio * float(target_count - 1))), 0, target_count - 1)

func get_node_by_id(id: int) -> MapNode:
	return nodes_by_id.get(id, null)

func _layer_has_type(layer: Array, node_type: NodeType) -> bool:
	for node in layer:
		if node.type == node_type:
			return true
	return false

func get_total_depth() -> int:
	return TOTAL_LAYERS

func is_final_node(id: int) -> bool:
	var node = get_node_by_id(id)
	return node != null and node.layer == BOSS_LAYER
