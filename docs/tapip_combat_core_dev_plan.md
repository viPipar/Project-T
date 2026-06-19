# 🗡️ Combat Core — Development Plan
> **Programmer:** Tapip | **Role:** Combat Core  
> **Project:** Gemshied (Godot 4 / GDScript)  
> **Last Updated:** May 2026  
> **Prinsip:** Setiap fase bisa dikerjakan **tanpa bergantung pada progress teman**

---

## 📌 Overview Tugas Tapip

| Sistem | Task | Priority |
|--------|------|----------|
| Turn Base System | Player Phase Manager (Concurrent) | 🔴 Critical |
| Turn Base System | Enemy Phase Manager (Sequential) | 🔴 Critical |
| Turn Base System | Phase Transition Handler | 🟠 High |
| Action Economy | Action Point & Bonus AP Manager | 🔴 Critical |
| Action Economy | Energy Charge Manager — Fighter (P1) | 🔴 Critical |
| Action Economy | Spell Slot Manager Lv1–4 — Wizard (P2) | 🔴 Critical |
| Action Economy | Mana Equivalence Converter | 🟡 Medium |
| Action Economy | Movement Point Manager | 🟠 High |
| RNG System | Damage/Heal Dice Roller (D4–D20, multi-dice) | 🔴 Critical |
| RNG System | Hit/Miss Resolver (D20 + ACC/2 vs Armor) | 🔴 Critical |
| RNG System | Critical Hit Resolver | 🟠 High |
| RNG System | Luck Event Roller (D20 + LCK/5) | 🟡 Medium |

---

## 🧩 Strategi Modular — Cara Kerja Mandiri

Masalah utama: beberapa task Tapip **secara teknis** butuh output dari Candra (Stat System) dan Gilang (SignalBus). Solusinya:

```
┌─────────────────────────────────────────────────────────┐
│  PRINSIP ISOLASI                                        │
│                                                         │
│  1. Buat MOCK/STUB untuk semua dependency eksternal     │
│  2. Coding semua logic berdasarkan interface/kontrak    │
│  3. Saat Candra/Gilang selesai → tinggal swap stub-nya  │
└─────────────────────────────────────────────────────────┘
```

**Mock yang perlu dibuat:**
- `MockStatProvider.gd` → menyimulasikan output Candra (Armor, Resist, ACC, LCK, dll.)
- `MockSignalBus.gd` → stub SignalBus Gilang, cukup untuk test RNG Resolver
- `MockEntity.gd` → dummy entity untuk test Phase Manager

---

## 🗺️ Peta Dependensi Internal Tapip

```
[Phase 0 — Setup & Mock]
        ↓
[Phase 1 — RNG Foundation]   ← TIDAK ADA DEPENDENCY
  DiceRoller, LuckRoller
        ↓
[Phase 2 — Action Economy]   ← TIDAK ADA DEPENDENCY
  AP/BAP, MovementPoint
  EnergyCharge, SpellSlot
  ManaConverter
        ↓
[Phase 3 — Turn Base System] ← Butuh Action Economy (sudah jadi di Phase 2)
  PlayerPhaseManager
  EnemyPhaseManager
  PhaseTransitionHandler
        ↓
[Phase 4 — RNG Combat]       ← Butuh DiceRoller (Phase 1) + MockStatProvider
  HitMissResolver
  CritResolver
        ↓
[Phase 5 — Integrasi]        ← Swap mock → sistem nyata dari teman
  Ganti MockStatProvider → Candra's StatSystem
  Ganti MockSignalBus → Gilang's SignalBus
```

---

## 📁 Struktur Folder yang Direkomendasikan

```
combat_core/
├── _mock/
│   ├── MockStatProvider.gd
│   ├── MockSignalBus.gd
│   └── MockEntity.gd
│
├── rng/
│   ├── DiceRoller.gd
│   ├── HitMissResolver.gd
│   ├── CritResolver.gd
│   └── LuckRoller.gd
│
├── action_economy/
│   ├── ActionPointManager.gd
│   ├── MovementPointManager.gd
│   ├── EnergyChargeManager.gd
│   ├── SpellSlotManager.gd
│   └── ManaConverter.gd
│
├── turn_base/
│   ├── PlayerPhaseManager.gd
│   ├── EnemyPhaseManager.gd
│   └── PhaseTransitionHandler.gd
│
└── tests/
    ├── test_dice_roller.gd
    ├── test_action_economy.gd
    └── test_phase_manager.gd
```

---

---

# 🔵 PHASE 0 — Project Setup & Mock Layer
> **Estimasi:** 0.5–1 hari | **Dependency:** Tidak ada

Ini adalah fondasi agar kamu bisa kerja mandiri. Buat semua stub/mock sebelum mulai coding sistem nyata.

---

### 0.1 — MockStatProvider

File: `_mock/MockStatProvider.gd`

Tujuan: mensimulasikan data yang nanti akan datang dari **Candra's Stat System**.  
Saat Candra selesai, tinggal ganti referensi dari `MockStatProvider` ke `StatSystem` milik Candra.

```gdscript
# _mock/MockStatProvider.gd
# Stub untuk Candra's Stat System
# Swap ini dengan StatSystem.gd milik Candra saat sudah selesai
class_name MockStatProvider
extends Node

# Kembalikan nilai statis untuk testing
func get_armor(entity: Node) -> int:
    return 12  # default test value

func get_resist(entity: Node) -> int:
    return 8

func get_acc(entity: Node) -> int:
    return 10

func get_lck(entity: Node) -> int:
    return 5

func get_mov(entity: Node) -> int:
    return 6

func get_att(entity: Node) -> int:
    return 10

func get_dex(entity: Node) -> int:
    return 8

func get_int(entity: Node) -> int:
    return 10
```

---

### 0.2 — MockSignalBus

File: `_mock/MockSignalBus.gd`

Tujuan: stub untuk SignalBus yang akan dibuat oleh **Gilang**.

```gdscript
# _mock/MockSignalBus.gd
# Stub untuk Gilang's SignalBus autoload
# Swap dengan SignalBus.gd milik Gilang saat sudah selesai
class_name MockSignalBus
extends Node

signal on_hit(attacker, target, result)
signal on_miss(attacker, target)
signal on_knockback(entity, direction, tiles)
signal on_status(entity, status_name)

# Utility: emit dummy hit untuk testing
func debug_emit_hit(attacker, target, dmg: int):
    emit_signal("on_hit", attacker, target, {"damage": dmg})
```

---

### 0.3 — MockEntity

File: `_mock/MockEntity.gd`

Tujuan: dummy karakter/musuh untuk test Phase Manager dan RNG.

```gdscript
# _mock/MockEntity.gd
class_name MockEntity
extends Node

@export var entity_name: String = "DummyEntity"
@export var is_player: bool = false
@export var is_alive: bool = true
var current_hp: int = 50
var max_hp: int = 50

func take_damage(amount: int) -> void:
    current_hp -= amount
    if current_hp <= 0:
        is_alive = false

func is_dead() -> bool:
    return !is_alive
```

---

---

# 🎲 PHASE 1 — RNG Foundation
> **Estimasi:** 1–2 hari | **Dependency:** Tidak ada (fully standalone)

Mulai dari sini karena **tidak ada dependency sama sekali**. Ini juga yang paling sering dibutuhkan untuk test sistem lain nanti.

---

### 1.1 — DiceRoller

File: `rng/DiceRoller.gd`  
Ref: Task `#RNG — Damage/Heal Dice Roller`

Sistem ini harus mendukung:
- Single dice: `D4`, `D6`, `D8`, `D10`, `D12`, `D20`
- Multi-dice: `2D6`, `3D6`, `4D6`
- String-based parsing: input `"2D6"` → roll 2 buah D6 → jumlahkan

```gdscript
# rng/DiceRoller.gd
class_name DiceRoller
extends Node

# Roll satu dice: roll_dice(20) → 1..20
func roll_dice(sides: int) -> int:
    return randi_range(1, sides)

# Roll dari string: roll_from_string("2D6") → 2..12
func roll_from_string(dice_str: String) -> int:
    var parts = dice_str.to_upper().split("D")
    if parts.size() != 2:
        push_error("Invalid dice string: " + dice_str)
        return 0

    var count = int(parts[0])
    var sides = int(parts[1])
    var total = 0

    for i in range(count):
        total += roll_dice(sides)
    return total

# Shorthand: d20() → langsung roll D20
func d20() -> int:
    return roll_dice(20)

func d10() -> int:
    return roll_dice(10)

func d6() -> int:
    return roll_dice(6)

func d4() -> int:
    return roll_dice(4)
```

**Test cepat:**
```gdscript
# Dalam test scene atau @tool script
var roller = DiceRoller.new()
print(roller.roll_from_string("2D6"))   # output: 2–12
print(roller.roll_from_string("1D20"))  # output: 1–20
print(roller.d4())                      # output: 1–4
```

---

### 1.2 — LuckRoller

File: `rng/LuckRoller.gd`  
Ref: Task `#RNG — Luck Event Roller`

Formula: `D20 + floor(LCK / 5)`

```gdscript
# rng/LuckRoller.gd
class_name LuckRoller
extends Node

var dice_roller: DiceRoller

func _ready():
    dice_roller = DiceRoller.new()

# Roll luck untuk satu entity
func roll_luck(lck_stat: int) -> int:
    var roll = dice_roller.d20()
    var modifier = floori(lck_stat / 5.0)
    return roll + modifier

# Roll luck untuk dua pemain (rata-rata LCK) — untuk Luck Event
func roll_luck_coop(p1_lck: int, p2_lck: int) -> int:
    var avg_lck = floori((p1_lck + p2_lck) / 2.0)
    return roll_luck(avg_lck)

# Contested Pick: D20 + LCK/5 per player → kembalikan siapa yang menang
# Return: 1 (P1 menang), 2 (P2 menang)
# Reroll otomatis jika tie (sesuai GDD)
func roll_contested_pick(p1_lck: int, p2_lck: int) -> int:
    var p1_roll: int
    var p2_roll: int
    while true:
        p1_roll = roll_luck(p1_lck)
        p2_roll = roll_luck(p2_lck)
        if p1_roll != p2_roll:
            break
    return 1 if p1_roll > p2_roll else 2
```

---

---

# ⚡ PHASE 2 — Action Economy
> **Estimasi:** 2–3 hari | **Dependency:** Tidak ada (dapat dimulai setelah Phase 0)

Ini adalah inti dari "milik" Tapip. Semua resource (AP, Energy, Spell Slot, Movement) dikelola di sini. Tim lain (Rapit, Ilham) bergantung pada sistem ini, jadi selesaikan ini secepatnya.

---

### 2.1 — ActionPointManager

File: `action_economy/ActionPointManager.gd`  
Ref: Task `#Action Economy — Action Point & Bonus AP Manager`

Formula dari GDD:
- `AP base = 1 + floor(DEX / 10)`
- `BAP base = 1 + floor(INT / 10)`

```gdscript
# action_economy/ActionPointManager.gd
class_name ActionPointManager
extends Node

signal ap_changed(current_ap: int, max_ap: int)
signal bap_changed(current_bap: int, max_bap: int)

var max_ap: int = 1
var current_ap: int = 1
var max_bap: int = 1
var current_bap: int = 1

# Inisialisasi dari stat (DEX, INT)
func setup(dex: int, int_stat: int) -> void:
    max_ap = 1 + floori(dex / 10.0)
    max_bap = 1 + floori(int_stat / 10.0)
    reset()

# Tambah bonus AP dari item
func add_ap_bonus(amount: int) -> void:
    max_ap += amount
    current_ap += amount
    emit_signal("ap_changed", current_ap, max_ap)

func add_bap_bonus(amount: int) -> void:
    max_bap += amount
    current_bap += amount
    emit_signal("bap_changed", current_bap, max_bap)

# Coba pakai AP — return true jika berhasil
func spend_ap(amount: int = 1) -> bool:
    if current_ap >= amount:
        current_ap -= amount
        emit_signal("ap_changed", current_ap, max_ap)
        return true
    return false

func spend_bap(amount: int = 1) -> bool:
    if current_bap >= amount:
        current_bap -= amount
        emit_signal("bap_changed", current_bap, max_bap)
        return true
    return false

# Validasi tanpa memakainya (untuk preview di HUD)
func can_spend_ap(amount: int = 1) -> bool:
    return current_ap >= amount

func can_spend_bap(amount: int = 1) -> bool:
    return current_bap >= amount

# Reset di awal giliran
func reset() -> void:
    current_ap = max_ap
    current_bap = max_bap
    emit_signal("ap_changed", current_ap, max_ap)
    emit_signal("bap_changed", current_bap, max_bap)
```

---

### 2.2 — MovementPointManager

File: `action_economy/MovementPointManager.gd`  
Ref: Task `#Action Economy — Movement Point Manager`

Formula: `Movement = 6 + floor(MOV / 5)`

```gdscript
# action_economy/MovementPointManager.gd
class_name MovementPointManager
extends Node

signal movement_changed(current: int, max_tiles: int)

var max_tiles: int = 6
var current_tiles: int = 6

func setup(mov_stat: int) -> void:
    max_tiles = 6 + floori(mov_stat / 5.0)
    current_tiles = max_tiles
    emit_signal("movement_changed", current_tiles, max_tiles)

func add_movement_bonus(amount: int) -> void:
    max_tiles += amount
    current_tiles += amount
    emit_signal("movement_changed", current_tiles, max_tiles)

func spend_movement(tiles: int) -> bool:
    if current_tiles >= tiles:
        current_tiles -= tiles
        emit_signal("movement_changed", current_tiles, max_tiles)
        return true
    return false

func can_move(tiles: int) -> bool:
    return current_tiles >= tiles

func reset() -> void:
    current_tiles = max_tiles
    emit_signal("movement_changed", current_tiles, max_tiles)
```

---

### 2.3 — EnergyChargeManager (Fighter P1)

File: `action_economy/EnergyChargeManager.gd`  
Ref: Task `#Action Economy — Energy Charge Manager (Fighter)`

Formula:
- `Base Charges = 5`
- `Max Charges = 5 + item bonuses + Spell Slot conversions`

```gdscript
# action_economy/EnergyChargeManager.gd
class_name EnergyChargeManager
extends Node

signal charge_changed(current: int, max_charges: int)

const BASE_CHARGES = 5
var max_charges: int = BASE_CHARGES
var current_charges: int = BASE_CHARGES

func setup() -> void:
    max_charges = BASE_CHARGES
    current_charges = max_charges

# Digunakan oleh Item Effect Applier (Ilham) saat item diequip
func add_charge_cap(amount: int) -> void:
    max_charges += amount
    emit_signal("charge_changed", current_charges, max_charges)

# Konversi dari Spell Slot item (ManaConverter akan panggil ini)
# Slot Lv.1 item = +1 Charge cap, Lv.2 = +2, dst.
func add_charge_from_slot_item(slot_level: int) -> void:
    add_charge_cap(slot_level)  # level == jumlah charge yang ditambah

func spend_charge(amount: int = 1) -> bool:
    if current_charges >= amount:
        current_charges -= amount
        emit_signal("charge_changed", current_charges, max_charges)
        return true
    return false

func can_spend(amount: int = 1) -> bool:
    return current_charges >= amount

func restore_charges(amount: int) -> void:
    current_charges = min(current_charges + amount, max_charges)
    emit_signal("charge_changed", current_charges, max_charges)

# Restore parsial (untuk Rest node)
func restore_percent(percent: float) -> void:
    var restore_amount = int(max_charges * percent)
    restore_charges(restore_amount)

func reset_full() -> void:
    current_charges = max_charges
    emit_signal("charge_changed", current_charges, max_charges)
```

---

### 2.4 — SpellSlotManager (Wizard P2)

File: `action_economy/SpellSlotManager.gd`  
Ref: Task `#Action Economy — Spell Slot Manager Lv1–4 (Wizard)`

Formula dari GDD:
- `Slot Lv.1 = 2 + floor(ATT / 5)`
- `Slot Lv.2 = 2 + floor(ATT / 10)`
- `Slot Lv.3 = 1 + floor(ATT / 15)`
- `Slot Lv.4 = 0 (item only)`

```gdscript
# action_economy/SpellSlotManager.gd
class_name SpellSlotManager
extends Node

signal slots_changed(level: int, current: int, max_slots: int)

# max_slots[0] = Lv1, [1] = Lv2, [2] = Lv3, [3] = Lv4
var max_slots: Array[int] = [2, 2, 1, 0]
var current_slots: Array[int] = [2, 2, 1, 0]

func setup(att_stat: int) -> void:
    max_slots[0] = 2 + floori(att_stat / 5.0)
    max_slots[1] = 2 + floori(att_stat / 10.0)
    max_slots[2] = 1 + floori(att_stat / 15.0)
    max_slots[3] = 0  # hanya dari item
    reset_all()

# Tambah slot dari item (Ilham/ManaConverter akan panggil ini)
func add_slot_cap(level: int, amount: int = 1) -> void:
    assert(level >= 1 and level <= 4, "Slot level must be 1–4")
    max_slots[level - 1] += amount
    emit_signal("slots_changed", level, current_slots[level - 1], max_slots[level - 1])

# Konversi dari Energy Charge item (Wizard mendapat Lv.1 slot)
func add_slot_from_charge_item() -> void:
    add_slot_cap(1)

func spend_slot(level: int, amount: int = 1) -> bool:
    assert(level >= 1 and level <= 4, "Slot level must be 1–4")
    var idx = level - 1
    if current_slots[idx] >= amount:
        current_slots[idx] -= amount
        emit_signal("slots_changed", level, current_slots[idx], max_slots[idx])
        return true
    return false

func can_spend(level: int, amount: int = 1) -> bool:
    if level < 1 or level > 4:
        return false
    return current_slots[level - 1] >= amount

func restore_slots(level: int, amount: int) -> void:
    var idx = level - 1
    current_slots[idx] = min(current_slots[idx] + amount, max_slots[idx])
    emit_signal("slots_changed", level, current_slots[idx], max_slots[idx])

func restore_percent(percent: float) -> void:
    for i in range(4):
        var restore = int(max_slots[i] * percent)
        current_slots[i] = min(current_slots[i] + restore, max_slots[i])
        emit_signal("slots_changed", i + 1, current_slots[i], max_slots[i])

func reset_all() -> void:
    for i in range(4):
        current_slots[i] = max_slots[i]
        emit_signal("slots_changed", i + 1, current_slots[i], max_slots[i])
```

---

### 2.5 — ManaConverter

File: `action_economy/ManaConverter.gd`  
Ref: Task `#Action Economy — Mana Equivalence Converter`

Tabel konversi dari GDD:

| Item Type | Fighter (P1) | Wizard (P2) |
|-----------|-------------|------------|
| Spell Slot Lv.1 item | +1 Charge cap | +1 Slot Lv.1 cap |
| Spell Slot Lv.2 item | +2 Charge cap | +1 Slot Lv.2 cap |
| Energy Charge item | +1 Charge cap | +1 Slot Lv.1 cap |

```gdscript
# action_economy/ManaConverter.gd
class_name ManaConverter
extends Node

# Referensi ke manager masing-masing karakter
# Diisi saat setup di game scene
var fighter_charge_mgr: EnergyChargeManager
var wizard_slot_mgr: SpellSlotManager

func setup(charge_mgr: EnergyChargeManager, slot_mgr: SpellSlotManager) -> void:
    fighter_charge_mgr = charge_mgr
    wizard_slot_mgr = slot_mgr

# Dipanggil oleh Item Effect Applier (Ilham) saat item diequip
# item_type: "slot_lv1" | "slot_lv2" | "slot_lv3" | "slot_lv4" | "energy_charge"
# target_class: "fighter" | "wizard"
func apply_mana_item(item_type: String, target_class: String) -> void:
    match target_class:
        "fighter":
            _apply_to_fighter(item_type)
        "wizard":
            _apply_to_wizard(item_type)

func _apply_to_fighter(item_type: String) -> void:
    match item_type:
        "slot_lv1":
            fighter_charge_mgr.add_charge_cap(1)
        "slot_lv2":
            fighter_charge_mgr.add_charge_cap(2)
        "slot_lv3":
            fighter_charge_mgr.add_charge_cap(3)
        "slot_lv4":
            fighter_charge_mgr.add_charge_cap(4)
        "energy_charge":
            fighter_charge_mgr.add_charge_cap(1)

func _apply_to_wizard(item_type: String) -> void:
    match item_type:
        "slot_lv1":
            wizard_slot_mgr.add_slot_cap(1)
        "slot_lv2":
            wizard_slot_mgr.add_slot_cap(2)
        "slot_lv3":
            wizard_slot_mgr.add_slot_cap(3)
        "slot_lv4":
            wizard_slot_mgr.add_slot_cap(4)
        "energy_charge":
            wizard_slot_mgr.add_slot_from_charge_item()
```

---

---

# ⚔️ PHASE 3 — Turn Base System
> **Estimasi:** 3–4 hari | **Dependency:** Phase 2 (Action Economy) + MockEntity

Ini adalah sistem terbesar Tapip. Bangun setelah Phase 2 selesai, gunakan MockEntity untuk test tanpa butuh teman.

---

### 3.1 — PlayerPhaseManager

File: `turn_base/PlayerPhaseManager.gd`  
Ref: Task `#8 — Player Phase Manager (concurrent P1+P2)`

Logika: P1 dan P2 bertindak **bersamaan**. Jika keduanya menargetkan entity yang sama secara simultan, gunakan Sequential Resolver (P1 dulu, lalu P2).

```gdscript
# turn_base/PlayerPhaseManager.gd
class_name PlayerPhaseManager
extends Node

signal phase_started()
signal player_confirmed_end_turn(player_id: int)
signal both_players_confirmed()    # diterima oleh PhaseTransitionHandler
signal conflict_detected(p1_action: Dictionary, p2_action: Dictionary)

var p1_confirmed_end: bool = false
var p2_confirmed_end: bool = false

# Action yang sedang diantri
var p1_pending_action: Dictionary = {}
var p2_pending_action: Dictionary = {}

func start_phase() -> void:
    p1_confirmed_end = false
    p2_confirmed_end = false
    p1_pending_action = {}
    p2_pending_action = {}
    emit_signal("phase_started")

# Dipanggil oleh Input Manager (Rapit) saat player konfirmasi skill+target
func submit_action(player_id: int, action: Dictionary) -> void:
    # action = { "ability": BaseAbility, "targets": [Node], "caster": Node }
    if player_id == 1:
        p1_pending_action = action
    else:
        p2_pending_action = action

    _check_conflict_and_resolve()

func _check_conflict_and_resolve() -> void:
    if p1_pending_action.is_empty() or p2_pending_action.is_empty():
        return  # Belum ada keduanya, tunggu dulu

    var p1_targets = p1_pending_action.get("targets", [])
    var p2_targets = p2_pending_action.get("targets", [])

    # Cek apakah ada target yang sama
    for t in p1_targets:
        if t in p2_targets:
            emit_signal("conflict_detected", p1_pending_action, p2_pending_action)
            # Sequential resolver: P1 dulu
            _execute_action(p1_pending_action)
            _execute_action(p2_pending_action)
            return

    # Tidak ada conflict → eksekusi paralel
    _execute_action(p1_pending_action)
    _execute_action(p2_pending_action)

func _execute_action(action: Dictionary) -> void:
    if action.is_empty():
        return
    var ability = action.get("ability") as BaseAbility
    var targets = action.get("targets", [])
    var caster = action.get("caster")
    if ability and caster:
        ability.execute(caster, targets)

# Dipanggil oleh input "End Turn" dari masing-masing player
func confirm_end_turn(player_id: int) -> void:
    if player_id == 1:
        p1_confirmed_end = true
    elif player_id == 2:
        p2_confirmed_end = true

    emit_signal("player_confirmed_end_turn", player_id)

    if p1_confirmed_end and p2_confirmed_end:
        emit_signal("both_players_confirmed")
```

---

### 3.2 — EnemyPhaseManager

File: `turn_base/EnemyPhaseManager.gd`  
Ref: Task `#7 — Enemy Phase Manager (sequential queue)`

Logika: Semua musuh bertindak **satu per satu** berdasarkan urutan inisiatif (DEX-based). Delay 0.5 detik antar aksi untuk readability.

```gdscript
# turn_base/EnemyPhaseManager.gd
class_name EnemyPhaseManager
extends Node

signal phase_started()
signal enemy_turn_started(enemy: Node)
signal enemy_turn_ended(enemy: Node)
signal phase_ended()

const ACTION_DELAY_SEC = 0.5

var enemy_queue: Array[Node] = []
var is_processing: bool = false

func start_phase(enemies: Array[Node]) -> void:
    # Sort by DEX (descending) — butuh akses ke stat, gunakan MockStatProvider dulu
    enemy_queue = enemies.filter(func(e): return e.is_alive)
    enemy_queue.sort_custom(_sort_by_initiative)
    is_processing = true
    emit_signal("phase_started")
    _process_next_enemy()

func _sort_by_initiative(a: Node, b: Node) -> bool:
    # Placeholder: prioritas berdasarkan posisi di array (DEX dari StatSystem Candra nanti)
    # Saat integrasi: ganti dengan stat_provider.get_dex(a) > stat_provider.get_dex(b)
    return false

func _process_next_enemy() -> void:
    if enemy_queue.is_empty():
        is_processing = false
        emit_signal("phase_ended")
        return

    var enemy = enemy_queue.pop_front()

    if not enemy.is_alive:
        # Skip musuh yang sudah mati
        _process_next_enemy()
        return

    emit_signal("enemy_turn_started", enemy)
    _execute_enemy_turn(enemy)

func _execute_enemy_turn(enemy: Node) -> void:
    # Enemy AI logic: Move → Attack → Special
    # Ini placeholder — Enemy AI yang lengkap akan dikembangkan terpisah
    if enemy.has_method("do_ai_turn"):
        enemy.do_ai_turn()

    # Tunggu delay sebelum musuh berikutnya
    await get_tree().create_timer(ACTION_DELAY_SEC).timeout
    emit_signal("enemy_turn_ended", enemy)
    _process_next_enemy()
```

> **Catatan:** Enemy AI (`target_selector` + `action_executor`) bisa dikembangkan nanti sebagai sub-sistem terpisah di dalam EnemyPhaseManager atau sebagai komponen pada node Enemy.

---

### 3.3 — PhaseTransitionHandler

File: `turn_base/PhaseTransitionHandler.gd`  
Ref: Task `#Phase Transition Handler`

```gdscript
# turn_base/PhaseTransitionHandler.gd
class_name PhaseTransitionHandler
extends Node

signal player_phase_started()
signal enemy_phase_started()

enum Phase { PLAYER, ENEMY }
var current_phase: Phase = Phase.PLAYER

# Referensi ke manager
@export var player_phase_mgr: PlayerPhaseManager
@export var enemy_phase_mgr: EnemyPhaseManager

func _ready():
    player_phase_mgr.both_players_confirmed.connect(_on_players_end_turn)
    enemy_phase_mgr.phase_ended.connect(_on_enemy_phase_ended)

func start_combat(initial_enemies: Array[Node]) -> void:
    _begin_player_phase()

func _begin_player_phase() -> void:
    current_phase = Phase.PLAYER
    emit_signal("player_phase_started")
    player_phase_mgr.start_phase()

func _begin_enemy_phase(enemies: Array[Node]) -> void:
    current_phase = Phase.ENEMY
    emit_signal("enemy_phase_started")
    enemy_phase_mgr.start_phase(enemies)

func _on_players_end_turn() -> void:
    # Ambil daftar musuh yang masih hidup dari scene
    var living_enemies = _get_living_enemies()
    if living_enemies.is_empty():
        _trigger_combat_victory()
        return
    _begin_enemy_phase(living_enemies)

func _on_enemy_phase_ended() -> void:
    _begin_player_phase()

func _get_living_enemies() -> Array[Node]:
    # Placeholder: scan scene tree untuk enemy nodes
    # Ganti dengan reference ke EnemyManager saat tersedia
    var enemies: Array[Node] = []
    for node in get_tree().get_nodes_in_group("enemies"):
        if node.has_method("is_alive") and node.is_alive:
            enemies.append(node)
    return enemies

func _trigger_combat_victory() -> void:
    print("[PhaseTransitionHandler] All enemies defeated — Combat Victory!")
    # Panggil Level Manager (Ilham) untuk pindah ke node berikutnya
```

---

---

# 🎯 PHASE 4 — RNG Combat Resolvers
> **Estimasi:** 1–2 hari | **Dependency:** Phase 1 (DiceRoller) + MockStatProvider

---

### 4.1 — HitMissResolver

File: `rng/HitMissResolver.gd`  
Ref: Task `#RNG — Hit/Miss Resolver`

Formula: `D20 + floor(ACC / 2)` vs target `Armor` (fisik) atau `Resist` (magic/debuff)

```gdscript
# rng/HitMissResolver.gd
class_name HitMissResolver
extends Node

var dice_roller: DiceRoller
# Swap dengan StatSystem milik Candra saat selesai
var stat_provider  # DuckTyped: bisa MockStatProvider atau StatSystem

func setup(roller: DiceRoller, stat_prov) -> void:
    dice_roller = roller
    stat_provider = stat_prov

# Kembalikan Dictionary hasil resolusi
# Result: { "hit": bool, "roll": int, "threshold": int }
func resolve(attacker: Node, target: Node, is_magical: bool = false) -> Dictionary:
    var acc = stat_provider.get_acc(attacker)
    var modifier = floori(acc / 2.0)
    var roll = dice_roller.d20() + modifier

    var threshold: int
    if is_magical:
        threshold = stat_provider.get_resist(target)
    else:
        threshold = stat_provider.get_armor(target)

    return {
        "hit": roll >= threshold,
        "roll": roll,
        "threshold": threshold,
        "modifier": modifier
    }
```

---

### 4.2 — CritResolver

File: `rng/CritResolver.gd`  
Ref: Task `#RNG — Critical Hit Resolver`

Formula: `Natural Crit Threshold = 20 − floor(ACC / 10)`  
Crit terjadi jika **raw D20 roll** (sebelum modifier) >= threshold.

```gdscript
# rng/CritResolver.gd
class_name CritResolver
extends Node

var stat_provider  # DuckTyped

func setup(stat_prov) -> void:
    stat_provider = stat_prov

# Cek apakah raw roll (sebelum modifier) adalah critical
# raw_roll: hasil D20 mentah, sebelum ditambah modifier ACC
func is_critical(raw_roll: int, attacker: Node) -> bool:
    var acc = stat_provider.get_acc(attacker)
    var crit_threshold = 20 - floori(acc / 10.0)
    return raw_roll >= crit_threshold

# Versi terintegrasi dengan HitMissResolver
# Kembalikan: { "hit": bool, "crit": bool, "roll": int, "raw_roll": int }
func resolve_with_crit(attacker: Node, target: Node, is_magical: bool = false) -> Dictionary:
    var acc = stat_provider.get_acc(attacker)
    var modifier = floori(acc / 2.0)
    var threshold = stat_provider.get_armor(target) if not is_magical else stat_provider.get_resist(target)
    var crit_threshold = 20 - floori(acc / 10.0)

    var raw_roll = randi_range(1, 20)
    var total_roll = raw_roll + modifier
    var crit = raw_roll >= crit_threshold

    return {
        "hit": total_roll >= threshold or crit,  # crit selalu hit
        "crit": crit,
        "roll": total_roll,
        "raw_roll": raw_roll,
        "threshold": threshold
    }
```

---

---

# 🔗 PHASE 5 — Integrasi dengan Tim
> **Estimasi:** 1–2 hari | **Dependency:** Sistem Candra & Gilang sudah selesai

Fase ini adalah penggantian semua mock dengan sistem nyata dari teman.

---

### Checklist Integrasi

#### ✅ Swap MockStatProvider → Candra's StatSystem

```gdscript
# SEBELUM (mock):
var stat_provider = MockStatProvider.new()

# SESUDAH (integrasi dengan Candra):
var stat_provider = StatSystem  # Autoload milik Candra
# atau jika bukan autoload:
@onready var stat_provider = $StatSystem
```

Pastikan interface-nya cocok:
- `get_armor(entity) -> int`
- `get_resist(entity) -> int`
- `get_acc(entity) -> int`
- `get_lck(entity) -> int`
- `get_mov(entity) -> int`
- `get_att(entity) -> int`
- `get_dex(entity) -> int`

#### ✅ Connect ke Gilang's SignalBus

```gdscript
# Setelah SignalBus (Gilang) tersedia sebagai Autoload:
SignalBus.on_hit.connect(_on_hit_landed)
SignalBus.on_miss.connect(_on_hit_missed)
```

#### ✅ Expose API untuk Rapit (HUD)

Rapit butuh akses ke resource values untuk HUD. Pastikan signal-signal berikut tersedia:
- `ActionPointManager.ap_changed(current, max)`
- `ActionPointManager.bap_changed(current, max)`
- `EnergyChargeManager.charge_changed(current, max)`
- `SpellSlotManager.slots_changed(level, current, max)`
- `MovementPointManager.movement_changed(current, max)`

#### ✅ Expose API untuk Ilham (Item Effect Applier)

Ilham butuh memanggil:
- `EnergyChargeManager.add_charge_cap(amount)` — untuk item yang menambah charge cap
- `SpellSlotManager.add_slot_cap(level, amount)` — untuk item yang menambah slot
- `ManaConverter.apply_mana_item(item_type, target_class)` — untuk cross-class item
- `ActionPointManager.add_ap_bonus(amount)` — untuk item yang menambah AP

---

---

## 📊 Summary Timeline

| Phase | Fokus | Estimasi | Bisa dimulai? |
|-------|-------|----------|---------------|
| **Phase 0** | Mock Layer & Setup | 0.5–1 hari | ✅ Sekarang |
| **Phase 1** | RNG Foundation (Dice, Luck) | 1–2 hari | ✅ Sekarang |
| **Phase 2** | Action Economy (AP, Energy, Slot, Movement) | 2–3 hari | ✅ Sekarang |
| **Phase 3** | Turn Base System (Player, Enemy, Transition) | 3–4 hari | Setelah Phase 2 |
| **Phase 4** | RNG Combat (Hit/Miss, Crit) | 1–2 hari | Setelah Phase 1+2 |
| **Phase 5** | Integrasi dengan Candra & Gilang | 1–2 hari | Setelah Candra+Gilang selesai |
| **Total** | | **~9–14 hari** | |

---

## 🚀 Output yang Diserahkan ke Tim

Setelah Tapip selesai, tim akan mendapat:

| Apa | Untuk Siapa | Bagaimana |
|-----|------------|-----------|
| `ActionPointManager` signals | **Rapit** (HUD) | Connect ke `ap_changed`, `bap_changed` |
| `EnergyChargeManager` signals | **Rapit** (HUD) | Connect ke `charge_changed` |
| `SpellSlotManager` signals | **Rapit** (HUD) | Connect ke `slots_changed` |
| `EnergyChargeManager.add_charge_cap()` | **Ilham** (Item System) | Panggil saat item diequip |
| `SpellSlotManager.add_slot_cap()` | **Ilham** (Item System) | Panggil saat item diequip |
| `ManaConverter.apply_mana_item()` | **Ilham** (Item System) | Untuk cross-class item |
| `DiceRoller`, `LuckRoller` | **Ilham** (Luck Event Roll) | Instantiate atau autoload |
| `PhaseTransitionHandler` signals | **Semua** | Connect untuk tau fase aktif |

---

*Combat Core Plan v1.0 — Tapip — Gemshied Project — May 2026*
