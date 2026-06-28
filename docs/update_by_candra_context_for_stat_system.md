# Update by Candra - Context for Stat System

Dokumen ini mencatat pekerjaan bagian Candra untuk sistem stat, HP, modifier, status, dan data JSON.
Tujuannya supaya Candra atau anggota tim lain bisa melanjutkan proyek tanpa harus membaca ulang seluruh codebase dari nol.

## Ringkasan Status

Bagian Candra tahap fondasi sudah dibuat:

- `StatsComponent` menjadi sumber stat resmi entity.
- Modifier stat sudah multi-source, jadi class, item, buff, dan status tidak saling overwrite.
- `StatSystem` sudah menjadi autoload provider stat untuk combat runtime.
- `HealthComponent` sudah menangani HP, damage, heal, downed, revive, dan death.
- `ConditionComponent` sekarang sudah terintegrasi penuh dengan `status_effects.json`. Semua stat mods dan DoT dari JSON otomatis dieksekusi tanpa perlu hardcode, selain legacy support untuk `stunned`, `frozen`, `bleeding`, `weakened`.
- `CombatComponent` minimal sudah tersedia untuk enemy/AI.
- `CombatTestBridge` sudah memakai `StatSystem` dan apply damage ke `HealthComponent`.
- Data stat sudah mulai dipindah ke JSON lewat `StatDataDB`.
- `Main.tscn` sekarang spawn Aria, Kael, Goblin, dan Orc berdasarkan JSON aktif.

## File Baru Penting

### Stat Runtime

```text
tiles_isometric_testing/autoloads/StatSystem.gd
tiles_isometric_testing/autoloads/StatDataDB.gd
```

`StatSystem.gd` adalah adapter stat runtime. Combat code sebaiknya membaca stat lewat file ini, bukan menghitung sendiri.

API penting:

```gdscript
StatSystem.get_armor(entity)
StatSystem.get_resist(entity)
StatSystem.get_acc(entity)
StatSystem.get_lck(entity)
StatSystem.get_mov(entity)
StatSystem.get_att(entity)
StatSystem.get_dex(entity)
StatSystem.get_int_stat(entity)
StatSystem.get_str_stat(entity)
StatSystem.get_max_hp(entity)
StatSystem.get_physical_damage_modifier(entity)
StatSystem.get_magical_damage_modifier(entity)
StatSystem.get_hit_roll_modifier(entity)
StatSystem.get_natural_crit_requirement(entity)
StatSystem.get_luck_roll_modifier(entity)
StatSystem.apply_damage(target, amount, attacker, "physical")
StatSystem.apply_heal(target, amount, source)
```

`StatDataDB.gd` adalah loader JSON untuk data stat module.

API penting:

```gdscript
StatDataDB.get_player_data("aria")
StatDataDB.get_enemy_data("goblin")
StatDataDB.apply_player_data("aria", player)
StatDataDB.apply_enemy_data("goblin", enemy)
StatDataDB.apply_item_mod(player, "ring_str")
StatDataDB.remove_item_mod(player, "ring_str")
StatDataDB.apply_condition_mod(enemy, "weakened")
StatDataDB.remove_condition_mod(enemy, "weakened")
```

### Komponen Entity

```text
tiles_isometric_testing/components/StatsComponent.gd
tiles_isometric_testing/components/HealthComponent.gd
tiles_isometric_testing/components/ConditionComponent.gd
tiles_isometric_testing/components/CombatComponent.gd
tiles_isometric_testing/components/ClassComponent.gd
```

`StatsComponent.gd` menyimpan base stat dan modifier.

`HealthComponent.gd` menyimpan:

```gdscript
max_hp
current_hp
get_hp()
get_max_hp()
set_hp(value)
add_hp(amount)
sub_hp(amount, attacker, "true")
take_damage()
heal()
down()
revive()
kill()
is_dead()
is_downed()
```

`ConditionComponent.gd` menyimpan status:

```text
stunned
frozen
bleeding
weakened
```

`CombatComponent.gd` adalah combat minimal untuk AI/enemy:

```gdscript
can_attack(target)
attack(target)
```

## File JSON Aktif

Semua JSON stat ada di:

```text
tiles_isometric_testing/data/stat_module/
```

Struktur aktif:

```text
data/stat_module/
  README.md
  _schemas/stat_keys.json
  entity_base_stats/players.json
  entity_base_stats/enemies.json
  item_stat_mods/equipment.json
  buff_stat_mods/class_buffs.json
  condition_stat_mods/status_effects.json
```

Tidak ada file `.example.json` lagi agar tidak membingungkan tim.

### players.json

File:

```text
tiles_isometric_testing/data/stat_module/entity_base_stats/players.json
```

Dipakai runtime untuk spawn dan apply stat Aria dan Kael.

Format utama:

```json
{
  "players": {
    "aria": {
      "display_name": "Aria",
      "scene": "res://entities/player/Player.tscn",
      "player_id": 1,
      "class_id": "slayer",
      "starting_buffs": ["slayer:blood_oath"],
      "base_stats": {
        "vit": 12,
        "str": 10,
        "int": 4,
        "con": 8,
        "acc": 8,
        "dex": 6,
        "mov": 5,
        "att": 0,
        "lck": 5
      },
      "health": {
        "use_stats_max_hp": true
      },
      "spawn": {
        "map_id": 1,
        "grid_pos": [5, 7]
      }
    }
  }
}
```

### enemies.json

File:

```text
tiles_isometric_testing/data/stat_module/entity_base_stats/enemies.json
```

Dipakai runtime untuk spawn dan apply stat Goblin dan Orc.

Field penting:

```json
{
  "display_name": "Goblin",
  "scene": "res://entities/enemies/EnemyPlaceholder.tscn",
  "base_stats": {},
  "health": {
    "use_stats_max_hp": false,
    "max_hp": 20
  },
  "combat": {
    "attack_dice": "1D6",
    "attack_range": 1,
    "is_magical": false
  },
  "spawn": {
    "grid_pos": [5, 5]
  }
}
```

### equipment.json

File:

```text
tiles_isometric_testing/data/stat_module/item_stat_mods/equipment.json
```

Dipakai untuk item yang memberi modifier stat.

Format:

```json
{
  "ring_str": {
    "display_name": "Ring of Strength",
    "item_type": "accessory",
    "equip_slot": "ring",
    "source_id": "item:ring_str",
    "stat_mods": {
      "str": 2
    }
  }
}
```

Cara apply runtime:

```gdscript
StatDataDB.apply_item_mod(player, "ring_str")
StatDataDB.remove_item_mod(player, "ring_str")
```

### class_buffs.json

File:

```text
tiles_isometric_testing/data/stat_module/buff_stat_mods/class_buffs.json
```

`ClassComponent` masih mendukung `ClassDB.gd`, tetapi sekarang juga bisa fallback ke JSON ini lewat `StatDataDB`.

Format:

```json
{
  "classes": {
    "slayer": {
      "display_name": "Slayer Order",
      "buffs": {
        "blood_oath": {
          "display_name": "Blood Oath",
          "source_id": "class:slayer:blood_oath",
          "duration": "passive",
          "stat_mods": {
            "str": 2
          }
        }
      }
    }
  }
}
```

### status_effects.json

File:

```text
tiles_isometric_testing/data/stat_module/condition_stat_mods/status_effects.json
```

Dipakai untuk kontrak data status/debuff.

Format:

```json
{
  "weakened": {
    "display_name": "Weakened",
    "type": "debuff",
    "default_duration_turns": 2,
    "source_id": "condition:weakened",
    "stat_mods": {
      "armor": -2
    },
    "component_args": {
      "armor_penalty": 2
    }
  }
}
```

## Key Stat Resmi

Primary stat:

```text
vit, str, int, con, acc, dex, mov, att, lck
```

Derived modifier yang boleh dipakai item, buff, atau status:

```text
hp
max_hp
armor
resist
physical_damage
magical_damage
action_points
bonus_action_points
hit_roll
crit_reduction
movement_tiles
spell_slots_l1
spell_slots_l2
spell_slots_l3
luck_roll
```

Catatan penting:

- Di JSON pakai key `"str"` dan `"int"`.
- Di `StatsComponent.gd`, variable export-nya bernama `str_stat` dan `int_stat`.
- Mapping sudah ditangani oleh `StatDataDB.apply_base_stats()`.

## Formula Yang Berlaku

Formula di `StatsComponent.gd`:

```text
Max HP = 15 + floor(VIT / 2) + floor(STR / 4)
Armor = 10 + floor(CON / 2) + floor(DEX / 4)
Resist = 5 + floor(VIT / 4) + floor(CON / 4)
Physical Damage Bonus = floor(STR / 2)
Magical Damage Bonus = floor(INT / 2)
Action Points = 1 + floor(DEX / 10)
Bonus Action Points = 1 + floor(INT / 10)
Hit Roll Bonus = floor(ACC / 2)
Crit Roll Reduction = floor(ACC / 10)
Movement Tile Bonus = floor(MOV / 5)
Spell Slot Lv1 = 2 + floor(ATT / 5)
Spell Slot Lv2 = 2 + floor(ATT / 10)
Spell Slot Lv3 = 1 + floor(ATT / 15)
Luck Roll Bonus = floor(LCK / 5)
```

## Modifier Multi-Source

Modifier tidak boleh langsung mengubah base stat permanen kecuali memang sistem permanent upgrade.
Untuk item, buff, dan status, gunakan source id.

Contoh:

```gdscript
var stats := entity.get_node("StatsComponent") as StatsComponent
stats.set_mod_source("item:ring_str", {"str": 2})
stats.set_mod_source("condition:weakened", {"armor": -2})
stats.equip({"id": "iron_ring", "mods": {"str": 2, "armor": 1}})
stats.apply_buff({"buff_id": "battle_focus", "stat_mods": {"acc": 4}})
stats.apply_debuff({"debuff_id": "weakened", "modifiers": {"armor": -2}})
```

Hapus modifier:

```gdscript
stats.remove_mod_source("item:ring_str")
stats.clear_mod_sources("condition:")
stats.unequip("iron_ring")
stats.remove_buff("battle_focus")
stats.remove_debuff("weakened")
```

Pola source id yang disarankan:

```text
class:slayer:blood_oath
item:ring_str
condition:weakened
buff:blessing
debuff:crippled
```

## Scene Yang Sudah Dipasang Component

### Player

File:

```text
tiles_isometric_testing/entities/player/Player.tscn
```

Child component:

```text
StatsComponent
ClassComponent
MovementComponent
HealthComponent
ConditionComponent
```

`Player.gd` sekarang punya API:

```gdscript
take_damage(amount, attacker)
heal(amount)
get_hp()
get_max_hp()
sub_hp(amount, attacker, "physical")
add_hp(amount)
get_armor()
get_resist()
get_stat("str")
is_dead()
is_downed()
```

### EnemyPlaceholder

File:

```text
tiles_isometric_testing/entities/enemies/EnemyPlaceholder.tscn
```

Child component:

```text
StatsComponent
ClassComponent
HealthComponent
ConditionComponent
CombatComponent
```

`EnemyPlaceholder.gd` sekarang memakai `HealthComponent`.
Enemy phase juga bisa memberi damage ke player lewat `StatSystem.apply_damage()`.

### BaseEnemy

File:

```text
tiles_isometric_testing/entities/enemies/BaseEnemy.tscn
```

Child component:

```text
HealthComponent
StatsComponent
MovementComponent
CombatComponent
ConditionComponent
AIComponent
```

`BaseEnemy` sudah disiapkan, tetapi `Main.tscn` masih memakai `EnemyPlaceholder`.

## Integrasi Combat Yang Sudah Diubah

File:

```text
tiles_isometric_testing/combat_core/tests/CombatTestBridge.gd
```

Perubahan:

- Provider stat sekarang memakai `/root/StatSystem` jika tersedia.
- `MockStatProvider` tetap fallback untuk test lama.
- Hit/miss membaca `ACC`, `Armor`, `Resist` dari stat runtime.
- Damage masuk ke `HealthComponent`.
- Physical damage memakai STR modifier lewat `StatSystem.get_physical_damage_modifier()`.
- Magical damage memakai INT modifier lewat `StatSystem.get_magical_damage_modifier()`.
- Combat input unblock sekarang me-refresh movement highlight setelah dice/attack selesai.
- `EventBus.damage_dealt`, `on_miss`, dan `entity_died` tetap dipakai.

## Debug Yang Bisa Dicoba

Jalankan:

```text
Main.tscn
```

Lalu:

1. Tekan `F1`.
2. Aktifkan debug stats jika checkbox tersedia.
3. Cek Aria, Kael, Goblin, Orc.
4. Ubah `players.json` atau `enemies.json`.
5. Restart scene.
6. Pastikan angka debug berubah sesuai JSON.

Yang harus terlihat:

```text
HP current/max
VIT STR INT CON ACC DEX MOV ATT LCK
Armor final
Resist final
Hit bonus
Crit reduction
Spell slot Lv1/Lv2/Lv3
Class
Buff
```

## Cara Melanjutkan Proyek Dari Sini

### 1. Stabilkan runtime Godot

Wajib dites di editor:

- Run `Main.tscn`.
- Pastikan autoload `StatSystem` dan `StatDataDB` tidak error.
- Pastikan JSON terbaca.
- Pastikan F1 debug stats muncul.
- Serang enemy dan cek HP turun.
- End turn sampai enemy phase dan cek player bisa kena damage.

### 2. Balancing angka JSON

Edit:

```text
data/stat_module/entity_base_stats/players.json
data/stat_module/entity_base_stats/enemies.json
```

Tambahkan entity baru dengan format yang sama.

Untuk player baru:

```json
"new_player_id": {
  "display_name": "Name",
  "scene": "res://entities/player/Player.tscn",
  "player_id": 1,
  "class_id": "slayer",
  "starting_buffs": [],
  "base_stats": {},
  "health": {"use_stats_max_hp": true},
  "spawn": {"grid_pos": [5, 7]}
}
```

Untuk enemy baru:

```json
"new_enemy_id": {
  "display_name": "Enemy Name",
  "scene": "res://entities/enemies/EnemyPlaceholder.tscn",
  "base_stats": {},
  "health": {"use_stats_max_hp": false, "max_hp": 20},
  "combat": {"attack_dice": "1D6", "attack_range": 1, "is_magical": false},
  "spawn": {"grid_pos": [5, 5]}
}
```

### 3. Integrasi item/equipment

Item team harus menulis item di:

```text
data/stat_module/item_stat_mods/equipment.json
```

Saat item dipasang:

```gdscript
StatDataDB.apply_item_mod(entity, "item_id")
```

Saat item dilepas:

```gdscript
StatDataDB.remove_item_mod(entity, "item_id")
```

### 4. Integrasi status/buff/debuff

Status team harus menulis status di:

```text
data/stat_module/condition_stat_mods/status_effects.json
```

Untuk modifier stat sementara:

```gdscript
StatDataDB.apply_condition_mod(entity, "weakened")
```

Untuk behavior status seperti stun/frozen/bleeding, pakai `ConditionComponent`:

```gdscript
var cond := entity.get_node("ConditionComponent") as ConditionComponent
cond.add_condition("bleeding", 3, 1, {"damage": 1})
cond.add_condition("weakened", 2, 1, {"armor_penalty": 2})
```

### 5. Migrasi EnemyPlaceholder ke BaseEnemy

Tahap sekarang masih aman memakai `EnemyPlaceholder`.
Nanti kalau enemy system sudah matang:

1. Ubah `scene` enemy di `enemies.json` ke `res://entities/enemies/BaseEnemy.tscn`.
2. Pastikan BaseEnemy punya sprite/visual.
3. Pastikan `AIComponent`, `CombatComponent`, `HealthComponent`, dan `StatsComponent` aktif.

### 6. UI HUD

Debug panel sudah cukup untuk developer.
HUD proper masih perlu dibuat oleh tim UI:

- HP bar player/enemy.
- Status icon.
- Armor/resist indicator.
- Buff/debuff list.

Data yang harus dipakai UI:

```gdscript
HealthComponent.current_hp
HealthComponent.max_hp
StatsComponent.get_armor()
StatsComponent.get_resist()
ConditionComponent.get_conditions()
```

## Kontrak Untuk Teman Satu Tim

Teman lain tidak perlu menghitung stat sendiri.

Gunakan:

```gdscript
StatSystem.get_armor(entity)
StatSystem.get_resist(entity)
StatSystem.get_acc(entity)
StatSystem.get_max_hp(entity)
```

Untuk damage/heal:

```gdscript
StatSystem.apply_damage(target, amount, attacker, "physical")
StatSystem.apply_heal(target, amount, source)
```

Untuk item modifier:

```gdscript
StatDataDB.apply_item_mod(entity, "item_id")
StatDataDB.remove_item_mod(entity, "item_id")
```

Jangan membuat key stat baru tanpa koordinasi dengan Candra.
Kalau butuh stat baru, update dulu:

```text
StatsComponent.gd
StatSystem.gd
StatDataDB.gd
data/stat_module/_schemas/stat_keys.json
```

## Yang Masih Belum Selesai

- Runtime sudah bisa dicek lewat executable Godot lokal/headless jika path executable tersedia.
- Inventory/equipment belum tersambung ke `StatDataDB.apply_item_mod()`.
- HUD proper untuk HP/status belum dibuat.
- Status visual/icon belum dibuat.
- Ability damage runtime di `CombatTestBridge` sudah membaca physical/magical damage modifier dari stat. Integrasi penuh `BaseAbility.execute()` ke action queue masih belum selesai.
- Enemy utama masih `EnemyPlaceholder`, belum migrasi penuh ke `BaseEnemy`.
- JSON belum punya schema validator otomatis di Godot, baru valid secara parse JSON.

## Checklist Tes Manual

Gunakan Godot Editor:

1. Buka project `tiles_isometric_testing`.
2. Run `Main.tscn`.
3. Pastikan console memunculkan:

```text
[StatDataDB] JSON stat module loaded...
```

4. Tekan `F1`.
5. Cek stat Aria/Kael/Goblin/Orc.
6. Edit `players.json`, misalnya ubah Aria `vit`.
7. Restart scene.
8. Pastikan HP/max stat berubah.
9. Serang Goblin/Orc.
10. Pastikan HP enemy turun.
11. End turn sampai enemy phase.
12. Pastikan enemy bisa damage player jika berdekatan.

## Catatan Akhir

Bagian Candra sekarang sudah menjadi fondasi data/stat resmi.
Mulai dari sini, pekerjaan lanjutan paling penting adalah:

1. Tes runtime sampai bersih di Godot Editor.
2. Balance angka di JSON.
3. Sambungkan item/equipment ke `StatDataDB.apply_item_mod()`.
4. Buat HUD HP/status.
5. Migrasi enemy ke `BaseEnemy` jika sistem enemy sudah siap.
