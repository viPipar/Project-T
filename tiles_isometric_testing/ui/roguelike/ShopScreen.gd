extends Control

@onready var grid = $GridContainer
@onready var reroll_btn = $RerollButton

func _ready() -> void:
	# Add Neobrutalism to the background
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", NeobrutalStyle.get_panel(NeobrutalStyle.COLOR_WHITE))
	add_child(bg)
	move_child(bg, 0)
	
	NeobrutalStyle.apply_to_button(reroll_btn, NeobrutalStyle.COLOR_RED)
	
	_populate_shop()

func _populate_shop() -> void:
	# Clear existing
	for child in grid.get_children():
		child.queue_free()
		
	# Mock 7 Items
	for i in range(7):
		var item_card = Button.new()
		item_card.custom_minimum_size = Vector2(250, 350)
		
		# Give it a random color
		var colors = [NeobrutalStyle.COLOR_YELLOW, NeobrutalStyle.COLOR_CYAN, NeobrutalStyle.COLOR_PINK]
		var color = colors[randi() % colors.size()]
		NeobrutalStyle.apply_to_button(item_card, color)
		
		var label = Label.new()
		label.text = "Item 🗡️\nCost: 50"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_color_override("font_color", Color.BLACK)
		item_card.add_child(label)
		
		item_card.pressed.connect(_on_buy_clicked.bind(i))
		grid.add_child(item_card)

func _on_buy_clicked(index: int) -> void:
	print("Bought item at slot: ", index)
	# TODO: Hook to StockManager

func _on_reroll_pressed() -> void:
	print("Rerolled Shop!")
	_populate_shop()
