class_name StatusTray
extends HBoxContainer
## One round chip per active AI source, in the source's color with its initial, and a small badge
## for its state: spinning ring (working), check (done), "!" (needs input), cross (error).
## Clicking opens the history.

signal clicked

const CHIP_SIZE: float = 28.0


func _init() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false


## Rebuilds the chips for the sources that are doing something (most urgent first).
func show_sources(sources: Array[SourceInfo]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for source: SourceInfo in sources:
		var chip: TrayChip = TrayChip.new()
		chip.source = source
		add_child(chip)
	visible = not sources.is_empty()
	reset_size()


func gui_rect() -> Rect2:
	return Rect2(position, size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


class TrayChip extends Control:
	var source: SourceInfo

	func _init() -> void:
		custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		# Spinner and pulse animate; static statuses need no redraw.
		queue_redraw()

	func _draw() -> void:
		if source == null:
			return
		var center: Vector2 = Vector2(CHIP_SIZE, CHIP_SIZE) * 0.5
		draw_circle(center, 13.0, source.color.darkened(0.6))
		draw_arc(center, 12.0, 0.0, TAU, 28, source.color, 2.0)
		var font: Font = get_theme_default_font()
		var glyph_size: int = 14
		var text_pos: Vector2 = Vector2(0.0, center.y + (font.get_ascent(glyph_size) - font.get_descent(glyph_size)) * 0.5)
		draw_string(font, text_pos, source.glyph, HORIZONTAL_ALIGNMENT_CENTER, CHIP_SIZE, glyph_size, Color.WHITE)
		_draw_badge(Vector2(CHIP_SIZE - 7.0, CHIP_SIZE - 7.0))

	func _draw_badge(at: Vector2) -> void:
		var time: float = Time.get_ticks_msec() / 1000.0
		var color: Color = UiStyle.STATUS_COLORS[source.status]
		match source.status:
			SourceInfo.Status.WORKING:
				draw_circle(at, 6.0, Color("1b2540"))
				draw_arc(at, 4.0, time * 5.0, time * 5.0 + PI * 1.4, 12, color, 2.0)
			SourceInfo.Status.DONE:
				draw_circle(at, 6.0, color)
				draw_polyline(PackedVector2Array([at + Vector2(-3, 0), at + Vector2(-1, 2.5), at + Vector2(3, -2.5)]),
					Color.WHITE, 1.6)
			SourceInfo.Status.NEEDS_INPUT:
				var pulse: float = 6.0 + sin(time * 6.0) * 1.2
				draw_circle(at, pulse, color)
				draw_rect(Rect2(at + Vector2(-0.8, -3.5), Vector2(1.6, 4.5)), Color.WHITE)
				draw_rect(Rect2(at + Vector2(-0.8, 2.0), Vector2(1.6, 1.6)), Color.WHITE)
			SourceInfo.Status.ERROR:
				draw_circle(at, 6.0, color)
				draw_line(at + Vector2(-2.5, -2.5), at + Vector2(2.5, 2.5), Color.WHITE, 1.6)
				draw_line(at + Vector2(-2.5, 2.5), at + Vector2(2.5, -2.5), Color.WHITE, 1.6)
