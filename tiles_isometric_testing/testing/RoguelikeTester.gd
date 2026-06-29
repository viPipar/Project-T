extends RefCounted

func run_all_tests() -> void:
	print("\n==============================================")
	print("🚀 ROGUELIKE SYSTEM TEST STARTING...")
	print("==============================================\n")
	
	test_node_graph()
	test_balancing_and_items()
	test_shop_and_economy()
	test_luck_event()
	
	print("\n==============================================")
	print("✅ ALL TESTS COMPLETED. Check output above.")
	print("==============================================\n")

func test_node_graph() -> void:
	print("--- 🗺️ TESTING NODE GRAPH ---")
	var graph = NodeGraph.new()
	graph.generate()
	
	var path_handler = PathHandler.new()
	path_handler.init(graph)
	
	var unlocked = path_handler.get_unlocked_nodes()
	print("Unlocked Nodes at Start (Layer 0): ", unlocked)
	
	if unlocked.size() > 0:
		var first_node = unlocked[0]
		path_handler.travel_to(first_node)
		print("Traveled to node. New Unlocked Nodes: ", path_handler.get_unlocked_nodes())
	print("")

func test_balancing_and_items() -> void:
	print("--- ⚔️ TESTING BALANCING & ITEMS ---")
	var registry = ItemRegistry
	var pool = ItemPoolGenerator.new()
	pool.init(registry, BalancingData.new())
	
	print("Rolling 3 Normal Battle Drops:")
	for i in range(3):
		print(" - ", pool.roll_item("normal"))
		
	print("Rolling 3 Boss Battle Drops:")
	for i in range(3):
		print(" - ", pool.roll_item("boss"))
	print("")

func test_shop_and_economy() -> void:
	print("--- 💰 TESTING SHOP & ECONOMY ---")
	var economy = preload("res://systems/shop/CoinEconomy.gd").new()
	economy.add_coins(1, 100) # Player 1 gets 100
	economy.add_coins(2, 20)  # Player 2 gets 20
	
	print("P1 sending half to P2...")
	economy.send_half(1, 2)
	
	var registry = ItemRegistry
	var pool = ItemPoolGenerator.new()
	pool.init(registry, BalancingData.new())
	
	var stock = StockManager.new()
	stock.init(pool)
	stock.generate_stock()
	print("")

func test_luck_event() -> void:
	print("--- 🎲 TESTING LUCK EVENT ---")
	var luck = LuckEventHandler.new()
	luck.event_started.connect(func(data): print("Event Started: ", data["narrative"]))
	luck.event_resolved.connect(func(success, reward): print("Event Resolved! Success: ", success, " | Reward: ", reward))
	
	luck.start_event("event_wolves")
	print("Player 1 chooses Option 0 (Sneak)")
	luck.select_choice(1, 0)
	print("Player 2 chooses Option 0 (Sneak)")
	luck.select_choice(2, 0) # This triggers the resolution
	print("")
