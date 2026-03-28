extends Node

# =============================================================================
#  HighlightManager  (Autoload)
#
#  Sistem highlight ubin berbasis AnimatedSprite2D.
#  Setiap warna/tipe highlight punya AnimatedSprite2D sendiri di HighlightLayer.tscn,
#  sehingga tiap ubin yang menyala pakai animasi gerak — bukan sekadar tint warna.
#
#  ─── CARA PAKAI UMUM ───────────────────────────────────────────────────────
#    HighlightManager.show_tiles(tiles, "move")      # highlight banyak tile
#    HighlightManager.show_tile(pos, "attack")       # highlight satu tile
#    HighlightManager.clear("move")                  # hapus satu tipe
#    HighlightManager.clear_all()                    # hapus semua
#
#  ─── CARA PAKAI CURSOR (per player) ────────────────────────────────────────
#    HighlightManager.show_cursor(pos, 1, "valid")   # cursor P1 state valid
#    HighlightManager.show_cursor(pos, 2, "entity")  # cursor P2 state entity
#    HighlightManager.clear_cursor(1)                # hapus cursor P1
#
#  ─── STATE CURSOR YANG VALID ────────────────────────────────────────────────
#    "valid"   → tile kosong, dalam jangkauan        (P1: hijau,  P2: ungu)
#    "invalid" → di luar jangkauan / terblokir       (P1&P2: merah)
#    "entity"  → ada entitas, adjacent reachable     (P1&P2: kuning)
#    "self"    → tile milik player sendiri           (P1&P2: biru)
#
#  ─── TIPE HIGHLIGHT GAMEPLAY ────────────────────────────────────────────────
#    "move"     → hijau   (tile yang bisa dilewati)
#    "attack"   → merah   (tile serangan / jangkauan)
#    "select"   → biru    (tile yang sedang dipilih)
#    "skill"    → ungu    (tile efek skill)
#    "hover"    → kuning  (tile yang sedang di-hover)
#    "danger"   → oranye  (tile bahaya / ancaman musuh)
# =============================================================================

# -- Konfigurasi tipe highlight -----------------------------------------------
#  "node_name" → nama AnimatedSprite2D di dalam HighlightLayer.tscn
#  "anim"      → animasi default; untuk cursor dioverride via show_cursor()
#  "z_offset"  → z_index relatif di atas tile (hindari z-fighting)
const HIGHLIGHT_CONFIG: Dictionary = {
	# ── Gameplay highlights ──────────────────────────────────────────────────
	"move":      { "node_name": "MoveHighlight",      "anim": "move",   "z_offset": 1 },
	"move_p1":   { "node_name": "MoveHighlight",      "anim": "move",   "z_offset": 1 },
	"move_p2":   { "node_name": "MoveHighlight",      "anim": "move",   "z_offset": 1 },
	"attack":    { "node_name": "AttackHighlight",    "anim": "attack", "z_offset": 2 },
	"select":    { "node_name": "SelectHighlight",    "anim": "select", "z_offset": 3 },
	"skill":     { "node_name": "SkillHighlight",     "anim": "skill",  "z_offset": 2 },
	"hover":     { "node_name": "HoverHighlight",     "anim": "hover",  "z_offset": 4 },
	"danger":    { "node_name": "DangerHighlight",    "anim": "danger", "z_offset": 1 },
	# ── Cursor highlights (multi-animasi, gunakan show_cursor()) ─────────────
	# CursorP1Highlight punya animasi: valid(hijau), invalid(merah), entity(kuning), self(biru)
	# CursorP2Highlight punya animasi: valid(ungu),  invalid(merah), entity(kuning), self(biru)
	"cursor_p1": { "node_name": "CursorP1Highlight", "anim": "valid",  "z_offset": 5 },
	"cursor_p2": { "node_name": "CursorP2Highlight", "anim": "valid",  "z_offset": 5 },
	"cursor_p1_back": {"node_name" : "CursorP1HighlightBack", "anim": "valid","z_offset": 0 },
	"cursor_p2_back": {"node_name" : "CursorP2HighlightBack", "anim": "valid","z_offset": 0 },
}

# State cursor yang boleh dipakai di show_cursor()
const CURSOR_STATES: Array[String] = ["valid", "invalid", "entity", "self"]

# -- State internal -----------------------------------------------------------
var _layer: Node2D = null                              # referensi ke HighlightLayer node
var _active: Dictionary = {}                           # tipe → Array[AnimatedSprite2D]
var _pool:   Dictionary = {}                           # tipe → Array[AnimatedSprite2D] (reuse)


# =============================================================================
#  Setup — dipanggil sekali oleh HighlightLayer saat _ready()
# =============================================================================

## Daftarkan HighlightLayer ke manager ini.
func register_layer(layer: Node2D) -> void:
	_layer = layer
	_active.clear()
	_pool.clear()
	for key in HIGHLIGHT_CONFIG:
		_active[key] = []
		_pool[key]   = []


# =============================================================================
#  Public API — Gameplay Highlights
# =============================================================================

## Tampilkan highlight untuk SATU tile.
## [param grid_pos]  posisi grid (Vector2i)
## [param type]      tipe highlight (String), lihat HIGHLIGHT_CONFIG
func show_tile(grid_pos: Vector2i, type: String) -> void:
	if not _is_valid_type(type):
		return
	_place_sprite(grid_pos, type)


## Tampilkan highlight untuk BANYAK tile sekaligus.
## [param tiles]  Array[Vector2i] posisi grid
## [param type]   tipe highlight (String)
func show_tiles(tiles: Array, type: String) -> void:
	if not _is_valid_type(type):
		return
	for pos in tiles:
		_place_sprite(pos, type)


## Hapus semua highlight untuk satu tipe tertentu.
func clear(type: String) -> void:
	if not _active.has(type):
		return
	for sprite in _active[type]:
		_return_to_pool(sprite, type)
	_active[type].clear()


## Hapus SEMUA highlight dari semua tipe (termasuk cursor).
func clear_all() -> void:
	for type in _active.keys():
		clear(type)


## Ganti highlight: hapus tipe dulu, lalu isi ulang dengan tiles baru.
## Berguna untuk update highlight setiap giliran tanpa duplicate.
func replace_tiles(tiles: Array, type: String) -> void:
	clear(type)
	show_tiles(tiles, type)


## Cek apakah tile tertentu sedang di-highlight oleh tipe tertentu.
func is_highlighted(grid_pos: Vector2i, type: String) -> bool:
	if not _active.has(type):
		return false
	for sprite in _active[type]:
		if sprite.get_meta("grid_pos", Vector2i(-1, -1)) == grid_pos:
			return true
	return false


# =============================================================================
#  Public API — Cursor Highlights
# =============================================================================

## Tampilkan cursor highlight untuk satu player di tile tertentu.
##
## Contoh penggunaan:
##   HighlightManager.show_cursor(Vector2i(3, 4), 1, "valid")
##   HighlightManager.show_cursor(Vector2i(5, 2), 2, "invalid")
##
## [param grid_pos]  posisi grid (Vector2i)
## [param player_id] nomor player (1 atau 2)
## [param state]     "valid" | "invalid" | "entity" | "self"
func show_cursor(grid_pos: Vector2i, player_id: int, state: String) -> void:
	var type := "cursor_p%d" % player_id
	if not _is_valid_type(type):
		return
	if not state in CURSOR_STATES:
		push_warning("HighlightManager: state cursor '%s' tidak valid. Gunakan: %s" % [state, CURSOR_STATES])
		return
	# Cursor hanya 1 tile aktif sekaligus — clear dulu sebelum place
	clear(type)
	_place_sprite(grid_pos, type, state)

func show_back_cursor(grid_pos: Vector2i, player_id: int, state: String) -> void:
	var type := "cursor_p%d_back" % player_id
	if not _is_valid_type(type):
		return
	if not state in CURSOR_STATES:
		push_warning("HighlightManager: state cursor '%s' tidak valid. Gunakan: %s" % [state, CURSOR_STATES])
		return
	# Cursor hanya 1 tile aktif sekaligus — clear dulu sebelum place
	clear(type)
	_place_sprite(grid_pos, type, state)

## Hapus cursor highlight untuk player tertentu.
##
## Contoh: HighlightManager.clear_cursor(1)
func clear_cursor(player_id: int) -> void:
	clear("cursor_p%d" % player_id)
	
func clear_cursor_back(player_id: int) -> void:
	clear("cursor_p%d_back" % player_id)


## Pindahkan cursor ke tile baru (clear + show dalam satu call).
## Berguna dipanggil setiap frame jika posisi berubah.
##
## [param grid_pos]  posisi grid baru
## [param player_id] nomor player (1 atau 2)
## [param state]     "valid" | "invalid" | "entity" | "self"
func move_cursor(grid_pos: Vector2i, player_id: int, state: String) -> void:
	show_cursor(grid_pos, player_id, state)  # show_cursor sudah clear sebelum place
	show_back_cursor(grid_pos,player_id,state)

# =============================================================================
#  Internal — Pool & Placement
# =============================================================================

## Tempatkan sprite highlight di grid_pos.
## [param anim_override] jika tidak kosong, pakai animasi ini alih-alih cfg.anim
## (digunakan oleh cursor yang satu node-template-nya punya banyak animasi)
func _place_sprite(grid_pos: Vector2i, type: String, anim_override: String = "") -> void:
	
	if _layer == null:
		push_error("HighlightManager: layer belum diregister! Pastikan HighlightLayer ada di scene.")
		return

	var cfg: Dictionary = HIGHLIGHT_CONFIG[type]
	var anim: String    = anim_override if anim_override != "" else cfg.anim

	# Ambil sprite dari pool, atau buat baru dari template di HighlightLayer
	var sprite: AnimatedSprite2D = _get_from_pool(type)
	if sprite == null:
		sprite = _create_sprite(type, cfg)
		if sprite == null:
			return  # node template tidak ditemukan, skip

	# Posisikan di tile
	sprite.position = IsoUtils.world_to_iso(grid_pos)
	#ngatur z-index
	var template_node := _layer.get_node(cfg["node_name"]) as AnimatedSprite2D
	var inspector_z_offset: int = template_node.z_index  # baca dari inspector
	var inspector_pos_offset: Vector2 = template_node.position
	sprite.position = IsoUtils.world_to_iso(grid_pos) + inspector_pos_offset  # ← pakai offset
	sprite.z_index = IsoUtils.get_depth(grid_pos) + inspector_z_offset
	sprite.set_meta("grid_pos", grid_pos)
	sprite.visible  = true

	# Mulai / ganti animasi jika perlu
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)

	_active[type].append(sprite)


func _create_sprite(type: String, cfg: Dictionary) -> AnimatedSprite2D:
	var template_path: String = cfg["node_name"] as String

	if not _layer.has_node(template_path):
		push_warning("HighlightManager: node '%s' tidak ditemukan di HighlightLayer." % template_path)
		return null

	var template := _layer.get_node(template_path) as AnimatedSprite2D
	if template == null:
		return null

	var clone := template.duplicate() as AnimatedSprite2D
	clone.visible = false
	_layer.add_child(clone)
	return clone


func _get_from_pool(type: String) -> AnimatedSprite2D:
	if _pool[type].is_empty():
		return null
	return _pool[type].pop_back() as AnimatedSprite2D


func _return_to_pool(sprite: AnimatedSprite2D, type: String) -> void:
	sprite.visible = false
	sprite.stop()
	_pool[type].append(sprite)


func _is_valid_type(type: String) -> bool:
	if not HIGHLIGHT_CONFIG.has(type):
		push_warning("HighlightManager: tipe '%s' tidak ada di HIGHLIGHT_CONFIG." % type)
		return false
	return true
