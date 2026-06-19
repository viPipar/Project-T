# Project_Context.md
> Game Design Document — Internal Reference

---

## 1. System Architecture Overview

```
Game
├── Dialogue System
│   └── Dialogue Manager 3
│       └── Dynamic Characters Vocalion
│
├── Roguelite Run System
│   └── Level Manager
│       ├── [NEW] Procedural Node Graph Generator        ← #1
│       │   ├── Node Type Pool (Battle / Elite / Boss / Event / Rest / Shop / Loot)
│       │   ├── Path Branching Handler (Slay the Spire-style)
│       │   ├── Depth Layer Manager
│       │   ├── Forced Boss Node (final layer)
│       │   └── Node Unlock Resolver (player chooses branch)
│       │
│       ├── Level: Battle
│       │   ├── Level: Elite Battle
│       │   └── Level: Boss Battle
│       │
│       ├── Level: Roguelite Select Item                  ← #4 (revised)
│       │   ├── Item Pool Generator
│       │   │   ├── Battle (Normal)  — 5 items each player, low good-item chance
│       │   │   ├── Elite Battle     — shared pool (contested), medium good-item chance
│       │   │   └── Boss Battle      — shared pool (contested), high good-item chance
│       │   ├── Rarity Reveal Handler
│       │   │   └── Rarity FX on pick (White glow = Common, Blue glow = Rare, Gold glow = Legendary)
│       │   └── Player Consensus Handler
│       │
│       ├── Level: Luck Event
│       │   ├── Narrative Scene Manager
│       │   ├── Player Consensus Handler
│       │   │   └── Timer (optional)
│       │   ├── Luck Roll Resolver
│       │   │   └── D20 + LCK modifier
│       │   ├── Win State Handler                         ← #2 (revised)
│       │   │   ├── Outcome Pool Resolver (random outcome type)
│       │   │   ├── Reward: 2 random items
│       │   │   ├── Reward: Full HP Heal (100%)
│       │   │   └── [Extendable: more win outcomes]
│       │   └── Lose State Handler                        ← #3 (revised)
│       │       ├── Outcome Pool Resolver (random outcome type)
│       │       ├── Penalty: −50% HP
│       │       ├── Penalty: Cursed Item (negative passive effect)
│       │       └── Penalty: Trigger Random Elite Battle
│       │
│       ├── Level: Loot                                   ← #5
│       │   ├── Item Pool Generator (shared, contested pick)
│       │   └── Minigame Handler (TBD)
│       │
│       ├── Level: Rest                                   ← #6 (rebalanced)
│       │   ├── Option A: Full Rest (+50% HP, +50% Charge/Slot)
│       │   ├── Option B: Partial Rest (+25% HP, +100% Charge/Slot)
│       │   └── Option C: Treasure Search (1 random item, costs −50% HP)
│       │
│       └── Level: Shop
│           ├── Stock Manager
│           │   ├── Item Slot Generator (7 slots)
│           │   ├── Rarity Resolver (Common / Rare / Legendary)
│           │   └── Reroll Handler (cost: 100 Coin)
│           └── Coin Economy
│               ├── Wallet (per player)
│               ├── Send 1/2 Coin
│               └── Send 1/4 Coin
│
├── Combat System
│   ├── Turn Base System
│   │   ├── Player Phase Manager                          ← #8 (concurrent actions)
│   │   │   ├── P1 Action Handler  ─┐
│   │   │   ├── P2 Action Handler  ─┤ Run concurrently (no waiting)
│   │   │   └── Action Queue (Anti-conflict / Sequential Resolver for same-target conflicts)
│   │   ├── Enemy Phase Manager                           ← #7 (sequential execution)
│   │   │   └── Enemy Turn Queue
│   │   │       ├── Sequential Enemy Iterator (one enemy acts at a time)
│   │   │       ├── Per-Enemy AI
│   │   │       │   ├── Target Selector (lowest HP + nearest)
│   │   │       │   └── Action Executor
│   │   │       └── Next Enemy Trigger (fires after current enemy finishes)
│   │   └── Phase Transition Handler
│   │       └── End Turn Detector (both players confirm)
│   │
│   ├── Action Economy System
│   │   ├── Action Point (base 1, +DEX/10)
│   │   ├── Bonus Action Point (base 1, +INT/10)
│   │   ├── Spell Slot Manager  [Wizard / P2]            ← #14 (differentiated)
│   │   │   ├── Lv.1 Slot (base 2, +ATT/5)
│   │   │   ├── Lv.2 Slot (base 2, +ATT/10)
│   │   │   ├── Lv.3 Slot (base 1, +ATT/15)
│   │   │   └── Lv.4 Slot
│   │   ├── Energy Charge Manager  [Fighter / P1]        ← #14 (differentiated)
│   │   │   └── Charge Stack (base 5)
│   │   ├── Mana Equivalence Converter                   ← #14 (cross-item normalization)
│   │   │   ├── +Spell Slot Lv.1 item  → +1 Energy Charge
│   │   │   ├── +Spell Slot Lv.2 item  → +2 Energy Charge
│   │   │   ├── +Spell Slot Lv.3 item  → +3 Energy Charge
│   │   │   └── +Spell Slot Lv.4 item  → +4 Energy Charge
│   │   └── Movement Point (base 6 tiles, +MOV/5)
│   │
│   ├── Ability System                                    ← #9 #11 (modular + FF merged)
│   │   ├── IAbility Interface
│   │   │   ├── execute(caster, target, grid) → void
│   │   │   ├── get_cost() → ActionCost
│   │   │   ├── get_area() → GridArea
│   │   │   └── emit_signals() → [on_hit, on_miss, on_knockback, on_status]
│   │   ├── Physical Abilities  [implements IAbility]
│   │   │   ├── Main Attack
│   │   │   ├── Elbow Smash
│   │   │   ├── Slash Flash
│   │   │   ├── Cleave
│   │   │   ├── Dagger Throw
│   │   │   ├── Rupture
│   │   │   ├── Epimorphic
│   │   │   └── Autotomy
│   │   ├── Magic Abilities  [implements IAbility]
│   │   │   ├── Spell Slot Consumer
│   │   │   └── Scholar / Wizard Skill Set (TBD)
│   │   └── Friendly Fire Handler  [built into IAbility]  ← #11 (merged, not separate)
│   │       ├── Ally Damage Resolver
│   │       └── Enemy Heal / Buff Resolver
│   │
│   ├── Projectile System                                 ← #12 (new)
│   │   ├── Projectile Spawner
│   │   ├── Projectile Mover (grid-step or physics)
│   │   └── Grid Collision Detector
│   │       ├── Check occupied tiles along trajectory
│   │       ├── On collision → trigger hit resolution
│   │       └── Wall / Object Blocker Handler
│   │
│   ├── RNG System
│   │   ├── Hit / Miss Resolver
│   │   │   └── D20 + floor(ACC/2) vs. target Armor / Resist
│   │   ├── Damage / Heal Roller
│   │   │   └── Dice Pool (D4 / D6 / D8 / D10 / D12 / D20 / multi-dice)
│   │   ├── Critical Hit Resolver
│   │   │   └── Natural Crit Threshold = 20 − floor(ACC/10)
│   │   └── Luck Event Roller
│   │       └── D20 + floor(LCK/5)
│   │
│   ├── Elemental & Status Effect System
│   │   ├── Element Tag Manager
│   │   │   ├── True (Physical)
│   │   │   ├── Fire
│   │   │   ├── Water
│   │   │   ├── Air
│   │   │   └── Earth
│   │   ├── Physical Status Effects
│   │   │   ├── Bleeding (DoT)
│   │   │   ├── Stun (skip turn)
│   │   │   ├── Lacerate (movement −)
│   │   │   ├── Weakened (armor −)
│   │   │   └── Vulnerable (damage +)
│   │   ├── Elemental Combo Resolver
│   │   │   ├── Fire + Earth → Magma (DoT)
│   │   │   ├── Earth + Water → Mud (movement −)
│   │   │   ├── Water + Fire → Vapor (damage +20%)
│   │   │   ├── Air + Water → Mist (accuracy −)
│   │   │   ├── Air + Earth → Erosion (armor −)
│   │   │   └── Fire + Air → Conflagration (spread AoE)
│   │   ├── DoT / Persistent Effect Ticker
│   │   └── Status Particle FX Manager                   ← #15 (new)
│   │       ├── Per-entity particle emitter (attached to entity node)
│   │       ├── Bleeding  → red drip particles
│   │       ├── Stun      → star / spark particles
│   │       ├── Fire tag  → flame particles
│   │       ├── Water tag → water droplet particles
│   │       ├── Earth tag → dust/rock chip particles
│   │       ├── Air tag   → swirl/wind particles
│   │       └── [Extendable for each new status]
│   │
│   ├── Stat System
│   │   ├── Attribute Manager (VIT / STR / INT / CON / ACC / DEX / MOV / ATT / LCK)
│   │   ├── Derived Stat Calculator
│   │   │   ├── HP
│   │   │   ├── Armor
│   │   │   ├── Resist
│   │   │   ├── Physical Damage Bonus
│   │   │   └── Magical Damage Bonus
│   │   └── Health Manager
│   │       ├── Health Attribute
│   │       ├── Damage Applier
│   │       ├── Heal Applier
│   │       ├── Downed State Handler
│   │       └── Revive Handler (adjacent ally + 1 Action → 20% HP)
│   │
│   ├── Item System                                       ← #10 (rarity dependency)
│   │   ├── Item Registry
│   │   │   ├── Common    — Stat Modifier only
│   │   │   ├── Rare      — Stat Modifier + Resource Modifier
│   │   │   └── Legendary — Stat Modifier + Resource Modifier (enhanced values)
│   │   ├── Item Effect Applier
│   │   │   ├── Stat Modifier
│   │   │   ├── Resource Modifier (AP / BAP / Slot / Movement / Charge)
│   │   │   └── Cross-class Buff (Roguelite pickup)
│   │   ├── Cursed Item Handler  (Lose State from Luck Event)
│   │   │   └── Negative Passive Effect Applier
│   │   └── Inventory Manager (per player)
│   │
│   └── Movement System
│       ├── Isometric Tiles
│       ├── Grid Manager
│       ├── Pathfinding (A* or similar)
│       ├── Knockback Resolver                            ← #13 (signal listener)
│       │   ├── Wall Collision → Bonus Damage
│       │   └── on_knockback signal listener (from IAbility emit_signals)
│       └── Environmental Interaction Handler
│
└── UI System
    ├── Split-Screen Manager
    │   ├── P1 Viewport (Left)
    │   ├── P2 Viewport (Right)
    │   └── Shared World State Sync
    ├── HUD Manager
    │   ├── Resource Bar — Fighter (P1)
    │   │   ├── Action Point / Bonus Action Point
    │   │   ├── Energy Charge (🔥)
    │   │   ├── Movement
    │   │   └── Inventory Icon
    │   ├── Resource Bar — Wizard (P2)
    │   │   ├── Action Point / Bonus Action Point
    │   │   ├── Spell Slot Lv1–4 (🔵 I/II/III/IV)
    │   │   ├── Movement
    │   │   └── Inventory Icon
    │   ├── Character Profile Icon
    │   ├── HP / Armor Floating Indicator (above targets)
    │   └── Blink Indicator (on skill preview — consumed resources)
    ├── Radial Menu System
    │   ├── Skill Slot Renderer
    │   ├── Navigation Handler (< / > for overflow)
    │   └── Selection Confirmer
    ├── Pointer / Target Cursor
    │   ├── P1 Cursor
    │   └── P2 Cursor
    ├── Floating Combat Text
    │   ├── Damage Number Popup
    │   ├── Heal Number Popup
    │   ├── "MISS!" Label
    │   └── Element Icon Popup (Fire / Water / Air / Earth)
    ├── Item Rarity Reveal FX                             ← #4
    │   ├── White Glow  → Common
    │   ├── Blue Glow   → Rare
    │   └── Gold Glow   → Legendary
    ├── Dice Roll Animation
    │   └── D20 Spin Overlay
    └── Input Manager
        ├── P1 Keys (W A S D Q E Z X C F R LSHIFT)
        └── P2 Keys (I J K L U O M , . / P RSHIFT)
```

---

## 2. Stats & Modifiers

### Base Stats Formula

| Stat | Formula | Notes |
|------|---------|-------|
| HP | `15 + floor(VIT/2) + floor(STR/4)` | Survivability |
| Armor | `10 + floor(CON/2) + floor(DEX/4)` | Hit difficulty for enemy attacks |
| Resist | `5 + floor(VIT/4) + floor(CON/4)` | Debuff/stun hit difficulty |
| Physical Damage | `[Dice Roll] + floor(STR/2)` | Dice depends on skill |
| Magical Damage | `[Dice Roll] + floor(INT/2)` | Dice depends on skill |

### Roll Stats

| Roll | Formula |
|------|---------|
| Hit or Miss | `D20 + floor(ACC/2)` |
| Natural Crit Threshold | `20 - floor(ACC/10)` |
| Luck Event | `D20 + floor(LCK/5)` |

### Resource Stats

| Resource | Player | Formula |
|----------|--------|---------|
| Spell Slot Lv.1 | Wizard (P2) | `2 + floor(ATT/5)` |
| Spell Slot Lv.2 | Wizard (P2) | `2 + floor(ATT/10)` |
| Spell Slot Lv.3 | Wizard (P2) | `1 + floor(ATT/15)` |
| Energy Charge | Fighter (P1) | Base 5 (modified by items) |
| Tiles (Movement) | Both | `6 + floor(MOV/5)` |
| Action Point | Both | `1 + floor(DEX/10)` |
| Bonus Action Point | Both | `1 + floor(INT/10)` |

### Mana / Energy Equivalence Table ← #14

When an item that modifies Spell Slots is picked up by P1 (Fighter), the value is converted to Energy Charges:

| Item Effect | Wizard (P2) gets | Fighter (P1) gets |
|-------------|-----------------|-------------------|
| +Spell Slot Lv.1 | +1 Spell Slot Lv.1 | +1 Energy Charge |
| +Spell Slot Lv.2 | +1 Spell Slot Lv.2 | +2 Energy Charge |
| +Spell Slot Lv.3 | +1 Spell Slot Lv.3 | +3 Energy Charge |
| +Spell Slot Lv.4 | +1 Spell Slot Lv.4 | +4 Energy Charge |

### Modifier Summary

| Attribute | Effect | Rate |
|-----------|--------|------|
| VIT (Vitality) | +HP | 2 VIT → +1 HP |
| VIT (Vitality) | +Resist | 4 VIT → +1 Resist |
| STR (Strength) | +Physical Damage | 2 STR → +1 Phys DMG |
| STR (Strength) | +HP | 4 STR → +1 HP |
| INT (Intelligence) | +Magical Damage | 2 INT → +1 Mag DMG |
| INT (Intelligence) | +Bonus Action Point | 10 INT → +1 Bonus AP |
| CON (Constitution) | +Armor | 2 CON → +1 Armor |
| CON (Constitution) | +Resist | 4 CON → +1 Resist |
| ACC (Accuracy) | +Hit Roll | 2 ACC → +1 Hit Roll |
| ACC (Accuracy) | −Natural Crit Threshold | 10 ACC → −1 Crit Roll |
| DEX (Dexterity) | +Armor | 4 DEX → +1 Armor |
| DEX (Dexterity) | +Action Point | 10 DEX → +1 AP |
| MOV (Movement) | +Tiles | 5 MOV → +1 Tile |
| ATT (Attunement) | +Spell Slot Lv.1 | 5 ATT → +1 Slot |
| ATT (Attunement) | +Spell Slot Lv.2 | 10 ATT → +1 Slot |
| ATT (Attunement) | +Spell Slot Lv.3 | 15 ATT → +1 Slot |
| LCK (Luck) | +Luck Event Roll | 5 LCK → +1 Roll |

---

## 3. Classes & Orders

Class system inspired by HSR Path (Faith-Based).

| Order | Logo | Motto | Class Role |
|-------|------|-------|-----------|
| Slayer Order | Broken Sword | *VENI VIDI VICI* | Fighter (Player 1 default) |
| Hunter Order | Butterfly + Arrow | *EX TENEBRIS VERITAS* | Ranger |
| Scholar Order | Star/Planet Ring | *ASTRA REGAMUS* | Wizard (Player 2 default) |
| Soldier Order | Shield Beetle | *MVRVS INEXPUGNABILIS* | Tank |
| Cleric Order | Angel Wings | *BENEDICTIO* | Healer |

> Players have one main class but can acquire items/buffs from other classes (roguelike-style).

---

## 4. Combat System

### Action Economy (Per Turn)

| Resource | Icon | Base | Player | Can Increase? |
|----------|------|------|--------|---------------|
| Action Point | 🟢 | 1 | Both | Yes (items/skills/DEX) |
| Bonus Action Point | 🟡 | 1 | Both | Yes (items/skills/INT) |
| Spell Slot (Lv1–Lv4) | 🔵 | 2/2/1/— | Wizard (P2) | Yes (items/skills/ATT) |
| Energy Charge | 🔥 | 5 | Fighter (P1) | Yes (items) |
| Movement | ⬆️ | 6 Tiles | Both | Yes (items/skills/MOV) |

### Dice Reference

| Dice | Range |
|------|-------|
| D4 | 1–4 |
| D6 | 1–6 |
| D8 | 1–8 |
| D10 | 1–10 |
| D12 | 1–12 |
| D20 | 1–20 |
| 2D6 | 2–12 |
| 3D6 | 3–18 |
| 4D6 | 4–24 |

### Combat Flow

```
Combat Start
    ↓
[Player Phase] — P1 & P2 act CONCURRENTLY (no waiting for each other)
    │
    ├─ P1 & P2 independently: Choose Skill → Target → Roll → Apply
    ├─ Friendly Fire ON (handled inside IAbility)
    ├─ Same-target conflicts resolved sequentially via Action Queue
    │
    ├─ If both players press End Turn
    ↓
[Enemy Phase] — Enemies act SEQUENTIALLY (one by one, no overlap)
    ├─ Enemy 1 acts → finishes → Enemy 2 acts → … → Enemy N acts
    ↓
All enemies dead?
    ├─ No  → Back to Player Phase
    └─ Yes → NEXT LEVEL
```

### Combat Example — Heavy Attack (2D10)

1. Player 1 uses Heavy Attack on enemy (costs 🟢 Action Point).
2. Roll D20 + Hit modifier vs. enemy Armor (e.g., 12).
3. Roll ≥ 12 → HIT → Roll 2D10 (e.g., 5+10 = **15 damage**).
4. Roll < 12 → MISS → No effect.

### Combat Example — Heal Beam (4D6)

1. Player 2 uses Heal Beam on Player 1 (costs 🔵 Spell Slot).
2. Roll D20 vs. base difficulty (e.g., 10).
3. Roll ≥ 10 → HIT → Roll 4D6 (e.g., 5+4+6+5 = **20 HP healed**).
4. Roll < 10 → MISS → Roll 4D6 anyway → result **halved** (e.g., 20/2 = **10 HP healed**).

---

## 5. Elemental Synergy

### Physical Status Effects

| Status | Effect | Trigger |
|--------|--------|---------|
| Bleeding | Damage Over Time (DoT) | Physical attacks |
| Stun | Delay enemy turn for 1 round | Physical attacks |
| Lacerate | Movement Reduction | Physical attacks |
| Weakened | Armor Reduction | Physical attacks |
| Vulnerable | Damage Increase [+] | Physical attacks |

### Elements

Four base magical elements: **FIRE**, **EARTH**, **WATER**, **AIR**
Plus **True (Physical)** as the fifth damage type.

### Elemental Combo Status Effects

| Combo | Result | Effect |
|-------|--------|--------|
| Fire + Earth | **Magma** | Damage Over Time (DoT) |
| Earth + Water | **Mud** | Movement Reduction |
| Water + Fire | **Vapor** | Damage Increase [+20%] |
| Air + Water | **Mist** | Enemy Accuracy Decrease [−] |
| Air + Earth | **Erosion** | Armor Reduction |
| Fire + Air | **Conflagration** | Spread Damage to Nearby |

> Logic: If enemy has status *Burn* (Fire), a Water attack triggers Vapor → adds +20% damage.

### Status Particle FX Reference ← #15

| Status / Tag | Particle Effect |
|--------------|----------------|
| Bleeding | Red drip particles around entity |
| Stun | Yellow stars / spark burst |
| Fire tag | Flame emitter on entity |
| Water tag | Water droplet spray around entity |
| Earth tag | Dust / rock chip particles |
| Air tag | Swirl / wind streak particles |
| Magma | Lava drip + ember particles |
| Mud | Brown splatter particles |
| Mist | Faint fog puff emitter |
| Conflagration | Spreading ember spray |

---

## 6. Key Features

### 1. Split-Screen Native
- Vertical split (Left = P1, Right = P2), shared world state.
- **P1 Keys:** W A S D Q E Z X C F R LSHIFT
- **P2 Keys:** I J K L U O M , . / P RSHIFT
- Playable solo (switch between WASD ↔ IJKL) or local co-op.

### 2. Action Point Economy
Full action economy per turn (AP, Bonus AP, Spell Slots / Energy Charge, Movement).

### 3. RNG Hit/Miss & Damage System
D20 for hit resolution, separate dice for damage/heal amounts.

### 4. Friendly Fire (Built into Ability System) ← #11
- Friendly fire logic is part of the IAbility interface — not a separate system.
- Can damage allies, can heal/buff enemies.
- Discourages mindless AoE spam; rewards strategic positioning.

### 5. Turn Order: Player Phase (Concurrent) → Enemy Phase (Sequential) ← #7 #8
- Both players act simultaneously in Player Phase — P1 and P2 do not wait for each other.
- Enemies act one at a time in Enemy Phase to prevent chaotic multi-action overlap.

### 6. Elemental Synergy / Tag System
5 base elements (True/Physical, Fire, Water, Air, Earth) with combo effects via status tags.

### 7. Modular Ability System ← #9
- All abilities implement a shared `IAbility` interface in Godot.
- Adding new abilities = implement interface + register in ability pool.
- Signals emitted by abilities (`on_hit`, `on_knockback`, etc.) are consumed by other systems (knockback, status FX, etc.).

### 8. Procedural Level Map ← #1
- Node graph generated each run (Slay the Spire–style branching paths).
- Player chooses which branch/node to traverse.
- Boss node always anchors the final depth layer.

### 9. Item Rarity Dependency ← #10

| Rarity | Contents |
|--------|----------|
| Common | Stat Modifier only |
| Rare | Stat Modifier + Resource Modifier |
| Legendary | Stat Modifier + Resource Modifier (enhanced/amplified values) |

Item rarity is revealed via a light effect **after** the player picks the item (white/blue/gold glow).

---

## 7. Programmer Task Lists

### Combat / Gameplay

- [ ] Co-op turn system (P1 & P2 simultaneous player phase, then sequential enemy phase)
- [ ] IAbility interface — modular ability architecture (execute, cost, area, signals)
- [ ] Friendly fire logic merged into IAbility (remove standalone Friendly Fire System)
- [ ] Grid-based movement + pathfinding
- [ ] Action queue / anti-conflict system (concurrent same-target attacks resolve sequentially)
- [ ] Action Economy enforcement (AP, Bonus AP, Spell Slots [P2], Energy Charge [P1], Movement)
- [ ] Mana equivalence converter (Spell Slot item → Energy Charge for Fighter)
- [ ] D20 RNG hit/miss system vs. Armor/Resist thresholds
- [ ] Damage/heal dice system (separate roll post hit-check)
- [ ] Elemental synergy & status tag system
- [ ] Status particle FX per entity (bleeding, stun, fire, water, earth, air, combo statuses)
- [ ] Projectile system with grid tile collision detection
- [ ] Signal bridge: IAbility `on_knockback` signal → Knockback Resolver
- [ ] Environmental interaction (knockback into walls → bonus damage)
- [ ] Revive mechanic (downed player → ally stands adjacent + spends Action → revived at 20% HP)
- [ ] Enemy AI — sequential turn execution (enemies act one by one)

### Roguelite / Level

- [ ] Procedural node graph generator (Slay the Spire–style branching)
- [ ] Luck Event — win/lose outcome pool (multiple possible outcomes per state)
- [ ] Cursed Item system (negative passive items from Luck Event lose state)
- [ ] Luck Event lose state: random Elite Battle trigger
- [ ] Select Item rarity reveal FX (white/blue/gold glow on pick)
- [ ] Select Item differentiation by battle tier (Normal: individual picks, low odds; Elite: contested, medium odds; Boss: contested, high odds)
- [ ] Loot level — contested shared item pool
- [ ] Rest Option C balancing: Treasure Search costs −50% HP

### UI / Narrative

- [ ] Vertical split-screen rendering (shared world, independent cameras)
- [ ] Radial (circular) action/skill menu
- [ ] D20 dice roll animation on-screen
- [ ] Floating combat text (damage numbers, "MISS!", element icons)
- [ ] HUD differentiation: P1 shows Energy Charge (🔥), P2 shows Spell Slots (🔵)
- [ ] Clean HUD — coordinate with Illustrator team
- [ ] Dialogue system integration (Dialogue Manager 3 + Dynamic Vocalion)

---

## 8. Fighter (P1) — Action List (Detailed)

| # | Skill Name | Tag ID | Effect | Cost | Grid Area |
|---|-----------|--------|--------|------|-----------|
| 1 | **Main Attack** | `basic-attack-test` | [1D10] 1–10 Physical | 1 Action | 4 adjacent tiles (↑↓←→) — 🟡 Yellow |
| 2 | **Elbow Smash** | `knockback-test` | [1D4] 1–4 Physical + Knockback 1 Tile | 1 Bonus Action | 4 adjacent tiles (↑↓←→) — 🟡 Yellow |
| 3 | **Slash Flash** | `dash-attack-test` | [1D6] 1–6 Physical + Dash Toward Target | 1 Action + 1 Bonus Action + 1 Charge | Straight line 3 tiles × 4 directions — 🟡 Yellow |
| 4 | **Cleave** | `aoe-attack-test` | [1D8] 1–8 Physical AoE | 1 Action + 2 Charge | 3×3 box around character — 🔴 Red (AoE) |
| 5 | **Dagger Throw** | `armor-reduct-status` | [1D4] 1–4 Physical + Weakened (−2 Armor) | 1 Bonus Action + 1 Charge | 5×5 box around character — 🟡 Yellow |
| 6 | **Rupture** | `dot-status-test` | [1D6] 1–6 Physical + Bleeding (DoT 1–4/turn) | 1 Action + 2 Charge | 3×3 box around character — 🟡 Yellow |
| 7 | **Epimorphic** | `self-heal-test` | [1D8] 1–8 Heal (Self) | 1 Bonus Action + 1 Charge | Self tile only — 🟢 Green |
| 8 | **Autotomy** | `self-damage-test` | −20% HP, +4 Armor (Self) | 1 Action + 2 Charge | Self tile only — 🟢 Green |

### Grid Area Legend

| Color | Meaning |
|-------|---------|
| 🟡 Yellow | Targeted / Directional |
| 🔴 Red | Area of Effect (AoE) |
| 🟢 Green | Self / Friendly |

---

## 9. Level Types & Flow

The game is structured as a roguelite run with multiple level types between battles.

### Level Map (Node Types)

| Level Type | Description |
|-----------|-------------|
| **Battle** | Standard combat encounter |
| **Elite Battle** | Stronger enemy variant — "BATTLE BUT MORE STRONGER" |
| **Boss Battle** | Boss encounter — "BATTLE BUT STRONG" |
| **Roguelite Select Item** | Item selection — rules vary by battle tier (see §10) |
| **Luck Event** | Interactive narrative scene with dice-based outcome |
| **Loot** | Contested shared item pool reward screen |
| **Rest** | Campfire — players choose a recovery option |
| **Shop** | Purchase items using Coins; shareable economy between players |

### Procedural Node Graph ← #1

- Each run generates a new node graph with branching paths (inspired by Slay the Spire map).
- Players view the map and **choose which node to travel to** at each junction.
- Nodes are distributed across depth layers; each layer can offer 1–3 branch choices.
- **Boss node is always fixed at the final depth layer.**
- Node type distribution is weighted (e.g., more Battles early, more Events and Rest mid-run, Boss at end).

---

## 10. Level Detail: Roguelite Select Item ← #4 (revised)

Item selection rules vary depending on which battle tier just completed:

| Battle Tier | Selection Mode | Good Item Chance |
|-------------|---------------|-----------------|
| Normal Battle | Each player selects from their **own 5-item pool** | Low |
| Elite Battle | Both players pick from a **shared contested pool** | Medium |
| Boss Battle | Both players pick from a **shared contested pool** | High |

- Items are displayed as silhouettes (Triangle, Oval, Rectangle, Star, Diamond).
- After a player picks an item, the silhouette **reveals its rarity via light FX**:
  - ✨ White glow → Common
  - 💙 Blue glow → Rare
  - 🌟 Gold glow → Legendary
- In contested pools, communication and negotiation between players is required.

---

## 11. Level Detail: Luck Event ← #2 #3 (revised)

A narrative interactive scene where both players face a choice together.

**Example scene:** *"A giant snail is trapped under a log and wants help."*

**Options:**
- a. Try to pull the log
- b. Leave it

**Rules:**
- Both players must agree on the same option before the game proceeds.
- A countdown timer may be needed if players can't agree.

### Luck Event Flow

```
[Luck Event - Choice Screen]
    ↓ Both players agree on an option
[Luck Event - Roll Dice]
    → Roll D20 (Luck modifier applied)
    ↓
    ├─ WIN STATE  → Outcome Pool (random):
    │               • 2 random items (Star + Diamond silhouettes)
    │               • Full HP Heal (100%)
    │               • [More win outcomes — extendable]
    │
    └─ LOSE STATE → Outcome Pool (random):
                    • −50% HP
                    • Receive a Cursed Item (negative passive debuff)
                    • Trigger a random Elite Battle
```

---

## 12. Level Detail: Rest (Campfire) ← #6 (rebalanced)

Players find a campfire and choose one of three options:

| Option | Effect | Notes |
|--------|--------|-------|
| a. Full Rest | +50% HP + +50% Energy Charge / Spell Slot | Safe choice |
| b. Partial Rest | +25% HP + +100% Energy Charge / Spell Slot | Resource-focused |
| c. Treasure Search | Gain 1 random item, **−50% HP** | High risk, high reward |

> Option C now has a real cost — searching nearby is dangerous and leaves the party weakened.

---

## 13. Level Detail: Shop

### Shop Layout

**Item Rarities & Prices (example stock):**

| Slot | Rarity | Shape | Price |
|------|--------|-------|-------|
| 1 | Common | Triangle | 100 |
| 2 | Rare | Oval | 300 |
| 3 | Common | Rectangle | 120 |
| 4 | Rare | Star | 350 |
| 5 | Rare | Diamond | 850 |
| 6 | Common | Small Rectangle | 150 |
| 7 | Legendary | Inverted Triangle | 600 |

### Coin Economy

- Each player has their own Coin wallet displayed in the shop HUD.
- Players can **share coins** with each other using:
  - `Send 1/2 Coin` button
  - `Send 1/4 Coin` button
- Example: P1 has 190 Coin, P2 has 50 Coin — P1 can send coins to help P2 afford items.

### Reroll

- A **REROLL** button (cost: 100 Coin) refreshes the shop's item stock.

---

## 14. Battle UI Overview

### Split-Screen Layout

- Screen split **vertically** (P1 = Left, P2 = Right).
- Both sides render the **same shared world** — actions by one player are visible to the other.
- Isometric grid-based arena.

### Resource Bar — Fighter (P1, Left)

| Icon | Resource | Base Value |
|------|----------|------------|
| 🟢 Circle | Action Point | 1 |
| 🟡 Triangle | Bonus Action Point | 1 |
| ⬆️ Arrow | Movement | 30.0 |
| 🔥 Fire | Energy Charge | 5 |
| 🎒 Bag | Inventory | — |

### Resource Bar — Wizard (P2, Right)

| Icon | Resource | Base Value |
|------|----------|------------|
| 🎒 Bag | Inventory | — |
| 🟢 Circle | Action Point | 1 |
| 🟡 Triangle | Bonus Action Point | 1 |
| ⬆️ Arrow | Movement | 30.0 |
| 🔵 Box (I/II/III/IV) | Spell Slot (Lv1–4) | 1 each |

### Movement (Pathfinding)

- Selecting movement shows a glowing white arrow path on the isometric grid tiles.
- Grid-based pathfinding to selected destination tile.

### Radial Menu (Skill Select)

- Pressing the menu button opens a **circular radial menu** centered on the player's screen.
- Icons arranged radially — player navigates with `<` / `>` arrows if more skills than slots.
- Each player's radial is **independent** (P1 and P2 can open theirs simultaneously).

**Fighter radial (example):** Sword (top), Green Fist (right), Cyan Heal Hand (left)

**Wizard radial (example):** Sword (top), Green Fist (right), Cyan Cross (bottom), Blue Claw (left)

### Target Selection

After selecting a skill:
1. A white pointer cursor appears on the grid.
2. Player aims at a target (enemy or ally — Friendly Fire ON).
3. A **stat indicator** floats above the target showing: ❤️ HP / 🛡️ Armor.
4. The **resource bar blinks** to indicate which resources will be consumed if the action is confirmed.

---

## 15. Architecture Revision Notes

| # | Area | Change Summary |
|---|------|---------------|
| 1 | Level Map | Procedural node graph generator added (Slay the Spire–style branching) |
| 2 | Luck Event Win | Win state now draws from an outcome pool — not hardcoded to 2 items |
| 3 | Luck Event Lose | Lose state now draws from an outcome pool — cursed item, elite battle, or −50% HP |
| 4 | Select Item | Three tiers with different selection modes and good-item probability; rarity FX on pick |
| 5 | Loot | Clarified as contested shared pool (same as Elite/Boss item select) |
| 6 | Rest | Option C (Treasure Search) now costs −50% HP for balance |
| 7 | Enemy Phase | Enemies now act sequentially (one at a time) to prevent chaos |
| 8 | Player Phase | Confirmed: P1 and P2 act fully concurrently |
| 9 | Ability System | Refactored to IAbility interface; modular plug-in pattern |
| 10 | Item Rarity | Rarity tiers now have strict content dependency (Common/Rare/Legendary) |
| 11 | Friendly Fire | Merged into IAbility — no longer a standalone system |
| 12 | Projectile | New Projectile System with grid-based tile collision detection |
| 13 | Knockback | Knockback Resolver now listens to `on_knockback` signal from IAbility |
| 14 | Mana | Energy Charge (Fighter) and Spell Slots (Wizard) are separate; cross-item equivalence table defined |
| 15 | Status FX | Status Particle FX Manager added — each status tag has a visual particle emitter |

---

*Last updated: April 2026 — Architecture revisions 1–15 applied.*