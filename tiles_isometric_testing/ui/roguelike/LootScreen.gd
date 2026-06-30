extends Control

@onready var grid = $HBoxContainer
@onready var title = $Title
@onready var leave_btn = $LeaveButton

var _cards: Array[Dictionary] = []
var _chosen: bool = false

func _ready() -> void:
	# Add Neobrutalism background
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", NeobrutalStyle.get_panel(NeobrutalStyle.COLOR_WHITE))
	add_child(bg)
	move_child(bg, 0)
	
	leave_btn.add_theme_font_size_override("font_size", 24)
	NeobrutalStyle.apply_to_button(leave_btn, NeobrutalStyle.COLOR_PINK)
	leave_btn.pressed.connect(func():
		var current = get_parent()
		var shell = null
		while current and current != get_tree().get_root():
			if "RoguelikeUIShell" in current.name or current.has_method("show_screen"):
				shell = current
				break
			current = current.get_parent()
		if shell:
			shell.show_screen("res://ui/roguelike/MapScreen.tscn")
	)
	leave_btn.visible = false
	
	_generate_loot()
	_populate_cards()

func _generate_loot() -> void:
	var commons = ItemRegistry.get_items_by_rarity(ItemRegistry.Rarity.COMMON)
	var legendaries = ItemRegistry.get_items_by_rarity(ItemRegistry.Rarity.LEGENDARY)
	
	commons.shuffle()
	legendaries.shuffle()
	
	if legendaries.size() > 0:
		_cards.append({
			"data": ItemRegistry.get_item(legendaries[0]),
			"rarity": ItemRegistry.Rarity.LEGENDARY
		})
	if commons.size() >= 2:
		_cards.append({
			"data": ItemRegistry.get_item(commons[0]),
			"rarity": ItemRegistry.Rarity.COMMON
		})
		_cards.append({
			"data": ItemRegistry.get_item(commons[1]),
			"rarity": ItemRegistry.Rarity.COMMON
		})
	
	_cards.shuffle()

func _populate_cards() -> void:
	for child in grid.get_children():
		child.queue_free()
		
	for i in range(_cards.size()):
		var card = Button.new()
		card.custom_minimum_size = Vector2(250, 350)
		card.pivot_offset = Vector2(125, 175)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		NeobrutalStyle.apply_to_button(card, NeobrutalStyle.COLOR_GRAY)
		
		var label = Label.new()
		label.text = "???\n\nPick a Card"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 24)
		card.add_child(label)
		
		card.pressed.connect(_on_card_clicked.bind(i))
		grid.add_child(card)

func _on_card_clicked(idx: int) -> void:
	if _chosen: return
	_chosen = true
	
	leave_btn.visible = true
	title.text = "LOOT REVEALED!"
	
	var children = grid.get_children()
	for i in range(_cards.size()):
		var card = children[i] as Button
		var data = _cards[i]["data"]
		var rarity = _cards[i]["rarity"]
		
		var color = NeobrutalStyle.COLOR_WHITE
		if rarity == ItemRegistry.Rarity.COMMON: color = NeobrutalStyle.COLOR_CYAN
		if rarity == ItemRegistry.Rarity.LEGENDARY: color = NeobrutalStyle.COLOR_YELLOW
		
		NeobrutalStyle.apply_to_button(card, color)
		
		var label = card.get_child(0) as Label
		label.text = "%s\n%s" % [data.name, ItemRegistry.Rarity.keys()[rarity]]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		# Add a visual icon to the card upon reveal
		var rect = TextureRect.new()
		var placeholder_tex = load("res://assets/ui_assets/placeholder.jpeg")
		rect.texture = placeholder_tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(80, 80)
		rect.position = Vector2(85, 80)
		card.add_child(rect)
		
		# Position text below the icon
		label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		label.position.y = 180
		
		if i == idx:
			label.text += "\n(ACQUIRED!)"
			var picker := 1
			if card.has_meta("last_clicked_by_player"):
				picker = card.get_meta("last_clicked_by_player")
			if InventoryManager != null:
				InventoryManager.add_item(picker, data.id)
			card.scale = Vector2(1.1, 1.1)
			if EventBus != null:
				EventBus.item_revealed.emit(rarity)
		else:
			card.modulate = Color(0.6, 0.6, 0.6)
			
	call_deferred("_trigger_cursor_rescan")

func _trigger_cursor_rescan() -> void:
	var current = get_parent()
	var shell = null
	while current and current != get_tree().get_root():
		if "RoguelikeUIShell" in current.name or current.has_method("show_screen"):
			shell = current
			break
		current = current.get_parent()
	if shell and shell.get("dual_cursor") != null:
		shell.dual_cursor.rescan()
