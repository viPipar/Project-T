extends Node
class_name RestLootHandler

# Handles logic for Rest nodes and Loot nodes (including minigame).

enum RestOption {
	FULL_HEAL,
	PARTIAL_HEAL_BUFF,
	TREASURE
}

func handle_rest_choice(player_id: int, option: RestOption) -> void:
	var player = null
	if TurnManager != null and TurnManager.has_method("_get_player_by_id"):
		player = TurnManager._get_player_by_id(player_id)
		
	var hc = null
	var stats = null
	if player != null:
		hc = player.get_node_or_null("HealthComponent")
		stats = player.get_node_or_null("StatsComponent")
		
	match option:
		RestOption.FULL_HEAL:
			print("[RestLootHandler] P%d selected Full Heal." % player_id)
			if hc != null:
				hc.heal_to_full() if hc.has_method("heal_to_full") else hc.heal(9999)
		RestOption.PARTIAL_HEAL_BUFF:
			print("[RestLootHandler] P%d selected Partial Heal + Buff." % player_id)
			if hc != null and stats != null:
				var max_hp = stats.get_max_hp() if stats.has_method("get_max_hp") else hc.max_hp
				hc.heal(int(max_hp * 0.3))
			# Stats.apply_buff(player_id, "damage", 1) # TODO: Apply buff via StatsComponent
		RestOption.TREASURE:
			print("[RestLootHandler] P%d selected Treasure." % player_id)
			# Inventory.add_item(player_id, random_rare_item)

# ── LOOT MINIGAME ────────────────────────────────────────────────────────────

# Mock: 3-Card Monte style game
func start_loot_minigame() -> void:
	print("[RestLootHandler] Starting Loot Minigame (3-Card Monte)...")
	# UI would show 3 chests/cards, shuffle them, and ask player to pick one.
	# One has Legendary, one has Common, one is empty (or Cursed).

func resolve_loot_minigame(player_id: int, choice_index: int, correct_index: int) -> void:
	if choice_index == correct_index:
		print("[RestLootHandler] P%d won the minigame! Legendary Reward!" % player_id)
	else:
		print("[RestLootHandler] P%d lost the minigame! Common Reward." % player_id)
