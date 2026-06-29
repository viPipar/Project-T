extends Node

# ─────────────────────────────────────────────
#  CombatFeedbackManager
#  Listens to EventBus combat signals and spawns 
#  in-world dice rolls and other feedback.
# ─────────────────────────────────────────────

var dice_scene = preload("res://components/dice/sandbox/DiceVisual.tscn")

func _ready() -> void:
	if EventBus.has_signal("request_dice_roll"):
		EventBus.request_dice_roll.connect(_on_request_dice_roll)

func _on_request_dice_roll(attacker: Node, target: Node, hit_result: Dictionary) -> void:
	if attacker == null or target == null:
		EventBus.dice_roll_finished.emit()
		return
		
	var main_scene = get_tree().current_scene
	if main_scene == null:
		EventBus.dice_roll_finished.emit()
		return
		
	var dice = dice_scene.instantiate()
	main_scene.add_child(dice)
	
	var roll_val: int = hit_result.get("raw_roll", hit_result.get("roll", 1))
	var is_crit: bool = hit_result.get("crit", false)
	var is_hit: bool = hit_result.get("hit", false)
	var outcome: String = "hit"
	
	if is_crit:
		outcome = "crit"
	elif not is_hit:
		outcome = "miss"
		
	var p_id: int = attacker.get("player_id") if attacker.get("player_id") != null else 0
	
	# Spawn dice above the ATTACKER (since they are rolling the dice)
	var spawn_pos: Vector2 = attacker.global_position
	# Large upward offset to clear isometric sprite height
	spawn_pos += Vector2(0, -120)
	
	# Listen for the animation to finish
	dice.roll_finished.connect(func(_res): EventBus.dice_roll_finished.emit())
	
	dice.start_roll(
		roll_val, 
		"d20", 
		1.5, # roll_duration
		spawn_pos, 
		p_id, 
		outcome, 
		true, # in_place
		Vector2(0.5, 0.5) # Scale increased for visibility
	)
