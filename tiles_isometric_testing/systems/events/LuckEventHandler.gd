extends Node
class_name LuckEventHandler

# Handles Luck Event nodes, requiring consensus and a D20 roll to resolve.

const EventDropGenerator = preload("res://systems/events/ItemPoolGenerator.gd")

signal event_started(event_data: Dictionary)
signal choice_selected(player_id: int, choice_index: int)
signal consensus_reached(choice_index: int)
signal event_resolved(success: bool, reward: Dictionary)

var current_event: Dictionary
var p1_choice: int = -1
var p2_choice: int = -1
var timer: Timer = null

func _setup_timer() -> void:
	if timer == null:
		timer = Timer.new()
		timer.one_shot = true
		timer.timeout.connect(_on_timer_timeout)
		add_child(timer)

func start_event(event_id: String) -> void:
	# Load event data from a hypothetical EventDB
	current_event = {
		"id": event_id,
		"narrative": "You find a glowing chest surrounded by sleeping wolves.",
		"choices": [
			{ "desc": "Sneak and open (D20 > 10)", "target_dc": 10, "reward": "random_item" },
			{ "desc": "Leave safely", "target_dc": 0, "reward": "none" }
		]
	}
	p1_choice = -1
	p2_choice = -1
	
	_setup_timer()
	timer.start(15.0)
	
	event_started.emit(current_event)

func select_choice(player_id: int, choice_index: int) -> void:
	if player_id == 1:
		p1_choice = choice_index
	elif player_id == 2:
		p2_choice = choice_index
		
	choice_selected.emit(player_id, choice_index)
	
	if p1_choice != -1 and p2_choice != -1:
		if p1_choice == p2_choice:
			_resolve_event(p1_choice)
		else:
			print("[LuckEventHandler] Players disagree! Waiting for consensus...")

func _on_timer_timeout() -> void:
	print("[LuckEventHandler] Consensus timer expired! Forcing default option...")
	EventNotifier.show_message("Consensus Timeout! Party leaves safely.", Color.ORANGE)
	var am = get_node_or_null("/root/AudioManager")
	if am != null: am.play_sfx("ui_cancel")
	# Force option 1 (Leave safely)
	_resolve_event(1)

func _resolve_event(choice_index: int) -> void:
	if timer != null:
		timer.stop()
		
	consensus_reached.emit(choice_index)
	var choice = current_event.get("choices", [])[choice_index]
	var dc = choice.get("target_dc", 0)
	
	if dc > 0:
		# Calculate Average Luck modifier of players
		var avg_lck = 0.0
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0:
			var total_lck = 0
			for p in players:
				if StatSystem != null:
					total_lck += StatSystem.get_lck(p)
				elif p.has_node("StatsComponent"):
					total_lck += p.get_node("StatsComponent").lck
			avg_lck = float(total_lck) / players.size()
			
		var luck_mod = floor(avg_lck / 5.0)
		var roll = randi_range(1, 20)
		var total_roll = roll + luck_mod
		var success = (total_roll >= dc)
		
		print("[LuckEventHandler] D20 Roll: %d + LCK mod: %d = %d vs DC: %d. Success: %s" % [roll, luck_mod, total_roll, dc, success])
		EventNotifier.show_message("Luck Roll: %d + %d = %d vs DC %d" % [roll, luck_mod, total_roll, dc], Color.AQUAMARINE)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("dice_roll")
		
		if success:
			_apply_win_outcome()
			event_resolved.emit(true, {"outcome": "win"})
		else:
			_apply_lose_outcome()
			event_resolved.emit(false, {"outcome": "lose"})
	else:
		# Auto success
		_apply_reward_or_penalty(choice)
		event_resolved.emit(true, choice)

func _apply_reward_or_penalty(outcome: Dictionary) -> void:
	var reward_type = outcome.get("reward", "")
	var amount = outcome.get("amount", 0)
	
	if reward_type == "damage" or reward_type == "heal":
		if reward_type == "damage":
			EventNotifier.show_message("Luck Failed! -%d HP" % amount, Color.RED)
		else:
			EventNotifier.show_message("Luck Succeeded! +%d HP" % amount, Color.GREEN)
			
		for p in get_tree().get_nodes_in_group("players"):
			var hc = p.get_node_or_null("HealthComponent")
			if hc:
				if reward_type == "damage" and hc.has_method("take_damage"):
					hc.take_damage(amount, null, "true_damage")
				elif reward_type == "heal" and hc.has_method("heal"):
					hc.heal(amount)
					
	elif reward_type == "random_item":
		var reward = EventDropGenerator.generate_drop("normal")
		EventNotifier.show_message("Luck Succeeded! You found %s!" % reward, Color.GOLD)
		if InventoryManager != null:
			InventoryManager.add_item(1, reward)

func _apply_win_outcome() -> void:
	var roll = randf()
	if roll < 0.40:
		# 40% -> Reward: 2 random items (rarity by current run depth)
		var depth = 1
		if RunManager != null:
			depth = RunManager.current_depth
		var battle_type = "normal"
		if depth == 2:
			battle_type = "elite"
		elif depth >= 3:
			battle_type = "boss"
			
		var item1 = EventDropGenerator.generate_drop(battle_type)
		var item2 = EventDropGenerator.generate_drop(battle_type)
		
		print("[LuckEventHandler] Win Outcome: 2 random items (%s) -> %s, %s" % [battle_type, item1, item2])
		EventNotifier.show_message("Luck Win: Found %s and %s!" % [item1, item2], Color.GOLD)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_rare")
		if InventoryManager != null:
			InventoryManager.add_item(1, item1)
			InventoryManager.add_item(2, item2)
			
	elif roll < 0.65:
		# 25% -> Full HP Restore (both players 100% HP)
		print("[LuckEventHandler] Win Outcome: Full HP Restore")
		EventNotifier.show_message("Luck Win: Full HP Restore for both players!", Color.GREEN)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("victory")
		for p in get_tree().get_nodes_in_group("players"):
			var hc = p.get_node_or_null("HealthComponent")
			if hc != null:
				if hc.has_method("heal_to_full"):
					hc.heal_to_full()
				elif hc.has_method("heal"):
					hc.heal(9999)
					
	elif roll < 0.85:
		# 20% -> Reward: 1 Legendary item
		var item = EventDropGenerator.generate_drop("boss") # boss guarantees legendary
		print("[LuckEventHandler] Win Outcome: 1 Legendary item -> %s" % item)
		EventNotifier.show_message("Luck Win: Found Legendary %s!" % item, Color.GOLD)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_legendary")
		if InventoryManager != null:
			InventoryManager.add_item(1, item)
			
	elif roll < 0.95:
		# 10% -> Gold Windfall (+200 Coin each player)
		print("[LuckEventHandler] Win Outcome: +200 Coin each")
		EventNotifier.show_message("Luck Win: Gold Windfall! +200 Coins each!", Color.YELLOW)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_rare")
		if CoinEconomy != null:
			CoinEconomy.add_coins(1, 200)
			CoinEconomy.add_coins(2, 200)
			
	else:
		# 5% -> Stat Boost (permanent +2 to random attribute, both)
		var attrs = ["vit", "str_stat", "int_stat", "con", "acc", "dex", "mov", "att", "lck"]
		var attr = attrs[randi() % attrs.size()]
		var attr_display = attr.replace("_stat", "").to_upper()
		print("[LuckEventHandler] Win Outcome: Permanent +2 to %s" % attr_display)
		EventNotifier.show_message("Luck Win: Permanent +2 to %s for both players!" % attr_display, Color.CYAN)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_rare")
		for p in get_tree().get_nodes_in_group("players"):
			var stats = p.get_node_or_null("StatsComponent")
			if stats != null:
				var current_val = stats.get(attr)
				stats.set(attr, current_val + 2)
				if stats.has_method("emit_changed"):
					stats.emit_changed()

func _apply_lose_outcome() -> void:
	var roll = randf()
	if roll < 0.35:
		# 35% -> HP Penalty: -50% HP (both players)
		print("[LuckEventHandler] Lose Outcome: -50% HP Penalty")
		EventNotifier.show_message("Luck Failure: -50% HP Penalty for both players!", Color.RED)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_error")
		for p in get_tree().get_nodes_in_group("players"):
			var hc = p.get_node_or_null("HealthComponent")
			if hc != null:
				var max_hp = hc.get("max_hp") if hc.get("max_hp") != null else 20
				if hc.has_method("take_damage"):
					hc.take_damage(int(max_hp * 0.5), null, "true_damage")
					
	elif roll < 0.60:
		# 25% -> Cursed Item: 1 random debuff item added to inventory (cannot be discarded until next Rest)
		var cursed_items = ["cursed_amulet"]
		if ItemRegistry != null:
			var reg_cursed = ItemRegistry.get_items_by_rarity(ItemRegistry.Rarity.CURSED)
			if reg_cursed.size() > 0:
				cursed_items = reg_cursed
		var item = cursed_items[randi() % cursed_items.size()]
		print("[LuckEventHandler] Lose Outcome: Cursed Item -> %s" % item)
		EventNotifier.show_message("Luck Failure: Received Cursed Item %s!" % item, Color.PURPLE)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_error")
		if InventoryManager != null:
			InventoryManager.add_item(1, item)
			
	elif roll < 0.80:
		# 20% -> Surprise Elite Battle
		print("[LuckEventHandler] Lose Outcome: Surprise Elite Battle!")
		EventNotifier.show_message("Luck Failure: Surprise Elite Battle Ambush!", Color.DARK_RED)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_error")
		EventBus.start_combat.emit(NodeGraph.NodeType.ELITE)
		
	elif roll < 0.95:
		# 15% -> Coin Loss: -30% Coin from each wallet
		print("[LuckEventHandler] Lose Outcome: -30% Coin Loss")
		EventNotifier.show_message("Luck Failure: -30% Coin Loss from wallets!", Color.ORANGE)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_cancel")
		if CoinEconomy != null:
			var p1_bal = CoinEconomy.get_balance(1)
			var p2_bal = CoinEconomy.get_balance(2)
			CoinEconomy.deduct_coins(1, int(p1_bal * 0.3))
			CoinEconomy.deduct_coins(2, int(p2_bal * 0.3))
			
	else:
		# 5% -> Attribute Debuff: -3 to random attribute (removable at Rest)
		var attrs = ["vit", "str_stat", "int_stat", "con", "acc", "dex", "mov", "att", "lck"]
		var attr = attrs[randi() % attrs.size()]
		var attr_display = attr.replace("_stat", "").to_upper()
		print("[LuckEventHandler] Lose Outcome: -3 Attribute Debuff to %s" % attr_display)
		EventNotifier.show_message("Luck Failure: Debuffed -3 %s (Removable at Rest campfire)" % attr_display, Color.MAGENTA)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_error")
		for p in get_tree().get_nodes_in_group("players"):
			p.set_meta("luck_debuff_attr", attr)
			p.set_meta("luck_debuff_amount", -3)
			
			var stats = p.get_node_or_null("StatsComponent")
			if stats != null:
				var current_val = stats.get(attr)
				stats.set(attr, current_val - 3)
				if stats.has_method("emit_changed"):
					stats.emit_changed()

