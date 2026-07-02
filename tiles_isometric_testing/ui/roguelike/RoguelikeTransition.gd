extends CanvasLayer
class_name RoguelikeTransition

signal midpoint_reached()
signal finished()

@export var fade_in_duration: float = 0.22
@export var hold_duration: float = 0.06
@export var fade_out_duration: float = 0.22
@export var loading_hold_duration: float = 0.35

@onready var overlay: ColorRect = $Overlay

var _is_playing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0, 0, 0, 0)
	_fit_overlay_to_viewport()

func play(midpoint_callback: Callable = Callable()) -> void:
	if _is_playing:
		return

	_is_playing = true
	visible = true
	_fit_overlay_to_viewport()
	overlay.color = Color(0, 0, 0, 0)

	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 1), fade_in_duration)
	tween.tween_callback(_on_midpoint.bind(midpoint_callback))
	tween.tween_interval(hold_duration)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), fade_out_duration)
	tween.tween_callback(_finish)

func play_loading_route(show_loading_callback: Callable, show_target_callback: Callable) -> void:
	if _is_playing:
		return

	_is_playing = true
	visible = true
	_fit_overlay_to_viewport()
	overlay.color = Color(0, 0, 0, 0)

	await _fade_to(Color(0, 0, 0, 1), fade_in_duration)
	_call_callback(show_loading_callback)
	await get_tree().process_frame
	await _fade_to(Color(0, 0, 0, 0), fade_out_duration)

	if loading_hold_duration > 0.0:
		await get_tree().create_timer(loading_hold_duration).timeout

	await _fade_to(Color(0, 0, 0, 1), fade_in_duration)
	_call_callback(show_target_callback)
	await get_tree().process_frame
	await _fade_to(Color(0, 0, 0, 0), fade_out_duration)
	_finish()

func _on_midpoint(midpoint_callback: Callable) -> void:
	midpoint_reached.emit()
	_call_callback(midpoint_callback)

func _call_callback(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()

func _fade_to(target_color: Color, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(overlay, "color", target_color, maxf(duration, 0.01))
	await tween.finished

func _finish() -> void:
	_is_playing = false
	visible = false
	finished.emit()
	queue_free()

func _fit_overlay_to_viewport() -> void:
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.size = get_viewport().get_visible_rect().size
