# Project Map (PROJECT_MAP.md)

This map describes the directory structure, global singletons, entity components, and system dependencies for **Project-T**. Use this as a guide to locate scripts, scenes, and JSON data.

---

## 1. Directory Structure Overview

* **`docs/`**: Technical specs, GDD, task checklists, and context logs.
* **`tiles_isometric_testing/`**: Main Godot project root.
  * **`assets/`**: Visual, audio, and shader assets (music, characters, tiles, ui_assets, etc.).
    * **`backgrounds/`**: Environment scene backgrounds (`scene_1` to `scene_5`).
    * **`characters/`**: Player classes (`p1_fighter`, `p2_wizard`) and enemy sprites (`big_beetle`, `medium_grasshopper`, `small_mosquito`).
    * **`ui_assets/`**: Font settings, HUD layouts, and subfolders for skill icons (`skill_icons/`), item icons (`item_icons/`), hit vfx (`vfx/`), and projectile sprites (`projectiles/`).
  * **`autoloads/`**: Global singletons (event buses, grid trackers, managers).
  * **`combat_core/`**: Combat actions, dice rolls, AI brains, and tests.
  * **`components/`**: Modular entity behavior nodes (composition over inheritance).
  * **`data/`**: JSON configuration files defining base stats, items, and status effects.
  * **`entities/`**: Player, enemy, and obstacle scene trees.
  * **`main/`**: Main entry scene and shaders.
  * **`systems/`**: Shop, progression (run state), and inventory logic.
  * **`testing/`**: Isolated test cases (e.g. roguelike flow tester).
  * **`ui/`**: Split-screen viewport, action wheels, and Neo-brutalist overlays.
  * **`world/`**: Camera, grids, and keyboard cursors.

---

## 2. Key Autoload Singletons (`tiles_isometric_testing/autoloads/`)

Global entry points loaded at startup. Read these to access grid or state queries:

* **[EventBus.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/EventBus.gd)**: Centralized pub/sub message broker. All combat, movement, phase change, and item signals are piped here.
* **[GridManager.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/GridManager.gd)**: Single source of truth for grid topology. Tracks walls, items, and entity placement. Offers A* pathfinding queries.
* **[StatSystem.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/StatSystem.gd)**: Computes dynamic runtime stats, combining base stats, item mods, and status buff/debuff modifiers.
* **[StatDataDB.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/StatDataDB.gd)**: Parses JSON definitions and applies/removes status and equipment modifiers.
* **[TurnManager.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/TurnManager.gd)**: Manages turn-based phase progression (Player Phase vs. Enemy Phase).
* **[IsoUtils.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/IsoUtils.gd)**: Screen-to-grid and grid-to-screen coordinate converters.
* **[InputManager.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/InputManager.gd)**: Dispatches keyboard inputs and locks player action keys when busy.
* **[ForcedMovementResolver.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/ForcedMovementResolver.gd)**: Computes knockbacks, pulls, grid collisions, and wall impacts.
* **[ElementSystem.gd](file:///d:/Project-T/tiles_isometric_testing/autoloads/ElementSystem.gd)**: Resolves elemental combo reactions (e.g., Water + Fire = Vapor).

---

## 3. Entity Composition Components (`tiles_isometric_testing/components/`)

Entities are built using modular components rather than deep inheritance:

* **[StatsComponent.gd](file:///d:/Project-T/tiles_isometric_testing/components/StatsComponent.gd)**: Stores base attributes (`VIT`, `STR`, `INT`, `CON`, `ACC`, `DEX`, `MOV`, `ATT`, `LCK`) and active modifiers.
* **[HealthComponent.gd](file:///d:/Project-T/tiles_isometric_testing/components/HealthComponent.gd)**: Manages HP calculations, downs/revives players, and processes death.
* **[ConditionComponent.gd](file:///d:/Project-T/tiles_isometric_testing/components/ConditionComponent.gd)**: Tick loops that process status DoT damages and temporary stat changes from JSON.
* **[StatusVisualizerComponent.gd](file:///d:/Project-T/tiles_isometric_testing/components/StatusVisualizerComponent.gd)**: Controls status particles and sprite shader tints.
* **[MovementComponent.gd](file:///d:/Project-T/tiles_isometric_testing/components/MovementComponent.gd)**: Animates tile-to-tile movement.
* **[ClassComponent.gd](file:///d:/Project-T/tiles_isometric_testing/components/ClassComponent.gd)**: Holds class information (Slayer, Scholar, etc.).

---

## 4. Combat Core (`tiles_isometric_testing/combat_core/`)

Where mechanics for phase execution and calculations live:

* **[CombatActionResolver.gd](file:///d:/Project-T/tiles_isometric_testing/combat_core/tests/CombatActionResolver.gd)**: Resolves accuracy rolls (D20 + Mod vs. Defense), critical hits, AOE collections, damage, and triggers status/movement reactions.
* **[CombatTestBridge.gd](file:///d:/Project-T/tiles_isometric_testing/combat_core/tests/CombatTestBridge.gd)**: Orchestrates real-time animations, player action queue confirmations, and ties the game view to backend logic.
* **`action_economy/`**:
  * `ActionPointManager.gd`: Handles Action Points (AP) and Bonus Action Points (BAP).
  * `EnergyChargeManager.gd`: P1 (Fighter) energy charge tracking.
  * `SpellSlotManager.gd`: P2 (Wizard) spell slots tracker.
* **`ai/`**:
  * `EnemyAIController.gd`: Basic target searching, resource checks, and ability usage choices.

---

## 5. Progression & Shop Systems (`tiles_isometric_testing/systems/`)

* **`items/`**:
  * `ItemRegistry.gd`: Catalog of valid items.
  * `InventoryManager.gd`: Per-player inventory stacks.
  * `ItemEffectApplier.gd`: Applies stat/resource changes when items are picked up.
* **`shop/`**:
  * `CoinEconomy.gd`: Trackers for player gold wallets and transaction logic.
* **`progression/`**:
  * `RunManager.gd`: Procedural seed generators, run depth tracking, and transition triggers.

---

## 6. UI & Viewport Layering (`tiles_isometric_testing/ui/`)

* **`split_screen/`**:
  * **[SplitScreenManager.gd](file:///d:/Project-T/tiles_isometric_testing/ui/split_screen/SplitScreenManager.gd)**: Configures co-op screen sharing. P1 view uses cull mask `1 | 2`, while P2 view uses cull mask `1 | 4`.
* **`action_wheel/`**:
  * Radial selection hubs for selecting action abilities on player turns.
* **`roguelike/`**:
  * Screens with Neo-brutalist layouts: `MapScreen.tscn` (node map), `ShopScreen.tscn` (item merchant), `RestScreen.tscn` (campfire rest/search), `LootScreen.tscn` (item loot), and `EventScreen.tscn` (luck encounters).
  * `DualCursorUI.gd`: Synchronized cursors for multi-player co-op menu selection.
