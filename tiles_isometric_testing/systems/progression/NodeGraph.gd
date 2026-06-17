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
	# Connect each node to at least one node in the next layer
	for i in range(layers.size() - 1):
		var current_layer = layers[i]
		var next_layer = layers[i + 1]
		
		# Ensure every node in current layer connects to something
		for node in current_layer:
			var target = next_layer[randi() % next_layer.size()]
			node.next_nodes.append(target.id)
			
		# Ensure every node in the next layer is reachable
		for next_node in next_layer:
			var is_reachable = false
			for node in current_layer:
				if next_node.id in node.next_nodes:
					is_reachable = true
					break
			if not is_reachable:
				var source = current_layer[randi() % current_layer.size()]
				if not next_node.id in source.next_nodes:
					source.next_nodes.append(next_node.id)

func get_node_by_id(id: int) -> MapNode:
	return nodes_by_id.get(id, null)
