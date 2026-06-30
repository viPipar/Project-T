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
		
	print("[StockManager] Stock Generated: %s" % str(current_stock))

func get_item_cost(item_id: String) -> int:
	if ItemRegistry == null:
		return 50
		
	var item_data = ItemRegistry.get_item(item_id)
	if item_data.is_empty():
		return 50
		
	var rarity = item_data.get("rarity", ItemRegistry.Rarity.COMMON)
	match rarity:
		ItemRegistry.Rarity.COMMON:
			return BalancingData.SHOP_PRICES.get("common_item", 50)
		ItemRegistry.Rarity.RARE:
			return BalancingData.SHOP_PRICES.get("rare_item", 120)
		ItemRegistry.Rarity.LEGENDARY:
			return BalancingData.SHOP_PRICES.get("legendary_item", 250)
		ItemRegistry.Rarity.CURSED:
			return 10
	return 50

func reroll_stock(player_id: int) -> bool:
	var cost = BalancingData.SHOP_PRICES.get("reroll", 100)
	
	if CoinEconomy != null:
		if CoinEconomy.get_balance(player_id) >= cost:
			if CoinEconomy.deduct_coins(player_id, cost):
				generate_stock()
				print("[StockManager] P%d rerolled shop stock for %d coins." % [player_id, cost])
				return true
				
	print("[StockManager] Reroll failed. P%d needs %d coins." % [player_id, cost])
	return false

func buy_item(player_id: int, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= current_stock.size():
		return false
		
	var item_id = current_stock[slot_index]
	if item_id == "":
		return false # already bought
		
	var cost = get_item_cost(item_id)
	
	if CoinEconomy != null:
		if CoinEconomy.get_balance(player_id) >= cost:
			if CoinEconomy.deduct_coins(player_id, cost):
				current_stock[slot_index] = "" # empty slot
				if InventoryManager != null:
					InventoryManager.add_item(player_id, item_id)
				print("[StockManager] P%d bought %s for %d coins." % [player_id, item_id, cost])
				return true
				
	return false
