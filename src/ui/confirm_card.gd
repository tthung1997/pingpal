class_name ConfirmCard
extends PanelContainer
## A small "are you sure?" card for destructive actions. Drawn in-window (not a native dialog)
## because the overlay is transparent, click-through and never takes focus. It cancels itself
## after a few seconds so it can never linger over your work.

signal confirmed
signal cancelled

const TIMEOUT_SECONDS: float = 10.0
const DANGER: Color = Color("ff5a4d")

var _label: Label
var _confirm_button: Button
var _cancel_button: Button
var _left: float = 0.0


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.card(DANGER, 8))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_label = UiStyle.label("", UiStyle.FONT_SIZE)
	column.add_child(_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	UiStyle.style_button(_cancel_button, Color("6fc7f2"))
	_cancel_button.pressed.connect(_finish.bind(false))
	buttons.add_child(_cancel_button)
	_confirm_button = Button.new()
	UiStyle.style_button(_confirm_button, DANGER)
	_confirm_button.pressed.connect(_finish.bind(true))
	buttons.add_child(_confirm_button)
	set_process(false)


## Shows the question (use a newline for a second line) with a confirm button labelled
## `confirm_text`, its bottom-left corner at `at` (parent coordinates).
func ask(text: String, confirm_text: String, at: Vector2) -> void:
	_label.text = text
	_confirm_button.text = confirm_text
	reset_size()
	position = Vector2(at.x, maxf(at.y - size.y, 2.0))
	visible = true
	_left = TIMEOUT_SECONDS
	set_process(true)


func gui_rect() -> Rect2:
	return Rect2(position, size)


## Counts down to the automatic cancel. `_process` drives it; tests call it directly.
func tick(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		_finish(false)


func _process(delta: float) -> void:
	tick(delta)


func _finish(accepted: bool) -> void:
	visible = false
	set_process(false)
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
