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
			if shell.has_method("transition_to_map"):
				shell.transition_to_map()
			else:
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
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		NeobrutalStyle.apply_to_button(card, NeobrutalStyle.COLOR_GRAY)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)
		
		var label = Label.new()
		label.text = "???\n\nPick a Card"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 24)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(label)
		
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

		var vbox = card.get_child(0) as VBoxContainer
		for c in vbox.get_children():
			c.queue_free()

		var rect = TextureRect.new()
		var placeholder_tex = load("res://assets/ui_assets/placeholder.jpeg")
		rect.texture = placeholder_tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(90, 90)
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(rect)

		var label = Label.new()
		label.text = "%s\n" % data.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(label)

		var rarity_label = Label.new()
		rarity_label.text = ItemRegistry.Rarity.keys()[rarity]
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		rarity_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(rarity_label)

		if i == idx:
			var acquired_label = Label.new()
			acquired_label.text = "(ACQUIRED!)"
			acquired_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			acquired_label.add_theme_color_override("font_color", Color(0, 0.6, 0))
			acquired_label.add_theme_font_size_override("font_size", 18)
			vbox.add_child(acquired_label)

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
