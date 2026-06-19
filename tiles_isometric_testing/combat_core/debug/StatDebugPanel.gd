# combat_core/debug/StatDebugPanel.gd
# ── DEBUG STAT MANIPULATOR ────────────────────────────────────────────────────
# Panel sisi kanan layar — toggle dengan F1 (sama dengan DebugPanel).
# Fitur:
#   - Tampilkan semua stat P1 dan P2
#   - Tombol + / − untuk setiap stat (hold = cepat)
#   - Perubahan langsung ke _external_mods StatsComponent (base stat tidak berubah)
#   - Derived stats (AP, Move, Crit threshold, dll.) langsung terupdate
#   - Tombol Reset per player untuk kembali ke base stat
#
# Cara pakai:
#   Tambah scene ini sebagai child dari DebugUI/Root di Main.tscn
#   Atau instansiate dari main.gd — sudah auto-add dari CombatTestBridge hook
class_name StatDebugPanel
extends Control

# ── Konstanta tampilan ─────────────────────────────────────────────────────────
const STAT_KEYS := ["vit", "str", "int", "con", "acc", "dex", "mov", "att", "lck"]
const STAT_LABELS := {
	"vit": "VIT  (Vitality)",
	"str": "STR  (Strength)",
	"int": "INT  (Intelligence)",
	"con": "CON  (Constitution)",
	"acc": "ACC  (Accuracy)",
	"dex": "DEX  (Dexterity)",
	"mov": "MOV  (Movement)",
	"att": "ATT  (Attunement)",
	"lck": "LCK  (Luck)"
}
const STAT_COLORS := {
	"vit": Color(0.9, 0.4, 0.4),   # merah muda
	"str": Color(1.0, 0.6, 0.2),   # oranye
	"int": Color(0.4, 0.7, 1.0),   # biru muda
	"con": Color(0.6, 0.9, 0.5),   # hijau
	"acc": Color(1.0, 0.9, 0.3),   # kuning
	"dex": Color(0.7, 0.5, 1.0),   # ungu
	"mov": Color(0.3, 0.9, 0.9),   # cyan
	"att": Color(1.0, 0.5, 0.8),   # pink
	"lck": Color(0.9, 0.9, 0.9),   # putih
}

# Step dan hold-repeat config
const STEP_NORMAL    := 1
const HOLD_DELAY_SEC := 0.5   # berapa lama tahan sebelum mulai repeat
const HOLD_REPEAT_HZ := 10.0  # berapa kali per detik saat hold

# ── State ─────────────────────────────────────────────────────────────────────
var _p1_entity: Node = null
var _p2_entity: Node = null
var _p1_mods: Dictionary = {}  # override stat per key
var _p2_mods: Dictionary = {}

# Hold-button state
var _held_button: Button = null
var _held_callback: Callable
var _hold_timer: float  = 0.0
var _hold_triggered: bool = false

# Simpan referensi semua SpinBox atau nilai label supaya mudah update
var _p1_row_refs: Dictionary = {}  # stat_key -> { "val_label": Label, "derived_label": Label }
var _p2_row_refs: Dictionary = {}

var _derived_label_p1: Label = null
var _derived_label_p2: Label = null

# Drag & Resize
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_resizing: bool = false
var _resize_offset: Vector2 = Vector2.ZERO


# ── BUILD UI ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_find_entities()
	_refresh_all()


func _build_ui() -> void:
	# Lepas anchor agar bisa di-drag bebas
	set_anchors_preset(PRESET_TOP_LEFT)
	position = Vector2(50, 50)
	size = Vector2(420, 600)

	# ── Root panel ────────────────────────────────────────────────────────────
	custom_minimum_size = Vector2(420, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_END

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.border_color = Color(0.3, 0.3, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)

	# ── Scroll container ──────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var header_container = MarginContainer.new()
	header_container.mouse_filter = Control.MOUSE_FILTER_STOP
	header_container.gui_input.connect(_on_header_gui_input)
	vbox.add_child(header_container)

	var header := Label.new()
	header.text = "🎛  STAT DEBUG MANIPULATOR"
	header.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_constant_override("margin_top", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_container.add_child(header)

	var hint := Label.new()
	hint.text = "Ubah stat → efek langsung ke combat\nBase stat tidak berubah (external mod)"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hint.add_theme_font_size_override("font_size", 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	_add_separator(vbox)

	# ── Resize Handle ─────────────────────────────────────────────────────────
	var resize_handle = ColorRect.new()
	resize_handle.color = Color(1, 1, 1, 0.15)
	resize_handle.custom_minimum_size = Vector2(25, 25)
	resize_handle.size_flags_horizontal = Control.SIZE_SHRINK_END
	resize_handle.size_flags_vertical = Control.SIZE_SHRINK_END
	resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	resize_handle.gui_input.connect(_on_resize_gui_input)
	add_child(resize_handle)

	# ── P1 Section ────────────────────────────────────────────────────────────
	_p1_row_refs = {}
	_build_player_section(vbox, 1, _p1_row_refs)

	_derived_label_p1 = Label.new()
	_derived_label_p1.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_derived_label_p1.add_theme_font_size_override("font_size", 10)
	_derived_label_p1.text = "derived: —"
	vbox.add_child(_derived_label_p1)

	var reset_p1 := _make_reset_button("↺  Reset P1 ke Base Stat", 1)
	vbox.add_child(reset_p1)

	_add_separator(vbox)

	# ── P2 Section ────────────────────────────────────────────────────────────
	_p2_row_refs = {}
	_build_player_section(vbox, 2, _p2_row_refs)

	_derived_label_p2 = Label.new()
	_derived_label_p2.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_derived_label_p2.add_theme_font_size_override("font_size", 10)
	_derived_label_p2.text = "derived: —"
	vbox.add_child(_derived_label_p2)

	var reset_p2 := _make_reset_button("↺  Reset P2 ke Base Stat", 2)
	vbox.add_child(reset_p2)

	_add_separator(vbox)

	# ── Bottom hint ───────────────────────────────────────────────────────────
	var close_hint := Label.new()
	close_hint.text = "F1 = tutup panel ini"
	close_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	close_hint.add_theme_font_size_override("font_size", 9)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(close_hint)


func _build_player_section(parent: VBoxContainer, player_id: int, refs: Dictionary) -> void:
	var name_str := "P%d — %s" % [player_id, ("Fighter" if player_id == 1 else "Wizard")]
	var header_color := Color(0.4, 0.8, 1.0) if player_id == 1 else Color(1.0, 0.6, 0.9)

	var section_label := Label.new()
	section_label.text = "► " + name_str
	section_label.add_theme_color_override("font_color", header_color)
	section_label.add_theme_font_size_override("font_size", 13)
	parent.add_child(section_label)

	for key in STAT_KEYS:
		# _build_stat_row akan mengisi refs[key] secara internal
		var row := _build_stat_row(key, player_id)
		parent.add_child(row)



func _build_stat_row(stat_key: String, player_id: int) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	style.set_corner_radius_all(4)
	pc.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	pc.add_child(hbox)

	# Label stat
	var label := Label.new()
	label.text = STAT_LABELS.get(stat_key, stat_key.to_upper())
	label.custom_minimum_size.x = 155
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", STAT_COLORS.get(stat_key, Color.WHITE))
	hbox.add_child(label)

	# Nilai sekarang (base + mod)
	var val_label := Label.new()
	val_label.name = "ValLabel_%s_P%d" % [stat_key, player_id]
	val_label.custom_minimum_size.x = 32
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.add_theme_color_override("font_color", Color.WHITE)
	val_label.text = "0"
	hbox.add_child(val_label)

	# Modifier saat ini (±X)
	var mod_label := Label.new()
	mod_label.name = "ModLabel_%s_P%d" % [stat_key, player_id]
	mod_label.custom_minimum_size.x = 36
	mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mod_label.add_theme_font_size_override("font_size", 10)
	mod_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	mod_label.text = "(±0)"
	hbox.add_child(mod_label)

	# Tombol −
	var btn_minus := _make_step_button("−", stat_key, player_id, -1)
	hbox.add_child(btn_minus)

	# Tombol +
	var btn_plus := _make_step_button("+", stat_key, player_id, +1)
	hbox.add_child(btn_plus)

	# Simpan ke refs agar bisa diupdate
	var refs := _p1_row_refs if player_id == 1 else _p2_row_refs
	refs[stat_key] = {
		"val_label": val_label,
		"mod_label": mod_label,
	}

	return pc


func _make_step_button(label_text: String, stat_key: String, player_id: int, delta: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(28, 28)
	btn.add_theme_font_size_override("font_size", 14)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9) if delta > 0 else Color(0.3, 0.1, 0.1, 0.9)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.35, 0.35, 0.55) if delta > 0 else Color(0.5, 0.15, 0.15)
	btn.add_theme_stylebox_override("hover", style_hover)

	# Connect press
	btn.button_down.connect(_on_button_held.bind(stat_key, player_id, delta, btn))
	btn.button_up.connect(_on_button_released)
	btn.pressed.connect(_step_stat.bind(stat_key, player_id, delta))

	return btn


func _make_reset_button(label_text: String, player_id: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 11)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.35, 0.2, 0.9)
	style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.3, 0.55, 0.3)
	btn.add_theme_stylebox_override("hover", style_hover)

	btn.pressed.connect(_reset_player.bind(player_id))
	return btn


func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.4, 0.5))
	parent.add_child(sep)


# ── LOGIC ─────────────────────────────────────────────────────────────────────

func _find_entities() -> void:
	# Cari player entity di scene berdasarkan player_id
	for node in get_tree().get_nodes_in_group("players"):
		if node == null:
			continue
		var pid: Variant = node.get("player_id")  # get() returns Variant by design
		if pid == 1:
			_p1_entity = node
		elif pid == 2:
			_p2_entity = node


func _step_stat(stat_key: String, player_id: int, delta: int) -> void:
	var mods := _p1_mods if player_id == 1 else _p2_mods
	var current: int = mods.get(stat_key, 0)
	mods[stat_key] = current + delta

	# Terapkan ke StatsComponent entity
	_apply_mods(player_id)
	_refresh_player(player_id)


func _apply_mods(player_id: int) -> void:
	var entity := _p1_entity if player_id == 1 else _p2_entity
	var mods   := _p1_mods   if player_id == 1 else _p2_mods

	if entity == null:
		# Coba cari ulang
		_find_entities()
		entity = _p1_entity if player_id == 1 else _p2_entity

	if entity == null:
		push_warning("[StatDebugPanel] Entity P%d tidak ditemukan!" % player_id)
		return

	var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		push_warning("[StatDebugPanel] StatsComponent tidak ada di P%d!" % player_id)
		return

	stats.set_external_mods(mods)

	# Live update ke ActionPointManager dan MovementPointManager via CombatTestBridge
	_notify_combat_bridge(player_id, stats)


func _notify_combat_bridge(player_id: int, stats: StatsComponent) -> void:
	# Cari CombatTestBridge di scene
	var bridge := get_tree().get_root().find_child("CombatTestBridge", true, false)
	if bridge == null:
		return

	# ── Ambil AP manager dan Movement manager (typed via 'as') ──────────────
	var ap_key  : String = "_p1_ap"  if player_id == 1 else "_p2_ap"
	var mov_key : String = "_p1_mov" if player_id == 1 else "_p2_mov"

	var ap_mgr  := bridge.get(ap_key)  as ActionPointManager
	var mov_mgr := bridge.get(mov_key) as MovementPointManager

	if ap_mgr != null:
		ap_mgr.setup(stats.get_stat("dex"), stats.get_stat("int"))

	if mov_mgr != null:
		mov_mgr.setup(stats.get_stat("mov"))

	# ── Update class-spesifik: Fighter EC atau Wizard SpellSlot ─────────────
	if player_id == 1:
		# Fighter — EnergyCharge tidak bergantung stat, biarkan
		pass
	else:
		# Wizard — SpellSlot berubah saat ATT diubah
		var ss_mgr := bridge.get("_p2_ss") as SpellSlotManager
		if ss_mgr != null:
			ss_mgr.setup(stats.get_stat("att"))


func _reset_player(player_id: int) -> void:
	if player_id == 1:
		_p1_mods.clear()
	else:
		_p2_mods.clear()

	_apply_mods(player_id)
	_refresh_player(player_id)
	print("[StatDebugPanel] P%d stat di-reset ke base." % player_id)


func _refresh_all() -> void:
	_find_entities()
	_refresh_player(1)
	_refresh_player(2)


func _refresh_player(player_id: int) -> void:
	var entity  := _p1_entity   if player_id == 1 else _p2_entity
	var refs    := _p1_row_refs  if player_id == 1 else _p2_row_refs
	var mods    := _p1_mods      if player_id == 1 else _p2_mods
	var derived_label := _derived_label_p1 if player_id == 1 else _derived_label_p2

	if entity == null:
		_find_entities()
		entity = _p1_entity if player_id == 1 else _p2_entity

	var stats: StatsComponent = null
	if entity != null:
		stats = entity.get_node_or_null("StatsComponent") as StatsComponent

	for key in STAT_KEYS:
		if not refs.has(key):
			continue
		var row_data: Dictionary = refs[key]
		var val_label: Label     = row_data.get("val_label")
		var mod_label: Label     = row_data.get("mod_label")

		var base_val: int = stats.get_base_stat(key) if stats != null else 0
		var mod_val:  int = int(mods.get(key, 0))
		var total:    int = base_val + mod_val

		if val_label:
			val_label.text = str(total)
			# Warna: putih = no mod, hijau = positive, merah = negative
			if mod_val > 0:
				val_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			elif mod_val < 0:
				val_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			else:
				val_label.add_theme_color_override("font_color", Color.WHITE)

		if mod_label:
			if mod_val == 0:
				mod_label.text = "(±0)"
				mod_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			elif mod_val > 0:
				mod_label.text = "(+%d)" % mod_val
				mod_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			else:
				mod_label.text = "(%d)" % mod_val
				mod_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	# Update derived stats
	if derived_label != null and stats != null:
		var d := stats.get_derived()
		derived_label.text = (
			"→ AP+%d  Mv+%d  Hit+%d  Crit-%d  HP+%d  Arm+%d  Res+%d  Slot L1+%d L2+%d L3+%d  Luck+%d" % [
				d.bonus_action_points, d.bonus_movement_tiles,
				d.hit_roll_bonus, d.crit_roll_reduction,
				d.bonus_hp, d.bonus_armor, d.bonus_resist,
				d.bonus_spell_slots_l1, d.bonus_spell_slots_l2, d.bonus_spell_slots_l3,
				d.bonus_luck_roll
			]
		)
	elif derived_label != null:
		derived_label.text = "→ (entity tidak ditemukan)"


# ── HOLD BUTTON LOGIC ─────────────────────────────────────────────────────────

func _on_button_held(stat_key: String, player_id: int, delta: int, btn: Button) -> void:
	_held_button   = btn
	_held_callback = _step_stat.bind(stat_key, player_id, delta)
	_hold_timer    = 0.0
	_hold_triggered = false


func _on_button_released() -> void:
	_held_button = null
	_hold_triggered = false
	_hold_timer = 0.0


func _process(delta: float) -> void:
	if _held_button == null or not is_instance_valid(_held_button):
		return
	if not _held_button.button_pressed:
		_held_button    = null
		_hold_triggered = false
		_hold_timer     = 0.0
		return

	_hold_timer += delta

	if not _hold_triggered:
		# Tunggu delay awal sebelum mulai repeat
		if _hold_timer >= HOLD_DELAY_SEC:
			_hold_triggered = true
			_hold_timer = 0.0
	else:
		# Sudah melewati delay — repeat dengan kecepatan HOLD_REPEAT_HZ
		if _hold_timer >= (1.0 / HOLD_REPEAT_HZ):
			_hold_timer = 0.0
			_held_callback.call()


# ── DRAG & RESIZE LOGIC ───────────────────────────────────────────────────────

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_offset = event.global_position - self.global_position
		else:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		self.global_position = event.global_position - _drag_offset

func _on_resize_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_resizing = true
			_resize_offset = event.global_position - self.size
		else:
			_is_resizing = false
	elif event is InputEventMouseMotion and _is_resizing:
		self.size = event.global_position - _resize_offset
