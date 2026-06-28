extends Control

var loaded_abilities: Array[BaseAbility] = []

@onready var action_wheel_left = $LeftSide/ActionWheelLeft
@onready var action_wheel_right = $RightSide/ActionWheelRight


func _ready() -> void:
	_load_abilities()

	action_wheel_left.visible = false
	action_wheel_right.visible = false


func _load_abilities() -> void:
	var dir = DirAccess.open("res://combat_core/abilities/instances")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var p1_abilities: PackedStringArray = []
		var p2_abilities: PackedStringArray = []

		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var ability = load("res://combat_core/abilities/instances/" + file_name) as BaseAbility
				if ability:
					loaded_abilities.append(ability)
					if ability.ability_type == BaseAbility.AbilityType.PHYSICAL:
						p1_abilities.append(ability.ability_name)
					else:
						p2_abilities.append(ability.ability_name)
			file_name = dir.get_next()

		action_wheel_left.set_actions(p1_abilities)
		action_wheel_right.set_actions(p2_abilities)
	else:
		push_error("Failed to open abilities directory.")


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("p1_ability_1") or event.is_action_pressed("p1_ability_2")) and not action_wheel_left.visible and _can_open_wheel(1):
		action_wheel_left.visible = true
		get_viewport().set_input_as_handled()

	if (event.is_action_pressed("p2_ability_1") or event.is_action_pressed("p2_ability_2")) and not action_wheel_right.visible and _can_open_wheel(2):
		action_wheel_right.visible = true
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("p1_cancel") and action_wheel_left.visible:
		action_wheel_left.visible = false
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("p2_cancel") and action_wheel_right.visible:
		action_wheel_right.visible = false
		get_viewport().set_input_as_handled()


func _can_open_wheel(player_id: int) -> bool:
	if TurnManager != null and not TurnManager.can_player_act(player_id):
		return false

	for player in get_tree().get_nodes_in_group("players"):
		if player != null and player.get("player_id") == player_id:
			if player.has_method("is_downed") and player.is_downed():
				return false
			return true
	return true
