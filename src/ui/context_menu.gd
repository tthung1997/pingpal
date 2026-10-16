class_name ContextMenu
extends PanelContainer
## Right-click menu on the character. Drawn in-window (not a native popup) because the overlay
## window is transparent and click-through, where native popups misbehave.

signal item_chosen(id: StringName)

var _column: VBoxContainer
var _hide_timer: SceneTreeTimer


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.card(Color("6fc7f2"), 8))
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 3)
	add_child(_column)
	mouse_exited.connect(_on_mouse_exited)
	mouse_entered.connect(func() -> void: _hide_timer = null)


## Shows the menu with `items` ([{id, text}]) at `at` (parent coordinates).
func open(items: Array[Dictionary], at: Vector2) -> void:
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	for item: Dictionary in items:
		var button: Button = Button.new()
		button.text = item["text"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiStyle.style_button(button, Color("6fc7f2"))
		button.pressed.connect(func() -> void:
			visible = false
			item_chosen.emit(item["id"]))
		_column.add_child(button)
	reset_size()
	position = at
	visible = true
	# Moving the pointer away is the only "click outside" we can detect on a click-through window.
	_hide_timer = get_tree().create_timer(3.0)
	var timer: SceneTreeTimer = _hide_timer
	timer.timeout.connect(func() -> void:
		if _hide_timer == timer and not get_global_rect().has_point(get_global_mouse_position()):
			visible = false)


func gui_rect() -> Rect2:
	return Rect2(position, size)


func _on_mouse_exited() -> void:
	_hide_timer = get_tree().create_timer(0.5)
	var timer: SceneTreeTimer = _hide_timer
	timer.timeout.connect(func() -> void:
		if _hide_timer == timer:
			visible = false)
