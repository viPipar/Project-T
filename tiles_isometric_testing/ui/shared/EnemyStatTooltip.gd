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

const OFFSET_Y := -70.0

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
	# 1. Background Panel (Gelap, semi-transparan)
	_bg_panel = ColorRect.new()
	_bg_panel.color = Color(0.05, 0.05, 0.1, 0.85)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_bg_panel.offset_left   = -60
	_bg_panel.offset_right  =  60
	_bg_panel.offset_top    = -28
	_bg_panel.offset_bottom =  28
	add_child(_bg_panel)

	# Agar ada sedikit border style, bisa pakai frame tipis
	var border = ReferenceRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.2, 0.2, 0.25, 1.0)
	border.border_width = 1.5
	border.editor_only = false
	_bg_panel.add_child(border)

	# 2. Enemy Name (Baris Atas)
	_name_label = _make_label("", 12, Color(0.8, 0.8, 0.85))
	_name_label.position = Vector2(-60, -28)
	_name_label.size = Vector2(120, 20)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg_panel.add_child(_name_label)

	# Garis pemisah tipis
	var line = ColorRect.new()
	line.color = Color(0.2, 0.2, 0.25, 0.8)
	line.size = Vector2(100, 1)
	line.position = Vector2(10, 22)
	_bg_panel.add_child(line)

	# 3. HP Row (Baris Bawah Kiri)
	var hp_icon = _make_label("♥", 16, Color(1.0, 0.3, 0.3))
	hp_icon.position = Vector2(8, 28)
	hp_icon.size = Vector2(24, 24)
	_bg_panel.add_child(hp_icon)

	_hp_label = _make_label("0", 14, Color.WHITE)
	_hp_label.position = Vector2(28, 28)
	_hp_label.size = Vector2(30, 24)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bg_panel.add_child(_hp_label)

	# 4. Armor Row (Baris Bawah Kanan)
	var armor_icon = _make_label("🛡", 14, Color(0.6, 0.65, 0.8))
	armor_icon.position = Vector2(62, 28)
	armor_icon.size = Vector2(24, 24)
	_bg_panel.add_child(armor_icon)

	_armor_label = _make_label("0", 14, Color.WHITE)
	_armor_label.position = Vector2(82, 28)
	_armor_label.size = Vector2(30, 24)
	_armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bg_panel.add_child(_armor_label)


func _make_label(txt: String, f_size: int, f_color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", f_color)
	l.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	l.add_theme_constant_override("outline_size", 4)
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
