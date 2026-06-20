# ui/shared/EnemyStatTooltip.gd
# ── Tooltip enemy (HP + Armor) yang tampil saat di-hover ─────────────────────
# Fitur:
# - Dibangun murni via GDScript (tanpa .tscn terpisah)
# - Anchor posisi di atas kepala enemy (Y offset -70)
# - Mendukung split-screen BG3-style: hanya terlihat di viewport player yang hover
#   (via visibility_layer)
# ─────────────────────────────────────────────────────────────────────────────
class_name EnemyStatTooltip
extends Node2D

const OFFSET_Y := -140.0

var _bg_panel    : ColorRect
var _name_label  : Label
var _hp_label    : Label
var _armor_label : Label

var _is_visible  : bool = false
var _target_layer: int  = 0


func _ready() -> void:
	z_index = 50
	position = Vector2(0, OFFSET_Y)
	visible = false
	_build_ui()


# ── UI Builder ───────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# 1. Background Panel (Transparent)
	_bg_panel = ColorRect.new()
	_bg_panel.color = Color(0, 0, 0, 0) # TRANSPARENT SAJA
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_bg_panel.offset_left   = -80
	_bg_panel.offset_right  =  80
	_bg_panel.offset_top    = -35
	_bg_panel.offset_bottom =  35
	add_child(_bg_panel)

	# 2. Enemy Name (Baris Atas)
	_name_label = _make_label("", 18, Color(0.9, 0.9, 0.95))
	_name_label.position = Vector2(-80, -35)
	_name_label.size = Vector2(160, 25)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg_panel.add_child(_name_label)

	# 3. HP Row (Baris Bawah Kiri)
	var hp_icon = _make_label("♥", 22, Color(1.0, 0.3, 0.3))
	hp_icon.position = Vector2(15, 35)
	hp_icon.size = Vector2(30, 30)
	_bg_panel.add_child(hp_icon)

	_hp_label = _make_label("0", 20, Color.WHITE)
	_hp_label.position = Vector2(40, 35)
	_hp_label.size = Vector2(40, 30)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bg_panel.add_child(_hp_label)

	# 4. Armor Row (Baris Bawah Kanan)
	var armor_icon = _make_label("🛡", 20, Color(0.6, 0.65, 0.8))
	armor_icon.position = Vector2(85, 35)
	armor_icon.size = Vector2(30, 30)
	_bg_panel.add_child(armor_icon)

	_armor_label = _make_label("0", 20, Color.WHITE)
	_armor_label.position = Vector2(110, 35)
	_armor_label.size = Vector2(40, 30)
	_armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bg_panel.add_child(_armor_label)


func _make_label(txt: String, f_size: int, f_color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", f_color)
	l.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	l.add_theme_constant_override("outline_size", 6)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


# ── Public API ───────────────────────────────────────────────────────────────

## Menampilkan tooltip. layer_mask menentukan viewport mana yang merender ini.
func show_for(e_name: String, hp: int, max_hp: int, armor: int, layer_mask: int) -> void:
	_name_label.text  = e_name
	_hp_label.text    = str(hp)
	_armor_label.text = str(armor)
	_target_layer     = layer_mask
	
	# Node2D properties
	visibility_layer = _target_layer
	
	# Harus propagasi visibility_layer ke semua children karena ColorRect dan Label adalah CanvasItem
	_set_visibility_layer_recursive(self, _target_layer)

	if not _is_visible:
		_is_visible = true
		visible = true
		_animate_in()


func hide_tooltip() -> void:
	if _is_visible:
		_is_visible = false
		_animate_out()


## Dipanggil saat HP berubah secara real-time
func update_hp(hp: int) -> void:
	_hp_label.text = str(hp)
	# Animasi kedip kecil saat HP update
	if _is_visible:
		var tw = create_tween()
		tw.tween_property(_hp_label, "modulate", Color(1,0,0,1), 0.1)
		tw.tween_property(_hp_label, "modulate", Color.WHITE, 0.1)


# ── Animations ───────────────────────────────────────────────────────────────

func _animate_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_out() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_IN)
	await tw.finished
	if not _is_visible:
		visible = false


# ── Helper ───────────────────────────────────────────────────────────────────

func _set_visibility_layer_recursive(node: Node, layer_mask: int) -> void:
	if node is CanvasItem:
		node.visibility_layer = layer_mask
	for child in node.get_children():
		_set_visibility_layer_recursive(child, layer_mask)
