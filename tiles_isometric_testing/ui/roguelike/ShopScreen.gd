extends Control

@onready var grid = $GridContainer
@onready var reroll_btn = $RerollButton
var coins_label: Label
var _current_stock: Array[Dictionary] = []

const REROLL_COST = 100

func _ready() -> void:
	# Add Neobrutalism to the background
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", NeobrutalStyle.get_panel(NeobrutalStyle.COLOR_WHITE))
	add_child(bg)
	move_child(bg, 0)
	
	# Add Coin Display
	coins_label = Label.new()
	coins_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coins_label.position = Vector2(-380, 20)
	coins_label.add_theme_font_size_override("font_size", 36)
	coins_label.add_theme_color_override("font_color", Color.BLACK)
	add_child(coins_label)
	
	# Add Leave Shop Button
	var leave_btn = Button.new()
	leave_btn.text = "🏃 Leave Shop"
	leave_btn.position = Vector2(20, 20)
	leave_btn.add_theme_font_size_override("font_size", 24)
	NeobrutalStyle.apply_to_button(leave_btn, NeobrutalStyle.COLOR_PINK)
	leave_btn.pressed.connect(func():
		if RunManager != null and RunManager.has_method("complete_pending_node"):
			RunManager.complete_pending_node("node_completed")
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
	add_child(leave_btn)
	
	NeobrutalStyle.apply_to_button(reroll_btn, NeobrutalStyle.COLOR_RED)
	reroll_btn.text = "Reroll Shop (%d Coins)" % REROLL_COST
	
	# Add Patungan P1 -> P2 Button
	var p1_to_p2_btn = Button.new()
	p1_to_p2_btn.text = "💰 P1 Send Half to P2"
	p1_to_p2_btn.position = Vector2(20, 100)
	p1_to_p2_btn.add_theme_font_size_override("font_size", 18)
	NeobrutalStyle.apply_to_button(p1_to_p2_btn, NeobrutalStyle.COLOR_CYAN)
	p1_to_p2_btn.pressed.connect(func():
		if CoinEconomy != null:
			CoinEconomy.send_half(1, 2)
	)
	add_child(p1_to_p2_btn)

	# Add Patungan P2 -> P1 Button
	var p2_to_p1_btn = Button.new()
	p2_to_p1_btn.text = "💰 P2 Send Half to P1"
	p2_to_p1_btn.position = Vector2(20, 160)
	p2_to_p1_btn.add_theme_font_size_override("font_size", 18)
	NeobrutalStyle.apply_to_button(p2_to_p1_btn, NeobrutalStyle.COLOR_YELLOW)
	p2_to_p1_btn.pressed.connect(func():
		if CoinEconomy != null:
			CoinEconomy.send_half(2, 1)
	)
	add_child(p2_to_p1_btn)
	
	_refresh_coins_display()
	if CoinEconomy != null:
		CoinEconomy.balance_changed.connect(_on_coins_changed)
	
	_generate_stock()
	_populate_shop()

func _refresh_coins_display() -> void:
	if CoinEconomy != null:
		coins_label.text = "💰 P1: %d | P2: %d" % [CoinEconomy.get_balance(1), CoinEconomy.get_balance(2)]

func _on_coins_changed(_pid: int, _amt: int) -> void:
	_refresh_coins_display()

func _generate_stock() -> void:
	_current_stock.clear()
	if ItemRegistry == null: return
	
	# Generate 7 items
	for i in range(7):
		var r = randf()
		var target_rarity
		if r < 0.60: target_rarity = ItemRegistry.Rarity.COMMON
		elif r < 0.90: target_rarity = ItemRegistry.Rarity.RARE
		else: target_rarity = ItemRegistry.Rarity.LEGENDARY
		
		var pool = ItemRegistry.get_items_by_rarity(target_rarity)
		if pool.size() == 0:
			pool = ItemRegistry.items.keys() # Fallback
			
		var chosen_id = pool[randi() % pool.size()]
		var item_data = ItemRegistry.get_item(chosen_id)
		
		var cost = 50
		if target_rarity == ItemRegistry.Rarity.RARE: cost = 150
		if target_rarity == ItemRegistry.Rarity.LEGENDARY: cost = 300
		
		_current_stock.append({
			"id": chosen_id,
			"data": item_data,
			"cost": cost,
			"purchased": false
		})

func _populate_shop() -> void:
	# Clear existing
	for child in grid.get_children():
		child.queue_free()
		
	for i in range(_current_stock.size()):
		var stock = _current_stock[i]
		var item_card = Button.new()
		item_card.custom_minimum_size = Vector2(220, 220)
		item_card.pivot_offset = Vector2(110, 110)
		item_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		if stock.purchased:
			NeobrutalStyle.apply_to_button(item_card, NeobrutalStyle.COLOR_GRAY)
			item_card.disabled = true
			var l = Label.new()
			l.text = "SOLD OUT"
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			item_card.add_child(l)
			grid.add_child(item_card)
			continue
			
		# Color based on rarity
		var color = NeobrutalStyle.COLOR_WHITE
		if stock.data.rarity == ItemRegistry.Rarity.COMMON: color = NeobrutalStyle.COLOR_CYAN
		if stock.data.rarity == ItemRegistry.Rarity.RARE: color = NeobrutalStyle.COLOR_PINK
		if stock.data.rarity == ItemRegistry.Rarity.LEGENDARY: color = NeobrutalStyle.COLOR_YELLOW
		
		NeobrutalStyle.apply_to_button(item_card, color)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_card.add_child(vbox)
		
		var rect = TextureRect.new()
		var placeholder_tex = load("res://assets/ui_assets/placeholder.jpeg")
		rect.texture = placeholder_tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(80, 80)
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(rect)
		
		var label = Label.new()
		label.text = "%s\nCost: 💰 %d" % [stock.data.name, stock.cost]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_color_override("font_color", Color.BLACK)
		vbox.add_child(label)
		
		item_card.pressed.connect(_on_buy_clicked.bind(i))
		grid.add_child(item_card)
		
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

func _on_buy_clicked(index: int) -> void:
	var stock = _current_stock[index]
	if stock.purchased: return
	
	var item_card = grid.get_child(index) as Button
	var buyer = 0
	if item_card != null and item_card.has_meta("last_clicked_by_player"):
		buyer = item_card.get_meta("last_clicked_by_player")
		item_card.remove_meta("last_clicked_by_player")
		
	if buyer <= 0:
		if CoinEconomy != null:
			if CoinEconomy.get_balance(1) >= stock.cost: buyer = 1
			elif CoinEconomy.get_balance(2) >= stock.cost: buyer = 2
	
	if buyer > 0:
		if CoinEconomy.get_balance(buyer) >= stock.cost:
			if CoinEconomy.deduct_coins(buyer, stock.cost):
				stock.purchased = true
				if InventoryManager != null:
					InventoryManager.add_item(buyer, stock.id)
				if EventNotifier != null:
					EventNotifier.show_message("P%d Bought: %s" % [buyer, stock.data.name], Color.GREEN)
				_populate_shop()
		else:
			if EventNotifier != null:
				EventNotifier.show_message("P%d needs %d Coins!" % [buyer, stock.cost], Color.RED)
	else:
		if EventNotifier != null:
			EventNotifier.show_message("Not enough coins!", Color.RED)

func _on_reroll_pressed() -> void:
	var reroller = 0
	if reroll_btn.has_meta("last_clicked_by_player"):
		reroller = reroll_btn.get_meta("last_clicked_by_player")
		reroll_btn.remove_meta("last_clicked_by_player")
		
	if reroller <= 0:
		if CoinEconomy != null:
			if CoinEconomy.get_balance(1) >= REROLL_COST: reroller = 1
			elif CoinEconomy.get_balance(2) >= REROLL_COST: reroller = 2
		
	if reroller > 0:
		if CoinEconomy.get_balance(reroller) >= REROLL_COST:
			if CoinEconomy.deduct_coins(reroller, REROLL_COST):
				if EventNotifier != null:
					EventNotifier.show_message("Shop Rerolled by P%d!" % reroller, Color.ORANGE)
				_generate_stock()
				_populate_shop()
		else:
			if EventNotifier != null:
				EventNotifier.show_message("P%d needs %d Coins to Reroll!" % [reroller, REROLL_COST], Color.RED)
	else:
		if EventNotifier != null:
			EventNotifier.show_message("Need %d Coins to Reroll!" % REROLL_COST, Color.RED)
