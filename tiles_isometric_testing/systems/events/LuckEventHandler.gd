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

func _get_live_player(player_id: int) -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		var pid = p.get("player_id")
		if pid != null and int(pid) == player_id:
			return p
	return null

func _get_player_ids() -> Array[int]:
	var result: Array[int] = []
	for p in get_tree().get_nodes_in_group("players"):
		var pid = p.get("player_id")
		if pid != null and not result.has(int(pid)):
			result.append(int(pid))
	if result.is_empty():
		result = [1, 2]
	return result

func _get_player_lck(player_id: int) -> int:
	var player := _get_live_player(player_id)
	if player != null:
		if StatSystem != null:
			return StatSystem.get_lck(player)
		if player.has_node("StatsComponent"):
			return player.get_node("StatsComponent").get_stat("lck")

	if RunManager != null:
		var state: Dictionary = RunManager.get_player_state(player_id)
		var lck := int(state.get("base_stats", {}).get("lck", 0))
		for effect in state.get("active_effects", []):
			if effect is Dictionary:
				var mods: Dictionary = {}
				var raw_mods = effect.get("mods", {})
				if raw_mods is Dictionary:
					mods = raw_mods as Dictionary
				lck += int(mods.get("lck", 0))
		return maxi(0, lck)
	return 0

func _add_item(player_id: int, item_id: String) -> void:
	if InventoryManager != null:
		InventoryManager.add_item(player_id, item_id)
	elif RunManager != null and RunManager.has_method("add_run_item"):
		RunManager.add_run_item(player_id, item_id, false)

func _heal_player(player_id: int, amount: int) -> void:
	var player := _get_live_player(player_id)
	if player != null:
		var hc = player.get_node_or_null("HealthComponent")
		if hc != null and hc.has_method("heal"):
			hc.heal(amount)
	if RunManager != null and RunManager.has_method("heal_run_player"):
		RunManager.heal_run_player(player_id, amount)

func _damage_player(player_id: int, amount: int) -> void:
	var player := _get_live_player(player_id)
	if player != null:
		var hc = player.get_node_or_null("HealthComponent")
		if hc != null and hc.has_method("take_damage"):
			hc.take_damage(amount, null, "true_damage")
	if RunManager != null and RunManager.has_method("damage_run_player"):
		RunManager.damage_run_player(player_id, amount)

func _damage_player_percent(player_id: int, percent: float) -> void:
	var player := _get_live_player(player_id)
	var max_hp := 20
	if player != null:
		var hc = player.get_node_or_null("HealthComponent")
		if hc != null:
			max_hp = int(hc.get("max_hp")) if hc.get("max_hp") != null else max_hp
			if hc.has_method("take_damage"):
				hc.take_damage(int(max_hp * percent), null, "true_damage")
	if RunManager != null:
		if RunManager.has_method("get_run_max_hp"):
			max_hp = RunManager.get_run_max_hp(player_id)
		if RunManager.has_method("damage_run_player"):
			RunManager.damage_run_player(player_id, int(max_hp * percent))

func _add_coins(player_id: int, amount: int) -> void:
	if CoinEconomy != null:
		CoinEconomy.add_coins(player_id, amount)
	elif RunManager != null and RunManager.has_method("add_run_coins"):
		RunManager.add_run_coins(player_id, amount, false)

func _deduct_coin_percent(player_id: int, percent: float) -> void:
	if CoinEconomy != null:
		var balance = CoinEconomy.get_balance(player_id)
		CoinEconomy.deduct_coins(player_id, int(balance * percent))
	elif RunManager != null:
		var state: Dictionary = RunManager.get_player_state(player_id)
		RunManager.add_run_coins(player_id, -int(int(state.get("coins", 0)) * percent), false)

func _add_base_stat(player_id: int, stat_key: String, amount: int) -> void:
	var player := _get_live_player(player_id)
	var normalized_key := RunPlayerState.normalize_stat_key(stat_key)
	if player != null:
		var stats = player.get_node_or_null("StatsComponent")
		if stats != null and stats.has_method("add_base_stat"):
			stats.add_base_stat(normalized_key, amount)
	if RunManager != null and RunManager.has_method("add_run_base_stat"):
		RunManager.add_run_base_stat(player_id, normalized_key, amount)

func _apply_until_rest_debuff(player_id: int, stat_key: String, amount: int) -> void:
	var normalized_key := RunPlayerState.normalize_stat_key(stat_key)
	var source_id := "debuff:luck_%s" % normalized_key
	if RunManager != null and RunManager.has_method("apply_run_effect"):
		RunManager.apply_run_effect(player_id, {
			"id": "luck_%s" % normalized_key,
			"kind": "debuff",
			"source_id": source_id,
			"mods": {normalized_key: amount},
			"stacks": 1,
			"duration_type": "until_rest",
			"remaining": -1,
		})
		return

	var player := _get_live_player(player_id)
	if player != null:
		player.set_meta("luck_debuff_attr", normalized_key)
		player.set_meta("luck_debuff_amount", amount)
		var stats = player.get_node_or_null("StatsComponent")
		if stats != null and stats.has_method("set_mod_source"):
			stats.set_mod_source(source_id, {normalized_key: amount})

func _snapshot_run() -> void:
	if RunManager != null:
		if RunManager.has_method("snapshot_all_players"):
			RunManager.snapshot_all_players()
		elif RunManager.has_method("save_run_to_disk"):
			RunManager.save_run_to_disk()

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
		var player_ids := _get_player_ids()
		if player_ids.size() > 0:
			var total_lck = 0
			for player_id in player_ids:
				total_lck += _get_player_lck(player_id)
			avg_lck = float(total_lck) / player_ids.size()
			
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
	_snapshot_run()

func _apply_reward_or_penalty(outcome: Dictionary) -> void:
	var reward_type = outcome.get("reward", "")
	var amount = outcome.get("amount", 0)
	
	if reward_type == "damage" or reward_type == "heal":
		if reward_type == "damage":
			EventNotifier.show_message("Luck Failed! -%d HP" % amount, Color.RED)
		else:
			EventNotifier.show_message("Luck Succeeded! +%d HP" % amount, Color.GREEN)
			
		for player_id in _get_player_ids():
			if reward_type == "damage":
				_damage_player(player_id, amount)
			elif reward_type == "heal":
				_heal_player(player_id, amount)
					
	elif reward_type == "random_item":
		var reward = EventDropGenerator.generate_drop("normal")
		EventNotifier.show_message("Luck Succeeded! You found %s!" % reward, Color.GOLD)
		_add_item(1, reward)

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
		_add_item(1, item1)
		_add_item(2, item2)
			
	elif roll < 0.65:
		# 25% -> Full HP Restore (both players 100% HP)
		print("[LuckEventHandler] Win Outcome: Full HP Restore")
		EventNotifier.show_message("Luck Win: Full HP Restore for both players!", Color.GREEN)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("victory")
		for player_id in _get_player_ids():
			_heal_player(player_id, 9999)
					
	elif roll < 0.85:
		# 20% -> Reward: 1 Legendary item
		var item = EventDropGenerator.generate_drop("boss") # boss guarantees legendary
		print("[LuckEventHandler] Win Outcome: 1 Legendary item -> %s" % item)
		EventNotifier.show_message("Luck Win: Found Legendary %s!" % item, Color.GOLD)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_legendary")
		_add_item(1, item)
			
	elif roll < 0.95:
		# 10% -> Gold Windfall (+200 Coin each player)
		print("[LuckEventHandler] Win Outcome: +200 Coin each")
		EventNotifier.show_message("Luck Win: Gold Windfall! +200 Coins each!", Color.YELLOW)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_rare")
		_add_coins(1, 200)
		_add_coins(2, 200)
			
	else:
		# 5% -> Stat Boost (permanent +2 to random attribute, both)
		var attrs = ["vit", "str_stat", "int_stat", "con", "acc", "dex", "mov", "att", "lck"]
		var attr = attrs[randi() % attrs.size()]
		var attr_display = attr.replace("_stat", "").to_upper()
		print("[LuckEventHandler] Win Outcome: Permanent +2 to %s" % attr_display)
		EventNotifier.show_message("Luck Win: Permanent +2 to %s for both players!" % attr_display, Color.CYAN)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("reveal_rare")
		for player_id in _get_player_ids():
			_add_base_stat(player_id, attr, 2)

func _apply_lose_outcome() -> void:
	var roll = randf()
	if roll < 0.35:
		# 35% -> HP Penalty: -50% HP (both players)
		print("[LuckEventHandler] Lose Outcome: -50% HP Penalty")
		EventNotifier.show_message("Luck Failure: -50% HP Penalty for both players!", Color.RED)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_error")
		for player_id in _get_player_ids():
			_damage_player_percent(player_id, 0.5)
					
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
		_add_item(1, item)
			
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
		_deduct_coin_percent(1, 0.3)
		_deduct_coin_percent(2, 0.3)
			
	else:
		# 5% -> Attribute Debuff: -3 to random attribute (removable at Rest)
		var attrs = ["vit", "str_stat", "int_stat", "con", "acc", "dex", "mov", "att", "lck"]
		var attr = attrs[randi() % attrs.size()]
		var attr_display = attr.replace("_stat", "").to_upper()
		print("[LuckEventHandler] Lose Outcome: -3 Attribute Debuff to %s" % attr_display)
		EventNotifier.show_message("Luck Failure: Debuffed -3 %s (Removable at Rest campfire)" % attr_display, Color.MAGENTA)
		var am = get_node_or_null("/root/AudioManager")
		if am != null: am.play_sfx("ui_error")
		for player_id in _get_player_ids():
			_apply_until_rest_debuff(player_id, attr, -3)
