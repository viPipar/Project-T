extends Node
class_name FantasyStyle

# Utility to generate Fantasy TTRPG StyleBoxes via code.

static var _metamorphous: Font
static var _pirata_one: Font

static func _load_fonts() -> void:
	if not _metamorphous:
		_metamorphous = load("res://assets/ui_assets/Metamorphous-Regular.ttf") as Font
	if not _pirata_one:
		_pirata_one = load("res://assets/ui_assets/PirataOne-Regular.ttf") as Font

static func apply_title_font(lbl: Control) -> void:
	_load_fonts()
	if _pirata_one and lbl.has_method("add_theme_font_override"):
		lbl.add_theme_font_override("font", _pirata_one)

static func apply_body_font(lbl: Control) -> void:
	_load_fonts()
	if _metamorphous and lbl.has_method("add_theme_font_override"):
		lbl.add_theme_font_override("font", _metamorphous)

static func get_panel(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#5c4033") # Dark Leather/Brown
	
	style.shadow_color = Color(0, 0, 0, 0.4) # Soft shadow
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 4)
	
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	return style

static func get_button_normal(bg_color: Color) -> StyleBoxFlat:
	return get_panel(bg_color)

static func get_button_hover(bg_color: Color) -> StyleBoxFlat:
	var style = get_panel(bg_color.lightened(0.15))
	style.shadow_offset = Vector2(2, 6) # Slight lift
	style.border_color = Color("#d4af37") # Gold highlight on hover
	return style

static func get_button_pressed(bg_color: Color) -> StyleBoxFlat:
	var style = get_panel(bg_color.darkened(0.2))
	style.shadow_offset = Vector2(1, 1) # Pushed in
	return style

# Pre-defined Fantasy Color Palette
static var COLOR_PARCHMENT := Color("#f4e4bc")
static var COLOR_GOLD := Color("#d4af37")
static var COLOR_CRIMSON := Color("#a11d1d")
static var COLOR_SAPPHIRE := Color("#154c79")
static var COLOR_EMERALD := Color("#2e8540")
static var COLOR_BLOOD := Color("#7a0b0b")
static var COLOR_ROYAL := Color("#4b1b6b")
static var COLOR_LEATHER := Color("#5c4033")

static func get_color_by_name(color_name: String) -> Color:
	match color_name:
		"COLOR_WHITE", "COLOR_PARCHMENT": return COLOR_PARCHMENT
		"COLOR_YELLOW", "COLOR_GOLD": return COLOR_GOLD
		"COLOR_PINK", "COLOR_CRIMSON": return COLOR_CRIMSON
		"COLOR_CYAN", "COLOR_SAPPHIRE": return COLOR_SAPPHIRE
		"COLOR_GREEN", "COLOR_EMERALD": return COLOR_EMERALD
		"COLOR_RED", "COLOR_BLOOD": return COLOR_BLOOD
		"COLOR_PURPLE", "COLOR_ROYAL": return COLOR_ROYAL
		"COLOR_GRAY", "COLOR_LEATHER": return COLOR_LEATHER
		_: return COLOR_PARCHMENT

static func apply_to_button(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", get_button_normal(color))
	btn.add_theme_stylebox_override("hover", get_button_hover(color))
	btn.add_theme_stylebox_override("pressed", get_button_pressed(color))
	btn.add_theme_stylebox_override("focus", get_button_hover(color))
	
	var font_c = Color("#2b1d14") if color.get_luminance() > 0.5 else Color("#f4e4bc")
	btn.add_theme_color_override("font_color", font_c)
	btn.add_theme_color_override("font_hover_color", font_c)
	btn.add_theme_color_override("font_pressed_color", font_c.darkened(0.2))
	btn.add_theme_color_override("font_focus_color", font_c)
	
	_load_fonts()
	if _metamorphous:
		btn.add_theme_font_override("font", _metamorphous)
