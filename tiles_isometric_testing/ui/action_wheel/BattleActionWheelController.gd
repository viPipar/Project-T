extends Control

var loaded_abilities: Array[BaseAbility] = []

var _p1_ap: ActionPointManager
var _p1_ec: EnergyChargeManager
var _p2_ap: ActionPointManager
var _p2_ss: SpellSlotManager

@onready var action_wheel_left = $LeftSide/ActionWheelLeft
@onready var action_wheel_right = $RightSide/ActionWheelRight


func _ready() -> void:
	_load_abilities()

	action_wheel_left.visible = false
	action_wheel_right.visible = false
	
	action_wheel_left.action_hovered.connect(_on_action_hovered.bind(1))
	action_wheel_right.action_hovered.connect(_on_action_hovered.bind(2))
	action_wheel_left.visibility_changed.connect(_on_wheel_visibility_changed.bind(action_wheel_left, 1))
	action_wheel_right.visibility_changed.connect(_on_wheel_visibility_changed.bind(action_wheel_right, 2))
	
	EventBus.combat_hud_ready.connect(_on_combat_hud_ready)


func _load_abilities() -> void:
	var dir = DirAccess.open("res://combat_core/abilities/instances")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var p1_abilities: Array[BaseAbility] = []
		var p2_abilities: Array[BaseAbility] = []

		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var ability = load("res://combat_core/abilities/instances/" + file_name) as BaseAbility
				if ability:
					loaded_abilities.append(ability)
					if ability.ability_type == BaseAbility.AbilityType.PHYSICAL:
						p1_abilities.append(ability)
					else:
						p2_abilities.append(ability)
			file_name = dir.get_next()

		action_wheel_left.set_abilities(p1_abilities)
		action_wheel_right.set_abilities(p2_abilities)
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
			if is_instance_valid(player) and player.has_method("is_downed") and player.is_downed():
				return false
			return true
	return true

func _on_combat_hud_ready(pid: int, ap: ActionPointManager, _mov: Node, mana: Node) -> void:
	if pid == 1:
		_p1_ap = ap
		_p1_ec = mana as EnergyChargeManager
	elif pid == 2:
		_p2_ap = ap
		_p2_ss = mana as SpellSlotManager

func _on_action_hovered(action_name: String, action_index: int, page_index: int, slot_index: int, player_id: int) -> void:
	var wheel = action_wheel_left if player_id == 1 else action_wheel_right
	var ability: BaseAbility = null
	if action_index >= 0 and action_index < wheel.abilities.size():
		ability = wheel.abilities[action_index]
	
	EventBus.resource_blink_requested.emit(player_id, "stop_all")
	if ability != null:
		if ability.cost_action > 0: EventBus.resource_blink_requested.emit(player_id, "ap")
		if ability.cost_bonus_action > 0: EventBus.resource_blink_requested.emit(player_id, "bap")
		if ability.cost_mana > 0:
			var res := "energy_charge" if player_id == 1 else "spell_slot"
			EventBus.resource_blink_requested.emit(player_id, res)

func _on_wheel_visibility_changed(wheel: Control, player_id: int) -> void:
	if not wheel.visible:
		EventBus.resource_blink_requested.emit(player_id, "stop_all")
	else:
		_update_wheel_affordability(wheel, player_id)

func _update_wheel_affordability(wheel: Control, player_id: int) -> void:
	var ap_mgr = _p1_ap if player_id == 1 else _p2_ap
	var mana_mgr = _p1_ec if player_id == 1 else _p2_ss
	if ap_mgr == null or mana_mgr == null: return
	
	for i in range(wheel.abilities.size()):
		var ability = wheel.abilities[i]
		var can_afford = true
		if ability != null:
			if not ap_mgr.can_spend_ap(ability.cost_action): can_afford = false
			elif not ap_mgr.can_spend_bap(ability.cost_bonus_action): can_afford = false
			elif ability.cost_mana > 0:
				if player_id == 1 and not (mana_mgr as EnergyChargeManager).can_spend(ability.cost_mana):
					can_afford = false
				elif player_id == 2 and not (mana_mgr as SpellSlotManager).can_spend(1, ability.cost_mana):
					can_afford = false
		wheel.set_action_affordable(i, can_afford)
