# Implementation Plan: Roguelite Run System (Ilham)

This document outlines the tasks and implementation plan for Ilham, focusing on the Roguelite Run System, Item System, and Shop.

## 🗺️ Node Graph System
*Core structural generation for the run.*

- [x] **Procedural Node Graph Generator** (Critical) `[Ref #1]`
  - *Details*: Slay the Spire-style path generation.
- [x] **Node Type Pool** (Critical) `[Ref #1]`
  - *Details*: Implement types: Battle, Elite, Boss, Event, Rest, Shop, Loot.
  - *Depends On*: Node Graph Generator
- [x] **Path Branching Handler & Depth Layer Manager** (High) `[Ref #1]`
  - *Depends On*: Node Graph Generator
- [x] **Forced Boss Node & Unlock Resolver** (High) `[Ref #1]`
  - *Details*: Final layer forced boss node and resolving node unlock logic.
  - *Depends On*: Branching Handler

## ⚔️ Level Events System
*Handlers for various node type interactions and outcomes.*

- [ ] **Win State Handler** (High) `[Ref #2]`
  - *Details*: Handle winning (2 items / Full HP / extendable pool).
  - *Depends On*: Item System
- [ ] **Lose State Handler** (High) `[Ref #3]`
  - *Details*: Handle losing (−50% HP / Cursed Item / Elite Battle).
  - *Depends On*: Item System, Combat (Tapip)
- [ ] **Level: Luck Event** (High)
  - *Details*: Narrative + Consensus + D20 Roll.
  - *Depends On*: RNG System (Tapip)
- [ ] **Level: Loot** (Medium) `[Ref #5]`
  - *Details*: Shared pool + Minigame (TBD).
  - *Depends On*: Item System
- [ ] **Level: Rest** (Medium) `[Ref #6]`
  - *Details*: Full/Partial/Treasure options.
  - *Depends On*: HP/Health Manager (Candra)

## 🎒 Item System
*Core item structures, effects, and inventory management.*

- [ ] **Item Registry** (Critical) `[Ref #10]`
  - *Details*: Common/Rare/Legendary structure.
  - *Depends On*: Stat System (Candra)
- [ ] **Item Effect Applier** (Critical) `[Ref #10]`
  - *Details*: Stat/Resource/Cross-class modifiers.
  - *Depends On*: Item Registry, Action Economy (Tapip)
- [ ] **Inventory Manager** (High)
  - *Details*: Per player inventory.
  - *Depends On*: Item Effect Applier
- [ ] **Item Pool Generator** (High) `[Ref #4]`
  - *Details*: Generator per battle type (Normal/Elite/Boss).
  - *Depends On*: Item Registry
- [ ] **Rarity Reveal Handler** (Medium) `[Ref #4]`
  - *Details*: White/Blue/Gold glow — after pick.
  - *Depends On*: UI — Rarity FX (Rapit)
- [ ] **Cursed Item Handler** (Medium)
  - *Details*: Apply negative passives.
  - *Depends On*: Item Effect Applier

## 💰 Shop System
*Economy and item purchasing.*

- [ ] **Stock Manager** (Medium)
  - *Details*: 7 slots, Rarity Resolver, Reroll (100 coins).
  - *Depends On*: Item Registry
- [ ] **Coin Economy** (Medium)
  - *Details*: Wallet, Send 1/2, Send 1/4 options.

---
**Note:** Check dependencies before starting a task to ensure required systems from other programmers are ready or can be mocked during development.
