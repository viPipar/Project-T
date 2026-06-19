# TASK CHECKLIST — Detailed Breakdown per Programmer

## Tapip · Combat Core

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Tapip | Turn Base System | Implement Player Phase Manager (concurrent Tapip+Gilang) | Critical | Done tinggal tunggu yang lain | — | #8 |
| Tapip | Turn Base System | Implement Enemy Phase Manager (sequential queue) | Critical | Done tinggal tunggu yang lain | — | #7 |
| Tapip | Turn Base System | Build Phase Transition Handler (End Turn detection) | High | Done tinggal tunggu yang lain | Player Phase, Enemy Phase | — |
| Tapip | Action Economy | Action Point & Bonus AP Manager | Critical | Done tinggal tunggu yang lain | — | — |
| Tapip | Action Economy | Energy Charge Manager — Fighter (Tapip) | Critical | Done tinggal tunggu yang lain | — | #14 |
| Tapip | Action Economy | Spell Slot Manager Lv1–4 — Wizard (Gilang) | Critical | Done tinggal tunggu yang lain | — | #14 |
| Tapip | Action Economy | Mana Equivalence Converter (cross-class items) | Medium | Done tinggal tunggu yang lain | Spell Slot Mgr | #14 |
| Tapip | Action Economy | Movement Point Manager | High | Done tinggal tunggu yang lain | — | — |
| Tapip | RNG System | Hit/Miss Resolver (D20 + ACC/2 vs Armor) | Critical | Done tinggal tunggu yang lain | Stat System (Candra) | |
| Tapip | RNG System | Damage/Heal Dice Roller (D4–D20, multi-dice) | Critical | Done tinggal tunggu yang lain | — | — |
| Tapip | RNG System | Critical Hit Resolver (threshold = 20 − ACC/10) | High | Done tinggal tunggu yang lain | Hit/Miss Resolver | — |
| Tapip | RNG System | Luck Event Roller (D20 + LCK/5) | Medium | Done tinggal tunggu yang lain | — | — |
| Tapip | RNG System | Register HitMissResolver to /root for BaseAbility access | High | To Do | Hit/Miss Resolver | #9 |

## Gilang · Ability & Status System

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Gilang | Ability System | Design & implement Ability Base Class (Resource) | Critical | Done | SignalBus | #9 |
| Gilang | Ability System | Define SignalBus autoload (on_hit, on_miss, on_knockback, on_status) | Critical | Done | — | #9 |
| Gilang | Ability System | Implement Physical Abilities (Main Attack, Elbow Smash, Slash Flash, Cleave, Dagger Throw, Rupture, Epimorphic, Autotomy) | Critical | Done | Ability Base Class | #9 |
| Gilang | Ability System | Tambahin deskripsi ability field. Sama divine departure ketinggalan.| Critical | Done | Ability Base Class | #9 |
| Gilang | Ability System | Calculate Damage Multipliers (Vulnerable/Vapor) in BaseAbility before sending to Candra | High | Done | Status Effects | #9 |
| Gilang | Ability System | Implement Magic Abilities & Spell Slot Consumer | High | Done | Ability Base Class, Spell Slot Mgr (Tapip) | — |
| Gilang | Friendly Fire | Build Ally Damage Resolver (inside IAbility) | High | Done | Ability Base Class | #11 |
| Gilang | Friendly Fire | Build Enemy Heal/Buff Resolver (inside IAbility) | Medium | Done | Ability Base Class | #11 |
| Gilang | Elemental System | Element Tag Manager (True/Fire/Water/Air/Earth) | High | Done | — | — |
| Gilang | Elemental System | Elemental Combo Resolver (6 combos: Magma/Mud/Vapor/Mist/Erosion/Conflagration) | High | Done | Element Tag Mgr | — |
| Gilang | Status Effects | Physical Status Effects (Bleeding/Stun/Lacerate/Weakened/Vulnerable) | High | Done | SignalBus | — |
| Gilang | Status Effects | DoT / Persistent Effect Ticker | Medium | To Do | Status Effects | — |
| Gilang | Status Particle FX | Per-entity particle emitter (attach to entity node) | Medium | To Do | Status Effects | #15 |
| Gilang | Status Particle FX | Particle sets: Bleeding/Stun/Fire/Water/Earth/Air/Magma/Mud/Mist/Conflagration | Low | To Do | Particle Emitter | #15 |
| Gilang | Status Effects | Implement `autotomy_armor_buff` (+4 Armor for 1 turn) from Autotomy | Medium | Done | Status Effects | #9 |
| Gilang | Audio System | SFX & BGM Manager (Combat sounds, UI clicks, bgm tracks) | High | To Do | EventBus | — |

## Candra · Movement, Projectile & Stats

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Candra | Grid System | Isometric Grid Manager | Critical | To Do | — | — |
| Candra | Grid System | Pathfinding (A* or similar) | Critical | To Do | Grid Manager | — |
| Candra | Movement System | Movement System integration (tile-based) | High | To Do | Grid, Movement Pt (Tapip) | — |
| Candra | Movement System | Knockback Resolver — wall collision bonus damage | High | To Do | SignalBus (Gilang), Grid | #13 |
| Candra | Movement System | Environmental Interaction Handler | Low | To Do | Grid | — |
| Candra | Projectile System | Projectile Spawner | High | To Do | Grid | #12 |
| Candra | Projectile System | Projectile Mover (grid-step / physics) | High | To Do | Spawner | #12 |
| Candra | Projectile System | Grid Collision Detector (trajectory check + wall blocker) | High | To Do | Mover | #12 |
| Candra | Stat System | Attribute Manager (VIT/STR/INT/CON/ACC/DEX/MOV/ATT/LCK) | Critical | To Do | — | — |
| Candra | Stat System | Derived Stat Calculator (HP/Armor/Resist/PhysDMG/MagDMG) | Critical | To Do | Attribute Mgr | — |
| Candra | Stat System | Health Manager (Damage/Heal/Downed/Revive) | Critical | To Do | Derived Stats | — |
| Candra | Grid System | Provide `GridManager.is_walkable(pos)` so Slash Flash can check if dash destination is blocked by a wall/obstacle | High | To Do | Grid Manager | #9 |
| Candra | Stat System | Ensure all units have `HealthComponent` or register to `/root/StatSystem` so `BaseAbility._apply_damage()` can deal damage | Critical | To Do | Health Manager | #9 |

## Ilham · Roguelite Run System

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Ilham | Node Graph | Procedural Node Graph Generator (Slay the Spire-style) | Critical | To Do | — | #1 |
| Ilham | Node Graph | Node Type Pool (Battle/Elite/Boss/Event/Rest/Shop/Loot) | Critical | To Do | Node Graph | #1 |
| Ilham | Node Graph | Path Branching Handler & Depth Layer Manager | High | To Do | Node Graph | #1 |
| Ilham | Node Graph | Forced Boss Node (final layer) + Node Unlock Resolver | High | To Do | Branching Handler | #1 |
| Ilham | Level Events | Level: Luck Event — Narrative + Consensus + D20 Roll | High | To Do | RNG (Tapip) | — |
| Ilham | Level Events | Win State Handler (2 items / Full HP / extendable pool) | High | To Do | Item System | #2 |
| Ilham | Level Events | Lose State Handler (−50% HP / Cursed Item / Elite Battle) | High | To Do | Item System, Combat (Tapip) | #3 |
| Ilham | Level Events | Level: Rest (Full/Partial/Treasure options) | Medium | To Do | HP (Candra) | #6 |
| Ilham | Level Events | Level: Loot (shared pool + Minigame TBD) | Medium | To Do | Item System | #5 |
| Ilham | Item System | Item Registry (Common/Rare/Legendary structure) | Critical | To Do | Stat System (Candra) | #10 |
| Ilham | Item System | Item Effect Applier (Stat/Resource/Cross-class modifiers) | Critical | To Do | Item Registry, Action Economy (Tapip) | #10 |
| Ilham | Item System | Rarity Reveal Handler (White/Blue/Gold glow — after pick) | Medium | To Do | UI — Rarity FX (Rapit) | #4 |
| Ilham | Item System | Item Pool Generator per battle type (Normal/Elite/Boss) | High | To Do | Item Registry | #4 |
| Ilham | Item System | Cursed Item Handler (negative passive) | Medium | To Do | Item Effect Applier | — |
| Ilham | Item System | Inventory Manager (per player) | High | To Do | Item Effect Applier | — |
| Ilham | Shop | Stock Manager (7 slots, Rarity Resolver, Reroll 100 coins) | Medium | To Do | Item Registry | — |
| Ilham | Shop | Coin Economy (Wallet, Send 1/2, Send 1/4) | Medium | To Do | — | — |

## Rapit · UI System

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Rapit | Split-Screen | Split-Screen Manager (Tapip Left / Gilang Right viewports) | Critical | Done | — | — |
| Rapit | Split-Screen | Shared World State Sync | High | Done | Split-Screen | — |
| Rapit | HUD | HUD — Fighter (Tapip): AP/BAP/Energy/Movement/Inventory | High | To Do | Action Economy (Tapip) | — |
| Rapit | HUD | HUD — Wizard (Gilang): AP/BAP/Spell Slots Lv1–4/Movement/Inventory | High | To Do | Action Economy (Tapip) | — |
| Rapit | HUD | Character Profile Icon | Low | To Do | — | — |
| Rapit | HUD | HP/Armor Floating Indicator (above targets) | Medium | To Do | Health Mgr (Candra) | — |
| Rapit | HUD | Blink Indicator (resource consumed on skill preview) | Medium | To Do | HUD Bars | — |
| Rapit | Radial Menu | Skill Slot Renderer | High | To Do | Ability System (Gilang) | — |
| Rapit | Radial Menu | Navigation Handler (< / > overflow) | Medium | To Do | Skill Slot Renderer | — |
| Rapit | Radial Menu | Selection Confirmer | High | To Do | Navigation Handler | — |
| Rapit | Combat Text | Damage Number Popup | High | To Do | SignalBus (Gilang) | — |
| Rapit | Combat Text | Heal Number Popup | High | To Do | SignalBus (Gilang) | — |
| Rapit | Combat Text | MISS! Label | Medium | To Do | SignalBus (Gilang) | — |
| Rapit | Combat Text | Element Icon Popup (Fire/Water/Air/Earth) | Medium | To Do | Element Tags (Gilang) | — |
| Rapit | FX | Item Rarity Reveal FX (White/Blue/Gold glow) | Medium | To Do | Rarity Handler (Ilham) | #4 |
| Rapit | FX | Dice Roll Animation (D20 Spin Overlay) | Low | To Do | RNG (Tapip) | — |
| Rapit | Input | Pointer/Target Cursor (Tapip & Gilang) | High | Done | Grid (Candra) | — |
| Rapit | Input | Input Manager (P1: WASD/QE/F/X/R/ZC, P2: IJKL/UO/;/,/P/M.) | Critical | To Do | — | — |
| Rapit (w/ Gilang) | Animation System | Character Sprite/Model State Machine (Idle/Walk/Attack/Hurt/Die) | High | To Do | Ability System, Grid | — |

## Unassigned / Missing Systems (To Be Organized by Ilham)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| TBD | Combat Animation | Combat Action Queue / Animation Sync | Critical | To Do | EventBus | — |
| TBD | AI System | Enemy AI Brain (Target Selection, Ability Choice, Movement Logic) | Critical | To Do | Phase Mgr, A* Grid | — |
| TBD | Game Loop | Scene Transition Flow (Node Graph ↔ Combat Scene ↔ Win/Lose) | Critical | To Do | Node Graph | — |
| TBD | UI System | Core Menus (Main Menu, Pause, Settings, Game Over Screen) | High | To Do | — | — |
| TBD | Save System | Run State & Meta-Progression Persistence (Save/Load) | High | To Do | Data structures | — |
