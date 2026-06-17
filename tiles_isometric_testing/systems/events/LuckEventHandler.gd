extends Node
class_name LuckEventHandler

# Handles Luck Event nodes, requiring consensus and a D20 roll to resolve.

signal event_started(event_data: Dictionary)
signal choice_selected(player_id: int, choice_index: int)
signal consensus_reached(choice_index: int)
signal event_resolved(success: bool, reward: Dictionary)

var current_event: Dictionary
var p1_choice: int = -1
var p2_choice: int = -1

func start_event(event_id: String) -> void:
	# Load event data from a hypothetical EventDB
	current_event = {
		"id": event_id,
		"narrative": "You find a glowing chest surrounded by sleeping wolves.",
		"choices": [
			{ "desc": "Sneak and open (D20 > 10)", "target_dc": 10, "reward": "random_item" },
			{ "desc": "Leave safely", "target_dc": 0, "reward": "none" }
		]
	}
	p1_choice = -1
	p2_choice = -1
	event_started.emit(current_event)

func select_choice(player_id: int, choice_index: int) -> void:
	if player_id == 1:
		p1_choice = choice_index
	elif player_id == 2:
		p2_choice = choice_index
		
	choice_selected.emit(player_id, choice_index)
	
	if p1_choice != -1 and p2_choice != -1:
		if p1_choice == p2_choice:
			_resolve_event(p1_choice)
		else:
			print("[LuckEventHandler] Players disagree! Waiting for consensus...")

func _resolve_event(choice_index: int) -> void:
	consensus_reached.emit(choice_index)
	var choice = current_event.get("choices", [])[choice_index]
	var dc = choice.get("target_dc", 0)
	
	if dc > 0:
		# Need to roll D20 (simulating tapip's system hook)
		var roll = randi_range(1, 20)
		var success = (roll >= dc)
		print("[LuckEventHandler] Rolled %d vs DC %d. Success: %s" % [roll, dc, success])
		event_resolved.emit(success, choice if success else {})
	else:
		# Auto success
		event_resolved.emit(true, choice)
