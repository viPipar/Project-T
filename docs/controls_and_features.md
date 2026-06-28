# Battle Controls, Action Wheel, and Targeting

Dokumen ini mengikuti implementasi runtime di `Main.tscn` saat ini.

## Input Map

| Action | Player 1 | Player 2 |
| :--- | :--- | :--- |
| Move / Cursor Up | `W` | `I` |
| Move / Cursor Left | `A` | `J` |
| Move / Cursor Down | `S` | `K` |
| Move / Cursor Right | `D` | `L` |
| Confirm | `F` | `;` |
| Cancel | `X` | `,` |
| Open Wheel / Previous Page | `Q` | `U` |
| Open Wheel / Next Page | `E` | `O` |
| End Turn / Cancel End Turn | `R` | `P` |
| Inventory | `C` | `.` |
| Statistics | `Z` | `M` |
| Center Camera | `Shift` | `Enter` |
| Pause Menu | `Escape` / `Backspace` | Shared |

Debug shortcuts in `Main.tscn`:

| Key | Use |
| :--- | :--- |
| `F1` | Toggle debug/stat panel |
| `F2` | Toggle dice sandbox |
| `F3` | Toggle per-player debug HUD |
| `T` | Run integrated roguelite + combat tests |

F3 debug HUD is off by default in normal battle.

## Action Wheel Runtime

Main game now spawns:

```text
res://ui/action_wheel/BattleActionWheelOverlay.tscn
```

The old prototype scene is no longer used:

```text
res://ui/action_wheel/testing.tscn
```

Controller:

```text
res://ui/action_wheel/BattleActionWheelController.gd
```

Both wheels load abilities from:

```text
res://combat_core/abilities/instances/
```

Physical abilities are assigned to P1. Magical abilities are assigned to P2.

## Per-Player Menu Blocking

Action wheel input blocking is per-player, not global.

Implemented in:

```text
res://autoloads/InputManager.gd
res://ui/action_wheel/ActionWheel.gd
res://world/PlayerCamera2D.gd
```

Important API:

```gdscript
InputManager.set_player_menu_blocked(player_id, blocked)
InputManager.is_player_menu_blocked(player_id)
```

Rules:

- If P1 opens the wheel, only P1 gameplay input is blocked.
- If P2 opens the wheel, only P2 gameplay input is blocked.
- The other player can still pan camera and move cursor.
- Battle action wheel must not set `InputManager.is_in_menu`.
- `InputManager.is_in_menu` is reserved for true global menus.

Wheel visibility is broadcast with:

```gdscript
EventBus.action_wheel_visibility_changed(player_id, visible)
```

HUD uses this signal to reduce bottom-label clutter while the wheel is open.

## Attack and Targeting Flow

Direct confirm attack is disabled. A player cannot press confirm on self, ally, or enemy to roll damage before selecting an ability.

Correct flow:

1. Open action wheel with `Q` / `E` for P1 or `U` / `O` for P2.
2. Pick an ability.
3. Player enters targeting mode.
4. Movement highlight for the attacker is hidden.
5. Ability range / target area is highlighted.
6. Confirm a valid target tile or entity.
7. Dice / attack sequence runs.
8. Movement highlight returns only after combat input is unblocked.

Implemented in:

```text
res://entities/player/Player.gd
res://autoloads/MovementRangeManager.gd
res://world/SelectionCursor.gd
res://world/KeyboardTileCursor.gd
res://combat_core/tests/CombatTestBridge.gd
```

Player state used by highlight systems:

```gdscript
PlayerState.IDLE
PlayerState.TARGETING
PlayerState.ACTING
```

Cursor validity during targeting uses ability target tiles, not movement tiles.

## End Turn Overlay

End-turn overlay text reads the current `InputMap` action instead of hardcoded old keys.

Implemented in:

```text
res://ui/split_screen/SplitScreenManager.gd
```

Current default cancel/end-turn keys:

```text
P1: R
P2: P
```

## Manual UX Smoke Test

1. Run `res://main/Main.tscn`.
2. Open P1 wheel with `Q` or `E`.
3. Confirm P2 can still move cursor/camera with `IJKL`.
4. Close P1 wheel with `X`.
5. Open P2 wheel with `U` or `O`.
6. Confirm P1 can still move cursor/camera with `WASD`.
7. Press confirm on an enemy without choosing an ability. It must not roll attack.
8. Choose an ability, confirm a valid target, and wait for dice/attack to finish.
9. Confirm movement highlight is hidden during targeting/attack and returns after the attack sequence.
