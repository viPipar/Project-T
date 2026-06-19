extends Node

# ═══════════════════════════════════════════════════════════
# Phase 0 — Movement
# ═══════════════════════════════════════════════════════════
signal player_moved(entity: Node, from: Vector2i, to: Vector2i)

# ═══════════════════════════════════════════════════════════
# Phase 1 — Combat Core (Tapip)
# ═══════════════════════════════════════════════════════════
signal combat_started(combatants: Array)
signal start_combat(node_type: int)
signal combat_ended(result: String)
signal turn_started(entity: Node, player_id: int)
signal turn_ended(entity: Node)
signal damage_dealt(target: Node, amount: int, type: String, is_crit: bool)
signal entity_died(entity: Node, killer: Node)
# TODO (Team): miss_occurred has been deleted and merged into on_miss below
signal dice_rolled(player_id: int, natural: int, total: int, vs_ac: int, is_hit: bool, is_crit: bool)
signal attackcam_started(attacker: Node, target: Node, ability_id: String)
signal action_wheel_selected(player_id: int, action_name: String)
signal attackcam_finished(attacker: Node)

# Phase movement+ - forced movement / knockback events
signal forced_movement_started(entity: Node, from: Vector2i, direction: Vector2i, power: int)
signal forced_movement_finished(entity: Node, from: Vector2i, to: Vector2i, moved_steps: int)
signal forced_movement_collided(entity: Node, collision_tile: Vector2i, collision_damage: int, collision_type: String)

# Phase 1+ - input blocking during combat animations
# player_id: 1 atau 2. blocked: true = blok, false = buka
signal combat_input_blocked(player_id: int, blocked: bool)

# ═══════════════════════════════════════════════════════════
# Phase 2 — Class / Stats (Candra)
# ═══════════════════════════════════════════════════════════
signal class_changed(entity: Node, class_id: String)
signal buffs_changed(entity: Node)
signal stats_changed(entity: Node)

# Phase 5 — Combat HUD overlay
# Emitted by CombatTestBridge after action economy managers are created.
# resource_mgr: EnergyChargeManager (P1) or SpellSlotManager (P2)
signal combat_hud_ready(player_id: int, ap_mgr: Node, mov_mgr: Node, resource_mgr: Node)

# Inventory toggle (Tab key)
signal inventory_toggled()

# ═══════════════════════════════════════════════════════════
# Phase 3 — Ability System (Gilang)
# ═══════════════════════════════════════════════════════════

## Emitted after any BaseAbility.execute() resolves.
## result dict contains: { damage, knockback_tiles, status_effect, element_tag, is_crit }
# TODO (Gilang): Integrate Ability execution to emit these signals
signal ability_executed(caster: Node, targets: Array, result: Dictionary)

## Hit/miss resolution — downstream of ability_executed
signal on_hit(attacker: Node, target: Node, result: Dictionary)
signal on_miss(attacker: Node, target: Node)

## Knockback — emitted by KnockbackResolver after processing ability_executed
signal on_knockback(entity: Node, direction: Vector2, tiles: int)

## Status effects lifecycle
signal on_status_applied(entity: Node, status_id: String, duration: int, stacks: int)
signal on_status_removed(entity: Node, status_id: String)

## Elemental combo trigger
signal elemental_combo_triggered(target: Node, combo_name: String, combo_effect: String)

# ═══════════════════════════════════════════════════════════
# Phase 4 — UI Notifications (Rapit)
# ═══════════════════════════════════════════════════════════

## HUD blink when cross-conversion item is applied
## resource_type: "ap", "bap", "energy_charge", "spell_slot", "movement"
# TODO (Rapit): Listen to these signals to trigger HUD animations
signal resource_blink_requested(player_id: int, resource_type: String)

## Generic floating text request
## type: "damage", "heal", "miss", "status", "element"
signal floating_text_requested(entity: Node, text: String, color: Color, type: String)

# ═══════════════════════════════════════════════════════════
# Phase 5 — Roguelite / Item System (Ilham)
# ═══════════════════════════════════════════════════════════

## Item selection flow
# TODO (Ilham): Integrate Roguelite item picking logic to emit these
signal item_picked(player_id: int, item_data: Resource)
signal contested_pick_started(item_data: Resource, p1_roll: int, p2_roll: int)
signal contested_pick_resolved(winner_id: int, item_data: Resource)

## Rarity reveal for particle systems (Rapit)
signal item_revealed(rarity: int)
