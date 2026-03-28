# Project Changes & Implemented Features

This file summarizes the changes applied and the current implemented systems.

## Implemented Systems
- Isometric grid movement with A* pathing, grid occupancy, and wall blocking (entities mark tiles solid).
- Two-player control with independent cursors and highlight states.
- Line-of-sight projectile check for attacks (hit entity / hit wall / miss).
- AttackCam visual/sfx trigger on hit.
- Turn system with shared player phase and queued enemy phase.
- Turn number display ("Turn N - Players/Enemies").
- Enemy placeholder target with red-tinted sprite (previewable in its own scene).
- Stats system with derived modifiers based on VIT/STR/INT/CON/ACC/DEX/MOV/ATT/LCK.
- Class/Order system with cross-class buff pickups (roguelike style).
- Debug panel option to show live stats/classes/buffs for players and enemies.
- Debug UI, grid, and dice sandbox hidden by default (toggle via F-keys).
- "F1: Toggle Debug Info" tooltip always visible.
- Movement range highlights from each player's tile (pathing-aware).
- Default movement range reduced (smaller highlight footprint).
- Cursor movement is unlimited by default (no clamping); optional safety clamp available.

## Control Scheme (Current)
- P1: Move WASD, Confirm E, End Turn Q
- P2: Move IJKL, Confirm O, End Turn U
- F1: Toggle Debug Panel
- F2: Toggle Dice Sandbox
- F3: Toggle Debug Grid

## Turn System Behavior
- Players can act freely during player phase.
- Each player must end their turn before enemies act.
- Enemy phase processes each enemy in a queue.
- Turn number increments after enemy phase completes.

## Stats System (Derived Modifiers)
- VIT: +1 HP per 2 VIT, +1 Resist per 4 VIT
- STR: +1 Physical Damage per 2 STR, +1 HP per 4 STR
- INT: +1 Magical Damage per 2 INT, +1 Bonus Action Point per 10 INT
- CON: +1 Armor per 2 CON, +1 Resist per 4 CON
- ACC: +1 Hit Roll per 2 ACC, -1 Natural Crit Roll per 10 ACC
- DEX: +1 Armor per 4 DEX, +1 Action Point per 10 DEX
- MOV: +1 Tiles per 5 MOV (wired into movement range)
- ATT: +1 Spell Slot L1 per 10 ATT, L2 per 15 ATT, L3 per 20 ATT
- LCK: +1 Luck Event Roll per 5 LCK

## Class / Order System (Scalable)
- Data-driven Order definitions live in `autoloads/ClassDB.gd` (autoload name: `OrderDB`).
- Each unit has a `ClassComponent` that:
  - Stores primary class (Order).
  - Accepts buffs from any class.
  - Applies stat modifiers to `StatsComponent` automatically.
- Player defaults:
  - P1 primary class: `slayer`
  - P2 primary class: `scholar`

## Debug Panel: Stats & Classes
- Toggle inside the debug menu: "Show Stats & Classes".
- Displays per-entity:
  - Primary class
  - Buff list
  - Final stat totals (base + buffs)
  - Derived bonuses (HP/Armor/Resist/AP/Movement/Hit/Crit)

## Files Added
- `autoloads/TurnManager.gd`
- `autoloads/MovementRangeManager.gd`
- `ui/shared/TurnLabel.gd`
- `entities/enemies/EnemyPlaceholder.gd`
- `entities/enemies/EnemyPlaceholder.tscn`
- `components/StatsComponent.gd`
- `components/ClassComponent.gd`
- `autoloads/ClassDB.gd` (autoloaded as `OrderDB`)
- `ui/debug/DebugPanel.gd`
- `PROJECT_CHANGES.md`

## Files Updated
- `project.godot` (autoloads, input actions)
- `main/main.gd` (turn start, player class defaults, debug defaults)
- `main/Main.tscn` (turn label node, enemy instance, debug panel nodes)
- `entities/player/Player.gd` (turn end input, class/stats refs)
- `entities/player/Player.tscn` (StatsComponent + ClassComponent nodes)
- `entities/enemies/EnemyPlaceholder.gd` (start_grid_pos support)
- `entities/enemies/EnemyPlaceholder.tscn` (StatsComponent + ClassComponent nodes, previewable sprite)
- `components/MovementComponent.gd` (MOV stat bonus applied to movement range, respects occupancy, smaller default range)
- `autoloads/GridManager.gd` (centralized occupancy rules, can_enter_tile)
- `autoloads/EventBus.gd` (class/stats events)
- `autoloads/InputManager.gd` (turn-phase input gating + end turn)
- `ui/debug/DebugPanel.gd` (uses scene nodes for stats UI)
- `main/main.gd` (debug tooltip always visible)
- `world/KeyboardTileCursor.gd` (unlimited cursor movement by default, optional safety clamp)
- `autoloads/MovementRangeManager.gd` (typed range caching helpers)

## Known Gaps / Next Steps
- Combat resolution system is stubbed (no damage application yet).
- Turn-based enemy AI triggers are ready but combat components are not fully implemented.
- Action points are not yet enforced; players currently have unlimited actions per turn.
