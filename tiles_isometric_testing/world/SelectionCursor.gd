extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  SelectionCursor
#
#  Logic-only node — tidak ada rendering di sini.
#  Semua highlight ditampilkan lewat HighlightManager.show_cursor().
#
#  States cursor:
#    "valid"   — tile kosong, masih dalam jangkauan    → P1: hijau  / P2: ungu
#    "invalid" — di luar jangkauan atau terblokir      → P1&P2: merah
#    "entity"  — ada entitas, tile sebelahnya reachable → P1&P2: kuning
#    "self"    — tile player sendiri                   → P1&P2: biru
#
#  Highlight di-update hanya saat tile atau state berubah (bukan tiap frame),
#  sehingga aman dipanggil banyak cursor sekaligus.
# ─────────────────────────────────────────────────────────────────────────────

var _player:     Node2D   = null
var _last_pos:   Vector2i = Vector2i(-1, -1)
var _last_state: String   = ""


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _player == null:
		return

	var target: Vector2i = Vector2i(-1, -1)
	if _player._cursor != null and _player._cursor.has_method("get_hovered_tile"):
		target = _player._cursor.get_hovered_tile()

	if target.x < 0:
		_clear_highlight()
		return

	var origin: Vector2i = _player.grid_pos
	var new_state: String

	if target == origin:
		new_state = "self"
	elif GridManager.has_entity_at(target):
		var reachable_adj := _has_reachable_adjacent(origin, target, _player.get_movement_left())
		new_state = "entity" if reachable_adj else "invalid"
	else:
		var cost := GridManager.get_path_cost(origin, target)
		var reachable: bool = cost >= 0 and cost <= _player.get_movement_left()
		new_state = "valid" if reachable else "invalid"

	# Update HighlightManager hanya kalau tile atau state berubah
	if target != _last_pos or new_state != _last_state:
		_last_pos   = target
		_last_state = new_state
		HighlightManager.show_cursor(target, _player.player_id, new_state)


func _exit_tree() -> void:
	_clear_highlight()


# ── Public API ────────────────────────────────────────────────────────────────

## Bind cursor ini ke sebuah Player node.
func bind(player: Node) -> void:
	_player = player


# ── Internal ──────────────────────────────────────────────────────────────────

func _clear_highlight() -> void:
	if _player == null:
		return
	HighlightManager.clear_cursor(_player.player_id)
	_last_pos   = Vector2i(-1, -1)
	_last_state = ""


func _has_reachable_adjacent(origin: Vector2i, entity_tile: Vector2i, budget: int) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if dx != 0 and dy != 0:
				continue  # cardinal only
			var nb := entity_tile + Vector2i(dx, dy)
			if not GridManager.is_walkable(nb):
				continue
			var cost := GridManager.get_path_cost(origin, nb)
			if cost >= 0 and cost <= budget:
				return true
	return false
