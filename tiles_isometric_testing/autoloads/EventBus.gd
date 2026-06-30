extends Node

# ═══════════════════════════════════════════════════════════
# Phase 0 — Movement
# ═══════════════════════════════════════════════════════════
@warning_ignore("unused_signal")
signal player_moved(entity: Node, from: Vector2i, to: Vector2i)

# ═══════════════════════════════════════════════════════════
# Phase 1 — Combat Core (Tapip)
# ═══════════════════════════════════════════════════════════
@warning_ignore("unused_signal")
signal combat_started(combatants: Array)
@warning_ignore("unused_signal")
signal start_combat(node_type: int)
@warning_ignore("unused_signal")
signal combat_ended(result: String)
@warning_ignore("unused_signal")
signal turn_started(entity: Node, player_id: int)
@warning_ignore("unused_signal")
signal turn_ended(entity: Node)
@warning_ignore("unused_signal")
signal damage_dealt(target: Node, amount: int, type: String, is_crit: bool, source: Node)
@warning_ignore("unused_signal")
signal entity_died(entity: Node, killer: Node)
@warning_ignore("unused_signal")
signal entity_downed(entity: Node, attacker: Node)
# TODO (Team): miss_occurred has been deleted and merged into on_miss below
@warning_ignore("unused_signal")
signal dice_rolled(player_id: int, natural: int, total: int, vs_ac: int, is_hit: bool, is_crit: bool)
@warning_ignore("unused_signal")
signal attackcam_started(attacker: Node, target: Node, ability_id: String, target_pos: Vector2i)
@warning_ignore("unused_signal")
signal action_wheel_selected(player_id: int, action_name: String)
@warning_ignore("unused_signal")
signal action_wheel_visibility_changed(player_id: int, visible: bool)
@warning_ignore("unused_signal")
signal attackcam_finished(attacker: Node)
@warning_ignore("unused_signal")
signal combat_action_finished()

# Phase movement+ - forced movement / knockback events
@warning_ignore("unused_signal")
signal forced_movement_started(entity: Node, from: Vector2i, direction: Vector2i, power: int)
@warning_ignore("unused_signal")
signal forced_movement_finished(entity: Node, from: Vector2i, to: Vector2i, moved_steps: int)
@warning_ignore("unused_signal")
signal forced_movement_collided(entity: Node, collision_tile: Vector2i, collision_damage: int, collision_type: String)

# Phase 1+ - input blocking during combat animations
# player_id: 1 atau 2. blocked: true = blok, false = buka
@warning_ignore("unused_signal")
signal combat_input_blocked(player_id: int, blocked: bool)

# ═══════════════════════════════════════════════════════════
# Phase 2 — Class / Stats (Candra)
# ═══════════════════════════════════════════════════════════
@warning_ignore("unused_signal")
signal class_changed(entity: Node, class_id: String)
@warning_ignore("unused_signal")
signal buffs_changed(entity: Node)
@warning_ignore("unused_signal")
signal stats_changed(entity: Node)

# Phase 5 — Combat HUD overlay
# Emitted by CombatTestBridge after action economy managers are created.
# resource_mgr: EnergyChargeManager (P1) or SpellSlotManager (P2)
@warning_ignore("unused_signal")
signal combat_hud_ready(player_id: int, ap_mgr: Node, mov_mgr: Node, resource_mgr: Node)

# Inventory toggle (Tab key)
@warning_ignore("unused_signal")
signal inventory_toggled()

# ═══════════════════════════════════════════════════════════
# Phase 3 — Ability System (Gilang)
# ═══════════════════════════════════════════════════════════

## Emitted after any BaseAbility.execute() resolves.
## result dict contains: { damage, knockback_tiles, status_effect, element_tag, is_crit }
# TODO (Gilang): Integrate Ability execution to emit these signals
@warning_ignore("unused_signal")
signal ability_executed(caster: Node, targets: Array, result: Dictionary)

## Hit/miss resolution — downstream of ability_executed
@warning_ignore("unused_signal")
signal request_dice_roll(attacker: Node, target: Node, hit_result: Dictionary)
@warning_ignore("unused_signal")
signal dice_roll_finished()

@warning_ignore("unused_signal")
signal on_hit(attacker: Node, target: Node, result: Dictionary)
@warning_ignore("unused_signal")
signal on_miss(attacker: Node, target: Node)

## Knockback — emitted by KnockbackResolver after processing ability_executed
@warning_ignore("unused_signal")
signal on_knockback(entity: Node, direction: Vector2, tiles: int)

## Status effects lifecycle
@warning_ignore("unused_signal")
signal on_status_applied(entity: Node, status_id: String, duration: int, stacks: int)
@warning_ignore("unused_signal")
signal on_status_removed(entity: Node, status_id: String)

## Elemental combo trigger
@warning_ignore("unused_signal")
signal elemental_combo_triggered(target: Node, combo_name: String, combo_effect: String)

# ═══════════════════════════════════════════════════════════
# Phase 4 — UI Notifications (Rapit)
# ═══════════════════════════════════════════════════════════

## HUD blink when cross-conversion item is applied
## resource_type: "ap", "bap", "energy_charge", "spell_slot", "movement"
# TODO (Rapit): Listen to these signals to trigger HUD animations
@warning_ignore("unused_signal")
signal resource_blink_requested(player_id: int, resource_type: String)

## Generic floating text request
## type: "damage", "heal", "miss", "status", "element"
@warning_ignore("unused_signal")
signal floating_text_requested(entity: Node, text: String, color: Color, type: String)

# ═══════════════════════════════════════════════════════════
# Phase 5 — Roguelite / Item System (Ilham)
# ═══════════════════════════════════════════════════════════

## Item selection flow
# TODO (Ilham): Integrate Roguelite item picking logic to emit these
@warning_ignore("unused_signal")
signal item_picked(player_id: int, item_data: Variant)
@warning_ignore("unused_signal")
signal contested_pick_started(item_data: Variant, p1_roll: int, p2_roll: int)
@warning_ignore("unused_signal")
signal contested_pick_resolved(winner_id: int, item_data: Variant)

## Rarity reveal for particle systems (Rapit)
@warning_ignore("unused_signal")
signal item_revealed(rarity: int)
