# Task Checklist - Detailed Breakdown per Programmer

## Tapip - Combat Core

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Tapip | Turn Base System | Implement Player Phase Manager (concurrent Tapip+Gilang) | Critical | Done tinggal tunggu yang lain | - | #8 |
| Tapip | Turn Base System | Implement Enemy Phase Manager (sequential queue) | Critical | Done tinggal tunggu yang lain | - | #7 |
| Tapip | Turn Base System | Build Phase Transition Handler (End Turn detection) | High | Done tinggal tunggu yang lain | Player Phase, Enemy Phase | - |
| Tapip | Action Economy | Action Point & Bonus AP Manager | Critical | Done tinggal tunggu yang lain | - | - |
| Tapip | Action Economy | Energy Charge Manager - Fighter (Tapip) | Critical | Done tinggal tunggu yang lain | - | #14 |
| Tapip | Action Economy | Spell Slot Manager Lv1-4 - Wizard (Gilang) | Critical | Done tinggal tunggu yang lain | - | #14 |
| Tapip | Action Economy | Mana Equivalence Converter (cross-class items) | Medium | Done tinggal tunggu yang lain | Spell Slot Mgr | #14 |
| Tapip | Action Economy | Movement Point Manager | High | Done tinggal tunggu yang lain | - | - |
| Tapip | RNG System | Hit/Miss Resolver (D20 + ACC/2 vs Armor) | Critical | Done tinggal tunggu yang lain | Stat System (Candra) | - |
| Tapip | RNG System | Damage/Heal Dice Roller (D4-D20, multi-dice) | Critical | Done tinggal tunggu yang lain | - | - |
| Tapip | RNG System | Critical Hit Resolver (threshold = 20 - ACC/10) | High | Done tinggal tunggu yang lain | Hit/Miss Resolver | - |
| Tapip | RNG System | Luck Event Roller (D20 + LCK/5) | Medium | Done tinggal tunggu yang lain | - | - |
| Tapip | RNG System | Register HitMissResolver to /root for BaseAbility access | High | To Do | Hit/Miss Resolver | #9 |
| 🆕 Tapip | RNG System | Contested Pick Roller (D20 + LCK/5 per player, reroll on tie) | Medium | To Do | Luck Roller | — |

## Gilang - Ability & Status System

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Gilang | Ability System | Design & implement Ability Base Class (Resource) | Critical | Done | SignalBus | #9 |
| Gilang | Ability System | Define SignalBus autoload (on_hit, on_miss, on_knockback, on_status) | Critical | Done | - | #9 |
| Gilang | Ability System | Implement Physical Abilities (Main Attack, Elbow Smash, Slash Flash, Cleave, Dagger Throw, Rupture, Epimorphic, Autotomy) | Critical | Done | Ability Base Class | #9 |
| Gilang | Ability System | Tambahin deskripsi ability field. Sama divine departure ketinggalan. | Critical | Done | Ability Base Class | #9 |
| Gilang | Ability System | Calculate Damage Multipliers (Vulnerable/Vapor) in BaseAbility before sending to Candra | High | Done | Status Effects | #9 |
| Gilang | Ability System | Implement new abilities: Divine Departure, Great Bash, Thrust, Chain Dagger, Kitin Bomb | High | Done | Ability Base Class, AOE System | #9 |
| Gilang | Ability System | Implement Pull mechanic (negative knockback_tiles) in CombatActionResolver | High | Done | ForcedMovementResolver | #13 |
| Gilang | Ability System | Implement AOE Heal resolution in CombatActionResolver | High | Done | HealthComponent | #9 |
| Gilang | Ability System | Implement TargetAlignment-aware AOE collection (ENEMY_ONLY/ALLY_ONLY/SELF_ONLY/ANY) | High | Done | Ability Base Class | #11 |
| Gilang | Ability System | Implement Magic Abilities & Spell Slot Consumer | High | Done | Ability Base Class, Spell Slot Mgr (Tapip) | - |
| Gilang | Friendly Fire | Build Ally Damage Resolver (inside IAbility) | High | Done | Ability Base Class | #11 |
| Gilang | Friendly Fire | Build Enemy Heal/Buff Resolver (inside IAbility) | Medium | Done | Ability Base Class | #11 |
| Gilang | Elemental System | Element Tag Manager (True/Fire/Water/Air/Earth) | High | Done | - | - |
| Gilang | Elemental System | Elemental Combo Resolver (6 combos: Magma/Mud/Vapor/Mist/Erosion/Conflagration) | High | Done | Element Tag Mgr | - |
| Gilang | Status Effects | Physical Status Effects (Bleeding/Stun/Lacerate/Weakened/Vulnerable) | High | Done | SignalBus | - |
| Gilang | Status Effects | DoT / Persistent Effect Ticker | Medium | Done | Status Effects | - |
| Gilang | Status Effects | Vulnerable damage multiplier (×1.5 phys) in CombatActionResolver | High | Done | ConditionComponent | #9 |
| Gilang | Status Particle FX | Per-entity particle emitter (attach to entity node) | Medium | To Do | Status Effects | #15 |
| Gilang | Status Particle FX | Particle sets: Bleeding/Stun/Fire/Water/Earth/Air/Magma/Mud/Mist/Conflagration | Low | To Do | Particle Emitter | #15 |
| Gilang | Status Effects | Implement `autotomy_armor_buff` (+4 Armor for 1 turn) from Autotomy | Medium | Done | Status Effects | #9 |
| Gilang | Audio System | SFX & BGM Manager (Combat sounds, UI clicks, bgm tracks) | High | To Do | EventBus | - |
| Gilang | AI System | Enemy AI Brain (Target Selection, Ability Choice, Movement Logic) | Critical | Done | Phase Mgr, A* Grid | - |
| Gilang | AI System | Simple Ranged Brain (kiting, maximize distance, shoot) | High | Done | Enemy AI Brain | - |
| Gilang | AI System | Character Specific Custom Brains (Bosses/Elites) | Medium | To Do | Enemy AI Brain | - |

## Candra - Movement, Projectile & Stats

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Candra | Grid System | Isometric Grid Manager | Critical | To Do | - | - |
| Candra | Grid System | Pathfinding (A* or similar) | Critical | To Do | Grid Manager | - |
| Candra | Movement System | Movement System integration (tile-based) | High | To Do | Grid, Movement Pt (Tapip) | - |
| Candra | Movement System | Knockback Resolver - wall collision bonus damage | High | Done | SignalBus (Gilang), Grid | #13 |
| Candra | Movement System | Environmental Interaction Handler | Low | To Do | Grid | - |
| Candra | Projectile System | Projectile Spawner | High | To Do | Grid | #12 |
| Candra | Projectile System | Projectile Mover (grid-step / physics) | High | To Do | Spawner | #12 |
| Candra | Projectile System | Grid Collision Detector (trajectory check + wall blocker) | High | To Do | Mover | #12 |
| Candra | Stat System | Attribute Manager (VIT/STR/INT/CON/ACC/DEX/MOV/ATT/LCK) | Critical | Done | - | - |
| Candra | Stat System | Derived Stat Calculator (HP/Armor/Resist/PhysDMG/MagDMG) | Critical | Done | Attribute Mgr | - |
| Candra | Stat System | Health Manager (Damage/Heal/Downed/Revive API) | Critical | Done | Derived Stats | - |
| Candra | Grid System | Provide `GridManager.is_walkable(pos)` so Slash Flash can check if dash destination is blocked by a wall/obstacle | High | To Do | Grid Manager | #9 |
| Candra | Stat System | Player/enemy `HealthComponent` wrapper + `/root/StatSystem.apply_damage()` integration | Critical | Done | Health Manager | #9 |
| 🆕 Candra | Grid System | Grid Occupancy Map (tracks what's on each tile — used by Projectile System) | High | To Do | Grid Manager | #12 |
| 🆕 Candra | Movement System | Knockback — Entity Collision Check (D4 damage to both on entity-in-path) | Medium | To Do | Knockback Resolver | #13 |
| 🆕 Candra | Movement System | Dash Handler — `dash(direction, distance)`, auto-stop on wall, wall damage | Medium | To Do | Grid, Knockback Resolver | - |
| 🆕 Candra | Projectile System | Projectile Pool Manager (reuse instances for performance) | Medium | To Do | Spawner | #12 |
| 🆕 Candra | Stat System | Revive Handler — adjacent ally + 1 Action → 20% HP | High | To Do | Health Manager | - |

## Ilham - Roguelite Run System

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Ilham | Node Graph | Procedural Node Graph Generator (Slay the Spire-style) | Critical | To Do | - | #1 |
| Ilham | Node Graph | Node Type Pool (Battle/Elite/Boss/Event/Rest/Shop/Loot) | Critical | To Do | Node Graph | #1 |
| Ilham | Node Graph | Path Branching Handler & Depth Layer Manager | High | To Do | Node Graph | #1 |
| Ilham | Node Graph | Forced Boss Node (final layer) + Node Unlock Resolver | High | To Do | Branching Handler | #1 |
| 🆕 Ilham | Node Graph | Seed Manager (reproducible RNG per run) | Medium | To Do | Node Graph | #1 |
| 🆕 Ilham | Node Graph | Path Connectivity Validator (no dead ends) | High | To Do | Branching Handler | #1 |
| 🆕 Ilham | Node Graph | Node Selection Handler + Reachability Checker (only adjacent forward nodes) | High | To Do | Node Graph | #1 |
| Ilham | Level Events | Level: Luck Event - Narrative + Consensus + D20 Roll | High | To Do | RNG (Tapip) | - |
| 🆕 Ilham | Level Events | Luck Event — Win Outcome Pool (weighted: 40% 2 items / 25% Full HP / 20% 1 Legendary / 10% +200 Coin / 5% +2 Attr) | High | To Do | Luck Event | #2 |
| 🆕 Ilham | Level Events | Luck Event — Lose Outcome Pool (weighted: 35% −50% HP / 25% Cursed Item / 20% Elite Battle / 15% −30% Coin / 5% −3 Attr) | High | To Do | Luck Event | #3 |
| 🆕 Ilham | Level Events | Luck Event — Outcome Presenter (narrative flavor text per outcome) | Medium | To Do | Outcome Pools | - |
| 🆕 Ilham | Level Events | Luck Event — Consensus Timer (forces default option on expiry) | Low | To Do | Luck Event | - |
| Ilham | Level Events | Win State Handler (2 items / Full HP / extendable pool) | High | To Do | Item System | #2 |
| Ilham | Level Events | Lose State Handler (-50% HP / Cursed Item / Elite Battle) | High | To Do | Item System, Combat (Tapip) | #3 |
| Ilham | Level Events | Level: Rest (Full/Partial/Treasure options) | Medium | To Do | HP (Candra) | #6 |
| 🆕 Ilham | Level Events | Rest — Treasure Search Probability Roll (70% safe / 20% trap / 10% jackpot, hidden) | Medium | To Do | Rest Level | #6 |
| 🆕 Ilham | Level Events | Rest — Cursed Item Removal option (sacrifice heal to remove curse) | Medium | To Do | Cursed Item Handler, Rest | #6 |
| Ilham | Level Events | Level: Loot (shared pool + Minigame TBD) | Medium | To Do | Item System | #5 |
| Ilham | Item System | Item Registry (Common/Rare/Legendary structure) | Critical | To Do | Stat System (Candra) | #10 |
| Ilham | Item System | Item Effect Applier (Stat/Resource/Cross-class modifiers) | Critical | To Do | Item Registry, Action Economy (Tapip) | #10 |
| Ilham | Item System | Rarity Reveal Handler (White/Blue/Gold glow - after pick) | Medium | To Do | UI - Rarity FX (Rapit) | #4 |
| Ilham | Item System | Item Pool Generator per battle type (Normal/Elite/Boss) | High | To Do | Item Registry | #4 |
| Ilham | Item System | Cursed Item Handler (negative passive) | Medium | To Do | Item Effect Applier | - |
| Ilham | Item System | Inventory Manager (per player) | High | To Do | Item Effect Applier | - |
| 🆕 Ilham | Item System | Contested Pick System — Simultaneous Selection Detector | High | To Do | Item Pool Generator | #4 |
| 🆕 Ilham | Item System | Contested Pick — Tiebreaker Roll Handler (D20 + LCK/5, reroll on tie) | High | To Do | Contested Pick Detector, RNG (Tapip) | #4 |
| 🆕 Ilham | Item System | Contested Pick — Result Broadcaster (winner gets item, loser picks again) | High | To Do | Tiebreaker Handler | #4 |
| Ilham | Shop | Stock Manager (7 slots, Rarity Resolver, Reroll 100 coins) | Medium | To Do | Item Registry | - |
| Ilham | Shop | Coin Economy (Wallet, Send 1/2, Send 1/4) | Medium | To Do | - | - |

## Rapit - UI System

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Rapit | Split-Screen | Split-Screen Manager (Tapip Left / Gilang Right viewports) | Critical | Done | - | - |
| Rapit | Split-Screen | Shared World State Sync | High | Done | Split-Screen | - |
| Rapit | HUD | HUD - Fighter (Tapip): AP/BAP/Energy/Movement/Inventory | High | To Do | Action Economy (Tapip) | - |
| Rapit | HUD | HUD - Wizard (Gilang): AP/BAP/Spell Slots Lv1-4/Movement/Inventory | High | To Do | Action Economy (Tapip) | - |
| Rapit | HUD | Character Profile Icon | Low | To Do | - | - |
| Rapit | HUD | HP/Armor Floating Indicator (above targets) | Medium | To Do | Health Mgr (Candra) | - |
| Rapit | HUD | Blink Indicator (resource consumed on skill preview) | Medium | To Do | HUD Bars | - |
| 🆕 Rapit | HUD | Status Icon Bar (above entity, lists active status tags with icons) | Medium | To Do | Status Effects (Gilang) | - |
| Rapit | Radial Menu | Skill Slot Renderer | High | Done | Ability System (Gilang) | - |
| Rapit | Radial Menu | Navigation Handler (per-player Q/E and U/O pages + hold-to-scroll) | Medium | Done | Skill Slot Renderer | - |
| Rapit | Radial Menu | Selection Confirmer | High | Done | Navigation Handler | - |
| Rapit | Combat Text | Damage Number Popup | High | To Do | SignalBus (Gilang) | - |
| Rapit | Combat Text | Heal Number Popup | High | To Do | SignalBus (Gilang) | - |
| Rapit | Combat Text | MISS! Label | Medium | To Do | SignalBus (Gilang) | - |
| Rapit | Combat Text | Element Icon Popup (Fire/Water/Air/Earth) | Medium | To Do | Element Tags (Gilang) | - |
| Rapit | FX | Item Rarity Reveal FX (White/Blue/Gold glow) | Medium | To Do | Rarity Handler (Ilham) | #4 |
| 🆕 Rapit | FX | Rarity Reveal Full-Screen Overlay (dim + center-stage + light burst + stat card slide-in) | Medium | To Do | Rarity Reveal FX | #4 |
| Gilang | FX | Dice Roll Animation (In-world D20 Spin above caster's head) | Low | Done | RNG (Tapip) | - |
| Rapit | Input | Pointer/Target Cursor (Tapip & Gilang) | High | Done | Grid (Candra) | - |
| Rapit | Input | Input Manager (P1: WASD/QE/F/X/R/ZC, P2: IJKL/UO/;/,/P/M.) | Critical | Done | - | - |
| Rapit | Input | Per-player action wheel blocking and targeting highlight cleanup | High | Done | Input Manager, Action Wheel | - |
| Rapit (w/ Gilang) | Animation System | Character Sprite/Model State Machine (Idle/Walk/Attack/Hurt/Die) | High | To Do | Ability System, Grid | - |
| Rapit (w/ Gilang) | Animation System | Character Animation Hooks (`play_anim("attack")`/`"hurt"`) in `CombatTestBridge` | High | To Do | Combat Animation Sync | - |
| 🆕 Rapit | Map UI | Map UI Renderer (node icons, path lines, visited/locked/current states) | Critical | To Do | Node Graph (Ilham) | #1 |
| 🆕 Rapit | Map UI | Map Scroll / Pan Handler | Medium | To Do | Map UI Renderer | #1 |
| 🆕 Rapit | Map UI | Current Position Highlighter | Medium | To Do | Map UI Renderer | #1 |
| 🆕 Rapit | Map UI | Map Node Legend Panel | Low | To Do | Map UI Renderer | #1 |

## Unassigned / Missing Systems

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Gilang | Combat Animation | Combat Action Queue / Animation Sync (CombatTestBridge) | Critical | Done | EventBus | - |
| Gilang | Combat Core | Split combat logic into dedicated scripts: CombatActionResolver (damage/status/knockback) + CombatVFXController (animations/UI) | Critical | Done | CombatTestBridge | - |
| TBD | Game Loop | Scene Transition Flow (Node Graph -> Combat Scene -> Win/Lose) | Critical | To Do | Node Graph | - |
| TBD | UI System | Core Menus (Main Menu, Pause, Settings, Game Over Screen) | High | To Do | - | - |
| TBD | Save System | Run State & Meta-Progression Persistence (Save/Load) | High | To Do | Data structures | - |
| 🆕 TBD | Dialogue | Dialogue Manager 3 integration | Medium | To Do | - | - |
| 🆕 TBD | Dialogue | Dynamic Characters Vocalion setup | Medium | To Do | Dialogue Manager 3 | - |

---

## 🆕 Expanded Breakdown — Placeholder-Assigned Systems (Final Owners TBD)

> These sections expand the summary rows above into detailed task breakdowns from PLAN.md / Project_Context_Revisi v2.0.

### AI System (Gilang)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Gilang | Core AI Controller | EnemyAIController node — attached per enemy, drives its turn in the Enemy Phase | Critical | To Do | Phase Mgr (Tapip) | - |
| Gilang | Core AI Controller | Hook into Sequential Enemy Executor — exposes take_turn(), called one enemy at a time | Critical | To Do | Enemy Phase Mgr (Tapip) | - |
| Gilang | Core AI Controller | AI State Machine: Idle → Evaluate → Move → Act → Done | High | To Do | - | - |
| Gilang | Core AI Controller | Per-enemy AI Profile (Resource): aggro_range, preferred_ability_tags, behavior_type | Medium | To Do | - | - |
| Gilang | Target Selection | Target Selector — lowest HP% player, tiebreak by nearest (grid distance) | Critical | To Do | Stat System (Candra) | - |
| Gilang | Target Selection | Line-of-sight / reachability filter (skip targets blocked by walls for melee-only) | High | To Do | A* Grid (Candra) | - |
| Gilang | Target Selection | Threat override hooks (e.g. always target Vulnerable status) — stub for future variety | Medium | To Do | Status Effects (Gilang) | - |
| Gilang | Target Selection | Support-type target override (heal lowest-HP ally enemy instead of attacking) | Low | To Do | - | - |
| Gilang | Ability Choice Logic | Ability Picker — filters available abilities by current resource cost vs. what's left | Critical | To Do | Action Economy (Tapip) | - |
| Gilang | Ability Choice Logic | Scoring heuristic: prefer AoE if 2+ players adjacent, status if target undebuffed, else Main Attack | High | To Do | Ability System (Gilang) | - |
| Gilang | Ability Choice Logic | Cooldown/usage-limit support if any enemy ability is once-per-fight | Medium | To Do | - | - |
| Gilang | Ability Choice Logic | Difficulty hook — dumb vs smart profile toggle (random vs scored pick) | Low | To Do | - | - |
| Gilang | Movement Logic | Move-to-range behavior — use A* to path toward target until within ability range | Critical | To Do | A* Grid (Candra) | - |
| Gilang | Movement Logic | Kiting behavior for ranged enemies (keep distance, retreat if player closes in) | High | To Do | Move-to-range | - |
| Gilang | Movement Logic | Avoid-friendly-fire-zone pathing (don't block ally AoE) — stretch goal | Medium | To Do | Grid (Candra) | - |
| Gilang | Movement Logic | Flee/retreat behavior when HP below threshold (optional enemy archetype) | Low | To Do | Health Mgr (Candra) | - |
| Gilang | Action Execution | Action Executor — move → attack → special sequence, signals done to Sequential Executor | Critical | To Do | Enemy Phase Mgr (Tapip) | - |
| Gilang | Action Execution | Wire into Current Actor Highlighter so AI turn is visually clear | High | To Do | Enemy Phase Mgr (Tapip) | - |
| Gilang | Action Execution | Respect 0.5s Action Delay Timer between enemy actions (don't double-fire) | Medium | To Do | Enemy Phase Mgr (Tapip) | - |
| Gilang | Testing / Tuning | Debug overlay: print chosen target + ability + score to console (toggle-able) | Medium | To Do | - | - |
| Gilang | Testing / Tuning | Enemy AI test scene with 3-4 dummy enemies to validate logic in isolation | Low | To Do | - | - |

### Audio System (Gilang)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Gilang | Core Audio Manager | AudioManager autoload singleton — play_sfx(id), play_bgm(track, fade_sec), stop_bgm() | Critical | To Do | - | - |
| Gilang | Core Audio Manager | Audio bus setup: Master / Music / SFX / UI buses with independent volume control | High | To Do | - | - |
| Gilang | Core Audio Manager | Sound pool / polyphony limiter (avoid SFX stacking distortion on AoE hits) | High | To Do | - | - |
| Gilang | SFX — Combat | Hit / Miss SFX (tied to SignalBus on_hit / on_miss) | High | To Do | SignalBus (Gilang) | - |
| Gilang | SFX — Combat | Per-element impact SFX variants (Physical/Fire/Water/Air/Earth) | High | To Do | Element Tags (Gilang) | - |
| Gilang | SFX — Combat | Status-applied SFX (Bleeding tick, Stun applied, buff applied) | Medium | To Do | Status Effects (Gilang) | - |
| Gilang | SFX — Combat | Death / Downed SFX | Medium | To Do | Health Mgr (Candra) | - |
| Gilang | SFX — Combat | Critical hit stinger (layered on crit, ties into Game Feel hit-stop) | Low | To Do | RNG Crit Resolver (Tapip) | - |
| Gilang | SFX — Combat | Dice roll SFX (tie into Dice Roll Animation) | Low | To Do | Dice Roll Animation (Rapit) | - |
| Gilang | SFX — UI | Button click / hover SFX (menus, radial menu selection) | High | To Do | - | - |
| Gilang | SFX — UI | Error/invalid-action SFX (e.g. target out of range) | Medium | To Do | - | - |
| Gilang | SFX — UI | Item pickup / rarity reveal stinger (White/Blue/Gold — Gold bigger sting) | Medium | To Do | Rarity Reveal Handler (Ilham) | - |
| Gilang | SFX — UI | Coin spend / shop transaction SFX | Low | To Do | - | - |
| Gilang | BGM | BGM track set: Map/Menu, Normal/Elite/Boss Battle, Shop, Rest, Luck Event | High | To Do | - | - |
| Gilang | BGM | Crossfade handler between tracks on scene transition (avoid hard cuts) | High | To Do | Game Loop | - |
| Gilang | BGM | Combat intensity layering (swap/layer stems entering Enemy Phase) — stretch goal | Medium | To Do | Enemy Phase Mgr (Tapip) | - |
| Gilang | BGM | Victory / Defeat jingle stingers | Low | To Do | Game Loop | - |
| Gilang | Integration | Wire SFX triggers into SignalBus so Audio isn't coupled to Ability/Combat code | High | To Do | SignalBus (Gilang) | - |
| Gilang | Integration | Wire BGM track swap into Game Loop's Scene Transition Flow | Medium | To Do | Game Loop | - |
| Gilang | Integration | Volume settings persistence | Low | To Do | Save System | - |
| Gilang | Asset Pipeline | Audio asset folder structure + naming convention (sfx_combat_*, bgm_*, sfx_ui_*) | Medium | To Do | - | - |
| Gilang | Asset Pipeline | Placeholder/temp SFX pack for early integration testing | Low | To Do | - | - |

### Animation System (Rapit w/ Gilang)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Rapit | Core State Machine | AnimationStateMachine component, attached per character/enemy entity | Critical | To Do | - | - |
| Rapit | Core State Machine | Core states: Idle, Walk, Attack, Hurt, Die | Critical | To Do | AnimationStateMachine | - |
| Rapit | Core State Machine | State transition rules (e.g. can't interrupt Attack with Walk) | High | To Do | Core states | - |
| Rapit | Core State Machine | Extended states if time allows: Cast, Downed, Victory | Medium | To Do | Core states | - |
| Rapit | Combat Hooks | Attack animation trigger — tied to ability_executed signal, per-ability/element variant | Critical | To Do | SignalBus (Gilang) | - |
| Rapit | Combat Hooks | Hurt animation trigger — tied to on_hit, only plays if damage > 0 | High | To Do | SignalBus (Gilang) | - |
| Rapit | Combat Hooks | Die animation trigger — tied to Health Manager's Downed/Death state | High | To Do | Health Mgr (Candra) | - |
| Rapit | Combat Hooks | Animation-locked input prevention (can't queue new action mid-attack-animation) | Medium | To Do | Action Queue (Tapip) | - |
| Rapit | Movement Animation | Walk/move animation synced to Movement System tile-steps (one step per tile) | Critical | To Do | Movement System (Candra) | - |
| Rapit | Movement Animation | Dash animation variant (ties into Dash Handler — dash(arah, jarak)) | Medium | To Do | Dash Handler (Candra) | - |
| Rapit | Movement Animation | Knockback animation (stagger/slide) tied into Knockback Resolver | Low | To Do | Knockback Resolver (Candra) | - |
| Rapit | Status Visual Tie-in | Stun animation override (forced idle/dazed pose while stunned) | Medium | To Do | Status Effects (Gilang) | - |
| Rapit | Status Visual Tie-in | Coordinate timing with Status Particle FX so animation + particles don't clash | Low | To Do | Status Particle FX (Gilang) | - |
| Rapit | Asset/Tech Decision | DECISION: Sprite-based vs skeletal animation tech — affects all animation work | Critical | To Do | - | - |
| Rapit | Asset/Tech Decision | Animation naming convention doc (Illustrator exports map to state machine states) | High | To Do | Tech decision | - |
| Rapit | Asset/Tech Decision | Placeholder animation set to unblock other programmers' integration testing | Medium | To Do | Tech decision | - |
| Rapit | Enemy Animation | Apply same state machine to enemies (reuse component, driven by AI Action Executor) | High | To Do | AI System, Core State Machine | - |
| Rapit | Enemy Animation | Enemy-specific animation variants if enemy roster grows | Low | To Do | - | - |

### Game Loop (Tapip)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Tapip | Core Game State Manager | GameStateManager autoload — single source of truth for current scene/phase | Critical | To Do | - | - |
| Tapip | Core Game State Manager | State transition function with validation (e.g. no MainMenu → Battle skip) | Critical | To Do | GameStateManager | - |
| Tapip | Core Game State Manager | Transition history/stack (for back support in menus only, not mid-run) | High | To Do | GameStateManager | - |
| Tapip | Scene Transition Flow | Node Graph → Level Loader bridge: reads selected node type, loads correct scene | Critical | To Do | Node Graph (Ilham) | - |
| Tapip | Scene Transition Flow | Combat Scene → Win/Lose detection: all enemies dead OR both players downed | Critical | To Do | Health Mgr (Candra) | - |
| Tapip | Scene Transition Flow | Win/Lose → back to Node Graph (post-combat reward flow → Item Select → map) | High | To Do | Item System (Ilham) | - |
| Tapip | Scene Transition Flow | Transition loading screen / fade-to-black handler | Medium | To Do | - | - |
| Tapip | Scene Transition Flow | Scene preloading/caching for snappier transitions — stretch goal | Medium | To Do | - | - |
| Tapip | Run Lifecycle | Run Start handler — fresh player state, seeds Node Graph RNG, resets inventory/coins | Critical | To Do | Node Graph (Ilham) | - |
| Tapip | Run Lifecycle | Run End handler — distinguishes Victory vs Defeat, routes to correct end screen | Critical | To Do | - | - |
| Tapip | Run Lifecycle | Mid-run pause/resume handling (doesn't break combat state) | High | To Do | Pause Menu (UI System) | - |
| Tapip | Run Lifecycle | Run abandon/quit-to-menu confirmation flow | Medium | To Do | - | - |
| Tapip | Level-Type Routing | Router table: Node Type → which scene/controller to instantiate | High | To Do | Node Graph (Ilham) | - |
| Tapip | Level-Type Routing | Pass node metadata (depth/row context) into loaded scene for rarity weight rolls | Medium | To Do | Item System (Ilham) | - |
| Tapip | Integration | Hook Win/Lose State Handler (Luck Event) into same transition flow as Battle | High | To Do | Level Events (Ilham) | - |
| Tapip | Integration | Hook BGM track swap into every state transition | Medium | To Do | Audio System | - |
| Tapip | Integration | Debug jump-to-scene cheat/dev-menu for faster testing | Low | To Do | - | - |

### UI System — Core Menus (Rapit)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Rapit | Main Menu | Main Menu scene: New Run / Continue / Settings / Quit buttons | Critical | To Do | - | - |
| Rapit | Main Menu | Continue button disabled/hidden if no save data exists | High | To Do | Save System | - |
| Rapit | Main Menu | Simple background/logo presentation (placeholder acceptable for now) | Medium | To Do | - | - |
| Rapit | Main Menu | Version number display (useful for QA build tracking) | Low | To Do | - | - |
| Rapit | Pause Menu | Pause trigger (input binding) — freezes game state without breaking combat/timers | Critical | To Do | - | - |
| Rapit | Pause Menu | Pause Menu options: Resume / Settings / Quit to Main Menu | Critical | To Do | - | - |
| Rapit | Pause Menu | Quit-to-menu confirmation dialog (run progress will be lost warning) | High | To Do | - | - |
| Rapit | Pause Menu | Co-op pause handling — does either player's pause input pause for both? | Medium | To Do | - | - |
| Rapit | Settings Menu | Audio settings: Master/Music/SFX volume sliders | High | To Do | Audio System | - |
| Rapit | Settings Menu | Control remapping display (read-only P1/P2 keybinds reference at minimum) | Medium | To Do | Input Manager (Rapit) | - |
| Rapit | Settings Menu | Display settings: resolution/fullscreen toggle, if needed for target platform | Medium | To Do | - | - |
| Rapit | Settings Menu | Accessibility toggles (colorblind-friendly indicators, text size) — stretch goal | Low | To Do | - | - |
| Rapit | Game Over / Victory Screen | Game Over screen — triggered on Lose, shows run summary (depth, items collected) | Critical | To Do | Game Loop | - |
| Rapit | Game Over / Victory Screen | Victory screen — triggered on boss defeat, shows run summary + celebratory state | High | To Do | Game Loop | - |
| Rapit | Game Over / Victory Screen | Run Again / Main Menu buttons from either end screen | Medium | To Do | - | - |
| Rapit | Game Over / Victory Screen | Basic run stats display (turns taken, enemies defeated, items found) | Low | To Do | Save System | - |
| Rapit | Menu Navigation/Shell | Shared menu navigation component (keyboard/controller if planned) | High | To Do | - | - |
| Rapit | Menu Navigation/Shell | Co-op-aware menu focus (avoid P1/P2 input fighting over same menu cursor) | Medium | To Do | Input Manager (Rapit) | - |
| Rapit | Menu Navigation/Shell | Menu transition animations/polish (fade/slide) — low priority until core flow works | Low | To Do | - | - |

### Save System (Candra)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Candra | Save Data Schema | Define RunSaveData structure: node graph state, stats/HP/resources, inventory, coins, statuses | Critical | To Do | Data structures (Candra, Ilham) | - |
| Candra | Save Data Schema | Define MetaSaveData structure IF meta-progression exists — scope unclear, confirm first | High | To Do | Open question | - |
| Candra | Save Data Schema | Versioning field in save schema (future format changes don't break old saves) | Medium | To Do | - | - |
| Candra | Serialization | Save Writer — serializes RunSaveData to file on disk (user://saves/) | Critical | To Do | Save Data Schema | - |
| Candra | Serialization | Save Reader — deserializes and reconstructs full run state on load | Critical | To Do | Save Data Schema | - |
| Candra | Serialization | Error handling: corrupted/missing save file → graceful fallback, no crash | High | To Do | Save Reader | - |
| Candra | Save Triggers | Auto-save on node transition (after every level completes, before next node) | High | To Do | Game Loop | - |
| Candra | Save Triggers | Manual save option from Pause Menu (if design wants explicit control) | Medium | To Do | Pause Menu (UI System) | - |
| Candra | Save Triggers | Save-on-quit safety net (catch app close/crash where possible) | Medium | To Do | - | - |
| Candra | Load Flow | Continue flow: load RunSaveData → reconstruct Node Graph, stats, inventory → resume map position | Critical | To Do | Save Reader, Node Graph (Ilham) | - |
| Candra | Load Flow | Validate loaded data against current game version (handle schema mismatches) | High | To Do | Versioning field | - |
| Candra | Load Flow | Delete-save-on-run-end (roguelite runs are one-shot, no continue after game over) | Medium | To Do | Game Loop | - |
| Candra | Settings Persistence | Separate lightweight SettingsSaveData (volume levels, keybinds) — persists across runs | Medium | To Do | - | - |
| Candra | Settings Persistence | Settings auto-save on change (no explicit save button needed) | Low | To Do | SettingsSaveData | - |
| Candra | Integration | Coordinate with Candra/Ilham on Stat/Item/Inventory schema stability before serializing | High | To Do | Stat System, Item System | - |
| Candra | Integration | Coordinate with UI System (Continue button, Game Over screen) on save-state visibility | Medium | To Do | UI System | - |

### Game Feel / QA-QC / Polishing / Build (Ilham)

| Programmer | System | Task | Priority | Status | Depends On | Ref # |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Ilham | Game Feel | Skill/Attack Feedback — hit-stop on confirm, input buffering for smooth action queueing | Medium | To Do | SignalBus (Gilang) | - |
| Ilham | Game Feel | Enemy Reaction / Impact — hurt-flinch reads clearly, knockback sells weight, crits feel bigger | Medium | To Do | Animation System | - |
| Ilham | Game Feel | Camera Shake — crits, wall-knockback bonus damage, AoE hits; small/medium/big tiers | Medium | To Do | SignalBus (Gilang) | - |
| Ilham | Game Feel | Camera Change — zoom punch on big hits, idle drift/pan easing | Low | To Do | - | - |
| Ilham | Game Feel | UI Feedback — button/skill icon pulse on press, cooldown visual feedback | Low | To Do | - | - |
| Ilham | QA / QC | Combat Balance Pass — damage curves vs enemy HP pools, RNG fairness, difficulty scaling | High | To Do | All Combat Systems | - |
| Ilham | QA / QC | Bug Tracking process — shared tracker, severity tagging, owner assignment per bug | Critical | To Do | - | - |
| Ilham | QA / QC | Regression Test Pass per build — checklist of core flows re-tested before milestone builds | Critical | To Do | - | - |
| Ilham | QA / QC | Playtest Session Coordination — schedule sessions, structured feedback form | Medium | To Do | - | - |
| Ilham | QA / QC | Edge case testing: solo play AI, simultaneous-target conflicts, Contested Pick tie-breaks | Medium | To Do | AI System | - |
| Ilham | QA / QC | Crash/error logging hookup (QA reports include stack traces) | Low | To Do | - | - |
| Ilham | Polishing | VFX Pass — ability impact particles, environment ambience, UI transitions | Low | To Do | Particle FX (Gilang) | - |
| Ilham | Polishing | Audio Mix Pass — volume balancing, ducking during big combat stingers | Low | To Do | Audio System | - |
| Ilham | Polishing | Performance Optimization Pass — draw calls (split-screen 2x), particles, load times, memory | Medium | To Do | - | - |
| Ilham | Polishing | Final input-feel pass — re-tune buffering/hit-stop timings from playtest feedback | Low | To Do | Game Feel | - |
| Ilham | Build & Release | Build Pipeline — export templates for target platform(s) | Medium | To Do | - | - |
| Ilham | Build & Release | Version tagging convention (e.g. v0.1.0-alpha) tied to build pipeline | Medium | To Do | Build Pipeline | - |
| Ilham | Build & Release | Build distribution method decided (itch.io, direct share, etc.) — open question | Low | To Do | - | - |
