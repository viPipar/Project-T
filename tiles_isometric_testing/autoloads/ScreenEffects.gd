extends CanvasLayer
	
var _flash_rect: ColorRect
var _flash_tween: Tween

func _ready() -> void:
	layer = 10
	_flash_rect = ColorRect.new()
	_flash_rect.name = "ImpactFlash"
	_flash_rect.anchors_preset = Control.PRESET_FULL_RECT
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	add_child(_flash_rect)

func impact_flash(color: Color = Color.WHITE, max_alpha: float = 0.6, duration: float = 0.15) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = Color(color.r, color.g, color.b, 0)
	_flash_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_flash_tween.tween_property(_flash_rect, "color", Color(color.r, color.g, color.b, max_alpha), duration * 0.3)
	_flash_tween.tween_property(_flash_rect, "color", Color(color.r, color.g, color.b, 0), duration * 0.7)
