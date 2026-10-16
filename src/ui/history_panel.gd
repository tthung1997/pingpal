class_name HistoryPanel
extends PanelContainer
## What you missed: every source's current status plus the latest messages, newest first.
## Unanswered questions show their buttons here, so a bubble that timed out is never lost.

signal closed
signal choice_picked(ask_id: int, index: int)

const MAX_ROWS: int = 30
const PANEL_WIDTH: float = 360.0
const MAX_HEIGHT: float = 240.0

var _hub: NotificationManager
var _list: VBoxContainer
var _scroll: ScrollContainer


func _init(hub: NotificationManager = null) -> void:
	_hub = hub
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.card(Color("6fc7f2")))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title: Label = UiStyle.label("History", UiStyle.FONT_SIZE, UiStyle.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close: Button = Button.new()
	close.text = "×"
	UiStyle.style_button(close, Color("6fc7f2"))
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 60)
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func open() -> void:
	refresh()
	visible = true


func close() -> void:
	visible = false


func gui_rect() -> Rect2:
	return Rect2(position, size)


func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var sources: Array[SourceInfo] = _hub.active_sources()
	for source: SourceInfo in sources:
		_list.add_child(_status_row(source))
	if not sources.is_empty():
		_list.add_child(HSeparator.new())
	var pending: Array[Notice] = _hub.pending_asks()
	for notice: Notice in pending:
		_list.add_child(_notice_row(notice, true))
	var shown: int = 0
	for index: int in range(_hub.history.size() - 1, -1, -1):
		var notice: Notice = _hub.history[index]
		if pending.has(notice):
			continue
		_list.add_child(_notice_row(notice, false))
		shown += 1
		if shown >= MAX_ROWS:
			break
	if shown == 0 and pending.is_empty() and sources.is_empty():
		_list.add_child(UiStyle.label("Nothing yet. Messages from your AIs will show up here.",
			UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT_DIM))
	_fit.call_deferred()
	reset_size()


## Sized after layout, when wrapped labels know their real height.
func _fit() -> void:
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y + 4.0, MAX_HEIGHT)
	reset_size()


func _status_row(source: SourceInfo) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_dot(source.color))
	row.add_child(UiStyle.label(source.display_name, UiStyle.SMALL_FONT_SIZE, source.color.lightened(0.2)))
	var status_text: String = String(source.status_name()).replace("_", " ")
	if not source.status_text.is_empty():
		status_text += ": " + source.status_text
	var detail: Label = UiStyle.label(status_text, UiStyle.SMALL_FONT_SIZE, UiStyle.STATUS_COLORS[source.status])
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = 200.0
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	return row


func _notice_row(notice: Notice, pending: bool) -> Control:
	var accent: Color = notice.source.color if notice.source != null else Color.WHITE
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	row.add_child(_dot(accent))
	var text: Label = UiStyle.label("%s  %s" % [notice.source.display_name, notice.text],
		UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT if notice.seen or pending else UiStyle.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 250.0
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	row.add_child(UiStyle.label(UiStyle.relative_time(notice.wall_time), UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT_DIM))
	if pending:
		var buttons: HBoxContainer = HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 6)
		for index: int in notice.choices.size():
			var button: Button = Button.new()
			button.text = notice.choices[index]
			UiStyle.style_button(button, accent)
			button.pressed.connect(func() -> void: choice_picked.emit(notice.id, index))
			buttons.add_child(button)
		box.add_child(buttons)
	return box


static func _dot(color: Color) -> Control:
	var dot: ColorRect = ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot
