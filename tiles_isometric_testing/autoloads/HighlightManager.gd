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
	"move_p1":   { "node_name": "MoveP1Highlight",    "anim": "move",   "z_offset": 1 },
	"move_p2":   { "node_name": "MoveP2Highlight",    "anim": "move",   "z_offset": 1 },
	"attack":    { "node_name": "AttackHighlight",    "anim": "attack", "z_offset": 2 },
	"select":    { "node_name": "SelectEntityHighlight", "anim": "select", "z_offset": 3 },
	"skill":     { "node_name": "SkillHighlight",     "anim": "skill",  "z_offset": 2 },
	"hover":     { "node_name": "HoverHighlight",     "anim": "hover",  "z_offset": 4 },
	"danger":    { "node_name": "DangerHighlight",    "anim": "danger", "z_offset": 1 },
	"skill_target": { "node_name": "SkillTarget", "anim": "select", "z_offset": 5 },
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
var _active: Dictionary = {}                           # tipe → Array[Node2D]
var _pool:   Dictionary = {}                           # tipe → Array[Node2D] (reuse)

var _shader: Shader = preload("res://ui/shared/hand_drawn_highlight.gdshader")


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
func show_tile(grid_pos: Vector2i, type: String, player_id: int = 0) -> void:
	if not _is_valid_type(type): return
	_place_rect(grid_pos, type, "", player_id)
	_update_borders(type)

## Tampilkan highlight untuk BANYAK tile sekaligus.
func show_tiles(tiles: Array, type: String, player_id: int = 0) -> void:
	if not _is_valid_type(type): return
	for pos in tiles:
		_place_rect(pos, type, "", player_id)
	_update_borders(type)

## Hapus semua highlight untuk satu tipe tertentu.
func clear(type: String) -> void:
	if not _active.has(type): return
	for rect in _active[type]:
		_return_to_pool(rect, type)
	_active[type].clear()

## Hapus SEMUA highlight dari semua tipe (termasuk cursor).
func clear_all() -> void:
	for type in _active.keys():
		clear(type)

## Ganti highlight: hapus tipe dulu, lalu isi ulang dengan tiles baru.
func replace_tiles(tiles: Array, type: String, player_id: int = 0) -> void:
	clear(type)
	show_tiles(tiles, type, player_id)

## Cek apakah tile tertentu sedang di-highlight oleh tipe tertentu.
func is_highlighted(grid_pos: Vector2i, type: String) -> bool:
	if not _active.has(type): return false
	for rect in _active[type]:
		if rect.get_meta("grid_pos", Vector2i(-1, -1)) == grid_pos:
			return true
	return false


# =============================================================================
#  Public API — Cursor Highlights
# =============================================================================

func show_cursor(grid_pos: Vector2i, player_id: int, state: String) -> void:
	var type := "cursor_p%d" % player_id
	if not _is_valid_type(type): return
	if not state in CURSOR_STATES: return
	clear(type)
	if state == "invalid": return
	_place_rect(grid_pos, type, state, player_id)
	_update_borders(type)

func show_back_cursor(grid_pos: Vector2i, player_id: int, state: String) -> void:
	var type := "cursor_p%d_back" % player_id
	if not _is_valid_type(type): return
	if not state in CURSOR_STATES: return
	clear(type)
	if state == "invalid": return
	_place_rect(grid_pos, type, state, player_id)
	_update_borders(type)

func clear_cursor(player_id: int) -> void:
	clear("cursor_p%d" % player_id)
	
func clear_cursor_back(player_id: int) -> void:
	clear("cursor_p%d_back" % player_id)

func move_cursor(grid_pos: Vector2i, player_id: int, state: String) -> void:
	show_cursor(grid_pos, player_id, state)
	show_back_cursor(grid_pos, player_id, state)


# =============================================================================
#  Internal — Pool & Placement
# =============================================================================

func _get_color_for_state(state: String, is_p1: bool) -> Color:
	if state == "valid": return Color(0.2, 0.8, 0.3) if is_p1 else Color(0.7, 0.2, 0.9)
	if state == "invalid": return Color(0.9, 0.1, 0.1)
	if state == "entity": return Color(0.9, 0.8, 0.1)
	if state == "self": return Color(0.1, 0.6, 1.0)
	return Color(1, 1, 1)

func _get_color_for_type(type: String) -> Color:
	if type == "move_p1": return Color(0.6, 0.1, 0.1) # Merah agak hitam (Crimson/Dark Red)
	if type == "move_p2": return Color(0.9, 0.9, 0.6) # Putih agak kuning (Pale Yellow)
	if type.begins_with("move"): return Color(0.1, 0.6, 0.9) # Biru segar untuk gerak
	if type == "attack": return Color(0.9, 0.1, 0.1)
	if type == "skill_target": return Color(0.9, 0.1, 0.3) # Merah Pink/Crimson
	if type == "select": return Color(0.9, 0.9, 0.9)
	if type == "skill": return Color(0.7, 0.2, 0.9)
	if type == "hover": return Color(0.9, 0.8, 0.1)
	if type == "danger": return Color(0.9, 0.5, 0.1)
	return Color(1,1,1)

func _place_rect(grid_pos: Vector2i, type: String, state_override: String = "", player_id: int = 0) -> void:
	if _layer == null: return

	var cfg: Dictionary = HIGHLIGHT_CONFIG[type]
	var node: Node2D = _get_from_pool(type)
	
	if node == null:
		node = Node2D.new()
		# Node2D ini akan di-Y-Sort oleh HighlightLayer
		node.y_sort_enabled = false
		
		if type == "skill_target":
			var iso_wrapper = Node2D.new()
			iso_wrapper.scale = Vector2(1.0, 0.5)
			
			var sprite = Sprite2D.new()
			var tex = preload("res://assets/tiles/ability_highlight.png")
			sprite.texture = tex
			
			# Rotasi 45 dan perhitungan scale agar pas dengan tile 256x128
			sprite.rotation_degrees = 45
			var s = 256.0 / (tex.get_width() * sqrt(2.0))
			sprite.scale = Vector2(s, s)
			
			var mat = ShaderMaterial.new()
			mat.shader = preload("res://ui/shared/shiny_sweep.gdshader")
			sprite.material = mat
			
			iso_wrapper.add_child(sprite)
			node.add_child(iso_wrapper)
		else:
			var rect = ColorRect.new()
			rect.size = Vector2(256, 128)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Offset posisi visual relatif terhadap center
			rect.position = Vector2(-128, -64)
			
			var mat = ShaderMaterial.new()
			mat.shader = _shader
			rect.material = mat
			node.add_child(rect)
			
		node.visible = false
		_layer.add_child(node)

	# Tentukan warna
	var base_color: Color
	if type.begins_with("cursor_"):
		var is_p1 = ("p1" in type)
		base_color = _get_color_for_state(state_override, is_p1)
	else:
		base_color = _get_color_for_type(type)
		
	if type == "skill_target":
		var iso_wrapper = node.get_child(0) as Node2D
		var sprite = iso_wrapper.get_child(0) as Sprite2D
		var mat = sprite.material as ShaderMaterial
		mat.set_shader_parameter("base_color", base_color)
		mat.set_shader_parameter("shine_color", Color(1.0, 1.0, 1.0, 1.0))
		mat.set_shader_parameter("shine_speed", 1.5)
	else:
		var rect = node.get_child(0) as ColorRect
		var mat = rect.material as ShaderMaterial
		var fill = base_color
		# Kurangi opacity fill agar tidak terlalu menyilaukan
		fill.a = 0.25 
		var edge = base_color
		edge.v = min(edge.v + 0.3, 1.0)
		# Kurangi opacity edge sedikit agar lebih soft
		edge.a = 0.85 
		
		mat.set_shader_parameter("fill_color", fill)
		mat.set_shader_parameter("edge_color", edge)

	# Set posisi Node2D ke center tile tepat (untuk Y-Sort yang sempurna)
	node.position = IsoUtils.world_to_iso(grid_pos)
	
	# Z-index dihapus karena kita pakai built-in Y-Sort
	node.z_index = 0
	node.set_meta("grid_pos", grid_pos)
	
	if type.begins_with("cursor_"):
		node.move_to_front()
	
	# Multiplayer visibility
	var vis_layer := 1
	if player_id == 1 or type.ends_with("_p1") or type == "cursor_p1" or type == "cursor_p1_back":
		vis_layer = 2
	elif player_id == 2 or type.ends_with("_p2") or type == "cursor_p2" or type == "cursor_p2_back":
		vis_layer = 4
	node.visibility_layer = vis_layer
	
	# Muncul dengan Tween Juicy
	if not node.visible:
		node.visible = true
		node.scale = Vector2(0.5, 0.5)
		# Pivot ada di (0,0) relatif ke Node2D, yang merupakan center lantai
		var tw = node.create_tween()
		tw.tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_active[type].append(node)


func _get_from_pool(type: String) -> Node2D:
	if _pool[type].is_empty():
		return null
	return _pool[type].pop_back() as Node2D


func _return_to_pool(node: Node2D, type: String) -> void:
	node.visible = false
	_pool[type].append(node)


func _is_valid_type(type: String) -> bool:
	if not HIGHLIGHT_CONFIG.has(type):
		return false
	return true


func _get_material(node: Node) -> ShaderMaterial:
	if node == null:
		return null
	if "material" in node and node.material is ShaderMaterial:
		return node.material as ShaderMaterial
	for child in node.get_children():
		var mat = _get_material(child)
		if mat != null:
			return mat
	return null


func _update_borders(type: String) -> void:
	if not _active.has(type): return
	# Buat lookup set posisi aktif untuk tipe highlight ini
	var active_positions: Dictionary = {}
	for rect in _active[type]:
		var pos = rect.get_meta("grid_pos", Vector2i(-1, -1))
		if pos.x >= 0:
			active_positions[pos] = rect
	
	# Update uniform shader tiap rect berdasarkan keberadaan tetangga
	for pos in active_positions:
		var rect_node = active_positions[pos] as Node2D
		var mat = _get_material(rect_node)
		if mat == null:
			continue
			
		var hide_tl = active_positions.has(pos + Vector2i(-1, 0))
		var hide_tr = active_positions.has(pos + Vector2i(0, -1))
		var hide_bl = active_positions.has(pos + Vector2i(0, 1))
		var hide_br = active_positions.has(pos + Vector2i(1, 0))
		
		mat.set_shader_parameter("hide_tl", hide_tl)
		mat.set_shader_parameter("hide_tr", hide_tr)
		mat.set_shader_parameter("hide_bl", hide_bl)
		mat.set_shader_parameter("hide_br", hide_br)
