class_name SpeechBubble
extends PanelContainer
## The speech bubble: source name and the text. Clicking the body dismisses it. It only displays;
## the hub decides what is shown and for how long.

signal dismissed

const MAX_TEXT_WIDTH: float = 280.0
## Longest the source name may be before it is cut with an ellipsis (the history shows it in full).
const MAX_NAME_WIDTH: float = 260.0
const TAIL_SIZE: float = 8.0

## X of the tail tip relative to this control; the owner sets it so the tail points at the character.
var tail_x: float = 40.0

var _name_label: Label
var _glyph: Label
var _text_label: Label
var _accent: Color = Color.WHITE
var _tween: Tween


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	_glyph = UiStyle.label("?", UiStyle.SMALL_FONT_SIZE, Color.WHITE)
	header.add_child(_glyph)
	_name_label = UiStyle.label("", UiStyle.SMALL_FONT_SIZE)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_name_label)
	_text_label = UiStyle.label("")
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size.x = 60.0
	column.add_child(_text_label)


func show_notice(notice: Notice) -> void:
	_accent = notice.source.color if notice.source != null else Color.WHITE
	add_theme_stylebox_override("panel", UiStyle.card(_accent))
	_glyph.text = notice.source.glyph if notice.source != null else "?"
	_glyph.add_theme_color_override("font_color", _accent)
	_name_label.text = notice.source.display_name if notice.source != null else ""
	_name_label.add_theme_color_override("font_color", _accent.lightened(0.2))
	var name_font: Font = _name_label.get_theme_font("font")
	var name_natural: float = name_font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiStyle.SMALL_FONT_SIZE).x
	_name_label.custom_minimum_size.x = minf(name_natural + 2.0, MAX_NAME_WIDTH)
	_text_label.text = notice.text
	# Short text hugs its content; long text wraps at MAX_TEXT_WIDTH.
	var font: Font = _text_label.get_theme_font("font")
	var natural: float = font.get_multiline_string_size(notice.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiStyle.FONT_SIZE).x
	_text_label.custom_minimum_size.x = clampf(natural + 2.0, 60.0, MAX_TEXT_WIDTH)
	reset_size()
	visible = true
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)


func hide_bubble() -> void:
	if _tween != null:
		_tween.kill()
	visible = false


func gui_rect() -> Rect2:
	return Rect2(position, size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismissed.emit()
		accept_event()


func _draw() -> void:
	var tip: float = clampf(tail_x, 14.0, size.x - 14.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(tip - TAIL_SIZE, size.y - 2.0), Vector2(tip + TAIL_SIZE, size.y - 2.0),
		Vector2(tip, size.y + TAIL_SIZE)]), UiStyle.BACKGROUND)
	draw_line(Vector2(tip - TAIL_SIZE, size.y - 1.0), Vector2(tip, size.y + TAIL_SIZE), _accent, 2.0)
	draw_line(Vector2(tip + TAIL_SIZE, size.y - 1.0), Vector2(tip, size.y + TAIL_SIZE), _accent, 2.0)
