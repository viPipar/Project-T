extends Node
class_name NeobrutalStyle

# Utility to generate Neobrutalist StyleBoxes via code.

static func get_panel(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color.BLACK
	
	style.shadow_color = Color.BLACK
	style.shadow_size = 0
	style.shadow_offset = Vector2(8, 8)
	
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	
	return style

static func get_button_normal(bg_color: Color) -> StyleBoxFlat:
	return get_panel(bg_color)

static func get_button_hover(bg_color: Color) -> StyleBoxFlat:
	var style = get_panel(bg_color.lightened(0.2))
	style.shadow_offset = Vector2(10, 10) # Pops out slightly more
	return style

static func get_button_pressed(bg_color: Color) -> StyleBoxFlat:
	var style = get_panel(bg_color.darkened(0.2))
	style.shadow_offset = Vector2(4, 4) # Pushed in
	return style

# Pre-defined Neobrutalist Color Palette
static var COLOR_WHITE := Color("#ffffff")
static var COLOR_YELLOW := Color("#ffde59")
static var COLOR_PINK := Color("#ff66c4")
static var COLOR_CYAN := Color("#00ffff")
static var COLOR_GREEN := Color("#00bf63")
static var COLOR_RED := Color("#ff3131")
static var COLOR_PURPLE := Color("#8c52ff")
static var COLOR_GRAY := Color("#888888")

static func get_color_by_name(color_name: String) -> Color:
	match color_name:
		"COLOR_WHITE": return COLOR_WHITE
		"COLOR_YELLOW": return COLOR_YELLOW
		"COLOR_PINK": return COLOR_PINK
		"COLOR_CYAN": return COLOR_CYAN
		"COLOR_GREEN": return COLOR_GREEN
		"COLOR_RED": return COLOR_RED
		"COLOR_PURPLE": return COLOR_PURPLE
		"COLOR_GRAY": return COLOR_GRAY
		_: return COLOR_WHITE

static func apply_to_button(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", get_button_normal(color))
	btn.add_theme_stylebox_override("hover", get_button_hover(color))
	btn.add_theme_stylebox_override("pressed", get_button_pressed(color))
	btn.add_theme_stylebox_override("focus", get_button_hover(color))
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_focus_color", Color.BLACK)
