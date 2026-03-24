extends Control

@export var player_id: int = 1

var _player: Node = null
var _coord_label: Label
var _name_label: Label

func _ready() -> void:
	_build_ui()
	# Cari player dengan retry karena player spawn async
	_find_player()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(12, 12)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.text = "P%d — —" % player_id
	_name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_name_label)

	_coord_label = Label.new()
	_coord_label.text = "Pos: (?, ?)"
	_coord_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_coord_label)

	var move_label := Label.new()
	move_label.name = "MoveLabel"
	move_label.text = "Move: -"
	move_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(move_label)

func _find_player() -> void:
	# Retry sampai player ditemukan (spawn async)
	_player = _scan_for_player()
	if _player == null:
		await get_tree().create_timer(0.3).timeout
		_find_player()
	else:
		EventBus.player_moved.connect(_on_player_moved)

func _scan_for_player() -> Node:
	# Cari di grup "players"
	var all := get_tree().get_nodes_in_group("players")
	for node in all:
		if node.get("player_id") == player_id:
			return node
	return null

func _process(_delta: float) -> void:
	if _player == null:
		return
	_coord_label.text = "Pos: (%d, %d)" % [_player.grid_pos.x, _player.grid_pos.y]
	if _player.get("movement_left") != null:
		var ml := _player.movement_left
		$"../VBoxContainer/MoveLabel".text = "Move: %d" % ml if has_node("../VBoxContainer/MoveLabel") else ""

func _on_player_moved(entity: Node, from: Vector2i, to: Vector2i) -> void:
	if entity != _player:
		return
	_coord_label.text = "Pos: (%d, %d)" % [to.x, to.y]
