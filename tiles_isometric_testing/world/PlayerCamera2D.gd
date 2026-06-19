# world/PlayerCamera2D.gd
# ─────────────────────────────────────────────────────────────────────────────
# PlayerCamera2D
#
# Camera2D yang dikendalikan oleh keyboard input player (BG3-style).
# Cursor terkunci di tengah viewport — camera yang pan mengikuti arah input.
#
# Cara pakai:
#   var cam = PlayerCamera2D.new()
#   cam.player_id = 1
#   add_child(cam)
#   cam.make_current()
# ─────────────────────────────────────────────────────────────────────────────
class_name PlayerCamera2D
extends Camera2D

## Player yang dikendalikan oleh kamera ini (1 atau 2)
@export var player_id: int = 1

## Kecepatan pan kamera (pixel per detik)
@export var pan_speed: float = 600.0

## Kecepatan lerp kamera (0.0 = instan, 1.0 = sangat lambat)
@export var lerp_speed: float = 8.0

## Batas pan dari titik asal (0 = tidak terbatas)
@export var max_pan_distance: float = 2000.0

# Target posisi kamera (smooth lerp ke sini)
var _target_pos: Vector2 = Vector2.ZERO

# Posisi asal (saat kamera di-spawn)
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_priority = -10
	_origin = position
	_target_pos = position
	# Nonaktifkan dulu — SplitScreenManager yang akan make_current()
	enabled = false


func _process(delta: float) -> void:
	if not enabled:
		return
	_handle_pan_input(delta)
	# Smooth lerp ke target
	position = position.lerp(_target_pos, lerp_speed * delta)


func _handle_pan_input(delta: float) -> void:
	if is_instance_valid(InputManager) and InputManager.is_in_menu:
		return

	var dir := Vector2.ZERO

	# Pakai raw Input — kamera pan tidak diblok oleh InputManager
	# (player tetap bisa pan kamera meskipun animasi dice sedang berjalan)
	var prefix := "p%d_" % player_id
	if Input.is_action_pressed(prefix + "move_right"): dir.x += 1.0
	if Input.is_action_pressed(prefix + "move_left"):  dir.x -= 1.0
	if Input.is_action_pressed(prefix + "move_down"):  dir.y += 1.0
	if Input.is_action_pressed(prefix + "move_up"):    dir.y -= 1.0

	if dir != Vector2.ZERO:
		_target_pos += dir.normalized() * pan_speed * delta

	# Clamp agar tidak terlalu jauh dari titik asal
	if max_pan_distance > 0.0:
		var dist := _target_pos.distance_to(_origin)
		if dist > max_pan_distance:
			_target_pos = _origin + (_target_pos - _origin).normalized() * max_pan_distance


## Reset kamera ke posisi asal
func reset_to_origin() -> void:
	_target_pos = _origin
	position    = _origin


## Set posisi target baru (untuk follow player saat spawn)
func set_target(new_pos: Vector2) -> void:
	_target_pos = new_pos
	_origin     = new_pos
