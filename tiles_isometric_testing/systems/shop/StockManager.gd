extends Node
class_name StockManager

# Generates the shop stock and handles rerolling.

var item_pool: ItemPoolGenerator
var current_stock: Array[String] = []
const STOCK_SIZE = 7

func init(_pool: ItemPoolGenerator) -> void:
	self.item_pool = _pool

func generate_stock() -> void:
	current_stock.clear()
	# The shop can have its own rarity weights or use normal battle drop rates
	# Shop might lean slightly heavier towards Rares.
	print("[StockManager] Generating Shop Stock...")
	for i in range(STOCK_SIZE):
		# Let's say shop is equivalent to "elite" tier drops roughly
		var item_id = item_pool.roll_item("elite")
		current_stock.append(item_id)
		
	print("[StockManager] Stock Generated: %s" % current_stock)

func reroll_stock(player_id: int) -> bool:
	var cost = BalancingData.SHOP_PRICES.get("reroll", 100)
	
	# Check if player has enough coins (assuming CoinEconomy is a global or passed in)
	# if CoinEconomy.get_balance(player_id) >= cost:
	# 	CoinEconomy.deduct(player_id, cost)
	# 	generate_stock()
	# 	return true
	
	print("[StockManager] Reroll failed. P%d needs %d coins." % [player_id, cost])
	return false

func buy_item(player_id: int, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= current_stock.size():
		return false
		
	var item_id = current_stock[slot_index]
	if item_id == "":
		return false # Slot empty (already bought)
		
	# Check cost based on rarity
	# var item_data = ItemRegistry.get_item(item_id)
	# var cost = BalancingData.SHOP_PRICES["common_item"] # simplify
	
	# if CoinEconomy.deduct(player_id, cost):
	# 	current_stock[slot_index] = "" # empty slot
	# 	InventoryManager.add_item(player_id, item_id)
	# 	return true
	
	return false
