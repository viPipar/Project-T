# Game Features Testing Guide

Panduan ini mengikuti implementasi runtime saat ini di project Godot `tiles_isometric_testing`.

## Main Scene Smoke Test

1. Open `res://main/Main.tscn`.
2. Run the scene.
3. Check the Godot Output panel.

Useful debug keys:

| Key | Use |
| :--- | :--- |
| `F1` | Toggle debug/stat panel |
| `F2` | Toggle dice sandbox |
| `F3` | Toggle per-player debug HUD |
| `T` | Run integrated roguelite + combat tests |

F3 debug HUD is disabled by default and only appears after pressing `F3`.

## Battle UX Manual Test

1. Move P1 cursor/camera with `WASD`.
2. Move P2 cursor/camera with `IJKL`.
3. Open P1 action wheel with `Q` or `E`.
4. Confirm P2 can still pan/move cursor while P1 wheel is open.
5. Close P1 wheel with `X`.
6. Open P2 action wheel with `U` or `O`.
7. Confirm P1 can still pan/move cursor while P2 wheel is open.
8. Press confirm on an enemy without selecting ability first. It must not roll attack.
9. Select an ability from the wheel.
10. Confirm movement highlight hides and ability target highlight appears.
11. Confirm target, wait for dice/attack sequence, then confirm movement highlight returns.

## Stat / HP Manual Test

1. Run `res://main/Main.tscn`.
2. Press `F1`.
3. Confirm Aria, Kael, Goblin, and Orc stats load from JSON.
4. Attack an enemy and confirm HP decreases.
5. Kill an enemy and confirm death/removal flow still runs.
6. Let enemy damage a player to 0 HP.
7. Confirm player becomes downed and does not disappear from the map.
8. Confirm heal on downed/dead target returns `0`.

Relevant data:

```text
res://data/stat_module/entity_base_stats/players.json
res://data/stat_module/entity_base_stats/enemies.json
res://data/stat_module/item_stat_mods/equipment.json
res://data/stat_module/buff_stat_mods/class_buffs.json
res://data/stat_module/condition_stat_mods/status_effects.json
```

## Status VFX Manual Test

1. Run `res://main/Main.tscn`.
2. Select P1, pick **Divine Departure** from the action wheel, and hit an enemy.
   - Confirm the enemy shows a **grey tint** and **yellow star(s) orbiting** their head in an isometric oval. Number of stars = turns remaining.
3. Let the enemy's turn pass and confirm the star count decrements each turn, disappearing when the stun expires.
4. Pick **Thrust** and hit an enemy. Confirm a **pulsing red tint** (Vulnerable).
5. Pick any **Fire** ability (e.g. Ring o' Fire). Confirm **flame particles** and **orange tint** on the enemy.
6. Kill a stunned/burning enemy. Confirm **all particles stop** and **tint resets to white** on death — no visual artifacts on the corpse.

> **Note:** `StatusVisualizerComponent` is auto-injected by `ConditionComponent._ready()`. No manual scene setup is needed. The main attack now also applies a **1-turn Stun on a critical hit**.

## Universal Test Shortcut

`Main.tscn` has a `T` shortcut that runs:

```text
res://testing/RoguelikeTester.gd
res://combat_core/tests/test_action_economy.gd
res://combat_core/tests/test_dice_roller.gd
res://combat_core/tests/test_phase_manager.gd
```

Run `Main.tscn`, press `T`, and read the Output panel.

## Individual Test Scripts

Roguelite:

```text
res://testing/RoguelikeTester.gd
```

Combat core:

```text
res://combat_core/tests/test_action_economy.gd
res://combat_core/tests/test_dice_roller.gd
res://combat_core/tests/test_phase_manager.gd
res://combat_core/tests/test.tscn
```

In Godot, right-click a `test_*.gd` script and choose Run, or open `test.tscn` and run the scene.

Headless example:

```bash
godot --headless --path tiles_isometric_testing --quit-after 1
```

On this local machine, the Godot executable may be outside PATH. Use the full executable path if needed.
