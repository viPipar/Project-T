extends Node

var killcam_active: bool = false
var is_in_menu: bool = false

var relic_focus_p1: bool = false
var relic_focus_p2: bool = false

# Blok input per-player saat animasi dice combat berjalan
var _player_blocked: Dictionary = {1: false, 2: false}
var _player_menu_blocked: Dictionary = {1: false, 2: false}

## Set blok input untuk player tertentu (1 atau 2)
func set_player_blocked(player_id: int, blocked: bool) -> void:
	_player_blocked[player_id] = blocked

## Cek apakah player sedang di-blok (misal: saat roll dadu)
func is_player_blocked(player_id: int) -> bool:
	if player_id == 1:
		return _player_blocked.get(1, false) or relic_focus_p1
	else:
		return _player_blocked.get(2, false) or relic_focus_p2

## Cek menu blocked
func is_player_menu_blocked(player_id: int) -> bool:
	return _player_menu_blocked.get(player_id, false)

## Blok input gameplay untuk satu player saat UI modal miliknya terbuka.
func set_player_menu_blocked(player_id: int, blocked: bool) -> void:
	_player_menu_blocked[player_id] = blocked

# action = "move_up" | "move_down" | "move_left" | "move_right" | "end_turn"
func _can_accept_input(player_id: int) -> bool:
	if killcam_active or is_in_menu:
		return false
	if _player_menu_blocked.get(player_id, false):
		return false
	if _player_blocked.get(player_id, false):
		return false
	if player_id == 1 and relic_focus_p1:
		return false
	if player_id == 2 and relic_focus_p2:
		return false
	if TurnManager != null and not TurnManager.can_player_act(player_id):
		return false
	return true

# action = "move_up" | "move_down" | "move_left" | "move_right" | "end_turn"
func is_just_pressed(player_id: int, action: String) -> bool:
	if not _can_accept_input(player_id):
		return false
	return Input.is_action_just_pressed("p%d_%s" % [player_id, action])

func is_pressed(player_id: int, action: String) -> bool:
	if not _can_accept_input(player_id):
		return false
	return Input.is_action_pressed("p%d_%s" % [player_id, action])

func _can_accept_end_turn_input(player_id: int) -> bool:
	if killcam_active or is_in_menu:
		return false
	if _player_menu_blocked.get(player_id, false):
		return false
	if _player_blocked.get(player_id, false):
		return false
	if player_id == 1 and relic_focus_p1:
		return false
	if player_id == 2 and relic_focus_p2:
		return false
	if TurnManager == null:
		return true
	if TurnManager.phase != TurnManager.Phase.PLAYERS:
		return false
	if TurnManager.is_player_ended(player_id):
		return true
	return TurnManager.can_player_act(player_id)

func get_movement_dir(player_id: int) -> Vector2i:
	if killcam_active or is_in_menu or _player_menu_blocked.get(player_id, false):
		return Vector2i.ZERO
	var up_pressed := is_pressed(player_id, "move_up")
	var down_pressed := is_pressed(player_id, "move_down")
	var left_pressed := is_pressed(player_id, "move_left")
	var right_pressed := is_pressed(player_id, "move_right")

	var up_just := is_just_pressed(player_id, "move_up")
	var down_just := is_just_pressed(player_id, "move_down")
	var left_just := is_just_pressed(player_id, "move_left")
	var right_just := is_just_pressed(player_id, "move_right")

	# Chorded diagonals (screen diagonals) for intuitive access:
	# up+left  -> (-1, 0)
	# up+right -> (0, -1)
	# down+left  -> (0, 1)
	# down+right -> (1, 0)
	if up_pressed and left_pressed and (up_just or left_just):
		return Vector2i(-1, 0)
	if up_pressed and right_pressed and (up_just or right_just):
		return Vector2i(0, -1)
	if down_pressed and left_pressed and (down_just or left_just):
		return Vector2i(0, 1)
	if down_pressed and right_pressed and (down_just or right_just):
		return Vector2i(1, 0)

	# Screen-space isometric directions:
	# right  -> ( +1, -1 )
	# left   -> ( -1, +1 )
	# up     -> ( -1, -1 )
	# down   -> ( +1, +1 )
	if up_just:
		return Vector2i(-1, -1)
	if down_just:
		return Vector2i(1, 1)
	if left_just:
		return Vector2i(-1, 1)
	if right_just:
		return Vector2i(1, -1)

	return Vector2i.ZERO
	
func is_confirm_pressed(player_id: int) -> bool:
	if not _can_accept_input(player_id):
		return false
	if player_id == 1:
		return Input.is_action_just_pressed("p1_confirm")
	elif player_id == 2:
		return Input.is_action_just_pressed("p2_confirm")
	return false

func is_end_turn_pressed(player_id: int) -> bool:
	if not _can_accept_end_turn_input(player_id):
		return false
	return Input.is_action_just_pressed("p%d_end_turn" % player_id)
