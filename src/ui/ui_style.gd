class_name UiStyle
extends RefCounted
## Shared look for the overlay UI: dark rounded cards with a colored accent per source.

const BACKGROUND: Color = Color(0.10, 0.12, 0.18, 0.96)
const TEXT: Color = Color("eef2fb")
const TEXT_DIM: Color = Color("93a0bd")
const FONT_SIZE: int = 14
const SMALL_FONT_SIZE: int = 12

const STATUS_COLORS: Dictionary = {
	SourceInfo.Status.WORKING: Color("5aa9ff"),
	SourceInfo.Status.DONE: Color("4ccf8a"),
	SourceInfo.Status.NEEDS_INPUT: Color("ffb347"),
	SourceInfo.Status.ERROR: Color("ff5a4d"),
	SourceInfo.Status.IDLE: Color("93a0bd"),
}


static func card(accent: Color, radius: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	return style


static func button(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func style_button(target: Button, accent: Color) -> void:
	target.add_theme_stylebox_override("normal", button(accent.darkened(0.45)))
	target.add_theme_stylebox_override("hover", button(accent.darkened(0.1)))
	target.add_theme_stylebox_override("pressed", button(accent.darkened(0.3)))
	target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	target.add_theme_color_override("font_color", TEXT)
	target.add_theme_color_override("font_hover_color", Color.WHITE)
	target.add_theme_font_size_override("font_size", FONT_SIZE)
	target.focus_mode = Control.FOCUS_NONE
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func label(text: String, size: int = FONT_SIZE, color: Color = TEXT) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func relative_time(wall_time: float) -> String:
	var seconds: int = maxi(int(Time.get_unix_time_from_system() - wall_time), 0)
	if seconds < 10:
		return "now"
	if seconds < 60:
		return "%ds" % seconds
	if seconds < 3600:
		return "%dm" % floori(seconds / 60.0)
	return "%dh" % floori(seconds / 3600.0)
