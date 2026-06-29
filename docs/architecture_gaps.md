# Project-T Architecture Gaps & Technical Debt

This document tracks known architectural gaps and massive refactors needed to glue the currently isolated systems together. These are critical issues that require team coordination and dedicated sprints to resolve.

## 1. Combat Action Queue & Animation Sync (The "CombatTestBridge" Issue)
**Status:** 🟢 Resolved
**Owner:** Gilang

**The Problem:**
Currently, combat is hardcoded inside `CombatTestBridge.gd`, which manually rolls dice, `await`s the `AttackCam` zoom animation, and applies damage sequentially. If we switch to using the true `BaseAbility.execute()` and `TurnManager` flow right now, damage and status effects apply *instantly* before the UI and animations have a chance to play. 

**The Solution (Implemented):**
We transformed `CombatTestBridge.gd` into a centralized combat orchestrator. 
1. `EventBus` signals (`turn_ended`, `combat_action_finished`) guarantee sequential execution without race conditions.
2. The orchestrator differentiates feedback dynamically: Players use the screen-space `CombatDiceOverlay`, while Enemies use a diegetic (in-world) `Node2D` feedback sequence with physics flinging.
3. The pipeline `await`s all visual resolutions (dice roll, clash, camera shake) before passing the turn back to the `TurnManager`.

## 2. Enemy AI Brain
**Status:** 🟢 Resolved
**Owner:** Gilang

**The Problem:**
`EnemyPlaceholder.gd` currently just prints `Bergerak menuju Player` or attacks if perfectly adjacent. There is no logic for pathfinding around obstacles to reach a target, no ability selection, and no threat evaluation.

**The Solution (Implemented):**
A unified `AIComponent` runs an injected `AIBrain` resource (e.g., `SimpleMeleeBrain`).
1. The AI calculates the closest valid target ignoring dead players.
2. It interacts with the `MovementComponent` to navigate towards the player.
3. Once in range, it triggers the exact same combat pipeline as the player via `CombatTestBridge`.
4. The `AIComponent` uses a re-entrancy lock (`_is_taking_turn`) to ensure only one enemy acts at a time, keeping the queue clean.

## 3. Game Loop & Scene Transition Flow
**Status:** 🔴 Critical Gap
**Owner:** TBD (Unassigned)

**The Problem:**
We have `Main.tscn` for combat testing, and we will have a Node Graph map. But there is no overarching State Machine that moves the player from:
`Main Menu -> Node Graph -> Combat Scene -> Victory Screen -> Node Graph`

**The Solution:**
A `GameManager` autoload that orchestrates scene loading, unloads the combat arena, grants rewards, and returns the player to the exact state on the Map.

## 4. Run State & Meta-Progression Persistence
**Status:** 🟡 High Gap
**Owner:** TBD (Unassigned)

**The Problem:**
Stats, unlocked items, and current HP are lost when closing the game. 

**The Solution:**
A `SaveManager` that serializes the `StatsComponent` states, current Node Graph seed, and inventory into JSON/binary, and reconstructs the `players` group on load.
