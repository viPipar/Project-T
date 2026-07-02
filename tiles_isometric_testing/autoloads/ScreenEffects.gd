extends CanvasLayer

var _flash_rect: ColorRect

func _ready() -> void:
	layer = 1000
	_flash_rect = ColorRect.new()
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color.WHITE
	_flash_rect.modulate.a = 0.0
	_flash_rect.hide()
	add_child(_flash_rect)

func impact_flash(color: Color = Color.WHITE, max_alpha: float = 0.6, duration: float = 0.3) -> void:
	if not is_inside_tree():
		return
	_flash_rect.color = color
	_flash_rect.modulate.a = max_alpha
	_flash_rect.show()
	
	var tw := create_tween()
	tw.tween_property(_flash_rect, "modulate:a", 0.0, duration)
	tw.tween_callback(_flash_rect.hide)
