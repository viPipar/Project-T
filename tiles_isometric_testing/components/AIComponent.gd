extends Node
class_name AIComponent

# ─────────────────────────────────────────────
#  AIComponent — Resource-based Strategy Pattern
#
#  This component acts as the "Controller" for Enemy AI.
#  It relies on an injected `AIBrain` resource to evaluate the 
#  entity's state and execute logic (movement, attacks).
# ─────────────────────────────────────────────

@export var brain: AIBrain

var _is_taking_turn: bool = false

func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)


func _on_turn_started(entity: Node, _pid: int) -> void:
	if entity != owner:
		return
	take_turn()


func take_turn() -> void:
	if _is_taking_turn:
		return
	_is_taking_turn = true
	
	# Kondisi yang mencegah aksi
	var cond := owner.get_node_or_null("ConditionComponent")
	if cond:
		if is_instance_valid(cond) and cond.has_method("is_stunned") and cond.is_stunned():
			end_turn()
			return
		if is_instance_valid(cond) and cond.has_method("is_frozen") and cond.is_frozen():
			end_turn()
			return

	if brain != null:
		print("---")
		print("[AIComponent] %s's turn started. Using brain: %s" % [owner.name, brain.resource_path.get_file()])
		brain.decide_and_act(owner, self)
	else:
		push_warning("AIComponent on %s has no brain assigned! Ending turn." % owner.name)
		end_turn()


# ── AI Helpers ────────────────────────────────

## Called by the AIBrain once it is finished with its actions.
func end_turn() -> void:
	_is_taking_turn = false
	TurnManager.request_end_turn()
