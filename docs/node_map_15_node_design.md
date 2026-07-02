# Node Map 15-Node Run Design

Dokumen ini adalah pegangan implementasi untuk node map roguelite horizontal:
start di kiri, last boss di kanan. Referensi visual mengikuti gambar map
bercabang ala Slay the Spire, tetapi aturan run dibuat lebih terkontrol:
pemain harus melewati 14 node dulu, lalu node ke-15 adalah last boss.

Catatan penting: "15 node" di sini berarti 15 depth/step dalam satu path run,
bukan total semua node yang digambar di map. Pada tiap depth boleh ada beberapa
pilihan node bercabang, tetapi pemain hanya menyelesaikan satu node per depth.

## Target Gameplay

Flow dasar:

1. Pemain mulai dari node paling kiri.
2. Pemain memilih salah satu node yang unlock di depth berikutnya.
3. Setelah node selesai, node berikutnya yang tersambung akan unlock.
4. Depth 15 selalu last boss.
5. Run selesai setelah last boss menang atau party kalah.

Map direction:

```text
START -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> LAST BOSS
 kiri                                                                    kanan
```

## Node Depth Rules

| Depth | Type Rule | Notes |
| --- | --- | --- |
| 1 | Battle | Start battle / awal run. |
| 2 | Flexible | Battle, Luck, Loot. |
| 3 | Flexible | Battle, Luck, Loot. |
| 4 | Rest, optional Shop choice | Sebelum elite pertama. |
| 5 | Elite Battle | Mid boss pertama. |
| 6 | Flexible | Battle, Luck, Loot. |
| 7 | Flexible | Battle, Luck, Loot. |
| 8 | Flexible | Battle, Luck, Loot. |
| 9 | Rest, optional Shop choice | Sebelum elite kedua. |
| 10 | Elite Battle | Mid boss kedua. |
| 11 | Flexible | Battle, Luck, Loot. |
| 12 | Flexible | Battle, Luck, Loot. |
| 13 | Flexible | Battle, Luck, Loot. |
| 14 | Rest, optional Shop choice | Sebelum last boss. |
| 15 | Boss | Last boss, wajib final node. |

Flexible depth pool:

```text
[2, 3, 6, 7, 8, 11, 12, 13]
```

Rules untuk flexible depth:

- Luck Event hanya muncul 1 kali sepanjang run.
- Loot muncul 2 kali sepanjang run.
- Sisa flexible depth menjadi Battle.
- Luck dan Loot tidak boleh muncul di depth Rest, Elite, atau Boss.
- Kalau nanti ingin lebih banyak variasi, Event/Loot bisa dibuat sebagai
  alternatif branch di depth yang sama, tetapi jumlah yang dilewati player tetap
  satu node per depth.

## Node Types

### 1. Level Battle

Tujuan:

- Melawan mob kecil.
- Setelah menang, lanjut map.
- Reward bisa kecil: coin, common item chance, atau progress saja.

Implementation target:

- Node type: `BATTLE`
- Encounter pool: normal mobs.
- Event route: `MapScreen -> Combat Scene -> WinLoseHandler -> MapScreen`

### 2. Level Elite Battle

Tujuan:

- Melawan mid boss.
- Wajib ada di depth 5 dan 10.
- Power spike sebelum masuk section berikutnya.

Implementation target:

- Node type: `ELITE`
- Encounter pool: elite/mid boss.
- Depth fixed: 5 dan 10.
- Reward lebih bagus dari battle biasa.

### 3. Level Rest

Tujuan:

- Recovery dan keputusan resource.
- Wajib ada di depth 4, 9, dan 14.

Pilihan:

1. Full Rest
   - +50% HP
   - +50% Energy Charge / Spell Slot
2. Partial Rest
   - +25% HP
   - +100% Energy Charge / Spell Slot
3. Search some treasure nearby
   - Dapat 1 random item

Implementation target:

- Node type: `REST`
- Current code sudah punya `RestScreen` dan `RestLootHandler`.
- Sesuaikan UI jadi 3 pilihan sesuai spec ini.
- Kalau tetap mau pilihan remove cursed item, jadikan fitur tambahan nanti,
  bukan bagian MVP node rest.

### 4. Level Boss

Tujuan:

- Last boss di depth 15.
- Final node selalu boss, tidak random.

Implementation target:

- Node type: `BOSS`
- Depth fixed: 15.
- Setelah menang: show run result victory.
- Setelah kalah: show run result defeat.

### 5. Level Luck Event

Tujuan:

- Satu event hoki sepanjang run.
- Pemain bisa bantu atau pergi tanpa konsekuensi.

Narrative MVP:

```text
Seekor siput tertiban kayu ingin membantunya?

Yes:
  50% dapat buff
  50% dapat debuff

No:
  Tidak ada konsekuensi, lanjut node berikutnya.
```

Rules:

- Hanya muncul 1 kali sepanjang run.
- Hanya bisa muncul di depth 2, 3, 6, 7, 8, 11, 12, 13.
- Kedua player harus setuju.
- Jika tidak setuju sampai timer habis, default aman: `No`.

Implementation target:

- Node type: `EVENT` atau lebih spesifik `LUCK_EVENT`.
- Current `LuckEventHandler` sudah punya consensus dan D20, tetapi spec baru
  lebih sederhana: yes/no + 50/50 buff/debuff.
- Current `EventScreen` masih mock; perlu connect ke `LuckEventHandler`.

Buff/debuff MVP:

- Buff examples:
  - +2 random stat untuk kedua player.
  - Heal 25% HP.
  - +100 coin each.
  - 1 random rare item.
- Debuff examples:
  - -25% HP.
  - -2 random stat sampai rest berikutnya.
  - 1 cursed item.
  - Lose 25% coin.

### 6. Level Loot

Tujuan:

- Ada 2 kali sepanjang run.
- Masing-masing player memilih 1 dari 5 item tersedia.
- Item untuk buff/build choice.

Rules MVP:

- Generate 5 item dari pool.
- P1 pilih 1 item.
- P2 pilih 1 item.
- Default: item yang sudah dipilih hilang dari pilihan agar tidak duplicate.
- Setelah kedua player memilih, lanjut map.

Implementation target:

- Node type: `LOOT`.
- Current `LootScreen` sudah punya reveal cards, tapi baru 3 cards dan belum
  jelas flow dua player.
- Ubah menjadi 5 item cards, track pick P1 dan P2, lalu enable continue.

### 7. Level Shop

Tujuan:

- Bisa muncul sebelum mid boss atau last boss.
- Pemain memilih mau Rest atau Shop.

Candidate depth:

- Depth 4 sebelum elite depth 5.
- Depth 9 sebelum elite depth 10.
- Depth 14 sebelum boss depth 15.

Recommended MVP:

- Jangan jadikan Shop depth terpisah dulu.
- Di Rest node depth 4/9/14, tampilkan pilihan awal:

```text
You found a safe area. What do you want?
1. Rest
2. Shop
```

- Jika pilih Rest, buka RestScreen.
- Jika pilih Shop, buka ShopScreen.
- Satu pilihan tetap menghitung selesai untuk depth itu.

Alternative later:

- Generate dua branch di depth yang sama: Rest node dan Shop node.
- Player harus memilih salah satu branch.

## Map Generation Spec

Generator harus deterministic by seed.

Input:

- `total_depth = 15`
- `lane_count = 3` untuk visual branch atas/tengah/bawah.
- `fixed_types`:

```gdscript
{
  1: BATTLE,
  4: REST,
  5: ELITE,
  9: REST,
  10: ELITE,
  14: REST,
  15: BOSS,
}
```

Random placement:

1. Ambil list flexible depth: `[2, 3, 6, 7, 8, 11, 12, 13]`.
2. Pilih 1 depth untuk Luck Event.
3. Dari sisa flexible depth, pilih 2 depth untuk Loot.
4. Sisanya Battle.

Pseudo:

```gdscript
var flexible_depths = [2, 3, 6, 7, 8, 11, 12, 13]
var luck_depth = pick_one(flexible_depths)
flexible_depths.erase(luck_depth)
var loot_depths = pick_many(flexible_depths, 2)

for depth in range(1, 16):
  if depth == 15:
    type = BOSS
  elif depth in [5, 10]:
    type = ELITE
  elif depth in [4, 9, 14]:
    type = REST
  elif depth == luck_depth:
    type = LUCK_EVENT
  elif depth in loot_depths:
    type = LOOT
  else:
    type = BATTLE
```

Branching:

- Setiap depth bisa punya 1 sampai 3 candidate nodes.
- Fixed depth sebaiknya 1 node saja supaya pacing jelas.
- Flexible depth boleh 2 sampai 3 node jika ingin pilihan path.
- Semua connection hanya boleh dari depth N ke depth N+1.
- Tidak boleh ada dead end.
- Tidak boleh skip depth.

MVP yang lebih cepat:

- Buat 1 node per depth dulu.
- Setelah flow stabil, baru tambah branch visual.

## Recommended Implementation Order

### Phase 1 - Data model dulu

Tujuan: node rules benar walau UI masih sederhana.

Files target:

- `tiles_isometric_testing/systems/progression/NodeGraph.gd`
- `tiles_isometric_testing/systems/progression/PathHandler.gd`
- `tiles_isometric_testing/systems/progression/RunManager.gd`

Tasks:

1. Tambah konsep `depth` 1 sampai 15.
2. Ubah `TOTAL_LAYERS` dari 10 ke 15.
3. Pisahkan `BOSS` final depth 15.
4. Force `ELITE` di depth 5 dan 10.
5. Force `REST` di depth 4, 9, dan 14.
6. Random 1 Luck Event dan 2 Loot dari flexible depth.
7. Simpan generated graph di `RunManager`, bukan dibuat ulang setiap
   `MapScreen` dibuka.

Acceptance:

- Print/debug graph selalu punya 15 depth.
- Depth 15 selalu Boss.
- Depth 5 dan 10 selalu Elite.
- Depth 4, 9, 14 selalu Rest.
- Luck count = 1.
- Loot count = 2.

### Phase 2 - Map screen dan unlock beneran

Tujuan: player tidak bisa klik node yang belum unlock.

Files target:

- `tiles_isometric_testing/ui/roguelike/MapScreen.gd`
- `tiles_isometric_testing/ui/roguelike/MapPathRenderer.gd`
- optional new scene: `MapNodeButton.tscn`

Tasks:

1. `MapScreen` ambil graph dari `RunManager`.
2. Hapus debug bypass di `_on_node_clicked`.
3. Pakai `path_handler.travel_to(node_id)`.
4. Disable locked nodes.
5. Bedakan visual state:
   - locked
   - available
   - current
   - completed
6. Layout kiri ke kanan, boss paling kanan.
7. Gambar dotted path antar node.

Acceptance:

- Saat start hanya node depth 1 atau start candidates yang clickable.
- Setelah selesai depth N, hanya depth N+1 yang connected yang clickable.
- Reopen map tidak regenerate map baru.

### Phase 3 - Route tiap node ke scene yang benar

Tujuan: klik node membuka mode gameplay yang sesuai.

Routes:

| Node Type | Route |
| --- | --- |
| Battle | Combat normal |
| Elite | Combat elite |
| Rest | Rest/Shop gate |
| Luck Event | LuckEventScreen |
| Loot | LootScreen |
| Boss | Combat boss |

Tasks:

1. Buat satu function `resolve_node_entered(node)` di `RunManager` atau
   `GameManager`.
2. Jangan hardcode terlalu banyak di `MapScreen`.
3. Setelah screen selesai, panggil `RunManager.complete_current_node()`.
4. Setelah complete, balik ke map dan unlock next.

Acceptance:

- Map -> Battle -> reward -> Map.
- Map -> Rest -> Map.
- Map -> Loot -> Map.
- Map -> Luck -> Map.
- Boss win -> RunResult victory.

### Phase 4 - Event screen sesuai spec baru

Tujuan: Luck Event bukan mock.

Files target:

- `tiles_isometric_testing/ui/roguelike/EventScreen.gd`
- `tiles_isometric_testing/systems/events/LuckEventHandler.gd`

Tasks:

1. Ganti mock button menjadi Yes/No untuk P1 dan P2.
2. Track consensus.
3. Timer default ke No.
4. Yes resolve 50/50 buff/debuff.
5. No langsung complete node tanpa konsekuensi.

Acceptance:

- Kedua player Yes -> roll 50/50.
- Kedua player No -> no consequence.
- Beda pilihan -> tunggu consensus/timer.

### Phase 5 - Loot 5 item, dua player pick

Tujuan: Loot node sesuai gambar.

Files target:

- `tiles_isometric_testing/ui/roguelike/LootScreen.gd`
- `tiles_isometric_testing/systems/events/RestLootHandler.gd`
- `tiles_isometric_testing/systems/items/ItemRegistry.gd`

Tasks:

1. Generate 5 item.
2. Tampilkan 5 card.
3. P1 pilih 1, P2 pilih 1.
4. Highlight item yang dipilih.
5. Add item ke inventory player masing-masing.
6. Enable continue setelah kedua player selesai.

Acceptance:

- Tidak lanjut sebelum P1 dan P2 memilih.
- Inventory P1/P2 bertambah sesuai pilihan.

### Phase 6 - Shop/Rest gate

Tujuan: sebelum elite/boss player bisa memilih rest atau shop.

Files target:

- `RestScreen.gd`
- `ShopScreen.gd`
- optional new scene: `SafeAreaChoiceScreen.tscn`

Recommended:

1. Buat `SafeAreaChoiceScreen`.
2. Pilihan `Rest` membuka RestScreen.
3. Pilihan `Shop` membuka ShopScreen.
4. Setelah selesai salah satu, complete node.

Acceptance:

- Depth 4/9/14 bisa masuk Rest atau Shop.
- Satu node tidak bisa dipakai dua kali untuk rest lalu shop kecuali memang
  desainnya mengizinkan.

## Assets Yang Perlu Disiapkan

Map visual:

- Background parchment/map.
- Dotted path texture atau shader/Line2D style.
- Start marker.
- Current player marker.
- Locked node overlay.
- Completed node overlay.
- Hover/selected frame.

Node icons:

- Battle: skull/mob.
- Elite: skull api/mid boss.
- Boss: crowned skull/last boss.
- Rest: campfire.
- Luck Event: question mark atau siput.
- Loot: chest.
- Shop: shop/coin/cart.

UI assets:

- Item card frame common/rare/legendary/cursed.
- Button frame untuk P1 dan P2 selection.
- Coin icon.
- HP icon.
- Energy charge icon.
- Spell slot icon.

Event art:

- Luck Event background siput tertiban kayu.
- Rest campfire background.
- Shop background.
- Loot room/background.

Audio optional:

- Node select.
- Node unlock.
- Battle enter.
- Item reveal.
- Shop buy.
- Luck success/fail.
- Rest heal.

## Data Yang Harus Disiapkan

Encounter data:

- Normal battle encounter pool per section.
- Elite battle 1 and 2.
- Last boss encounter.
- Reward table per battle type.

Item data:

- Item id.
- Name.
- Rarity.
- Description.
- Icon path.
- Price.
- Effect id / stat modifier.
- Stack/unique rule.

Luck data:

- Buff pool.
- Debuff pool.
- Text result success/fail.
- Whether debuff can be cleansed at Rest.

Shop data:

- Number of item slots.
- Price formula.
- Reroll cost.
- Send coin rules.
- Whether shop stock is shared or per player.

Rest data:

- Restore percentage.
- Treasure item pool.
- Whether rest removes debuff/cursed item.

## Current Code Mapping

Already exists:

- `NodeGraph.gd`: procedural graph and node type enum.
- `PathHandler.gd`: unlock resolver.
- `MapScreen.gd`: map UI and routes for battle/shop/loot/rest.
- `RestScreen.gd`: rest consensus UI.
- `LootScreen.gd`: card reveal prototype.
- `ShopScreen.gd`: shop prototype.
- `LuckEventHandler.gd`: event handler with consensus/roll logic.
- `WinLoseHandler.gd`: battle reward/penalty.
- `ItemPoolGenerator.gd`: item rarity generator.

Needs change:

- `MapScreen.gd` currently creates graph locally; move graph state to
  `RunManager`.
- `MapScreen.gd` currently allows debug teleport; use real `PathHandler`.
- `EventScreen.gd` is still mock; connect it to `LuckEventHandler`.
- `LootScreen.gd` uses 3 cards; update to 5 cards and two-player pick.
- `RestScreen.gd` has 4 options; align MVP to 3 options unless cursed purge
  stays as extra feature.
- `RunManager.gd` currently has placeholder map generation comments; make it
  own graph seed, current node, completed nodes, and node completion flow.

## Suggested First Implementation Slice

Mulai dari slice kecil ini supaya cepat terasa jalan:

1. Update `NodeGraph.gd` agar generate 15 depth dengan fixed node rules.
2. Update `RunManager.gd` agar menyimpan graph dan path handler.
3. Update `MapScreen.gd` agar memakai graph dari `RunManager`.
4. Matikan debug teleport dan aktifkan real unlock.
5. Route `EVENT` ke `EventScreen` walau screen masih simple.

Kenapa mulai dari sini:

- Ini fondasi semua node.
- Kalau graph dan unlock belum benar, Rest/Loot/Shop sebagus apa pun akan
  terasa lepas dari run.
- Setelah map flow stabil, tiap node screen bisa dipoles satu per satu tanpa
  bongkar ulang struktur utama.

## MVP Checklist

- [ ] Generated map has 15 depth.
- [ ] Start is left, boss is right.
- [ ] Depth 5 and 10 are Elite.
- [ ] Depth 4, 9, 14 are Rest/Safe Area.
- [ ] Depth 15 is Boss.
- [ ] Exactly 1 Luck Event per run.
- [ ] Exactly 2 Loot nodes per run.
- [ ] Locked nodes cannot be clicked.
- [ ] Current graph persists after leaving and returning to MapScreen.
- [ ] Battle node enters combat.
- [ ] Elite node enters elite combat.
- [ ] Rest node opens rest/shop choice.
- [ ] Luck node opens yes/no event.
- [ ] Loot node lets both players pick 1 from 5.
- [ ] Boss node ends run on victory.

