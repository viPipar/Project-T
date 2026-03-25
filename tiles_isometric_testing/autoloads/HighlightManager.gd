extends Node

# =============================================================================
#  HighlightManager  (Autoload)
#
#  Sistem highlight ubin berbasis AnimatedSprite2D.
#  Setiap warna/tipe highlight punya AnimatedSprite2D sendiri di HighlightLayer.tscn,
#  sehingga tiap ubin yang menyala pakai animasi gerak — bukan sekadar tint warna.
#
#  CARA PAKAI:
#    HighlightManager.show_tiles(tiles, "move")      # highlight banyak tile
#    HighlightManager.show_tile(pos, "attack")       # highlight satu tile
#    HighlightManager.clear("move")                  # hapus satu tipe
#    HighlightManager.clear_all()                    # hapus semua
#
#  TIPE HIGHLIGHT YANG TERSEDIA:
#    "move"     → hijau   (tile yang bisa dilewati)
#    "attack"   → merah   (tile serangan / jangkauan)
#    "select"   → biru    (tile yang sedang dipilih)
#    "skill"    → ungu    (tile efek skill)
#    "hover"    → kuning  (tile yang sedang di-hover)
#    "danger"   → oranye  (tile bahaya / ancaman musuh)
#    Tambah tipe baru cukup di HIGHLIGHT_CONFIG + HighlightLayer.tscn
# =============================================================================

# -- Konfigurasi tipe highlight -----------------------------------------------
#  "node_name" → nama AnimatedSprite2D di dalam HighlightLayer.tscn
#  "anim"      → nama animasi di SpriteFrames node tersebut
#  "z_offset"  → z_index relatif di atas tile (hindari z-fighting)
const HIGHLIGHT_CONFIG: Dictionary = {
	"move":   { "node_name": "MoveHighlight",   "anim": "move",   "z_offset": 1 },
	"attack": { "node_name": "AttackHighlight", "anim": "attack", "z_offset": 2 },
	"select": { "node_name": "SelectHighlight", "anim": "select", "z_offset": 3 },
	"skill":  { "node_name": "SkillHighlight",  "anim": "skill",  "z_offset": 2 },
	"hover":  { "node_name": "HoverHighlight",  "anim": "hover",  "z_offset": 4 },
	"danger": { "node_name": "DangerHighlight", "anim": "danger", "z_offset": 1 },
}

# -- State internal -----------------------------------------------------------
var _layer: Node2D = null                              # referensi ke HighlightLayer node
var _active: Dictionary = {}                           # tipe → Array[AnimatedSprite2D] yang sedang aktif
var _pool:   Dictionary = {}                           # tipe → Array[AnimatedSprite2D] (pool reuse)


# =============================================================================
#  Setup — dipanggil sekali oleh HighlightLayer saat _ready()
# =============================================================================

## Daftarkan HighlightLayer ke manager ini.
## HighlightLayer.gd memanggil fungsi ini di _ready() miliknya.
func register_layer(layer: Node2D) -> void:
	_layer = layer
	_active.clear()
	_pool.clear()
	for key in HIGHLIGHT_CONFIG:
		_active[key] = []
		_pool[key]   = []


# =============================================================================
#  Public API
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


## Hapus SEMUA highlight dari semua tipe.
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
#  Internal — Pool & Placement
# =============================================================================

func _place_sprite(grid_pos: Vector2i, type: String) -> void:
	if _layer == null:
		push_error("HighlightManager: layer belum diregister! Pastikan HighlightLayer ada di scene.")
		return

	var cfg: Dictionary = HIGHLIGHT_CONFIG[type]

	# Ambil sprite dari pool, atau buat baru dari template di HighlightLayer
	var sprite: AnimatedSprite2D = _get_from_pool(type)
	if sprite == null:
		sprite = _create_sprite(type, cfg)
		if sprite == null:
			return  # node template tidak ditemukan, skip

	# Posisikan di tile
	sprite.position = IsoUtils.world_to_iso(grid_pos)
	sprite.z_index  = IsoUtils.get_depth(grid_pos) + cfg.z_offset
	sprite.set_meta("grid_pos", grid_pos)
	sprite.visible  = true

	# Mulai / pastikan animasi berjalan
	if sprite.animation != cfg.anim or not sprite.is_playing():
		sprite.play(cfg.anim)

	_active[type].append(sprite)


func _create_sprite(type: String, cfg: Dictionary) -> AnimatedSprite2D:
	# Tambahkan 'as String' agar Godot tahu tipenya
	var template_path: String = cfg["node_name"] as String 
	
	if not _layer.has_node(template_path):
		push_warning("HighlightManager: node '%s' tidak ditemukan." % template_path)
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
