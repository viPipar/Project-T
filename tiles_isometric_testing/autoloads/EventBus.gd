extends Node

# Phase 0 — hanya sinyal movement
signal player_moved(entity: Node, from: Vector2i, to: Vector2i)

# Phase 1+ — didefinisikan sekarang, dipakai nanti
signal combat_started(combatants: Array)
signal combat_ended(result: String)
signal turn_started(entity: Node, player_id: int)
signal turn_ended(entity: Node)
signal damage_dealt(target: Node, amount: int, type: String, is_crit: bool)
signal entity_died(entity: Node, killer: Node)
signal miss_occurred(attacker: Node, target: Node)
signal dice_rolled(player_id: int, natural: int, total: int, vs_ac: int, is_hit: bool, is_crit: bool)
signal attackcam_started(attacker: Node, target: Node, ability_id: String)
signal attackcam_finished(attacker: Node)

# Phase 2 — class / stats events (scalable hooks)
signal class_changed(entity: Node, class_id: String)
signal buffs_changed(entity: Node)
signal stats_changed(entity: Node)
