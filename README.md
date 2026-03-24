# KONTEKS PROYEK: PROJECT-T
### Versi 2.1 — Updated Architecture + Progress Tracker

> **Status dokumen:** Diperbarui setelah sesi development pertama.
> Legend: ✅ Sudah selesai | 🔧 Sedang berjalan / partial | ⬜ Belum dimulai | 🐛 Bug diketahui

---

## GAMBARAN GAME

- **Genre:** Roguelike RPG, turn-based combat, dungeon crawler
- **Platform:** PC (Windows Only)
- **Player:** 2 pemain lokal di satu perangkat
- **Viewport:** SATU viewport, SATU Camera2D — map dilihat bersama
- **Perspektif:** True isometric 2D (Diablo style), tile size 128x64
- **Art style:** Hand-drawn sketchy 2D (referensi: Edmund McMillen / Mewgenics)
- **Combat:** Turn-based D&D style (1 Action, 1 Bonus Action, Movement tiles per turn)
- **Map:** Room-based roguelike, bukan open world — map statis per room
- **Save system:** JSON ke disk, 3 slot (slot 0 = auto save)
- **Offline only**

---

## PRINSIP UI

- **Map/World** — SHARED, satu Camera2D follow centroid party
- **HUD** — TERPISAH per player, P1 di kiri layar, P2 di kanan layar
- **Tidak ada splitscreen kamera** — P1 dan P2 lihat area yang sama
- **HUD P1 dan P2 tidak boleh overlap** — anchor P1 = 0.0 ke 0.5, P2 = 0.5 ke 1.0

---

## SCENE TREE UTAMA

```
Main.tscn  <- ROOT SCENE
├── World (Node2D — world/World.gd)
│   ├── TileMapLayer               <- isometric tileset 128x64
│   ├── Entities (Node2D)          <- y_sort_enabled=TRUE
│   └── Camera2D                   <- follow centroid party, lerp 0.08
│
└── UI_Overlay (CanvasLayer — NO script)  layer=1
    ├── InitiativeTracker (VBoxContainer — ui/shared/InitiativeTracker.gd)
    │   <- tengah atas, shared, show saat combat
    │
    ├── HUD_P1 (Control — ui/hud/HUD.gd)
    │   player_id=1, anchor LEFT=0.0 RIGHT=0.5 TOP=0.0 BOTTOM=1.0
    │   ├── [HUD elements dibangun via code]
    │   ├── AttackCam (SubViewportContainer) <- hidden by default
    │   │   └── SubViewport_P1
    │   │       └── Camera2D_AttackCam_P1
    │   └── DiceRollPopup (Control) <- hidden by default
    │
    └── HUD_P2 (Control — ui/hud/HUD.gd)
        player_id=2, anchor LEFT=0.5 RIGHT=1.0 TOP=0.0 BOTTOM=1.0
        ├── [HUD elements dibangun via code]
        ├── AttackCam (SubViewportContainer) <- hidden by default
        │   └── SubViewport_P2
        │       └── Camera2D_AttackCam_P2
        └── DiceRollPopup (Control) <- hidden by default
```

---

## HUD PER PLAYER (isi lengkap)

Tiap HUD_P1 / HUD_P2 berisi elemen berikut, semuanya independent:

- CharNameLabel — "Aria  Lv3"
- HP bar + label — ProgressBar + "80/120"
- MP bar + label — ProgressBar + "15/20"
- MovementPips — HBoxContainer, pip kuning = sisa gerak
- AbilityBar — HBoxContainer, tombol tiap ability yang diketahui
- EndTurnButton — disabled saat bukan giliran player ini
- DiceRollPopup — muncul di dalam HUD saat player ini roll, P2 tidak lihat roll P1
- AttackCam — SubViewportContainer, muncul saat PLAYER INI menyerang saja

**AttackCam:** Hanya muncul di sisi player yang menyerang. Player lain HUD-nya tidak berubah. Share world_2d dengan World. Durasi ~1-2 detik lalu hide.

**DiceRollPopup:** Muncul di HUD player yang roll. Tampilkan d20 natural, total, vs AC, hit/miss/crit. Auto-hide 1.2 detik.

**Yang SHARED (bukan per player):**
- InitiativeTracker — di map tiles beda warna untuk player1 dan player2, child langsung UI_Overlay
- Level up notification — world-space, spawn di atas karakter (bukan UI)
- Loot drop — world-space, spawn di tile, player jalan ke sana untuk pickup

---

## PLAYER.TSCN ⬜ (target arsitektur — belum diimplementasi)

```
CharacterBody2D (entities/player/Player.gd)
├── HealthComponent    (Node)
├── StatsComponent     (Node)
├── MovementComponent  (Node)
├── EquipmentComponent (Node)
├── AbilityComponent   (Node)
├── InventoryComponent (Node)
├── ConditionComponent (Node)
├── CombatComponent    (Node)
├── AnimatedSprite2D
└── CollisionShape2D
```

> **Catatan implementasi saat ini:** Player.gd masih monolitik — movement dan input langsung di
> `_process`. Refactor ke component-based dilakukan saat masuk Phase 1.
> `grid_pos`, `target_pos`, `movement_left` sudah exposed sebagai var publik
> sehingga SelectionCursor bisa polling tanpa perlu inject referensi ke Player.

---

## BASEENEMY.TSCN ⬜

```
CharacterBody2D (entities/enemies/BaseEnemy.gd)
├── HealthComponent    (Node)
├── StatsComponent     (Node)
├── MovementComponent  (Node)
├── ConditionComponent (Node)
├── CombatComponent    (Node)
├── AIComponent        (Node)
├── AnimatedSprite2D
└── CollisionShape2D
```

---

## AUTOLOADS (urutan load penting)

```
EventBus      autoloads/EventBus.gd       ✅ Implemented
GameManager   autoloads/GameManager.gd    ⬜
GridManager   autoloads/GridManager.gd    ✅ Implemented
IsoUtils      autoloads/IsoUtils.gd       ✅ Implemented
InputManager  autoloads/InputManager.gd   ✅ Implemented
DiceSystem    autoloads/DiceSystem.gd     ⬜
TurnManager   autoloads/TurnManager.gd    ⬜
SaveManager   autoloads/SaveManager.gd    ⬜
DataManager   autoloads/DataManager.gd    ⬜
```

---

## API AUTOLOADS

### EventBus ✅ Partial

```gdscript
# ✅ Sudah ada di file:
signal player_moved(entity: Node, from: Vector2i, to: Vector2i)

# ⬜ Didefinisikan tapi belum dipakai (Phase 1+):
signal combat_started(combatants: Array)
signal combat_ended(result: String)
signal turn_started(entity: Node, player_id: int)   # -1 = enemy
signal turn_ended(entity: Node)
signal round_started(round_num: int)
signal attack_started(attacker: Node, target: Node, ability_id: String)
signal damage_dealt(target: Node, amount: int, type: String, is_crit: bool)
signal entity_healed(target: Node, amount: int)
signal entity_died(entity: Node, killer: Node)
signal miss_occurred(attacker: Node, target: Node)
signal item_equipped(entity: Node, slot: String, item_id: String)
signal item_unequipped(entity: Node, slot: String)
signal item_picked_up(entity: Node, item_id: String)
signal inventory_changed(entity: Node)
signal xp_gained(entity: Node, amount: int)
signal level_up(entity: Node, new_level: int)
signal gold_changed(amount: int, total: int)
signal room_cleared(room: Node)
signal floor_changed(floor_num: int)
signal loot_spawned(pos: Vector2i, item_ids: Array)
signal loot_collected(entity: Node, item_id: String)
signal attackcam_started(attacker: Node, target: Node, ability_id: String)
signal attackcam_finished(attacker: Node)
signal dice_rolled(player_id: int, natural: int, total: int, vs_ac: int, is_hit: bool, is_crit: bool)

# [FIX-1] Signals untuk Reaction system ⬜
signal reaction_requested(reacting_entity: Node, trigger: String, trigger_data: Dictionary)
signal reaction_resolved(reacting_entity: Node, used: bool)
```

---

### GameManager ⬜

```gdscript
enum GameState { EXPLORE, COMBAT, PAUSED, CUTSCENE }
var state: GameState
var current_floor: int = 1
var total_gold: int = 0
var play_time: float = 0.0
var round_number: int = 0
func set_state(new_state: GameState)
func is_combat() -> bool
func is_explore() -> bool
func add_gold(amount: int)
```

---

### GridManager ✅ Implemented

```gdscript
var grid_size: Vector2i = Vector2i(16, 16)   # default, disetup ulang di World._ready()

func setup_grid(width: int, height: int)
func set_tile_walkable(pos: Vector2i, can_walk: bool)
func is_walkable(pos: Vector2i) -> bool       # ✅ cek _walkable DAN _entities
func register_entity(pos: Vector2i, entity: Node)
func unregister_entity(pos: Vector2i)
func move_entity(from: Vector2i, to: Vector2i, entity: Node)
func get_entity_at(pos: Vector2i) -> Node
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]
# PENTING: find_path BUKAN get_path — get_path bentrok dengan built-in AStarGrid2D
func get_path_cost(from: Vector2i, to: Vector2i) -> int   # -1 jika tidak bisa dicapai
func get_reachable_tiles(origin: Vector2i, max_steps: int) -> Array[Vector2i]
func get_distance(a: Vector2i, b: Vector2i) -> int   # Chebyshev
```

---

### IsoUtils ✅ Implemented

```gdscript
const TILE_W = 128
const TILE_H = 64
func world_to_iso(grid_pos: Vector2i) -> Vector2   # grid -> pixel
func iso_to_grid(pixel: Vector2) -> Vector2i        # pixel -> grid (untuk klik mouse)
func get_depth(grid_pos: Vector2i) -> int           # z_index = x + y
```

---

### InputManager ✅ Implemented

```gdscript
var killcam_active: bool = false
var is_in_menu: bool = false
func is_just_pressed(player_id: int, action: String) -> bool
func is_pressed(player_id: int, action: String) -> bool
func get_movement_dir(player_id: int) -> Vector2i
func is_confirm_pressed(player_id: int) -> bool
# P1: WASD + E + Space
# P2: Arrows + Enter + NumpadEnter
```

---

### DiceSystem ⬜ — [FIX-3] Advantage/Disadvantage

```gdscript
func roll(sides: int) -> int
func roll_multiple(count: int, sides: int) -> int
func roll_formula(formula: String) -> int   # "2d6+3" -> int
func ability_modifier(score: int) -> int    # floor((score-10)/2)
func proficiency_bonus(level: int) -> int   # ceil(level/4)+1
func xp_for_level(level: int) -> int

# advantage=true: roll 2d20 ambil tertinggi
# disadvantage=true: roll 2d20 ambil terendah
# keduanya true: cancel out, roll normal 1d20
func attack_roll(
    attacker_bonus: int,
    target_ac: int,
    advantage: bool = false,
    disadvantage: bool = false
) -> Dictionary
# Returns:
# {
#   natural: int,
#   natural_raw: Array,     # semua dice yang diroll [17] atau [14, 17]
#   total: int,
#   is_hit: bool,
#   is_crit: bool,          # natural == 20
#   is_fumble: bool,        # natural == 1
#   had_advantage: bool,
#   had_disadvantage: bool
# }
```

---

### TurnManager ⬜ — [FIX-1] + [FIX-2]

```gdscript
enum ActionPhase {
    NONE,
    ACTION,
    BONUS,
    MOVEMENT,
    REACTION,
    WAITING
}

class CombatAction:
    var actor: Node
    var target: Node
    var ability_id: String
    var callback: Callable

func start_combat(combatants: Array)
func end_combat(result: String = "victory")
func is_player_turn() -> bool
func player_end_turn(player: Node)
func reset_player_actions(player: Node)

func get_action_phase(player: Node) -> ActionPhase
func use_action(player: Node)
func use_bonus_action(player: Node)
func use_reaction(player: Node)
func restore_reaction(player: Node)

func request_reaction(reacting_entity: Node, trigger: String, trigger_data: Dictionary)

# [FIX-2] Combat queue — cegah race condition 2 player serang target sama
func queue_combat_action(action: CombatAction)
func _process_queue()
var _combat_queue: Array[CombatAction] = []
var _queue_processing: bool = false
```

---

### SaveManager ⬜ — [FIX-4]

```gdscript
# Schema SaveData:
# {
#   "version": int,
#   "timestamp": int,
#   "play_time": float,
#   "floor": int,
#   "round": int,
#   "gold": int,
#   "rng_seed": int,
#   "world": {
#     "rooms_cleared": Array,       # UNTYPED — JSON load tidak bisa assign ke typed array
#     "chests_opened": Array,       # UNTYPED
#     "current_room_id": String
#   },
#   "players": [ { serialize() dari tiap Player } ],
#   "enemies": [ { serialize() dari tiap Enemy } ]
# }

func save_game(slot: int)
func load_game(slot: int)
func auto_save()
func save_exists(slot: int) -> bool
func get_slot_info(slot: int) -> Dictionary
func _migrate_save(data: Dictionary, from_version: int) -> Dictionary
const CURRENT_SCHEMA_VERSION = 1
```

---

### DataManager ⬜ — [FIX-6]

```gdscript
func get_item(item_id: String) -> ItemData
func get_ability(ability_id: String) -> AbilityData
func get_enemy(enemy_id: String) -> EnemyData
func get_character(class_id: String) -> CharacterData
```

---

### World.gd 🔧 Partial — [FIX-5]

```gdscript
@onready var tile_map: TileMapLayer
@onready var entities: Node2D    # y_sort_enabled = true
@onready var camera: Camera2D

var players: Array[Node] = []    # ✅ diisi oleh spawn_entity() setelah bug fix
var rooms_cleared: Array = []    # UNTYPED — lihat gotcha #2
var chests_opened: Array = []    # UNTYPED
var current_room_id: String = ""

func get_world_2d() -> World2D   # ⬜ untuk AttackCam SubViewport
func spawn_entity(scene: PackedScene, grid_pos: Vector2i) -> Node   # ✅ implemented
func despawn_entity(entity: Node)                                    # ✅ implemented
func load_room(room_data: Dictionary)    # ⬜
func clear_room()                        # ⬜
func mark_room_cleared(room_id: String)  # ⬜
func get_party_centroid() -> Vector2     # ✅ implemented
func serialize() -> Dictionary           # ⬜
func deserialize(data: Dictionary)       # ⬜
```

> **Bug fix yang sudah diterapkan di World.gd:**
> - Path DebugGrid diperbaiki: `res://ui/world/DebugGrid.gd`
> - `spawn_entity()` sekarang push entity ke `players[]` jika `is_in_group("players")`

---

## UI NODES

### HUD.gd 🔧 Partial

```gdscript
# ✅ Sudah ada: _coord_label, _name_label, _move_label
# ✅ Bug fix: _move_label disimpan sebagai var, tidak lagi pakai $"../VBoxContainer/MoveLabel"
# ⬜ Belum: HP bar, MP bar, AbilityBar, EndTurnButton, MovementPips
# ⬜ Belum: AttackCam SubViewportContainer
# ⬜ Belum: DiceRollPopup
```

### DebugGrid.gd ✅ Implemented

```gdscript
# Draw diamond outline tiap tile + label koordinat (x,y)
# z_index = 100 (selalu di atas entity)
# Hanya untuk development, akan di-disable di build final
```

### SelectionCursor.gd ✅ Implemented (session ini)

```gdscript
# ui/world/SelectionCursor.gd
# Pattern: Cursor TIDAK inject ke Player, Player TIDAK tahu Cursor
# Cursor polling Player.target_pos dan Player.grid_pos setiap frame
# Tidak ada perubahan di Player.gd

@export var color_valid:   Color   # hijau — tile terjangkau dalam movement_left
@export var color_invalid: Color   # merah — terlalu jauh atau blocked
@export var color_self:    Color   # kuning — target == posisi sekarang

func bind(player: Node) -> void   # dipanggil dari main.gd

# Di _process:
# - Ambil target_pos dan grid_pos dari player
# - get_path_cost() untuk cek reachable
# - _show(state, grid_pos) -> queue_redraw()
# - Draw diamond di tile target, warna sesuai state
```

**Cara spawn di main.gd:**
```gdscript
var c1 = cursor_scene.instantiate()
world.entities.add_child(c1)
c1.bind(p1)
```

---

## API COMPONENTS ⬜ (semua belum diimplementasi)

### HealthComponent

```gdscript
signal health_changed(old_val: int, new_val: int)
signal died()
@export var base_max_hp: int = 100
var max_hp: int
var current_hp: int
func take_damage(amount: int) -> int
func heal(amount: int) -> int
func is_alive() -> bool
func serialize() -> Dictionary
func deserialize(data: Dictionary)
```

### StatsComponent

```gdscript
@export var strength, dexterity, constitution, intelligence, wisdom, charisma: int = 10
@export var movement: int = 6
@export var armor_class: int = 10
func get_modifier(stat: String) -> int
func get_stat(stat: String) -> int
func add_modifier(source_id: String, bonuses: Dictionary)
func remove_modifier(source_id: String)
func apply_level_up(level: int)
func serialize() -> Dictionary
func deserialize(data: Dictionary)
```

### MovementComponent

```gdscript
var grid_pos: Vector2i = Vector2i.ZERO
func setup(start_pos: Vector2i, max_move: int)
func can_move_to(target: Vector2i, movement_left: int) -> bool
func move_to(target: Vector2i) -> bool   # async, tween 0.12s/tile
func teleport_to(target: Vector2i)
func is_moving() -> bool
```

### AbilityComponent

```gdscript
signal mp_changed(current: int, max_mp: int)
@export var max_mp: int = 20
@export var known_ability_ids: Array = ["basic_attack"]
var current_mp: int
func can_use(ability_id: String) -> bool
func use_ability(ability_id: String) -> bool
func spend_mp(amount: int)
func restore_mp(amount: int)
func tick_cooldowns()
func serialize() -> Dictionary
func deserialize(data: Dictionary)
```

### CombatComponent

```gdscript
# [FIX-2] attack() masuk CombatActionQueue, bukan langsung eksekusi
func attack(target: Node, ability_id: String = "basic_attack")
# Flow internal setelah keluar dari queue:
# 1. Cek ActionPhase via TurnManager
# 2. emit attackcam_started -> tunggu attackcam_finished
# 3. range check (dari AbilityData.range_tiles)
# 4. Cek advantage/disadvantage dari ConditionComponent
# 5. DiceSystem.attack_roll()
# 6. emit dice_rolled -> DiceRollPopup di HUD player ini
# 7. apply damage, emit damage_dealt / miss_occurred / entity_died
# 8. TurnManager.use_action() atau use_bonus_action()
```

### ConditionComponent

```gdscript
func apply(condition_name: String, duration: int, data: Dictionary = {})
func remove(condition_name: String)
func has_condition(condition_name: String) -> bool
func is_stunned() -> bool
func is_slowed() -> bool

# [FIX-3] Helpers untuk advantage/disadvantage
func grants_advantage_on_attack() -> bool
func grants_disadvantage_on_attack() -> bool
func imposes_advantage_on_attacker() -> bool
func imposes_disadvantage_on_attacker() -> bool

func tick()
# Conditions: burn, poison, stun, slow, regen, blessed, blinded
func serialize() -> Array
func deserialize(data: Array)
```

### EquipmentComponent

```gdscript
const SLOTS = ["head","body","weapon","offhand","hands","feet","ring1","ring2","amulet"]
signal equipment_changed(slot: String, item_id: String)
func equip(slot: String, item_id: String) -> bool
func unequip(slot: String) -> String
func get_equipped(slot: String) -> String
func serialize() -> Dictionary
func deserialize(data: Dictionary)
```

### InventoryComponent

```gdscript
@export var max_slots: int = 20
func add_item(item_id: String) -> bool
func remove_item(item_id: String) -> bool
func has_item(item_id: String) -> bool
func get_all() -> Array
func serialize() -> Array
func deserialize(data: Array)
```

### AIComponent

```gdscript
func take_turn()   # async
# Cari player terdekat
#   -> dalam range attack -> queue_combat_action ke TurnManager
#   -> tidak dalam range -> maju ke player, cek opportunity attack trigger
```

---

## ENTITIES

### Player.gd 🔧 Partial

```gdscript
# ✅ Sudah ada (monolitik, belum component-based):
@export var player_id: int
@export var char_name: String
var grid_pos: Vector2i
var target_pos: Vector2i       # ✅ exposed — dipakai SelectionCursor polling
var movement_left: int = 2
func place_at(pos: Vector2i)
func get_grid_pos() -> Vector2i

# ✅ Bug fix: _try_move() sekarang cek is_walkable() dulu sebelum move
# ✅ Player dipastikan add_to_group("players") di _ready()

# ⬜ Belum ada (target Phase 1):
@export var char_class: String
var level: int = 1
var experience: int = 0
var actions: int = 1
var bonus_actions: int = 1
var reaction: int = 1
var ended_turn: bool = false
var is_dead: bool = false
var selected_ability: String = "basic_attack"
func can_act() -> bool
func use_action() -> bool
func end_turn()
func gain_xp(amount: int)
func serialize() -> Dictionary
func deserialize(data: Dictionary)
```

### BaseEnemy.gd ⬜

```gdscript
@export var enemy_id: String
@export var template_id: String
@export var enemy_name: String
@export var xp_reward: int = 50
@export var gold_reward: int = 10
var is_dead: bool = false
func serialize() -> Dictionary
func deserialize(data: Dictionary)
```

---

## ATTACK CAM FLOW ⬜ — [FIX-7] Failsafe time_scale

```
Player tekan attack
  -> CombatComponent.attack(target)
       -> TurnManager.queue_combat_action(action)
            -> Queue diproses sequential:

       -> EventBus.attackcam_started.emit(attacker, target, ability_id)
            -> HUD player yang menyerang SAJA:
                 AttackCam.show()
                 InputManager.killcam_active = true
                 SubViewport share world_2d
                 zoom 2.5x ke attacker (0.35s)
                 pan ke target (0.45s)
                 Engine.time_scale = 0.25 (slowmo)
                 camera shake

                 # [FIX-7] FAILSAFE: Timer 3 detik paksa cleanup
                 _failsafe_timer.start(3.0)

                 fade out (0.3s)
                 _failsafe_timer.stop()
                 AttackCam.hide()
                 InputManager.killcam_active = false
                 Engine.time_scale = 1.0    # SELALU reset sebelum emit
                 EventBus.attackcam_finished.emit(attacker)

            -> HUD player lain: tidak berubah sama sekali

       -> CombatComponent: await attackcam_finished
            var adv = attacker.condition.grants_advantage_on_attack()
            var dis = attacker.condition.grants_disadvantage_on_attack()
            dis = dis or target.condition.imposes_disadvantage_on_attacker()
            var result = DiceSystem.attack_roll(bonus, ac, adv, dis)
            emit dice_rolled(...)
            -> DiceRollPopup di HUD player yang menyerang, auto-hide 1.2s

func _force_cleanup_attackcam():
    Engine.time_scale = 1.0
    InputManager.killcam_active = false
    AttackCam.hide()
    push_warning("AttackCam failsafe triggered")
```

---

## COMBAT FLOW ⬜ — [FIX-1]

```
Enemy masuk jangkauan -> TurnManager.start_combat([p1, p2, e1, e2])
  -> EventBus.combat_started
       -> HUD: aktifkan END TURN button
          InitiativeTracker: show()
          TurnManager: set ActionPhase ACTION+BONUS+MOVEMENT untuk semua player

PLAYER PHASE:
  P1 dan P2 bebas act (tidak ada urutan ketat)
  Setiap aksi dicek via ActionPhase:
    - Attack -> use_action()
    - Bonus ability -> use_bonus_action()
    - Move -> kurangi movement_left
    - Reaction (opportunity attack saat enemy lewat) -> use_reaction()

  E/Enter -> end_turn() -> TurnManager.player_end_turn()
    -> ActionPhase = WAITING untuk player itu
  Semua player hidup WAITING -> ENEMY PHASE

  [FIX-2] Jika P1 dan P2 attack target yang sama:
    Queue proses P1 dulu -> apply damage -> cek isDead
    Target sudah mati saat giliran P2 -> P2 action di-cancel
    P2 mendapat Action kembali untuk target lain

ENEMY PHASE:
  Tiap enemy: turn_started -> tick() -> AIComponent.take_turn() -> turn_ended
  Enemy move -> cek Reaction player (opportunity attack)
  Setelah semua selesai:
    Semua enemy mati -> end_combat("victory")
    Semua player mati -> end_combat("defeat")
    Masih ada kedua pihak:
      Restore reaction semua player
      Tick cooldowns
      Player Phase lagi
```

---

## RESOURCE CLASSES ⬜ — [FIX-6]

```gdscript
# resources/characters/CharacterData.gd
class_name CharacterData extends Resource
@export var class_id, display_name, sprite_path: String
@export var base_hp, base_mp: int
@export var base_strength, base_dexterity, base_constitution: int
@export var base_intelligence, base_wisdom, base_charisma: int
@export var starting_abilities: Array[String]

# resources/abilities/AbilityData.gd
class_name AbilityData extends Resource
@export var ability_id, display_name, description: String
@export var mp_cost, range_tiles, cooldown_turns, condition_duration: int
@export var action_type: String     # "action" | "bonus_action" | "reaction"
@export var damage_formula: String  # "2d6+STR"
@export var damage_type: String     # "physical" | "fire" | "cold" | "lightning" | "heal"
@export var applies_condition: String
@export var requires_advantage: bool
@export var icon_path: String

# resources/items/ItemData.gd
class_name ItemData extends Resource
@export var item_id, display_name, description, item_type, equip_slot: String
@export var stat_bonuses: Dictionary
@export var on_use_ability: String
@export var value_gold: int
@export var stackable: bool
@export var icon_path: String

# resources/enemies/EnemyData.gd
class_name EnemyData extends Resource
@export var enemy_id, display_name, attack_ability_id, ai_behavior, sprite_path: String
@export var base_hp, armor_class, movement, xp_reward, gold_reward: int
@export var loot_table: Array[String]
```

---

## INCREMENTAL DEVELOPMENT MILESTONES

> Setiap Phase harus **fully playable dan testable** sebelum lanjut.

---

### PHASE 0 — Foundation 🔧 95% selesai

**Goal: Isometric grid bisa dirender, player bisa gerak**

- ✅ Main.tscn dengan World + UI_Overlay (CanvasLayer)
- ✅ TileMapLayer isometric 128x64 render tileset
- ✅ IsoUtils: world_to_iso + iso_to_grid
- ✅ GridManager: setup_grid, is_walkable, register/unregister/move entity, find_path, get_path_cost
- ✅ Player.tscn dengan movement dasar (monolitik, bukan component)
- ✅ InputManager: get_movement_dir P1 dan P2
- ✅ HUD_P1 dan HUD_P2 placeholder (nama + koordinat + movement_left)
- ✅ DebugGrid: outline tile + label koordinat
- ✅ SelectionCursor: highlight target tile, warna valid/invalid/self
- ✅ Camera2D ada di World (follow centroid sudah ada di `get_party_centroid()`)
- 🔧 Camera2D belum lerp ke centroid di `_process` — perlu disambung

**Bug fixes yang sudah diterapkan:**
- ✅ World.gd: path DebugGrid diperbaiki (`res://ui/world/DebugGrid.gd`)
- ✅ HUD.gd: `_move_label` disimpan sebagai var, hapus `$"../VBoxContainer"` path
- ✅ Player.gd: `_try_move()` cek `is_walkable()` sebelum move
- ✅ World.gd: `spawn_entity()` push ke `players[]` jika `is_in_group("players")`
- ✅ Player.gd: `add_to_group("players")` di `_ready()`

**Sisa Phase 0:**
- 🔧 Sambungkan Camera2D lerp ke `get_party_centroid()` di `World._process()`
- 🔧 Buat `SelectionCursor.tscn` di editor (Node2D root + attach script)

---

### PHASE 1 — Combat Core ⬜ (Minggu 3-4)

**Goal: 1 enemy bisa diserang dan mati**

- [ ] Refactor Player.gd ke component-based (HealthComponent, StatsComponent, MovementComponent, CombatComponent)
- [ ] HealthComponent (take_damage, heal, died signal)
- [ ] StatsComponent (stats dasar, get_modifier)
- [ ] CombatComponent (attack() tanpa AttackCam dulu)
- [ ] DiceSystem.attack_roll() dengan advantage/disadvantage [FIX-3]
- [ ] TurnManager: start_combat, player_end_turn, enemy phase
- [ ] TurnManager: ActionPhase enum + use_action() [FIX-1]
- [ ] TurnManager: CombatActionQueue [FIX-2]
- [ ] GameManager: state machine EXPLORE/COMBAT
- [ ] BaseEnemy.tscn + AIComponent (maju dan serang)
- [ ] EventBus: emit combat_started, turn_started, damage_dealt, entity_died
- [ ] HUD: HP bar hidup, EndTurnButton aktif saat giliran
- [ ] MovementComponent menggantikan logika move di Player.gd

**Test criteria:**
- Combat bisa start dan end (victory/defeat)
- P1 dan P2 bisa serang enemy yang sama tanpa crash [FIX-2]
- Enemy mati jika HP 0
- Turn berganti dengan benar

---

### PHASE 2 — Visual Polish Combat ⬜ (Minggu 5)

**Goal: Combat terasa satisfying**

- [ ] AttackCam SubViewport per player [FIX-7 failsafe wajib]
- [ ] Engine.time_scale slowmo + reset yang aman [FIX-7]
- [ ] DiceRollPopup di HUD player yang menyerang
- [ ] AnimatedSprite2D: idle, walk, attack, hurt, death animation
- [ ] Damage number float di world-space
- [ ] InitiativeTracker show/hide saat combat
- [ ] ConditionComponent: burn, poison, stun, slow, regen

**Test criteria:**
- AttackCam hanya muncul di sisi player yang menyerang
- time_scale selalu kembali ke 1.0 walau AttackCam di-interrupt [FIX-7]
- Kondisi burn/poison mengurangi HP tiap round

---

### PHASE 3 — Abilities & Equipment ⬜ (Minggu 6-7)

**Goal: Karakter bisa beda-beda**

- [ ] AbilityData.gd, ItemData.gd, CharacterData.gd class_name resource [FIX-6]
- [ ] DataManager dengan return typed [FIX-6]
- [ ] AbilityComponent: use_ability, mp_cost, cooldown
- [ ] EquipmentComponent: equip/unequip, stat bonus apply ke StatsComponent
- [ ] InventoryComponent: add/remove/has
- [ ] HUD AbilityBar dengan tombol per ability
- [ ] HUD MovementPips
- [ ] Loot drop world-space saat enemy mati
- [ ] 2 karakter class berbeda (misal: Warrior dan Mage)
- [ ] 5+ ability berbeda (termasuk 1 Bonus Action, 1 Reaction)
- [ ] TurnManager: Reaction request/resolve [FIX-1]

**Test criteria:**
- Warrior dan Mage punya playstyle beda
- Equip item mengubah stat yang terlihat di HUD
- Bonus action bisa dipakai di giliran yang sama dengan Action

---

### PHASE 4 — Dungeon & Progression ⬜ (Minggu 8-9)

**Goal: Game punya loop roguelike**

- [ ] Room-based dungeon: load_room, clear_room, mark_room_cleared
- [ ] World.gd full API [FIX-5]
- [ ] Procedural room connection sederhana (5-8 room per floor)
- [ ] SaveManager dengan SaveData schema [FIX-4]
- [ ] Semua component punya serialize/deserialize [FIX-4]
- [ ] 3 save slot (slot 0 = auto save)
- [ ] XP + level up (StatsComponent.apply_level_up)
- [ ] Level up notification world-space
- [ ] GameManager full state machine
- [ ] floor_changed, room_cleared events

**Test criteria:**
- Save, quit, load kembali ke posisi yang sama
- Level up mengubah stat
- Auto save tiap masuk room baru

---

### PHASE 5 — Content & Polish ⬜ (Minggu 10+)

**Goal: Game layak dimainkan orang lain**

- [ ] 3+ floor dengan difficulty scaling
- [ ] 5+ enemy type dengan behavior beda
- [ ] 20+ item dengan efek beda
- [ ] Chest loot, shop room (opsional)
- [ ] Main menu, character select, game over screen
- [ ] Sound effect combat (hit, miss, crit, death)
- [ ] Music per state (explore, combat)
- [ ] Bug bash & balance pass
- [ ] Build Windows .exe

**Test criteria:**
- Run pertama bisa selesai dalam 30-45 menit
- Tidak ada crash dalam 3 run berturut-turut

---

## FOLDER STRUCTURE

```
res://
├── autoloads/
│   ├── EventBus.gd          ✅
│   ├── GridManager.gd       ✅
│   ├── IsoUtils.gd          ✅
│   ├── InputManager.gd      ✅
│   ├── GameManager.gd       ⬜
│   ├── DiceSystem.gd        ⬜
│   ├── TurnManager.gd       ⬜
│   ├── SaveManager.gd       ⬜
│   └── DataManager.gd       ⬜
│
├── components/              ⬜ semua
│   ├── HealthComponent.gd
│   ├── StatsComponent.gd
│   ├── MovementComponent.gd
│   ├── AbilityComponent.gd
│   ├── EquipmentComponent.gd
│   ├── InventoryComponent.gd
│   ├── ConditionComponent.gd
│   ├── CombatComponent.gd
│   └── AIComponent.gd
│
├── entities/
│   ├── player/
│   │   ├── Player.gd        🔧 monolitik, refactor Phase 1
│   │   └── Player.tscn      🔧
│   └── enemies/
│       ├── BaseEnemy.gd     ⬜
│       └── BaseEnemy.tscn   ⬜
│
├── world/
│   └── World.gd             🔧 partial
│
├── ui/
│   ├── hud/
│   │   └── HUD.gd           🔧 partial (bug fixes applied)
│   ├── world/
│   │   ├── DebugGrid.gd     ✅
│   │   └── SelectionCursor.gd ✅ (session ini)
│   └── shared/
│       └── InitiativeTracker.gd ⬜
│
├── resources/
│   ├── characters/
│   │   ├── CharacterData.gd ⬜
│   │   └── classes/         ⬜ *.tres
│   ├── abilities/
│   │   ├── AbilityData.gd   ⬜
│   │   └── data/            ⬜ *.tres
│   ├── items/
│   │   ├── ItemData.gd      ⬜
│   │   └── data/            ⬜ *.tres
│   └── enemies/
│       ├── EnemyData.gd     ⬜
│       └── data/            ⬜ *.tres
│
├── shaders/
├── assets/
│   ├── characters/          ✅ (MiniHalberdMan, MiniHorseMan, MiniMage, MiniSwordMan)
│   └── tiles/               ✅ (spritesheet.png)
└── Main.tscn                🔧
```

---

## GOTCHA & BUG YANG SUDAH DIKETAHUI

1. **find_path bukan get_path** — `get_path` adalah built-in AStarGrid2D yang return NodePath, bentrok dan error
2. **rooms_cleared dan chests_opened harus Array untyped** — JSON load tidak bisa assign ke typed array
3. **HUD _find_player pakai retry loop** (await 0.3s) — player spawn async setelah HUD ready
4. **AttackCam SubViewport harus share world_2d** — `viewport.world_2d = world_node.get_world_2d()`
5. **SplitscreenManager sudah DIHAPUS** — game pakai single viewport
6. **InitiativeTracker node harus VBoxContainer** — bukan Node2D
7. **Lambda parameter tidak boleh underscore** — `func(_, val)` error, harus `func(old_val, new_val)`
8. **Engine.time_scale harus di-reset** ke 1.0 saat attackcam selesai atau di-skip — **[FIX-7] ada failsafe Timer 3 detik**
9. **AttackCam hanya muncul di HUD player yang menyerang** — player lain tidak terganggu
10. **[FIX-2] Jangan langsung eksekusi attack** — selalu lewat `TurnManager.queue_combat_action()`
11. **[FIX-3] Advantage DAN disadvantage bersamaan = cancel out**
12. **[FIX-4] JSON tidak bisa deserialize ke typed Array** — gunakan `Array` tanpa type annotation
13. **SelectionCursor tidak inject ke Player** — cursor polling `player.target_pos` langsung, Player.gd tidak tahu soal cursor
14. **spawn_entity() di World.gd menerima data Dictionary** — set property sebelum `add_child()`, bukan sesudah

---

## ISOMETRIC MATH

```
Grid (x, y) -> pixel:
  pixel.x = (x - y) * (TILE_W / 2) = (x - y) * 64
  pixel.y = (x + y) * (TILE_H / 2) = (x + y) * 32

z_index = x + y

Tile diamond polygon (dari center):
  top:   center + (0, -32)
  right: center + (64, 0)
  bottom:center + (0, +32)
  left:  center + (-64, 0)
```

---

## PROJECT SETTINGS

```
Application > Run > Main Scene         = res://Main.tscn
Application > Config > Name            = Hollow Crown
Rendering > 2D > Snap 2D Vertices      = ON
Display > Window > Size                = 1280 x 720
Display > Window > Stretch Mode        = canvas_items
```

---

## INPUT MAP

| Action                | P1      | P2           |
|-----------------------|---------|--------------|
| move_up               | W       | I            |
| move_down             | S       | K            |
| move_left             | A       | J            |
| move_right            | D       | L            |
| action                | E       | O            |
| END TURN              | Space   | Enter        |
| inventory             | Q       | U            |
