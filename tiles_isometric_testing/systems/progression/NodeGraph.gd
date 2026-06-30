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
	var type: NodeType
	var next_nodes: Array[int] = [] # IDs of connected nodes in the next layer
	
	func _init(_id: int, _layer: int, _type: NodeType):
		self.id = _id
		self.layer = _layer
		self.type = _type

var layers: Array = [] # Array of Arrays of MapNodes
var nodes_by_id: Dictionary = {}
var seed_value: int = -1
var rng: RandomNumberGenerator = null

const MIN_NODES_PER_LAYER = 2
const MAX_NODES_PER_LAYER = 4
const TOTAL_LAYERS = 10 # Let's say 10 floors until boss

func generate(new_seed: int = -1) -> void:
	layers.clear()
	nodes_by_id.clear()
	var current_id = 0
	
	if new_seed != -1:
		seed_value = new_seed
	if seed_value == -1:
		randomize()
		seed_value = randi()
		
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	print("[NodeGraph] Generating new map graph with seed: %d..." % seed_value)
	
	for layer_index in range(TOTAL_LAYERS):
		var layer_nodes: Array[MapNode] = []
		
		# Boss layer
		if layer_index == TOTAL_LAYERS - 1:
			var boss_node = MapNode.new(current_id, layer_index, NodeType.BOSS)
			layer_nodes.append(boss_node)
			nodes_by_id[current_id] = boss_node
			current_id += 1
		else:
			var node_count = rng.randi_range(MIN_NODES_PER_LAYER, MAX_NODES_PER_LAYER)
			# First layer is always battle
			var is_first_layer = (layer_index == 0)
			
			for i in range(node_count):
				var type = NodeType.BATTLE if is_first_layer else _get_random_node_type()
				var node = MapNode.new(current_id, layer_index, type)
				layer_nodes.append(node)
				nodes_by_id[current_id] = node
				current_id += 1
				
		layers.append(layer_nodes)
	
	_generate_paths()
	print("[NodeGraph] Map generation complete. Nodes: %d, Layers: %d" % [nodes_by_id.size(), TOTAL_LAYERS])

func _get_random_node_type() -> NodeType:
	var roll = rng.randf()
	if roll < 0.4: return NodeType.BATTLE
	elif roll < 0.6: return NodeType.EVENT
	elif roll < 0.75: return NodeType.REST
	elif roll < 0.85: return NodeType.SHOP
	elif roll < 0.95: return NodeType.ELITE
	else: return NodeType.LOOT

func _generate_paths() -> void:
	# Clear previous connections to be safe
	for layer in layers:
		for node in layer:
			node.next_nodes.clear()

	for layer_idx in range(layers.size() - 1):
		var current_layer = layers[layer_idx]
		var next_layer = layers[layer_idx + 1]
		
		var n = current_layer.size()
		var m = next_layer.size()
		
		var i = 0
		var j = 0
		
		# Slay the Spire non-crossing algorithm
		while i < n and j < m:
			var node = current_layer[i]
			var target = next_layer[j]
			
			if not target.id in node.next_nodes:
				node.next_nodes.append(target.id)
			
			var advance_i = false
			var advance_j = false
			
			if i == n - 1:
				advance_j = true
			elif j == m - 1:
				advance_i = true
			else:
				var roll = rng.randf()
				if roll < 0.33:
					advance_i = true
				elif roll < 0.66:
					advance_j = true
				else:
					advance_i = true
					advance_j = true
					
			if advance_i: i += 1
			if advance_j: j += 1

	# Connectivity Validator: ensure no isolated nodes or dead ends
	for layer_idx in range(layers.size() - 1):
		var current_layer = layers[layer_idx]
		var next_layer = layers[layer_idx + 1]
		
		# 1. Ensure every node in current_layer has at least one outgoing path
		for node in current_layer:
			if node.next_nodes.is_empty():
				var target = next_layer[rng.randi() % next_layer.size()]
				node.next_nodes.append(target.id)
		
		# 2. Ensure every node in next_layer has at least one incoming path
		for target in next_layer:
			var has_incoming = false
			for node in current_layer:
				if target.id in node.next_nodes:
					has_incoming = true
					break
			if not has_incoming:
				# Connect closest index node to prevent crossing paths
				var source_idx = clampi(int(float(target.id - next_layer[0].id) / next_layer.size() * current_layer.size()), 0, current_layer.size() - 1)
				var source_node = current_layer[source_idx]
				source_node.next_nodes.append(target.id)
				
		# Keep connections sorted for pathing consistency
		for node in current_layer:
			node.next_nodes.sort()

func get_node_by_id(id: int) -> MapNode:
	return nodes_by_id.get(id, null)

