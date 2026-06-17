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

const MIN_NODES_PER_LAYER = 2
const MAX_NODES_PER_LAYER = 4
const TOTAL_LAYERS = 10 # Let's say 10 floors until boss

func generate() -> void:
	layers.clear()
	nodes_by_id.clear()
	var current_id = 0
	
	print("[NodeGraph] Generating new map graph...")
	
	for layer_index in range(TOTAL_LAYERS):
		var layer_nodes: Array[MapNode] = []
		
		# Boss layer
		if layer_index == TOTAL_LAYERS - 1:
			var boss_node = MapNode.new(current_id, layer_index, NodeType.BOSS)
			layer_nodes.append(boss_node)
			nodes_by_id[current_id] = boss_node
			current_id += 1
		else:
			var node_count = randi_range(MIN_NODES_PER_LAYER, MAX_NODES_PER_LAYER)
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
	var roll = randf()
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
				var roll = randf()
				if roll < 0.33:
					advance_i = true
				elif roll < 0.66:
					advance_j = true
				else:
					advance_i = true
					advance_j = true
					
			if advance_i: i += 1
			if advance_j: j += 1

func get_node_by_id(id: int) -> MapNode:
	return nodes_by_id.get(id, null)
