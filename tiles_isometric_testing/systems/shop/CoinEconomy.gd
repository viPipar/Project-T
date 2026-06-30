extends Node

# Handles the player wallets and money transfers.

signal balance_changed(player_id: int, new_balance: int)

var wallets: Dictionary = {
	1: 9999,
	2: 9999
}

func get_balance(player_id: int) -> int:
	return wallets.get(player_id, 0)

func add_coins(player_id: int, amount: int) -> void:
	if not wallets.has(player_id): return
	wallets[player_id] += amount
	print("[CoinEconomy] P%d gained %d coins. Total: %d" % [player_id, amount, wallets[player_id]])
	balance_changed.emit(player_id, wallets[player_id])

func deduct_coins(player_id: int, amount: int) -> bool:
	if not wallets.has(player_id): return false
	
	if wallets[player_id] >= amount:
		wallets[player_id] -= amount
		print("[CoinEconomy] P%d spent %d coins. Total: %d" % [player_id, amount, wallets[player_id]])
		balance_changed.emit(player_id, wallets[player_id])
		return true
	return false

# ── TRANSFER MECHANICS ───────────────────────────────────────────────────────

func send_fraction(from_player: int, to_player: int, fraction: float) -> bool:
	if not wallets.has(from_player) or not wallets.has(to_player):
		return false
		
	var balance = wallets[from_player]
	if balance <= 0:
		return false
		
	# Floor the fraction so we don't transfer decimals
	var amount = int(balance * fraction)
	
	if amount <= 0:
		return false
		
	if deduct_coins(from_player, amount):
		add_coins(to_player, amount)
		print("[CoinEconomy] P%d sent %d coins to P%d." % [from_player, amount, to_player])
		return true
		
	return false

func send_half(from_player: int, to_player: int) -> void:
	send_fraction(from_player, to_player, 0.5)

func send_quarter(from_player: int, to_player: int) -> void:
	send_fraction(from_player, to_player, 0.25)

func reset() -> void:
	wallets[1] = 9999
	wallets[2] = 9999
	balance_changed.emit(1, 9999)
	balance_changed.emit(2, 9999)
