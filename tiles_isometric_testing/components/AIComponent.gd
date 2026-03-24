extends Node
class_name AIComponent

# ─────────────────────────────────────────────
#  AIComponent — Enemy AI State Machine
#
#  States:
#    IDLE    → diam, tidak melakukan apapun
#    PATROL  → jalan ke waypoint, loop
#    CHASE   → kejar target terdekat
#    ATTACK  → serang target
#
#  Behaviors:
#    AGGRESSIVE  → langsung kejar & serang siapa saja yang ketekuk
#    DEFENSIVE   → diam kecuali ada musuh di range pertahanan
#    PATROL      → jalan waypoint, switch ke CHASE jika ada target
#
#  Flow saat giliran:
#    TurnManager emit turn_started(entity)
#    → _on_turn_started() → take_turn()
#    → _update_state() → _execute_state()
#    → TurnManager.request_end_turn()
# ─────────────────────────────────────────────

enum AIState    { IDLE, PATROL, CHASE, ATTACK }
enum Behavior   { AGGRESSIVE, DEFENSIVE, PATROL }

@export var behavior:        Behavior = Behavior.AGGRESSIVE
@export var detection_range: int      = 6   # radius deteksi target (tiles)
@export var attack_range:    int      = 1   # diisi dari CombatComponent otomatis
@export var preferred_range: int      = 1   # jarak optimal saat chase

var state:          AIState      = AIState.IDLE
var _target:        Node         = null
var _patrol_points: Array[Vector2i] = []
var _patrol_index:  int          = 0


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)


# ── Turn Entry Point ──────────────────────────

func _on_turn_started(entity: Node, _pid: int) -> void:
	if entity != owner:
		return
	take_turn()


func take_turn() -> void:
	# Kondisi yang mencegah aksi
	var cond := owner.get_node_or_null("ConditionComponent") as ConditionComponent
	if cond:
		if cond.is_stunned() or cond.is_frozen():
			_end_my_turn()
			return

	_update_state()
	_execute_state()
	_end_my_turn()


# ── State Machine ─────────────────────────────

func _update_state() -> void:
	_target = _find_best_target()

	match behavior:
		Behavior.AGGRESSIVE:
			if _target != null:
				state = AIState.CHASE
			else:
				state = AIState.IDLE

		Behavior.DEFENSIVE:
			# Hanya bereaksi jika target sudah masuk setengah radius deteksi
			var guard_range := detection_range / 2
			if _target != null and _is_within_tiles(_target, guard_range):
				state = AIState.CHASE
			else:
				state = AIState.IDLE

		Behavior.PATROL:
			if _target != null and _is_within_tiles(_target, detection_range):
				state = AIState.CHASE
			elif not _patrol_points.is_empty():
				state = AIState.PATROL
			else:
				state = AIState.IDLE


func _execute_state() -> void:
	match state:
		AIState.IDLE:
			pass

		AIState.PATROL:
			_do_patrol()

		AIState.CHASE:
			_do_chase()

		AIState.ATTACK:
			_do_attack()


# ── State Actions ─────────────────────────────

func _do_patrol() -> void:
	if _patrol_points.is_empty():
		return
	var goal := _patrol_points[_patrol_index]
	var my_pos: Vector2i = owner.get("grid_pos")
	if my_pos == goal:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		return
	_move_step_towards(goal)


func _do_chase() -> void:
	if _target == null:
		return
	# Sudah dalam jangkauan → langsung serang
	if _can_attack_now(_target):
		_do_attack()
		return
	# Belum dalam jangkauan → dekati target
	_approach_target(_target)
	# Setelah bergerak, coba serang lagi
	if _can_attack_now(_target):
		_do_attack()


func _do_attack() -> void:
	if _target == null:
		return
	var combat := owner.get_node_or_null("CombatComponent") as CombatComponent
	if combat and combat.can_attack(_target):
		combat.attack(_target)


# ── Movement Helpers ──────────────────────────

## Gerak satu "putaran" movement menuju pos tujuan.
func _move_step_towards(goal: Vector2i) -> void:
	var move := owner.get_node_or_null("MovementComponent") as MovementComponent
	if move == null or not move.has_movement():
		return
	var my_pos: Vector2i = owner.get("grid_pos")
	var path := GridManager.find_path(my_pos, goal)
	if path.size() < 2:
		return
	# Jalan sejauh movement_left tersisa
	var dest := my_pos
	for i in range(1, path.size()):
		if move.movement_left <= 0:
			break
		dest = path[i]
	if dest != my_pos:
		move.move_to(dest)


## Dekati target, berhenti di preferred_range / dalam attack range.
func _approach_target(target: Node) -> void:
	var move := owner.get_node_or_null("MovementComponent") as MovementComponent
	if move == null or not move.has_movement():
		return

	var my_pos:     Vector2i = owner.get("grid_pos")
	var target_pos: Vector2i = target.get("grid_pos")

	# Cari tile yang bisa dicapai DAN paling dekat ke target
	var reachable    := move.get_reachable_tiles()
	var best_pos      := my_pos
	var best_dist     := GridManager.get_distance(my_pos, target_pos)
	var found_in_range := false

	for tile in reachable:
		var dist := GridManager.get_distance(tile, target_pos)
		# Tile yang menempatkan kita dalam preferred_range → prioritas
		if dist <= preferred_range and not found_in_range:
			best_pos       = tile
			best_dist      = dist
			found_in_range = true
		elif not found_in_range and dist < best_dist:
			best_dist = dist
			best_pos  = tile

	if best_pos != my_pos:
		move.move_to(best_pos)


# ── Queries ───────────────────────────────────

func _find_best_target() -> Node:
	var my_pos: Vector2i = owner.get("grid_pos")
	var all_players := owner.get_tree().get_nodes_in_group("players")
	var best: Node   = null
	var best_dist    := detection_range + 1

	for player in all_players:
		var health := player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_dead():
			continue
		var p_pos: Vector2i = player.get("grid_pos")
		var dist := GridManager.get_distance(my_pos, p_pos)
		if dist <= detection_range and dist < best_dist:
			best_dist = dist
			best      = player

	return best


func _is_within_tiles(target: Node, range_tiles: int) -> bool:
	var my_pos:     Vector2i = owner.get("grid_pos")
	var target_pos: Vector2i = target.get("grid_pos")
	return GridManager.get_distance(my_pos, target_pos) <= range_tiles


func _can_attack_now(target: Node) -> bool:
	var combat := owner.get_node_or_null("CombatComponent") as CombatComponent
	if combat == null:
		return false
	return combat.can_attack(target)


# ── Patrol Setup ──────────────────────────────

func set_patrol_points(points: Array[Vector2i]) -> void:
	_patrol_points  = points
	_patrol_index   = 0


# ── Internal ──────────────────────────────────

func _end_my_turn() -> void:
	TurnManager.request_end_turn()
