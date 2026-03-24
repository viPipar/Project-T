extends Node

var killcam_active: bool = false
var is_in_menu: bool = false
# action = "move_up" | "move_down" | "move_left" | "move_right" | "end_turn"
func is_just_pressed(player_id: int, action: String) -> bool:
	if killcam_active:
		return false
	return Input.is_action_just_pressed("p%d_%s" % [player_id, action])

func is_pressed(player_id: int, action: String) -> bool:
	if killcam_active:
		return false
	return Input.is_action_pressed("p%d_%s" % [player_id, action])

func get_movement_dir(player_id: int) -> Vector2i:
	if killcam_active:
		return Vector2i.ZERO
	var dir := Vector2i.ZERO
	if is_just_pressed(player_id, "move_up"):    dir.y -= 1
	if is_just_pressed(player_id, "move_down"):  dir.y += 1
	if is_just_pressed(player_id, "move_left"):  dir.x -= 1
	if is_just_pressed(player_id, "move_right"): dir.x += 1
	return dir
	
func is_confirm_pressed(player_id: int) -> bool:
	if is_in_menu:
		return false
	if player_id == 1:
		return Input.is_action_just_pressed("p1_confirm")
	elif player_id == 2:
		return Input.is_action_just_pressed("p2_confirm")
	return false
