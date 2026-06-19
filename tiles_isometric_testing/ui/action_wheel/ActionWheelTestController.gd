extends Control

var loaded_abilities: Array[BaseAbility] = []

var dummy_caster: Node
var dummy_target: Node

@onready var action_wheel_left = $LeftSide/ActionWheelLeft
@onready var action_wheel_right = $RightSide/ActionWheelRight

func _ready() -> void:
	_load_abilities()
	_setup_dummies()
	
	action_wheel_left.action_selected.connect(_on_player_1_ability_selected)
	action_wheel_right.action_selected.connect(_on_player_2_ability_selected)

func _load_abilities() -> void:
	var dir = DirAccess.open("res://combat_core/abilities/instances")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var ability_names: PackedStringArray = []
		
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var ability = load("res://combat_core/abilities/instances/" + file_name) as BaseAbility
				if ability:
					loaded_abilities.append(ability)
					ability_names.append(ability.ability_name)
			file_name = dir.get_next()
			
		action_wheel_left.set_actions(ability_names)
		action_wheel_right.set_actions(PackedStringArray())
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
	if action_index >= 0 and action_index < loaded_abilities.size():
		var ability = loaded_abilities[action_index]
		print("\n--- ", caster_name, " Executing: ", ability.ability_name, " ---")
		print(caster.name, " HP before: ", caster.get_node("HealthComponent").current_hp)
		print(target.name, " HP before: ", target.get_node("HealthComponent").current_hp)
		
		ability.execute(caster, [target])
		
		print(caster.name, " HP after: ", caster.get_node("HealthComponent").current_hp)
		print(target.name, " HP after: ", target.get_node("HealthComponent").current_hp)
		print("---------------------------------------\n")
