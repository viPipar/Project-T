extends Button
class_name RelicHUDButton

var player_id: int = 1
var item_name: String = ""
var rarity_name: String = ""
var description: String = ""
var manager_node: Node = null

var normal_style: StyleBoxFlat
var glow_style: StyleBoxFlat

var _tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	_on_hover_entered()

func _on_mouse_exited() -> void:
	_on_hover_exited()

func _on_hover_entered() -> void:
	if glow_style:
		add_theme_stylebox_override("normal", glow_style)
		add_theme_stylebox_override("hover", glow_style)
		add_theme_stylebox_override("focus", glow_style)
		
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.3), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if is_instance_valid(manager_node) and manager_node.has_method("show_relic_tooltip"):
		manager_node.show_relic_tooltip(player_id, item_name, rarity_name, description, self)

func _on_hover_exited() -> void:
	if normal_style:
		add_theme_stylebox_override("normal", normal_style)
		add_theme_stylebox_override("hover", normal_style)
		add_theme_stylebox_override("focus", normal_style)
		
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if is_instance_valid(manager_node) and manager_node.has_method("hide_relic_tooltip"):
		manager_node.hide_relic_tooltip(player_id)
