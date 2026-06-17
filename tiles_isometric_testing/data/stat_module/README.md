# Stat Module JSON Templates

Folder ini adalah tempat template data JSON untuk bagian stat Candra.
File JSON di folder ini sudah menjadi file aktif atau kontrak data.
Tidak ada file `.example.json` agar tidak membingungkan teman satu tim.

## Struktur Folder

```text
data/stat_module/
  README.md
  _schemas/
    stat_keys.json
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

## File Aktif Runtime

Edit file ini kalau ingin game berubah saat `Main.tscn` dijalankan:

```text
entity_base_stats/players.json
entity_base_stats/enemies.json
item_stat_mods/equipment.json
buff_stat_mods/class_buffs.json
condition_stat_mods/status_effects.json
_schemas/stat_keys.json
```

Autoload yang membaca file aktif:

```text
res://autoloads/StatDataDB.gd
```

Saat ini `Main.tscn` memakai `players.json` dan `enemies.json` untuk spawn Aria, Kael, Goblin, dan Orc.
Item/buff/status JSON sudah bisa dibaca lewat `StatDataDB`, tetapi belum disambungkan ke UI inventory/equipment.

## Key Stat Resmi

Primary stat:

```text
vit, str, int, con, acc, dex, mov, att, lck
```

Derived modifier yang boleh dipakai item/buff/status:

```text
hp, max_hp, armor, resist, physical_damage, magical_damage,
action_points, hit_roll, crit_reduction, movement_tiles,
spell_slots_l1, spell_slots_l2, spell_slots_l3, luck_roll
```

Catatan Godot:

```text
JSON memakai key "str" dan "int".
Di StatsComponent.gd, export variable-nya bernama str_stat dan int_stat.
Loader nanti harus mapping:
  "str" -> stats.str_stat
  "int" -> stats.int_stat
```

## Pola Modifier

Semua modifier stat sebaiknya masuk lewat:

```gdscript
stats.set_mod_source(source_id, stat_mods)
```

Contoh source id:

```text
class:slayer:blood_oath
item:ring_str
condition:weakened
buff:blessing
debuff:crippled
```

Dengan pola ini, class, item, buff, dan status tidak saling overwrite.

## Contoh Runtime

```gdscript
StatDataDB.apply_player_data("aria", player)
StatDataDB.apply_enemy_data("goblin", enemy)
StatDataDB.apply_item_mod(player, "ring_str")
StatDataDB.apply_condition_mod(enemy, "weakened")
```

Untuk menghapus modifier:

```gdscript
StatDataDB.remove_item_mod(player, "ring_str")
StatDataDB.remove_condition_mod(enemy, "weakened")
```

## Aturan Untuk Teman Satu Tim

- Jangan bikin key stat baru tanpa koordinasi dengan Candra.
- Kalau item/buff/status menambah stat, isi field `stat_mods`.
- Kalau status punya efek per-turn seperti bleeding, isi `turn_effect`.
- Kalau entity punya base stat, isi field `base_stats`.
- JSON harus valid: tidak boleh ada komentar di dalam file `.json`.
