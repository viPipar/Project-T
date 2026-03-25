extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  SelectionCursor
#
#  States (sesuai nama animasi di CursorSprite SpriteFrames):
#    "valid"   — tile kosong, masih dalam jangkauan    → hijau
#    "invalid" — di luar jangkauan atau terblokir      → merah
#    "entity"  — ada entitas, tile sebelahnya reachable → kuning
#    "self"    — tile player sendiri                   → biru
#
#  Highlight ditampilkan lewat AnimatedSprite2D ($CursorSprite),
#  bukan lagi draw_colored_polygon (tint).
# ─────────────────────────────────────────────────────────────────────────────

@onready var _sprite: AnimatedSprite2D = $CursorSprite

var _player: Node2D = null
var _state:  String = "valid"


func bind(player: Node) -> void:
	_player = player


func _process(_delta: float) -> void:
	if _player == null:
		return

	var target: Vector2i = Vector2i(-1, -1)
	if _player._cursor != null and _player._cursor.has_method("get_hovered_tile"):
		target = _player._cursor.get_hovered_tile()

	if target.x < 0:
		visible = false
		return

	var origin: Vector2i = _player.grid_pos

	if target == origin:
		_show("self", target)
		return

	if GridManager.has_entity_at(target):
		var reachable_adj := _has_reachable_adjacent(origin, target, _player.get_movement_left())
		_show("entity" if reachable_adj else "invalid", target)
		return

	var cost := GridManager.get_path_cost(origin, target)
	var reachable: bool = cost >= 0 and cost <= _player.get_movement_left()
	_show("valid" if reachable else "invalid", target)


func _show(state: String, grid_pos: Vector2i) -> void:
	_state   = state
	position = IsoUtils.world_to_iso(grid_pos)
	z_index  = IsoUtils.get_depth(grid_pos) + 1
	visible  = true

	# Ganti animasi hanya kalau state berubah (hindari restart animasi tiap frame)
	if _sprite.animation != state or not _sprite.is_playing():
		_sprite.play(state)


# ── Helpers ───────────────────────────────────────────────────────────────────

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
