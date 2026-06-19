# Project-T Architecture Gaps & Technical Debt

This document tracks known architectural gaps and massive refactors needed to glue the currently isolated systems together. These are critical issues that require team coordination and dedicated sprints to resolve.

## 1. Combat Action Queue & Animation Sync (The "CombatTestBridge" Issue)
**Status:** 🔴 Critical Gap
**Owner:** TBD (Unassigned)

**The Problem:**
Currently, combat is hardcoded inside `CombatTestBridge.gd`, which manually rolls dice, `await`s the `AttackCam` zoom animation, and applies damage sequentially. If we switch to using the true `BaseAbility.execute()` and `TurnManager` flow right now, damage and status effects apply *instantly* before the UI and animations have a chance to play. 

**The Solution:**
We need an **Action Queue / Command Pattern** system. 
1. When a player selects an action, it goes into the Queue.
2. The Queue locks input.
3. The Queue executes the logical hit/miss.
4. The Queue triggers the UI/FX (AttackCam, Dice Overlay).
5. The Queue *yields/awaits* signals from the FX system before actually mutating HP/Stats.
6. The Queue unlocks input.

## 2. Enemy AI Brain
**Status:** 🔴 Critical Gap
**Owner:** TBD (Unassigned)

**The Problem:**
`EnemyPlaceholder.gd` currently just prints `Bergerak menuju Player` or attacks if perfectly adjacent. There is no logic for pathfinding around obstacles to reach a target, no ability selection, and no threat evaluation.

**The Solution:**
A unified `AIComponent` or `Brain` that hooks into `GridManager`'s A* pathfinding.
1. Determine optimal target (closest, lowest HP, etc).
2. Calculate A* path to target.
3. Consume Movement Points walking along the path.
4. Execute optimal ability from the enemy's `Ability` list.

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
