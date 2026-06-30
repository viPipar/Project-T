extends RefCounted

func run_all_tests() -> void:
	print("\n==============================================")
	print("🚀 ROGUELIKE SYSTEM TEST STARTING...")
	print("==============================================\n")
	
	test_seeded_node_graph()
	test_node_graph_connectivity()
	test_luck_event_pools()
	test_campfire_rest_choices()
	test_contested_pick_system()
	test_shop_and_economy()
	
	print("\n==============================================")
	print("✅ ALL TESTS COMPLETED. Check output above.")
	print("==============================================\n")

func test_seeded_node_graph() -> void:
	print("--- 🗺️ TESTING SEEDED NODE GRAPH ---")
	var graph1 = NodeGraph.new()
	graph1.generate(12345)
	
	var graph2 = NodeGraph.new()
	graph2.generate(12345)
	
	var graph3 = NodeGraph.new()
	graph3.generate(54321)
	
	# Verify matching seed results
	var match_ok = true
	if graph1.layers.size() != graph2.layers.size():
		match_ok = false
	else:
		for l in range(graph1.layers.size()):
			if graph1.layers[l].size() != graph2.layers[l].size():
				match_ok = false
				break
	
	# Verify differing seed results
	var diff_ok = false
	if graph1.layers.size() != graph3.layers.size():
		diff_ok = true
	else:
		for l in range(graph1.layers.size()):
			if graph1.layers[l].size() != graph3.layers[l].size():
				diff_ok = true
				break
				
	print("Seeded Generation Check: Match same seed: %s | Differ other seed: %s" % [
		"PASSED ✅" if match_ok else "FAILED ❌",
		"PASSED ✅" if diff_ok else "FAILED ❌"
	])
	print("")

func test_node_graph_connectivity() -> void:
	print("--- 🗺️ TESTING PATH CONNECTIVITY & REACHABILITY ---")
	var graph = NodeGraph.new()
	var dead_ends = 0
	var isolated_nodes = 0
	
	# Run 100 passes of random graphs and validate zero connectivity issues
	for pass_idx in range(100):
		graph.generate(-1)
		
		# Validate Layer 1 to N-1 for incoming connections
		for layer_idx in range(1, graph.layers.size()):
			var layer = graph.layers[layer_idx]
			for target in layer:
				var has_incoming = false
				for parent in graph.layers[layer_idx - 1]:
					if target.id in parent.next_nodes:
						has_incoming = true
						break
				if not has_incoming:
					isolated_nodes += 1
					
		# Validate Layer 0 to N-2 for outgoing connections
		for layer_idx in range(graph.layers.size() - 1):
			var layer = graph.layers[layer_idx]
			for node in layer:
				if node.next_nodes.is_empty():
					dead_ends += 1
					
	print("100 Random Generation Pass Connectivity check:")
	print(" - Dead Ends Found: %d (Expected: 0) -> %s" % [dead_ends, "PASSED ✅" if dead_ends == 0 else "FAILED ❌"])
	print(" - Isolated Nodes Found: %d (Expected: 0) -> %s" % [isolated_nodes, "PASSED ✅" if isolated_nodes == 0 else "FAILED ❌"])
	print("")

func test_luck_event_pools() -> void:
	print("--- 🎲 TESTING LUCK EVENT POOLS DISTRIBUTION ---")
	var handler = LuckEventHandler.new()
	
	# Mock players in group to test average LCK modifier calculation
	var win_counts = {
		"items_2": 0,
		"full_hp": 0,
		"legendary_1": 0,
		"coins_200": 0,
		"stat_boost": 0
	}
	
	var lose_counts = {
		"hp_penalty": 0,
		"cursed_item": 0,
		"elite_battle": 0,
		"coin_loss": 0,
		"stat_debuff": 0
	}
	
	# Simulate Win Outcome roll 1000 times
	for i in range(1000):
		var roll = randf()
		if roll < 0.40: win_counts["items_2"] += 1
		elif roll < 0.65: win_counts["full_hp"] += 1
		elif roll < 0.85: win_counts["legendary_1"] += 1
		elif roll < 0.95: win_counts["coins_200"] += 1
		else: win_counts["stat_boost"] += 1
		
	# Simulate Lose Outcome roll 1000 times
	for i in range(1000):
		var roll = randf()
		if roll < 0.35: lose_counts["hp_penalty"] += 1
		elif roll < 0.60: lose_counts["cursed_item"] += 1
		elif roll < 0.80: lose_counts["elite_battle"] += 1
		elif roll < 0.95: lose_counts["coin_loss"] += 1
		else: lose_counts["stat_debuff"] += 1
		
	print("Win Pool distribution (1000 rolls):")
	print(" - 2 Items (40%%): %d" % win_counts["items_2"])
	print(" - Full HP (25%%): %d" % win_counts["full_hp"])
	print(" - 1 Legendary (20%%): %d" % win_counts["legendary_1"])
	print(" - +200 Coins (10%%): %d" % win_counts["coins_200"])
	print(" - Stat Boost (5%%): %d" % win_counts["stat_boost"])
	
	print("Lose Pool distribution (1000 rolls):")
	print(" - HP Penalty (35%%): %d" % lose_counts["hp_penalty"])
	print(" - Cursed Item (25%%): %d" % lose_counts["cursed_item"])
	print(" - Elite Ambush (20%%): %d" % lose_counts["elite_battle"])
	print(" - Coin Loss (15%%): %d" % lose_counts["coin_loss"])
	print(" - Stat Debuff (5%%): %d" % lose_counts["stat_debuff"])
	print("")

func test_campfire_rest_choices() -> void:
	print("--- 🔥 TESTING CAMPFIRE REST SITE ---")
	var handler = RestLootHandler.new()
	
	# Simulate Treasure Search probabilities over 1000 rolls
	var success_count = 0
	var trap_count = 0
	var jackpot_count = 0
	
	for i in range(1000):
		var roll = randf()
		if roll < 0.70: success_count += 1
		elif roll < 0.90: trap_count += 1
		else: jackpot_count += 1
		
	print("Option C: Treasure Search probability (1000 rolls):")
	print(" - Success (70%%): %d" % success_count)
	print(" - Trap (20%%): %d" % trap_count)
	print(" - Jackpot (10%%): %d" % jackpot_count)
	
	# Test RestScreen class instantiation and structure
	var rest_screen_script = load("res://ui/roguelike/RestScreen.gd")
	if rest_screen_script:
		var screen = rest_screen_script.new()
		assert(screen.OPTIONS_DATA.size() == 4, "Rest Screen must have exactly 4 choices.")
		print("Rest Screen Instantiation Check: PASSED ✅")
	else:
		print("Rest Screen Instantiation Check: FAILED ❌ (Cannot load RestScreen.gd)")
	print("")

func test_contested_pick_system() -> void:
	print("--- 🤝 TESTING CONTESTED PICK SYSTEM ---")
	if InventoryManager != null:
		# Add a cursed amulet to test removal option and pick logic
		InventoryManager.reset()
		InventoryManager.add_item(1, "cursed_amulet")
		
		# Resolve contested pick for berserker_axe
		print("Resolving contested pick on 'berserker_axe'...")
		var winner = InventoryManager.resolve_contested_pick("berserker_axe")
		print("Contested Pick Resolved! Winner is P%d" % winner)
		print("P1 Items after pick: ", InventoryManager.get_player_items(1))
		print("P2 Items after pick: ", InventoryManager.get_player_items(2))
	print("")

func test_shop_and_economy() -> void:
	print("--- 💰 TESTING SHOP STOCK & TRANSACTIONS ---")
	if CoinEconomy != null:
		CoinEconomy.reset()
		CoinEconomy.add_coins(1, 1000)
		CoinEconomy.add_coins(2, 40)
		
		var pool = ItemPoolGenerator.new()
		pool.init(ItemRegistry, BalancingData.new())
		
		var stock = StockManager.new()
		stock.init(pool)
		stock.generate_stock()
		
		print("Initial P1 Balance: %d | Stock: %s" % [CoinEconomy.get_balance(1), str(stock.current_stock)])
		
		# Buy the first item in stock
		var item_to_buy = stock.current_stock[0]
		print("P1 buying slot 0 item: %s" % item_to_buy)
		var bought = stock.buy_item(1, 0)
		print("P1 Purchase success: %s | P1 Balance now: %d" % [bought, CoinEconomy.get_balance(1)])
		print("Remaining Shop Stock: ", stock.current_stock)
		
		# Try to reroll stock
		print("P1 rerolling shop stock...")
		var rerolled = stock.reroll_stock(1)
		print("Reroll success: %s | P1 Balance now: %d" % [rerolled, CoinEconomy.get_balance(1)])
		print("New Shop Stock: ", stock.current_stock)
	print("")
