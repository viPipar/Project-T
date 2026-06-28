# Stat Module JSON Runtime

Folder ini berisi data JSON aktif untuk stat, HP, item modifier, buff, dan status. File di sini bukan contoh saja; perubahan angka akan memengaruhi runtime saat `Main.tscn` dijalankan.

## Struktur Folder

```text
data/stat_module/
  README.md
  _schemas/stat_keys.json
  entity_base_stats/
    players.json
    enemies.json
  item_stat_mods/
    equipment.json
  buff_stat_mods/
    class_buffs.json
  condition_stat_mods/
    status_effects.json
```

Autoload yang membaca data:

```text
res://autoloads/StatDataDB.gd
res://autoloads/StatSystem.gd
```

`Main.tscn` memakai `players.json` dan `enemies.json` untuk spawn Aria, Kael, Goblin, dan Orc.

## Runtime Components

Entity combat harus punya komponen ini jika ingin ikut sistem stat penuh:

```text
StatsComponent
HealthComponent
ConditionComponent
```

Player dan enemy wrapper juga menyediakan API dasar supaya sistem lain tidak perlu tahu isi child component:

```gdscript
entity.get_hp()
entity.get_max_hp()
entity.sub_hp(amount, attacker, "physical")
entity.add_hp(amount)
entity.take_damage(amount, attacker, "physical")
entity.heal(amount)
entity.get_armor()
entity.get_resist()
entity.get_stat("str")
entity.add_stat("str", 1)
entity.sub_stat("str", 1)
```

Untuk combat umum, gunakan autoload:

```gdscript
StatSystem.get_armor(entity)
StatSystem.get_resist(entity)
StatSystem.get_max_hp(entity)
StatSystem.get_physical_damage_modifier(entity)
StatSystem.get_magical_damage_modifier(entity)
StatSystem.get_hit_roll_modifier(entity)
StatSystem.get_natural_crit_requirement(entity)
StatSystem.get_luck_roll_modifier(entity)
StatSystem.apply_damage(target, amount, attacker, "physical")
StatSystem.apply_heal(target, amount, source)
```

## Key Stat Resmi

Primary stat:

```text
vit, str, int, con, acc, dex, mov, att, lck
```

Derived modifier yang boleh dipakai item, buff, dan status:

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

Catatan Godot:

```text
JSON memakai key "str" dan "int".
Di StatsComponent.gd, export variable-nya bernama str_stat dan int_stat.
Mapping "str" dan "int" sudah ditangani oleh StatDataDB.apply_base_stats().
```

## Formula Implementasi

Formula saat ini ada di `StatsComponent.gd`:

```text
Max HP = 15 + floor(VIT / 2) + floor(STR / 4) + modifier hp/max_hp
Armor = 10 + floor(CON / 2) + floor(DEX / 4) + modifier armor
Resist = 5 + floor(VIT / 4) + floor(CON / 4) + modifier resist
Physical Damage Modifier = floor(STR / 2) + modifier physical_damage
Magical Damage Modifier = floor(INT / 2) + modifier magical_damage
Action Points = 1 + floor(DEX / 10) + modifier action_points
Bonus Action Points = 1 + floor(INT / 10) + modifier bonus_action_points
Hit Roll Modifier = floor(ACC / 2) + modifier hit_roll
Natural Crit Requirement = 20 - floor(ACC / 10) - modifier crit_reduction
Movement Tiles = base movement + floor(MOV / 5) + modifier movement_tiles
Spell Slot Lv1 = 2 + floor(ATT / 5) + modifier spell_slots_l1
Spell Slot Lv2 = 2 + floor(ATT / 10) + modifier spell_slots_l2
Spell Slot Lv3 = 1 + floor(ATT / 15) + modifier spell_slots_l3
Luck Roll Modifier = floor(LCK / 5) + modifier luck_roll
```

Semua stat final di-clamp minimum 0. `max_hp` minimum 1.

## HP, Downed, dan Death

`HealthComponent` menjadi sumber HP runtime.

API utama:

```gdscript
health.get_hp()
health.get_max_hp()
health.set_hp(value)
health.add_hp(amount)
health.sub_hp(amount, attacker, "true")
health.take_damage(amount, attacker, "physical")
health.heal(amount)
health.down(attacker)
health.revive()
health.is_dead()
health.is_downed()
```

Rules:

- Player dengan HP 0 menjadi `downed`, tidak langsung hilang dari map.
- Enemy dengan HP 0 menjadi dead dan flow death lama berjalan.
- Heal ke target `downed` atau `dead` return `0`.
- `revive()` hanya menghidupkan target `downed` atau `dead`, dengan HP minimal 1.
- Jika Max HP turun di bawah current HP, current HP di-clamp ke Max HP baru.
- Jika Max HP naik, current HP tidak ikut naik otomatis.

## Armor dan Resist

Armor dan resist bukan resource terpisah. Keduanya derived stat dari `StatsComponent`.

Rules:

- Armor dipakai sebagai difficulty hit/miss.
- Serangan biasa hit jika roll `>= armor`.
- Resist dipakai sebagai difficulty status/debuff.
- Status/debuff masuk jika roll `>= resist`.
- Resist bukan damage reduction.

API runtime:

```gdscript
stats.get_armor()
stats.get_max_armor()
stats.add_armor(2)
stats.sub_armor(2)
stats.reset_armor()

stats.get_resist()
stats.add_resist(2)
stats.sub_resist(2)
stats.reset_resist()
```

`add_armor/sub_armor/reset_armor` dan versi resist memakai modifier source internal, bukan `current_armor/current_resist` baru.

## Modifier Multi-Source

Modifier item, buff, debuff, class, dan condition harus memakai source id supaya bisa dilepas tanpa menimpa modifier lain.

API langsung:

```gdscript
var stats := entity.get_node("StatsComponent") as StatsComponent

stats.set_mod_source("item:ring_str", {"str": 2})
stats.set_mod_source("condition:weakened", {"armor": -2})

stats.remove_mod_source("item:ring_str")
stats.clear_mod_sources("condition:")
```

Helper JSON/Dictionary fleksibel:

```gdscript
stats.apply_modifier_data(data, "item")
stats.remove_modifier_data("item:ring_str")

stats.equip(item_data)
stats.unequip("ring_str")

stats.apply_buff(buff_data)
stats.remove_buff("blessing")

stats.apply_debuff(debuff_data)
stats.remove_debuff("weakened")
```

`apply_modifier_data()` membaca source id dari:

```text
source_id, id, item_id, buff_id, debuff_id
```

Modifier dibaca dari:

```text
mods, stat_mods, modifiers
```

Source id yang disarankan:

```text
class:slayer:blood_oath
item:ring_str
condition:weakened
buff:blessing
debuff:crippled
```

## Contoh JSON dan Pemanggilan

Item:

```json
{
  "id": "iron_ring",
  "display_name": "Iron Ring",
  "mods": {
    "str": 2,
    "armor": 1
  }
}
```

```gdscript
stats.equip(item_data)
stats.unequip("iron_ring")
```

Buff:

```json
{
  "buff_id": "battle_focus",
  "duration_turns": 2,
  "stat_mods": {
    "acc": 4,
    "hit_roll": 1
  }
}
```

```gdscript
stats.apply_buff(buff_data)
stats.remove_buff("battle_focus")
```

Debuff:

```json
{
  "debuff_id": "weakened",
  "duration_turns": 3,
  "modifiers": {
    "str": -3,
    "armor": -2
  }
}
```

```gdscript
stats.apply_debuff(debuff_data)
stats.remove_debuff("weakened")
```

Via `StatDataDB`:

```gdscript
StatDataDB.apply_player_data("aria", player)
StatDataDB.apply_enemy_data("goblin", enemy)
StatDataDB.apply_item_mod(player, "ring_str")
StatDataDB.remove_item_mod(player, "ring_str")
StatDataDB.apply_condition_mod(enemy, "weakened")
StatDataDB.remove_condition_mod(enemy, "weakened")
```

## Aturan Untuk Tim

- Jangan bikin key stat baru tanpa koordinasi dengan Candra.
- Kalau entity punya base stat, isi `base_stats`.
- Kalau item/buff/status menambah stat, isi `stat_mods`, `mods`, atau `modifiers`.
- Untuk data runtime aktif, edit JSON di folder ini, bukan file contoh lain.
- JSON harus valid dan tidak boleh berisi komentar.
- Sistem lain sebaiknya pakai `StatSystem` atau wrapper entity, bukan menghitung stat sendiri.
