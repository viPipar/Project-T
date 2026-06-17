# ui/debug/DebugPanel.gd
# Tanggung jawab:
#   Panel debug ringan untuk melihat class, stat final, derived stat, dan HP runtime.
#
# Cara pakai:
#   Panel ini aktif dari Main.tscn.
#   Toggle "Show Stats & Classes" untuk melihat data player/enemy.
#
# Cara evaluasi:
#   1. Jalankan Main.tscn.
#   2. Aktifkan toggle stats.
#   3. Serang enemy dan pastikan angka HP di panel ikut berubah.
extends Control

@export var show_stats_default: bool = false

@onready var _controls_label: Label = $DebugLabel
@onready var _stats_toggle: CheckBox = $StatsToggle
@onready var _stats_label: Label = $StatsLabel
var _refresh_timer: float = 0.0


func _ready() -> void:
	if _stats_toggle != null:
		_stats_toggle.text = "Show Stats & Classes"
		if not _stats_toggle.toggled.is_connected(_on_stats_toggled):
			_stats_toggle.toggled.connect(_on_stats_toggled)
	if _stats_label != null:
		_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_stats_label.custom_minimum_size = Vector2(600, 80)
	_set_stats_visible(show_stats_default)
	_connect_bus()
	_refresh_stats()


func _process(delta: float) -> void:
	if _stats_label == null or not _stats_label.visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.5:
		_refresh_timer = 0.0
		_refresh_stats()


func _set_stats_visible(is_visible: bool) -> void:
	if _stats_label != null:
		_stats_label.visible = is_visible
	if _stats_toggle != null:
		_stats_toggle.button_pressed = is_visible


func _on_stats_toggled(pressed: bool) -> void:
	_set_stats_visible(pressed)
	if pressed:
		_refresh_stats()


func _connect_bus() -> void:
	if EventBus != null:
		if not EventBus.stats_changed.is_connected(_on_stats_changed):
			EventBus.stats_changed.connect(_on_stats_changed)
		if not EventBus.class_changed.is_connected(_on_class_changed):
			EventBus.class_changed.connect(_on_class_changed)
		if not EventBus.buffs_changed.is_connected(_on_buffs_changed):
			EventBus.buffs_changed.connect(_on_buffs_changed)


func _on_stats_changed(_entity: Node) -> void:
	_refresh_stats()


func _on_class_changed(_entity: Node, _class_id: String) -> void:
	_refresh_stats()


func _on_buffs_changed(_entity: Node) -> void:
	_refresh_stats()


func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var lines: Array[String] = []
	lines.append("Stats & Classes:")

	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		lines.append("Players: (none)")
	else:
		for p in players:
			lines.append(_format_entity_stats(p, "P"))

	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		lines.append("Enemies: (none)")
	else:
		for e in enemies:
			lines.append(_format_entity_stats(e, "E"))

	_stats_label.text = "\n".join(lines)


func _format_entity_stats(entity: Node, prefix: String) -> String:
	var name := ""
	var pid := -1
	if entity != null:
		name = str(_safe_get(entity, "char_name", ""))
		if name == "":
			name = str(_safe_get(entity, "enemy_name", ""))
		if name == "":
			name = entity.name
		var raw_pid = _safe_get(entity, "player_id", -1)
		if typeof(raw_pid) == TYPE_INT:
			pid = raw_pid

	var class_title := "Unknown"
	var buffs_text := "(none)"

	var class_comp := entity.get_node_or_null("ClassComponent") as ClassComponent
	if class_comp != null:
		var class_data := class_comp.get_primary_class()
		class_title = class_data.get("name", "Unknown")
		var buffs := class_comp.get_all_buffs()
		if not buffs.is_empty():
			var names: Array[String] = []
			for b in buffs:
				names.append(b.get("name", b.get("buff_id", "buff")))
			buffs_text = ", ".join(names)

	var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
	var health := entity.get_node_or_null("HealthComponent") as HealthComponent
	var stat_line := ""
	var derived_line := ""
	var hp_text := ""
	if health != null:
		hp_text = "HP %d/%d" % [health.current_hp, health.max_hp]
	if stats != null:
		stat_line = "VIT %d STR %d INT %d CON %d ACC %d DEX %d MOV %d ATT %d LCK %d" % [
			stats.get_stat("vit"), stats.get_stat("str"), stats.get_stat("int"),
			stats.get_stat("con"), stats.get_stat("acc"), stats.get_stat("dex"),
			stats.get_stat("mov"), stats.get_stat("att"), stats.get_stat("lck")
		]
		if hp_text == "":
			hp_text = "MaxHP %d" % stats.get_max_hp()
		derived_line = "%s ARM %d RES %d AP+%d Mv+%d Hit+%d Crit-%d Slots %d/%d/%d" % [
			hp_text, stats.get_armor(), stats.get_resist(),
			stats.bonus_action_points(), stats.bonus_movement_tiles(),
			stats.hit_roll_bonus(), stats.crit_roll_reduction(),
			stats.get_spell_slots_l1(), stats.get_spell_slots_l2(), stats.get_spell_slots_l3()
		]

	var header := "%s %s | Class: %s" % [prefix, name, class_title]
	if prefix == "P" and pid >= 0:
		header = "%s%d %s | Class: %s" % [prefix, pid, name, class_title]
	var buffs_line := "Buffs: %s" % buffs_text
	if stat_line == "":
		if hp_text != "":
			return "%s\n%s\n%s" % [header, buffs_line, hp_text]
		return "%s\n%s" % [header, buffs_line]
	return "%s\n%s\n%s\n%s" % [header, buffs_line, stat_line, derived_line]


func _safe_get(entity: Node, prop: String, fallback) -> Variant:
	if entity == null:
		return fallback
	for info in entity.get_property_list():
		if info.name == prop:
			return entity.get(prop)
	return fallback
