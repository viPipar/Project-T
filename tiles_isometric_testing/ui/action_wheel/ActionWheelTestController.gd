extends Control

var loaded_abilities: Array[BaseAbility] = []

var dummy_caster: Node
var dummy_target: Node

@onready var action_wheel_left = $LeftSide/ActionWheelLeft
@onready var action_wheel_right = $RightSide/ActionWheelRight

func _ready() -> void:
	_load_abilities()
	_setup_dummies()
	
	action_wheel_left.visible = false
	action_wheel_right.visible = false
	
	action_wheel_left.action_selected.connect(_on_player_1_ability_selected)
	action_wheel_right.action_selected.connect(_on_player_2_ability_selected)

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

func _setup_dummies() -> void:
	# Create caster (Player 1)
	dummy_caster = Node.new()
	dummy_caster.name = "DummyPlayer1"
	
	var script1 = GDScript.new()
	script1.source_code = "extends Node\nvar player_id = 1\nvar grid_pos = Vector2(0,0)\nvar is_alive = true"
	script1.reload()
	dummy_caster.set_script(script1)

	var caster_health = HealthComponent.new()
	caster_health.name = "HealthComponent"
	dummy_caster.add_child(caster_health)
	caster_health.owner = dummy_caster
	add_child(dummy_caster)
	caster_health.setup_fixed_max(20, true)
	
	# Create target (Player 2)
	dummy_target = Node.new()
	dummy_target.name = "DummyPlayer2"
	
	var script2 = GDScript.new()
	script2.source_code = "extends Node\nvar player_id = 2\nvar grid_pos = Vector2(1,0)\nvar is_alive = true"
	script2.reload()
	dummy_target.set_script(script2)

	var target_health = HealthComponent.new()
	target_health.name = "HealthComponent"
	dummy_target.add_child(target_health)
	target_health.owner = dummy_target
	add_child(dummy_target)
	target_health.setup_fixed_max(20, true)

func _on_player_1_ability_selected(action_name: String, action_index: int, page_index: int, slot_index: int) -> void:
	_execute_ability(action_index, dummy_caster, dummy_target, "Player 1")

func _on_player_2_ability_selected(action_name: String, action_index: int, page_index: int, slot_index: int) -> void:
	_execute_ability(action_index, dummy_target, dummy_caster, "Player 2")

func _execute_ability(action_index: int, caster: Node, target: Node, caster_name: String) -> void:
	# Removed dummy logic and prints. Main game player script will handle ability execution.
	pass

func _unhandled_input(event: InputEvent) -> void:
	# P1 open (Q or E)
	if (event.is_action_pressed("p1_ability_1") or event.is_action_pressed("p1_ability_2")) and not action_wheel_left.visible and _can_open_wheel(1):
		action_wheel_left.visible = true
		get_viewport().set_input_as_handled()
		
	# P2 open (U or O)
	if (event.is_action_pressed("p2_ability_1") or event.is_action_pressed("p2_ability_2")) and not action_wheel_right.visible and _can_open_wheel(2):
		action_wheel_right.visible = true
		get_viewport().set_input_as_handled()
		
	# Close on Cancel
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
