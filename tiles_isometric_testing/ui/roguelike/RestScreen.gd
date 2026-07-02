extends Control

# UI Nodes
var title_lbl: Label
var subtitle_lbl: Label
var timer_lbl: Label
var status_lbl: Label
var columns_hbox: HBoxContainer
var p1_buttons: Array[Button] = []
var p2_buttons: Array[Button] = []
var leave_btn: Button

# Choice Options
const OPTIONS_DATA = [
	{
		"name": "Full Rest",
		"desc": "+50% HP, +50% Resource",
		"color_name": "COLOR_GREEN"
	},
	{
		"name": "Partial Rest",
		"desc": "+25% HP, +100% Resource",
		"color_name": "COLOR_CYAN"
	},
	{
		"name": "Scavenge",
		"desc": "Search Camp (Risk Roll)",
		"color_name": "COLOR_YELLOW"
	},
	{
		"name": "Consecrate",
		"desc": "Purge all cursed items",
		"color_name": "COLOR_PINK"
	}
]

var p1_choice: int = -1
var p2_choice: int = -1
var timer: Timer
var time_left: int = 15
var resolved: bool = false

func _ready() -> void:
	# Neobrutalist BG
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", NeobrutalStyle.get_panel(NeobrutalStyle.COLOR_WHITE))
	add_child(bg)
	
	# CenterContainer for dynamic centering under any viewport size
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	# Main layout VBox inside CenterContainer
	var main_vbox = VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 20)
	center_container.add_child(main_vbox)
	
	# Title
	title_lbl = Label.new()
	title_lbl.text = "CAMPFIRE REST AREA"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_color", Color.BLACK)
	main_vbox.add_child(title_lbl)
	
	# Subtitle
	subtitle_lbl = Label.new()
	subtitle_lbl.text = "Agree on an activity to proceed. Consensus is required."
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 18)
	subtitle_lbl.add_theme_color_override("font_color", Color.BLACK)
	main_vbox.add_child(subtitle_lbl)
	
	# Timer Display
	timer_lbl = Label.new()
	timer_lbl.text = "Consensus Timer: 15s"
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.add_theme_font_size_override("font_size", 24)
	timer_lbl.add_theme_color_override("font_color", NeobrutalStyle.COLOR_RED)
	main_vbox.add_child(timer_lbl)
	
	# Columns HBox
	columns_hbox = HBoxContainer.new()
	columns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	columns_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(columns_hbox)
	
	# Player 1 Column
	var p1_vbox = VBoxContainer.new()
	p1_vbox.add_theme_constant_override("separation", 15)
	columns_hbox.add_child(p1_vbox)
	
	var p1_title = Label.new()
	p1_title.text = "PLAYER 1"
	p1_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_title.add_theme_font_size_override("font_size", 24)
	p1_title.add_theme_color_override("font_color", Color.BLACK)
	p1_vbox.add_child(p1_title)
	
	for i in range(OPTIONS_DATA.size()):
		var data = OPTIONS_DATA[i]
		var btn = Button.new()
		btn.text = "%s\n(%s)" % [data["name"], data["desc"]]
		btn.custom_minimum_size = Vector2(350, 80)
		var color = NeobrutalStyle.get_color_by_name(data["color_name"])
		NeobrutalStyle.apply_to_button(btn, color)
		btn.pressed.connect(_on_p1_choice.bind(i))	
		p1_vbox.add_child(btn)
		p1_buttons.append(btn)
		
	# Player 2 Column
	var p2_vbox = VBoxContainer.new()
	p2_vbox.add_theme_constant_override("separation", 15)
	columns_hbox.add_child(p2_vbox)
	
	var p2_title = Label.new()
	p2_title.text = "PLAYER 2"
	p2_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_title.add_theme_font_size_override("font_size", 24)
	p2_title.add_theme_color_override("font_color", Color.BLACK)
	p2_vbox.add_child(p2_title)
	
	for i in range(OPTIONS_DATA.size()):
		var data = OPTIONS_DATA[i]
		var btn = Button.new()
		btn.text = "%s\n(%s)" % [data["name"], data["desc"]]
		btn.custom_minimum_size = Vector2(350, 80)
		var color = NeobrutalStyle.get_color_by_name(data["color_name"])
		NeobrutalStyle.apply_to_button(btn, color)
		btn.pressed.connect(_on_p2_choice.bind(i))
		p2_vbox.add_child(btn)
		p2_buttons.append(btn)
		
	# Status Label
	status_lbl = Label.new()
	status_lbl.text = "Waiting for player votes..."
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 20)
	status_lbl.add_theme_color_override("font_color", Color.BLACK)
	main_vbox.add_child(status_lbl)
	
	# Leave Button
	leave_btn = Button.new()
	leave_btn.text = "Leave Campfire"
	leave_btn.custom_minimum_size = Vector2(250, 60)
	leave_btn.visible = false
	NeobrutalStyle.apply_to_button(leave_btn, NeobrutalStyle.COLOR_GREEN)
	leave_btn.pressed.connect(_on_leave_clicked)
	main_vbox.add_child(leave_btn)
	
	# Start Timer
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)

func _on_timer_tick() -> void:
	if resolved: return
	time_left -= 1
	timer_lbl.text = "Consensus Timer: %ds" % time_left
	if time_left <= 0:
		timer.stop()
		_force_default_choice()

func _on_p1_choice(idx: int) -> void:
	if resolved: return
	p1_choice = idx
	_update_button_highlights()
	_check_consensus()

func _on_p2_choice(idx: int) -> void:
	if resolved: return
	p2_choice = idx
	_update_button_highlights()
	_check_consensus()

func _update_button_highlights() -> void:
	for i in range(p1_buttons.size()):
		if p1_choice == i:
			p1_buttons[i].modulate = Color(1.2, 1.2, 1.2, 1.0)
		elif p1_choice != -1:
			p1_buttons[i].modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			p1_buttons[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
			
	for i in range(p2_buttons.size()):
		if p2_choice == i:
			p2_buttons[i].modulate = Color(1.2, 1.2, 1.2, 1.0)
		elif p2_choice != -1:
			p2_buttons[i].modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			p2_buttons[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
			
	var p1_text = OPTIONS_DATA[p1_choice]["name"] if p1_choice != -1 else "Undecided"
	var p2_text = OPTIONS_DATA[p2_choice]["name"] if p2_choice != -1 else "Undecided"
	if p1_choice != p2_choice:
		status_lbl.text = "P1 selected %s | P2 selected %s. Consensus required!" % [p1_text, p2_text]
	else:
		status_lbl.text = "Consensus reached on %s!" % p1_text

func _check_consensus() -> void:
	if p1_choice != -1 and p2_choice != -1 and p1_choice == p2_choice:
		_resolve_choice(p1_choice)

func _force_default_choice() -> void:
	EventNotifier.show_message("Consensus Timeout! Defaulting to Full Rest.", Color.ORANGE)
	_resolve_choice(0) # Default to Full Rest

func _resolve_choice(choice_idx: int) -> void:
	resolved = true
	timer.stop()
	timer_lbl.visible = false
	
	# Disable all selection buttons
	for btn in p1_buttons: btn.disabled = true
	for btn in p2_buttons: btn.disabled = true
	
	var chosen_option = OPTIONS_DATA[choice_idx]["name"]
	status_lbl.text = "Choice resolved: %s" % chosen_option
	
	# Execute backend logic in RestLootHandler
	var handler = RestLootHandler.new()
	add_child(handler)
	handler.handle_rest_choice(1, choice_idx)
	handler.handle_rest_choice(2, choice_idx)
	handler.queue_free()
	
	# Show leave button
	leave_btn.visible = true
	# Rescan dual cursor so it registers the leave button
	_trigger_cursor_rescan()

func _on_leave_clicked() -> void:
	if RunManager != null and RunManager.has_method("complete_pending_node"):
		RunManager.complete_pending_node("node_completed")

	var current = get_parent()
	var shell = null
	while current and current != get_tree().get_root():
		if "RoguelikeUIShell" in current.name or current.has_method("show_screen"):
			shell = current
			break
		current = current.get_parent()
		
	if shell != null:
		if shell.has_method("transition_to_map"):
			shell.transition_to_map()
		else:
			shell.show_screen("res://ui/roguelike/MapScreen.tscn")

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
