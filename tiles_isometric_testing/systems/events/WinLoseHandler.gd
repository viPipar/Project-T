extends Node
class_name WinLoseHandler

# Handles post-battle win/lose states and rewards.

var item_pool: ItemPoolGenerator

func init(_item_pool: ItemPoolGenerator) -> void:
	self.item_pool = _item_pool

func handle_win(battle_type: String) -> void:
	print("[WinLoseHandler] Processing Win State for %s battle..." % battle_type)
	
	# 1. Distribute Coins
	var coins = BalancingData.get_coin_drop(battle_type)
	# CoinEconomy.add_coins(1, coins / 2)
	# CoinEconomy.add_coins(2, coins / 2)
	
	# 2. Distribute Items (e.g. 2 items for winning)
	var rewards = item_pool.generate_reward_pool(battle_type, 2)
	print("[WinLoseHandler] Win Rewards: %s, Coins: %d" % [rewards, coins])
	
	# 3. Heal (Optional based on balancing, e.g. Full HP after Boss)
	if battle_type == "boss":
		print("[WinLoseHandler] Boss Defeated! Full Heal applied.")

func handle_lose() -> void:
	print("[WinLoseHandler] Processing Lose State...")
	
	# Lose 50% max HP penalty (handled by RunManager reset usually, but if escaping:)
	# Candra's HP system hook
	print("[WinLoseHandler] Applying -50% HP Penalty.")
	
	# Or give cursed item
	# InventoryManager.add_item(1, "cursed_amulet")
	# InventoryManager.add_item(2, "cursed_amulet")
