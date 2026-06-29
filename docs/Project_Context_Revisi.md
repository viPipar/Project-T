# Project_Context.md
> Game Design Document — Internal Reference  
> **Version:** 2.0 | **Last Updated:** May 2026  
> **Changelog v2.0:** Integrated 15 architecture improvements + Lead Programmer review revisions

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
│       │
│       ├── [NEW] Procedural Node Generator          ← POIN 1
│       │   ├── Map Graph Builder
│       │   │   ├── Path Brancher (min 2, max 4 paths per row)
│       │   │   ├── Node Type Assigner
│       │   │   │   ├── Row 1–2  : Battle heavy (70% Battle, 15% Luck, 15% Loot)
│       │   │   │   ├── Row 3–5  : Mixed (40% Battle, 20% Elite, 15% Rest,
│       │   │   │   │             10% Shop, 10% Luck, 5% Loot)
│       │   │   │   ├── Row 6–8  : Elite heavy (30% Battle, 35% Elite, 15% Rest,
│       │   │   │   │             10% Shop, 10% Luck)
│       │   │   │   └── Final Row: Boss Battle (forced)
│       │   │   ├── Path Connectivity Validator (no dead ends)
│       │   │   └── Seed Manager (reproducible per run via RNG seed)
│       │   ├── Map UI Renderer
│       │   │   ├── Node Icon Renderer (icon per node type)
│       │   │   ├── Path Line Renderer (accessible / locked / visited)
│       │   │   ├── Current Position Highlighter
│       │   │   └── Scroll / Pan Handler (if map exceeds screen)
│       │   └── Node Selection Handler
│       │       ├── Reachability Checker (only adjacent forward nodes)
│       │       └── Transition Trigger → Level Loader
│       │
│       ├── Level: Battle (Normal)
│       ├── Level: Elite Battle
│       └── Level: Boss Battle
│       │
│       ├── Level: Select Item                        ← POIN 4 (Revamped)
│       │   ├── Item Pool Generator
│       │   │   ├── Normal Battle Pool
│       │   │   │   ├── 5 items generated
│       │   │   │   ├── Rarity Weight: Common 70% / Rare 27% / Legendary 3%
│       │   │   │   └── Pick Mode: Individual (each player picks own item)
│       │   │   ├── Elite Battle Pool
│       │   │   │   ├── 5 items generated
│       │   │   │   ├── Rarity Weight: Common 40% / Rare 45% / Legendary 15%
│       │   │   │   └── Pick Mode: Contested (rebutan — see Contested Pick System)
│       │   │   └── Boss Battle Pool
│       │   │       ├── 5 items generated
│       │   │       ├── Rarity Weight: Common 15% / Rare 50% / Legendary 35%
│       │   │       └── Pick Mode: Contested (rebutan)
│       │   ├── [NEW] Contested Pick System (Rebutan)
│       │   │   ├── Simultaneous Selection Detector
│       │   │   │   └── Fires when both players target same item silhouette
│       │   │   ├── Tiebreaker Roll Handler
│       │   │   │   ├── D20 + floor(LCK/5) per player
│       │   │   │   ├── Higher roll wins the item
│       │   │   │   └── On exact tie → re-roll (no limit, keep until diff)
│       │   │   └── Result Broadcaster (winner gets item, loser picks again)
│       │   ├── [NEW] Rarity Reveal Animator             ← POIN 4
│       │   │   ├── Silhouette → Reveal transition (0.8s animation)
│       │   │   ├── Common  → White light burst
│       │   │   ├── Rare    → Blue light burst
│       │   │   └── Legendary → Gold light burst + particle shower
│       │   └── Item Applier → Inventory Manager
│       │
│       ├── Level: Luck Event                         ← POIN 2 & 3 (Revamped)
│       │   ├── Narrative Scene Manager
│       │   ├── Player Consensus Handler
│       │   │   └── Timer (optional, triggers default option on expiry)
│       │   ├── Luck Roll Resolver
│       │   │   └── D20 + floor(LCK/5) modifier (average of both players' LCK)
│       │   ├── [REVAMPED] Win State Handler
│       │   │   ├── Win Outcome Pool (weighted random pick)
│       │   │   │   ├── 40% → Reward: 2 random items (rarity by current run depth)
│       │   │   │   ├── 25% → Full HP Restore (both players 100% HP)
│       │   │   │   ├── 20% → Reward: 1 Legendary item
│       │   │   │   ├── 10% → Gold Windfall (+200 Coin each player)
│       │   │   │   └── 5%  → Stat Boost (permanent +2 to random attribute, both)
│       │   │   └── Outcome Presenter (narrative flavor text per outcome)
│       │   └── [REVAMPED] Lose State Handler
│       │       ├── Lose Outcome Pool (weighted random pick)
│       │       │   ├── 35% → HP Penalty: −50% HP (both players)
│       │       │   ├── 25% → Cursed Item: 1 random debuff item added to inventory
│       │       │   │         (cursed item cannot be discarded until next Rest)
│       │       │   ├── 20% → Surprise Elite Battle (spawns immediately after scene)
│       │       │   ├── 15% → Coin Loss: −30% Coin from each wallet
│       │       │   └── 5%  → Attribute Debuff: −3 to random attribute (removable
│       │       │             at Rest)
│       │       └── Outcome Presenter (narrative flavor text per outcome)
│       │
│       ├── Level: Loot                              ← POIN 5
│       │   ├── Item Pool Generator (3–5 items, Rarity: Rare/Legendary skewed)
│       │   ├── Pick Mode: Contested (Rebutan — same system as Elite/Boss Select Item)
│       │   │   └── Uses Contested Pick System (D20 + LCK tiebreaker)
│       │   └── Loot Minigame Handler (TBD — e.g., speed challenge unlocks more items)
│       │
│       ├── Level: Rest (Campfire)                   ← POIN 6 (Rebalanced)
│       │   ├── Option A: Full Rest
│       │   │   └── +50% HP + +50% Energy Charge / Spell Slot (both players)
│       │   ├── Option B: Partial Rest
│       │   │   └── +25% HP + +100% Energy Charge / Spell Slot (both players)
│       │   └── [REBALANCED] Option C: Treasure Search
│       │       ├── Probability Roll Handler (hidden from player)
│       │       │   ├── 70% → SUCCESS: Gain 1–2 random items (safe)
│       │       │   ├── 20% → TRAP: −30% HP + Gain 1 random Common item
│       │       │   └── 10% → JACKPOT: Gain 1 Legendary item (safe)
│       │       ├── Outcome Reveal Animator (dramatic pause → item reveal)
│       │       └── HP Applier (for TRAP outcome)
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
│   │   ├── [UPDATED] Player Phase Manager           ← POIN 8
│   │   │   ├── P1 Action Handler (fully concurrent)
│   │   │   ├── P2 Action Handler (fully concurrent)
│   │   │   ├── Action Queue
│   │   │   │   ├── Concurrent Conflict Detector
│   │   │   │   │   └── Fires when P1 & P2 target the same entity simultaneously
│   │   │   │   └── Sequential Resolver (resolve P1 first, then P2 on same target)
│   │   │   └── End Turn Detector (both players confirm End Turn)
│   │   │
│   │   ├── [UPDATED] Enemy Phase Manager            ← POIN 7
│   │   │   ├── Enemy Turn Queue Builder
│   │   │   │   └── Orders all living enemies by initiative (DEX-based or fixed order)
│   │   │   ├── Sequential Enemy Executor
│   │   │   │   ├── Iterates queue one enemy at a time (not parallel)
│   │   │   │   ├── Current Actor Highlighter (visual cue: outline glow)
│   │   │   │   ├── Action Delay Timer (0.5s between each enemy action for readability)
│   │   │   │   └── Post-Action State Validator (check death, status, position)
│   │   │   └── Enemy AI (per enemy)
│   │   │       ├── Target Selector (lowest HP player + nearest)
│   │   │       └── Action Executor (move → attack → special)
│   │   │
│   │   └── Phase Transition Handler
│   │       └── Player Phase → Enemy Phase → Player Phase cycle
│   │
│   ├── Action Economy System
│   │   ├── Action Point (base 1, +DEX/10)
│   │   ├── Bonus Action Point (base 1, +INT/10)
│   │   ├── [UPDATED] Mana System (Per Character)    ← POIN 14
│   │   │   ├── Fighter (P1): Energy Charge Manager
│   │   │   │   ├── Base Charges: 5
│   │   │   │   ├── Max Charges: derived from items / ATT stat
│   │   │   │   └── [NEW] Spell Slot → Energy Charge Converter
│   │   │   │       ├── Slot Lv.1 item = +1 Energy Charge cap
│   │   │   │       ├── Slot Lv.2 item = +2 Energy Charge cap
│   │   │   │       ├── Slot Lv.3 item = +3 Energy Charge cap
│   │   │   │       └── Slot Lv.4 item = +4 Energy Charge cap
│   │   │   └── Wizard (P2): Spell Slot Manager
│   │   │       ├── Lv.1 Slot (base 2, +ATT/5)
│   │   │       ├── Lv.2 Slot (base 2, +ATT/10)
│   │   │       ├── Lv.3 Slot (base 1, +ATT/15)
│   │   │       └── Lv.4 Slot
│   │   │           └── [NEW] Energy Charge → Spell Slot Converter
│   │   │               └── Energy Charge item gives Wizard equivalent Slot level
│   │   └── Movement Point (base 6 tiles, +MOV/5)
│   │
│   ├── [REVAMPED] Ability System                    ← POIN 9 & 11
│   │   ├── BaseAbility (class_name BaseAbility extends Resource)
│   │   │   ├── @export var ability_name : String
│   │   │   ├── @export var ability_tag : String
│   │   │   ├── @export var damage_dice : String   # e.g. "1D10", "2D6"
│   │   │   ├── @export var range_type : String    # "adjacent", "line", "aoe", "self"
│   │   │   ├── @export var range_size : int
│   │   │   ├── @export var is_projectile : bool
│   │   │   ├── @export var element_tag : String   # "physical", "fire", etc.
│   │   │   ├── @export var cost_action : int
│   │   │   ├── @export var cost_bonus_action : int
│   │   │   ├── @export var cost_mana : int        # Energy Charge OR Spell Slot level
│   │   │   ├── @export var status_effect : String # "" = none
│   │   │   ├── @export var knockback_tiles : int  # 0 = no knockback
│   │   │   ├── func execute(caster, targets) → virtual, override per ability .tres
│   │   │   └── signal ability_executed(caster, targets, result)
│   │   │       └── ↳ Caught by: Knockback Resolver, Status Effect System,
│   │   │             Friendly Fire Handler, Projectile System
│   │   │
│   │   ├── Physical Abilities (.tres files extending BaseAbility)
│   │   │   ├── main_attack.tres
│   │   │   ├── elbow_smash.tres     # knockback_tiles = 1
│   │   │   ├── slash_flash.tres
│   │   │   ├── cleave.tres
│   │   │   ├── dagger_throw.tres    # is_projectile = true
│   │   │   ├── rupture.tres         # status_effect = "bleeding"
│   │   │   ├── epimorphic.tres      # self-heal
│   │   │   └── autotomy.tres        # self-damage for armor buff
│   │   │
│   │   ├── Magic Abilities (.tres files extending BaseAbility)
│   │   │   ├── Spell Slot Consumer (built into BaseAbility.cost_mana)
│   │   │   └── Scholar / Wizard Skill Set (TBD — add as .tres files)
│   │   │
│   │   └── [MERGED] Friendly Fire Handler           ← POIN 11
│   │       ├── (No longer a separate system — handled inside Ability.execute())
│   │       ├── Ally Damage Check (if target is ally → still applies damage)
│   │       └── Enemy Heal/Buff Check (if heal targets enemy → still applies heal)
│   │
│   ├── [NEW] Projectile System                      ← POIN 12
│   │   ├── Projectile Spawner
│   │   │   ├── Spawned by abilities where is_projectile = true
│   │   │   ├── Assigns: direction, speed, originating caster, damage payload
│   │   │   └── Visual: sprite/particle trail per element type
│   │   ├── Projectile Mover
│   │   │   └── Moves tile-by-tile each frame along direction vector
│   │   ├── Grid Collision Detector
│   │   │   ├── On each tile traversal: checks GridManager for occupants
│   │   │   ├── Occupant Types: Enemy, Ally, Wall, Environmental Object
│   │   │   ├── On HIT occupant → emit signal hit_detected(projectile, target)
│   │   │   │   ├── → Damage Applier
│   │   │   │   ├── → Status Effect Applier
│   │   │   │   └── → Knockback Resolver (if knockback_tiles > 0)
│   │   │   └── On HIT wall → destroy projectile (no bonus damage from projectile itself)
│   │   └── Projectile Pool Manager (reuse instances for performance)
│   │
│   ├── RNG System
│   │   ├── Hit / Miss Resolver
│   │   │   └── D20 + floor(ACC/2) vs. target Armor / Resist
│   │   ├── Damage / Heal Roller
│   │   │   └── Dice Pool (D4 / D6 / D8 / D10 / D12 / D20 / multi-dice)
│   │   ├── Critical Hit Resolver
│   │   │   └── Natural Crit Threshold = 20 − floor(ACC/10)
│   │   ├── Luck Event Roller
│   │   │   └── D20 + floor(LCK/5)
│   │   └── [NEW] Contested Pick Roller
│   │       └── D20 + floor(LCK/5) per player (for item rebutan tiebreak)
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
│   │   └── [NEW] Status Particle Effect System      ← POIN 15
│   │       ├── Particle Emitter Manager (attached per entity node)
│   │       ├── Status → Particle Map
│   │       │   ├── Bleeding  → Red drip particles (downward drift)
│   │       │   ├── Stun      → Yellow stars orbiting head
│   │       │   ├── Fire tag  → Orange ember particles rising upward
│   │       │   ├── Water tag → Blue water droplet particles orbiting body
│   │       │   ├── Earth tag → Brown dust particles clinging to feet
│   │       │   ├── Air tag   → White wisp particles swirling around
│   │       │   ├── Magma     → Orange + red rising ember burst
│   │       │   ├── Mud       → Brown thick drip particles on legs
│   │       │   ├── Mist      → Semi-transparent white fog around entity
│   │       │   ├── Lacerate  → Purple slash marks flickering
│   │       │   ├── Weakened  → Grey cracked-armor fragments floating
│   │       │   ├── Vulnerable→ Red pulsing aura outline
│   │       │   └── Cursed    → Dark purple miasma wisps (from Luck Lose event)
│   │       ├── Particle Layer Priority (multiple statuses → all shown, layered)
│   │       └── Particle Cleanup Handler (remove on status expiry)
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
│   ├── [REVAMPED] Item System                       ← POIN 10
│   │   ├── Item Registry
│   │   │   ├── Common Items
│   │   │   │   └── Rule: Stat Modifier ONLY
│   │   │   │         (e.g. +5 STR, +3 VIT, +2 ACC — no resource changes)
│   │   │   ├── Rare Items
│   │   │   │   └── Rule: Stat Modifier + Resource Modifier
│   │   │   │         (e.g. +5 STR AND +1 Energy Charge cap / +1 Spell Slot Lv.1)
│   │   │   └── Legendary Items
│   │   │       └── Rule: Stat Modifier + Resource Modifier (enhanced values)
│   │   │             (e.g. +10 STR AND +3 Energy Charge cap AND special passive)
│   │   ├── Item Effect Applier
│   │   │   ├── Stat Modifier
│   │   │   ├── Resource Modifier (AP / BAP / Slot / Movement / Energy Charge)
│   │   │   │   └── Cross-System Converter (Slot ↔ Charge — see Mana System)
│   │   │   └── Cross-class Buff (Roguelite pickup from other class pool)
│   │   ├── [NEW] Cursed Item Handler
│   │   │   ├── Applies negative stat modifier or passive debuff
│   │   │   ├── Cannot be discarded until reaching a Rest node
│   │   │   └── Rest Option A/B allows cursed item removal (choose: remove OR heal)
│   │   └── Inventory Manager (per player)
│   │
│   └── Movement System
│       ├── Isometric Tiles
│       ├── Grid Manager
│       │   └── Occupancy Map (tracks what is on each tile — used by Projectile System)
│       ├── Pathfinding (A* or similar)
│       ├── [UPDATED] Knockback Resolver              ← POIN 13
│       │   ├── Listens to signal: ability_executed(caster, targets, result)
│       │   ├── Checks result.knockback_tiles > 0
│       │   ├── Calculates knockback direction (away from caster)
│       │   ├── Iterates tiles in knockback direction
│       │   ├── Wall Collision Check (per tile)
│       │   │   └── HIT wall → Bonus damage (floor(knockback_tiles * STR/4))
│       │   └── Entity Collision Check (another entity in path)
│       │       └── HIT entity → both take collision damage (D4 Physical)
│       └── Environmental Interaction Handler
│
└── UI System
    ├── Split-Screen Manager
    │   ├── P1 Viewport (Left)
    │   ├── P2 Viewport (Right)
    │   └── Shared World State Sync
    ├── [UPDATED] HUD Manager                         ← POIN 14 UI
    │   ├── P1 Resource Bar (Fighter)
    │   │   ├── 🟢 Action Point
    │   │   ├── 🟡 Bonus Action Point
    │   │   ├── ⬆️ Movement Tiles
    │   │   └── 🔥 Energy Charge (individual charge pips)
    │   │       └── [NEW] Blink Indicator: pulses when item converts Slot→Charge
    │   ├── P2 Resource Bar (Wizard)
    │   │   ├── 🟢 Action Point
    │   │   ├── 🟡 Bonus Action Point
    │   │   ├── ⬆️ Movement Tiles
    │   │   └── 🔵 Spell Slot Lv1/2/3/4 (individual slot pips)
    │   │       └── [NEW] Blink Indicator: pulses when item converts Charge→Slot
    │   ├── Character Profile Icon
    │   ├── HP / Armor Floating Indicator (above targets)
    │   ├── [NEW] Status Icon Bar (above entity, lists active status tags with icons)
    │   └── Inventory Icon
    ├── [NEW] Map UI (Procedural Node Map)
    │   ├── Full-screen map view (opened between levels)
    │   ├── Node icons + connecting path lines
    │   ├── Visited / Current / Available / Locked states
    │   └── Player position markers
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
    ├── [NEW] Rarity Reveal Overlay
    │   ├── Triggered on item pickup confirmation
    │   ├── Full-screen dim + item center-stage
    │   ├── Light burst animation (White / Blue / Gold by rarity)
    │   └── Item stat card slide-in
    ├── [NEW] Map Node Legend Panel (shown on map screen)
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
| Contested Item Pick | `D20 + floor(LCK/5)` per player (reroll on tie) |

### Resource Stats

| Resource | Character | Formula |
|----------|-----------|---------|
| Energy Charge | Fighter (P1) | `5 + item bonuses + Spell Slot conversions` |
| Spell Slot Lv.1 | Wizard (P2) | `2 + floor(ATT/5) + Energy Charge conversions` |
| Spell Slot Lv.2 | Wizard (P2) | `2 + floor(ATT/10)` |
| Spell Slot Lv.3 | Wizard (P2) | `1 + floor(ATT/15)` |
| Spell Slot Lv.4 | Wizard (P2) | Unlocked via items only |
| Tiles (Movement) | Both | `6 + floor(MOV/5)` |
| Action Point | Both | `1 + floor(DEX/10)` |
| Bonus Action Point | Both | `1 + floor(INT/10)` |

### Mana Cross-Conversion Table

| Item Type | Fighter (P1) Effect | Wizard (P2) Effect |
|-----------|--------------------|--------------------|
| Spell Slot Lv.1 item | +1 Energy Charge cap | +1 Spell Slot Lv.1 cap |
| Spell Slot Lv.2 item | +2 Energy Charge cap | +1 Spell Slot Lv.2 cap |
| Spell Slot Lv.3 item | +3 Energy Charge cap | +1 Spell Slot Lv.3 cap |
| Spell Slot Lv.4 item | +4 Energy Charge cap | +1 Spell Slot Lv.4 cap |
| Energy Charge item | +1 Energy Charge cap | +1 Spell Slot Lv.1 cap |

> **UI Rule:** HUD blinks/pulses the resource bar for 1.5 seconds whenever a cross-conversion item is applied, to clearly communicate the translation to both players.

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
| LCK (Luck) | +Contested Pick Roll | 5 LCK → +1 Roll |

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

> Players have one main class but can acquire items/buffs from other classes (roguelite cross-class pickup).

---

## 4. Combat System

### Action Economy (Per Turn)

| Resource | Icon | Base | Can Increase? |
|----------|------|------|---------------|
| Action Point | 🟢 | 1 | Yes (items/skills/DEX) |
| Bonus Action Point | 🟡 | 1 | Yes (items/skills/INT) |
| Energy Charge (P1) | 🔥 | 5 | Yes (items/ATT conversions) |
| Spell Slot Lv1–Lv4 (P2) | 🔵 | 2/2/1/— | Yes (items/skills/ATT) |
| Movement | ⬆️ | 6 Tiles | Yes (items/skills/MOV) |

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
[Player Phase] — P1 & P2 act simultaneously (concurrent)
    │
    ├─ Each player independently: Choose Skill → Target → Confirm
    ├─ Concurrent Conflict: if both target same entity simultaneously
    │       └─ Sequential Resolver: P1 resolves first, then P2 (or by initiative)
    ├─ Roll D20 + ACC modifier → vs. target Armor/Resist (Hit or Miss)
    │       ├─ HIT  → Roll damage/heal dice → Apply result
    │       └─ MISS → No damage (or halved heal if spell)
    │
    ├─ If both players press End Turn
    ↓
[Enemy Phase] — Enemies act SEQUENTIALLY (one at a time)
    │
    ├─ Enemy 1 acts → wait 0.5s → Enemy 2 acts → wait 0.5s → ...
    └─ All enemies done → back to Player Phase
    ↓
All enemies dead?
    ├─ No  → Back to Player Phase
    └─ Yes → NEXT LEVEL (show map → player picks next node)
```

### Ability Architecture (Godot 4 — Custom Resource Pattern)

```gdscript
# BaseAbility.gd
class_name BaseAbility
extends Resource

@export var ability_name    : String = ""
@export var ability_tag     : String = ""
@export var damage_dice     : String = "1D6"  # parsed by DiceRoller
@export var range_type      : String = "adjacent"
@export var range_size      : int    = 1
@export var is_projectile   : bool   = false
@export var element_tag     : String = "physical"
@export var cost_action     : int    = 1
@export var cost_bonus_action : int  = 0
@export var cost_mana       : int    = 0  # Energy Charge OR Spell Slot level
@export var status_effect   : String = ""
@export var knockback_tiles : int    = 0

signal ability_executed(caster: Node, targets: Array, result: Dictionary)

# Virtual — override in each .tres resource's attached script
func execute(caster: Node, targets: Array) -> void:
    pass

# Called by execute() after resolution
func _emit_result(caster: Node, targets: Array, result: Dictionary) -> void:
    emit_signal("ability_executed", caster, targets, result)
    # Listeners: KnockbackResolver, StatusEffectSystem, ProjectileSystem
```

> Each skill is a `.tres` file. Example: `cleave.tres` has `damage_dice = "1D8"`, `range_type = "aoe"`, `cost_action = 1`, `cost_mana = 2`.  
> No code needed per skill — just set export variables in the Godot Inspector.

---

## 5. Elemental Synergy

### Physical Status Effects

| Status | Effect | Trigger | Particle |
|--------|--------|---------|---------|
| Bleeding | Damage Over Time (DoT) | Physical attacks | 🔴 Red drip particles |
| Stun | Delay enemy turn for 1 round | Physical attacks | ⭐ Yellow orbiting stars |
| Lacerate | Movement Reduction | Physical attacks | 🟣 Purple flickering slashes |
| Weakened | Armor Reduction | Physical attacks | ⚫ Grey armor fragments |
| Vulnerable | Damage Increase [+] | Physical attacks | 🔴 Red pulsing aura |

### Elements

Four base magical elements: **FIRE**, **EARTH**, **WATER**, **AIR**  
Plus **True (Physical)** as the fifth damage type.

### Elemental Combo Status Effects

| Combo | Result | Effect | Particle |
|-------|--------|--------|---------|
| Fire + Earth | **Magma** | Damage Over Time (DoT) | 🟠 Orange+red ember burst |
| Earth + Water | **Mud** | Movement Reduction | 🟤 Brown thick drip particles |
| Water + Fire | **Vapor** | Damage Increase [+20%] | ⬜ Steam wisps upward |
| Air + Water | **Mist** | Enemy Accuracy Decrease [−] | ⬜ White fog cloud |
| Air + Earth | **Erosion** | Armor Reduction | 🟤 Swirling dust particles |
| Fire + Air | **Conflagration** | Spread Damage to Nearby | 🔥 Wide flame spread particles |

> **Logic:** If enemy has status *Burn* (Fire), a Water attack triggers Vapor → adds +20% damage.

---

## 6. Item Rarity System

### Rarity Tiers & Rules

| Rarity | Color | What It Can Modify | Notes |
|--------|-------|--------------------|-------|
| **Common** | ⬜ White | Stat modifiers ONLY | e.g. +5 STR, +3 VIT, +2 ACC |
| **Rare** | 🔵 Blue | Stat modifiers + Resource modifiers | e.g. +5 STR + +1 Energy Charge cap |
| **Legendary** | 🟡 Gold | Stat modifiers + Resource modifiers (enhanced) + Special passive | e.g. +10 STR + +3 Charge + unique passive effect |

### Rarity Dependency Rule

- **Common** items do NOT modify AP, BAP, Spell Slots, Energy Charge, or Movement Tiles.
- **Rare** items CAN modify one resource type in addition to stats (moderate values).
- **Legendary** items CAN modify multiple resources with higher values AND include a unique passive ability not available on lower tiers.

### Rarity Reveal Animation

Triggered when a player selects/receives an item:

1. **Screen dims** (overlay 60% opacity, 0.3s fade-in)
2. **Item silhouette** moves to center stage
3. **Light burst** fires:
   - Common → White burst (0.4s)
   - Rare → Blue burst + blue sparkles (0.6s)
   - Legendary → Gold burst + gold particle shower + screen shake (1.0s)
4. **Item stat card** slides in from below showing full stats
5. Dismiss with confirm input

### Cursed Items (Lose State from Luck Event)

| Property | Value |
|----------|-------|
| Visual | Dark purple border / skull icon |
| Effect | Negative stat modifier OR passive debuff |
| Can Discard? | ❌ NO — locked until Rest node |
| Removal Method | At Rest: sacrifice one of Option A/B's healing to remove the curse |
| Particle | 🟣 Dark purple miasma wisps permanently around entity |

---

## 7. Procedural Map Generation

### Map Structure

The map is generated fresh every run using a seeded RNG.

```
[START]
  Row 1: ○──○──○        (2–4 nodes per row, branching paths)
          └──○
  Row 2: ○──○           (always at least 2 path options visible)
          └──○──○
  ...
  Row N: ★              (Boss — always single forced node)
```

### Node Type Distribution by Row

| Map Stage | Battle | Elite | Rest | Shop | Luck Event | Loot | Boss |
|-----------|--------|-------|------|------|------------|------|------|
| Early (Row 1–2) | 70% | 0% | 0% | 0% | 15% | 15% | — |
| Mid (Row 3–5) | 40% | 20% | 15% | 10% | 10% | 5% | — |
| Late (Row 6–8) | 30% | 35% | 15% | 10% | 10% | 0% | — |
| Final Row | — | — | — | — | — | — | 100% |

### Map Generation Rules

- Minimum 2 paths always visible from current position (never railroaded)
- No row can be 100% a single node type (enforced diversity)
- Rest node guaranteed at least once every 3 rows in mid/late stage
- Shop node guaranteed at least once every 4 rows

---

## 8. Level Types & Flow

| Level Type | Pick Mode | Rarity Weight | Notes |
|-----------|-----------|--------------|-------|
| **Battle (Normal)** | Individual pick | Common 70% / Rare 27% / Leg 3% | Each player picks own item |
| **Elite Battle** | Contested (rebutan) | Common 40% / Rare 45% / Leg 15% | D20+LCK tiebreak on conflict |
| **Boss Battle** | Contested (rebutan) | Common 15% / Rare 50% / Leg 35% | Highest rewards in run |
| **Loot** | Contested (rebutan) | Rare-skewed | 3–5 items on screen |
| **Luck Event** | Consensus + Roll | Win/Lose outcome pool | See Section 9 |
| **Rest** | Player choice | N/A — probability based | Treasure has hidden 70/20/10 roll |
| **Shop** | Individual purchase | Rarity resolver | 7 slots, 100 Coin reroll |

---

## 9. Level Detail: Luck Event

A narrative interactive scene where both players face a choice together.

**Example scene:** *"A giant snail is trapped under a log and wants help."*  
**Options:** a. Try to pull the log — b. Leave it

**Rules:**
- Both players must agree on the same option before the game proceeds.
- A countdown timer may force the majority/default choice on expiry.
- Luck Roll = D20 + average of floor(P1_LCK/5) + floor(P2_LCK/5)

### Luck Event Flow

```
[Luck Event - Choice Screen]
    ↓ Both players agree
[Luck Event - Roll Dice]
    → D20 + LCK modifier
    ↓
    ├─ WIN STATE  → Roll Win Outcome Pool:
    │               40% 2 random items
    │               25% Full HP restore (100%)
    │               20% 1 Legendary item
    │               10% +200 Coin each
    │                5% +2 permanent attribute both players
    │
    └─ LOSE STATE → Roll Lose Outcome Pool:
                    35% −50% HP both players
                    25% Cursed Item in inventory
                    20% Surprise Elite Battle triggered
                    15% −30% Coin from each wallet
                     5% −3 to random attribute (removable at Rest)
```

---

## 10. Level Detail: Rest (Campfire)

| Option | Effect | Notes |
|--------|--------|-------|
| a. Full Rest | +50% HP + +50% Energy Charge / Spell Slot | Can also remove 1 Cursed Item instead of healing |
| b. Partial Rest | +25% HP + +100% Energy Charge / Spell Slot | Can also remove 1 Cursed Item instead of healing |
| c. Treasure Search | Hidden probability roll (70% safe / 20% trap / 10% jackpot) | See breakdown below |

### Treasure Search Probability

| Result | Probability | Outcome |
|--------|-------------|---------|
| SUCCESS | 70% | Gain 1–2 random items (Common/Rare weighted) |
| TRAP | 20% | −30% HP to both players + 1 random Common item |
| JACKPOT | 10% | Gain 1 Legendary item (safe, no HP cost) |

> The probability roll is hidden — players experience the narrative reveal without seeing numbers. Builds tension and gambling appeal.

---

## 11. Level Detail: Shop

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

## 12. Battle UI Overview

### Split-Screen Layout

- Screen split **vertically** (P1 = Left, P2 = Right).
- Both sides render the **same shared world** — actions by one player are visible to the other.
- Isometric grid-based arena.

### Resource Bar — Fighter (P1, Left)

| Icon | Resource | Base Value | Notes |
|------|----------|------------|-------|
| 🟢 Circle | Action Point | 1 | Blinks on skill preview |
| 🟡 Triangle | Bonus Action Point | 1 | Blinks on skill preview |
| ⬆️ Arrow | Movement | 6 Tiles | — |
| 🔥 Fire | Energy Charge | 5 | Blinks on cross-conversion item pickup |
| 🎒 Bag | Inventory | — | — |

### Resource Bar — Wizard (P2, Right)

| Icon | Resource | Base Value | Notes |
|------|----------|------------|-------|
| 🎒 Bag | Inventory | — | — |
| 🟢 Circle | Action Point | 1 | Blinks on skill preview |
| 🟡 Triangle | Bonus Action Point | 1 | Blinks on skill preview |
| ⬆️ Arrow | Movement | 6 Tiles | — |
| 🔵 Box I/II/III/IV | Spell Slot Lv1–4 | 2/2/1/— | Blinks on cross-conversion item pickup |

### Target Selection

After selecting a skill:
1. White pointer cursor appears on the grid.
2. Player aims at a target (enemy or ally — Friendly Fire ON).
3. A **stat indicator** floats above the target: ❤️ HP / 🛡️ Armor.
4. **Resource bar blinks** to show what will be consumed.
5. **Status particle effects** are always visible on entities with active statuses.

---

## 13. Fighter (P1) — Action List (Detailed)

| # | Skill Name | Tag ID | Effect | Cost | Grid Area | Projectile? |
|---|-----------|--------|--------|------|-----------|-------------|
| 1 | **Main Attack** | `basic-attack-test` | [1D10] 1–10 Physical | 1 Action | 4 adjacent tiles — 🟡 | ❌ |
| 2 | **Elbow Smash** | `knockback-test` | [1D4] 1–4 Physical + Knockback 1 Tile | 1 Bonus Action | 4 adjacent tiles — 🟡 | ❌ |
| 3 | **Slash Flash** | `dash-attack-test` | [1D6] 1–6 Physical + Dash Toward Target | 1 AP + 1 BAP + 1 Charge | Straight 3 tiles × 4 dir — 🟡 | ❌ |
| 4 | **Cleave** | `aoe-attack-test` | [1D8] 1–8 Physical AoE | 1 AP + 2 Charge | 3×3 box — 🔴 | ❌ |
| 5 | **Dagger Throw** | `armor-reduct-status` | [1D4] 1–4 Physical + Weakened (−2 Armor) | 1 BAP + 1 Charge | 5×5 box — 🟡 | ✅ |
| 6 | **Rupture** | `dot-status-test` | [1D6] 1–6 Physical + Bleeding (DoT 1–4/turn) | 1 AP + 2 Charge | 3×3 box — 🟡 | ❌ |
| 7 | **Epimorphic** | `self-heal-test` | [1D8] 1–8 Heal (Self) | 1 BAP + 1 Charge | Self tile — 🟢 | ❌ |
| 8 | **Autotomy** | `self-damage-test` | −20% HP, +4 Armor (Self) | 1 AP + 2 Charge | Self tile — 🟢 | ❌ |

### Grid Area Legend

| Color | Meaning |
|-------|---------|
| 🟡 Yellow | Targeted / Directional |
| 🔴 Red | Area of Effect (AoE) |
| 🟢 Green | Self / Friendly |

---

## 14. Key Features

### 1. Split-Screen Native
- Vertical split (Left = P1, Right = P2), shared world state.
- **P1 Keys:** W A S D Q E Z X C F R LSHIFT
- **P2 Keys:** I J K L U O M , . / P RSHIFT
- Playable solo (switch between WASD ↔ IJKL) or local co-op.

### 2. Procedural Node Map (Slay the Spire Style)
- Every run generates a unique branching map using a seeded RNG.
- Players always choose their path, never railroaded.
- Map visible at all times between nodes.

### 3. Action Point Economy
Full action economy per turn (AP, Bonus AP, Energy Charge / Spell Slots, Movement).  
Fighter and Wizard have distinct mana resources that cross-convert via items.

### 4. RNG Hit/Miss & Damage System
D20 for hit resolution, separate dice for damage/heal amounts.  
Luck also determines Contested Item Pick winner and Luck Event outcomes.

### 5. Friendly Fire (Integrated into Ability System)
- Handled directly inside `BaseAbility.execute()` — no separate system.
- Can damage allies, can heal/buff enemies.
- Discourages mindless AoE spam; rewards strategic positioning.

### 6. Turn Order: Player Phase → Enemy Phase
- Both players act **simultaneously** in Player Phase.
- Enemies act **sequentially** (one at a time) in Enemy Phase — prevents chaos.

### 7. Elemental Synergy / Tag System + Particle Feedback
- 5 base elements with combo effects via status tags.
- Every active status has a corresponding particle effect for clear visual feedback.

### 8. Contested Item Pick (Co-op Tension)
- Elite/Boss/Loot nodes use a rebutan system.
- If both players want the same item → D20 + LCK roll — highest wins.
- Ties reroll until resolved. Adds party-game tension to co-op.

### 9. Modular Ability Architecture (Godot 4 Custom Resources)
- All abilities are `.tres` files extending `BaseAbility` Resource.
- No code needed per skill — configure in Inspector.
- Adding new skills = creating a new `.tres` file, no engine restart needed.

### 10. Projectile System
- Abilities marked `is_projectile = true` spawn a traveling projectile.
- Projectile checks each grid tile for occupants as it moves.
- Collision triggers damage, status, and knockback signals.

---

## 15. Programmer Task Lists

### Combat / Gameplay

- [x] Co-op turn system (P1 & P2 simultaneous Player Phase)
- [x] **Sequential Enemy Phase** (queue-based, one enemy at a time with delay)
- [ ] Grid-based movement + pathfinding (A*)
- [ ] Action queue / anti-conflict resolver (concurrent P1+P2 on same target)
- [x] Action Economy enforcement (AP, Bonus AP, Energy Charge / Spell Slots, Movement)
- [x] D20 RNG hit/miss system vs. Armor/Resist thresholds
- [x] Damage/heal dice system (separate roll post hit-check)
- [ ] **BaseAbility Custom Resource** system (class_name, @export vars, execute(), signal)
- [ ] **Projectile System** (spawner, tile-by-tile mover, grid collision detector, pool)
- [ ] **Knockback via Signal** (Knockback Resolver listens to `ability_executed` signal)
- [ ] Elemental synergy & status tag system
- [ ] **Status Particle Effect** system (per-status particle emitters on entities)
- [ ] Environmental interaction (knockback into walls → bonus damage)
- [ ] Revive mechanic (downed player → ally stands adjacent + spends Action → 20% HP)
- [ ] Enemy AI (targets lowest HP + nearest player)
- [ ] **Contested Pick System** (D20 + LCK tiebreak on simultaneous item selection)
- [ ] **Cursed Item** handler (locked until Rest, visual/stat debuff)
- [x] **Mana Cross-Conversion** (Spell Slot item → Energy Charge for Fighter, vice versa)

### Roguelite / Meta

- [ ] **Procedural Node Map Generator** (graph builder, path connectivity validator, seed)
- [ ] Map UI Renderer (node icons, path lines, player position, visited/locked states)
- [ ] **Luck Event Win/Lose Outcome Pools** (weighted random, multiple possible outcomes)
- [ ] **Treasure Search probability** (70/20/10 hidden roll at Rest node)
- [ ] **Rarity Reveal Animation** (White/Blue/Gold light burst on item pickup)
- [ ] **Item Rarity Dependency** enforcement (Common = stat only, Rare = stat+resource, etc.)
- [ ] **Item Rarity Weight** per node type (Normal/Elite/Boss/Loot pools)

### UI / Narrative

- [ ] Vertical split-screen rendering (shared world, independent cameras)
- [ ] Radial (circular) action/skill menu
- [ ] D20 dice roll animation on-screen
- [ ] Floating combat text (damage numbers, "MISS!", element icons)
- [ ] Clean HUD — coordinate with Illustrator team
- [ ] **HUD Blink Indicator** for resource bar (on skill preview AND on cross-conversion)
- [ ] **Status Icon Bar** above entities (lists active status tags with icons)
- [ ] **Map UI** (full-screen map between nodes, current position, path options)
- [ ] Dialogue system integration (Dialogue Manager 3 + Dynamic Vocalion)

---

## 16. Open Questions & Design Notes

> Use this section to track unresolved design decisions.

| # | Question | Status |
|---|---------|--------|
| 1 | Wizard (P2) full skill set / ability list — needs detailing (equivalent to Fighter list) | 🔴 TODO |
| 2 | Loot minigame mechanic — what is the minigame exactly? | 🔴 TODO |
| 3 | How many rows / nodes does a full run have? (Estimated 8–10 rows) | 🟡 TBD |
| 4 | Enemy roster — how many enemy types for Battle vs Elite vs Boss? | 🔴 TODO |
| 5 | Item pool — total item count per rarity tier (needed before Item Registry implementation) | 🔴 TODO |
| 6 | Cursed Item pool — what specific cursed items exist? | 🔴 TODO |
| 7 | Boss Battle — does the boss have unique mechanics (phases, special abilities)? | 🔴 TODO |
| 8 | Does the Contested Pick (rebutan) apply in Shop as well, or is Shop always individual? | 🟡 TBD |
| 9 | Luck Event narratives — how many unique scenes are planned for v1? | 🔴 TODO |
| 10 | Solo mode: when playing alone, does P2's character become AI-controlled? | 🟡 TBD |

---

*Last Updated: May 2026 — v2.0 — Integrated 15 architecture improvements + Lead Programmer review*
