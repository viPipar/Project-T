extends Node2D

@export var color_valid:   Color = Color(0.2, 1.0, 0.4, 0.55)
@export var color_invalid: Color = Color(1.0, 0.2, 0.2, 0.45)
@export var color_self:    Color = Color(0.1, 0.1, 0.1, 0.3)

var _player: Node2D = null
var _state: String = "valid"
func bind(player: Node) -> void:
	_player = player
	var player_id: int = _player.get_player_id()
	var factor := float(player_id) * 0.3
	color_valid = Color(
		0.2,
		clamp(1.0 + factor, 0.0, 1.0),
		clamp(0.4 + factor, 0.0, 1.0),
		0.55
	)

func _process(_delta: float) -> void:
	if _player == null:
		return

	var target: Vector2i = _player.target_pos
	var origin: Vector2i = _player.grid_pos

	if target == origin:
		_show("self", target)
		return

	var cost = GridManager.get_path_cost(origin, target)
	if cost == null:
		_show("invalid", target)
		return
		
	var reachable: bool = cost >= 0 and cost <= _player.get_movement_left()	
	_show("valid" if reachable else "invalid", target)

func _show(state: String, grid_pos: Vector2i) -> void:
	_state = state
	position = IsoUtils.world_to_iso(grid_pos)
	z_index  = IsoUtils.get_depth(grid_pos) + 1
	visible  = true
	queue_redraw()

func _draw() -> void:
	var hw := IsoUtils.TILE_W / 2.0
	var hh := IsoUtils.TILE_H / 2.0
	var pts := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0),
		Vector2(0,  hh), Vector2(-hw, 0),
	])
	var col: Color = color_invalid if _state == "invalid" \
		else color_self if _state == "self" \
		else color_valid
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), col.lightened(0.3), 2.0)
