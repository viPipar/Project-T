extends Label

func _ready() -> void:
	_refresh()
	if TurnManager != null and not TurnManager.turn_state_changed.is_connected(_on_turn_state_changed):
		TurnManager.turn_state_changed.connect(_on_turn_state_changed)


func _on_turn_state_changed(_turn_number: int, _phase: int) -> void:
	_refresh()


func _refresh() -> void:
	if TurnManager != null:
		text = TurnManager.get_turn_display_text()
