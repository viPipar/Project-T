# Roguelike Node Map Assets

Folder ini untuk semua asset visual node map / run map.

## Struktur

- `backgrounds/`
  - Background besar untuk map screen.
  - Current: `swamp_path_22x33_map_public.jpg`
- `node_icons/`
  - Icon node: Battle, Elite, Boss, Rest, Luck, Loot, Shop.
- `path_markers/`
  - Dotted path, line marker, arrow, current path highlight.
- `event_art/`
  - Gambar khusus event seperti Luck Event siput.
- `item_cards/`
  - Frame kartu item, rarity border, item placeholder.
  - Temporary: boleh pakai asset node icon dulu untuk prototype.
  - TODO: ganti dengan item card frame khusus sebelum polish UI.
- `shop/`
  - Asset UI shop, coin icon, reroll button art.
- `rest/`
  - Asset rest/campfire, heal icon, resource icon.

## Naming

Pakai nama lowercase dan underscore supaya enak dipakai dari `res://`.

Contoh:

```text
battle_skull.png
elite_skull_fire.png
boss_crown_skull.png
rest_campfire.png
luck_snail.png
loot_chest.png
shop_cart.png
```
