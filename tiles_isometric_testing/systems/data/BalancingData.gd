extends Node
class_name BalancingData

# ── DROP RATES & RARITY ──────────────────────────────────────────────────────
# Normal Battle: Common 70%, Rare 25%, Legendary 5%
# Elite Battle: Common 30%, Rare 50%, Legendary 20%
# Boss Battle: Common 0%, Rare 30%, Legendary 70%

const DROP_WEIGHTS: Dictionary = {
	"normal": { "common": 70, "rare": 25, "legendary": 5 },
	"elite":  { "common": 30, "rare": 50, "legendary": 20 },
	"boss":   { "common": 0,  "rare": 30, "legendary": 70 }
}

# ── COIN ECONOMY ─────────────────────────────────────────────────────────────
# Coin drops per encounter type
const COIN_DROPS: Dictionary = {
	"normal": { "min": 15, "max": 25 },
	"elite":  { "min": 40, "max": 60 },
	"boss":   { "min": 100, "max": 150 },
	"event":  { "min": 10, "max": 50 } # Depending on event
}

const SHOP_PRICES: Dictionary = {
	"reroll": 100,
	"common_item": 50,
	"rare_item": 120,
	"legendary_item": 250,
	"heal_potion": 30
}

# ── ENEMY SCALING ────────────────────────────────────────────────────────────
# Base multipliers per depth layer. e.g. Depth 1 = 1.0, Depth 5 = 1.5
# (depth - 1) * scaling_factor
const SCALING_FACTOR_HP = 0.15
const SCALING_FACTOR_DMG = 0.10

# ── LEVEL EVENTS ─────────────────────────────────────────────────────────────
# Penalty for losing an event or running away
const PENALTY_HP_PERCENT = 0.5 # Lose 50% max HP

static func get_item_rarity(battle_type: String = "normal") -> String:
	if not DROP_WEIGHTS.has(battle_type):
		battle_type = "normal"
	
	var weights: Dictionary = DROP_WEIGHTS[battle_type]
	var total_weight = 0
	for w in weights.values():
		total_weight += w
	
	var roll = randi_range(1, total_weight)
	var current = 0
	
	for rarity in weights.keys():
		current += weights[rarity]
		if roll <= current:
			return rarity
	
	return "common"

static func get_coin_drop(battle_type: String = "normal") -> int:
	if not COIN_DROPS.has(battle_type):
		return 0
	return randi_range(COIN_DROPS[battle_type]["min"], COIN_DROPS[battle_type]["max"])

static func get_hp_multiplier(depth: int) -> float:
	return 1.0 + (max(0, depth - 1) * SCALING_FACTOR_HP)

static func get_dmg_multiplier(depth: int) -> float:
	return 1.0 + (max(0, depth - 1) * SCALING_FACTOR_DMG)
