extends Node
## Wires everything together: loads the character, starts the MCP server and routes the hub's
## notices to the character, bubble, status tray and history. Contains no rules of its own.
##
## Layers (signals flow up, calls flow down):
##   MCP clients -> McpHttpServer -> McpProtocol -> McpTools -> PingHub (rules, queue, state)
##   PingHub signals -> Main -> CharacterBrain / SpeechBubble / StatusTray / HistoryPanel

const GROUND_MARGIN: float = 6.0
## Per-source hats/antennas on the character while its bubble is up. Off until they are redrawn
## to match the pixel art; the source colour still shows on the bubble and tray chips.
const SHOW_ACCESSORIES: bool = false
const STACK_GAP: float = 4.0

var _overlay: OverlayWindow
var _stage: Control
var _pack: CharacterPack
var _brain: CharacterBrain
var _actor: CharacterActor
var _hitbox: Control
var _tray: StatusTray
var _bubble: SpeechBubble
var _history: HistoryPanel
var _menu: ContextMenu
var _server: McpHttpServer

var _world: Vector2 = Vector2(640, 420)
var _placed: bool = false
var _pressed: bool = false
var _dragging: bool = false
var _press_x: float = 0.0


func _ready() -> void:
	get_window().title = "PingPal"
	_pack = CharacterPack.load_by_id(PingConfig.pack_id)
	if _pack == null:
		push_warning("PingPal: character '%s' not found, using '%s'" % [PingConfig.pack_id, AppSettings.DEFAULT_PACK])
		_pack = CharacterPack.load_by_id(AppSettings.DEFAULT_PACK)
	if _pack == null:
		push_error("PingPal: no usable character pack. Reinstall or check packs/")
		get_tree().quit(1)
		return
	_build_scene()
	_connect_hub()
	_start_server()
	_overlay.apply()
	if PingConfig.preview.is_empty():
		PingHub.notify("PingPal", "Hi! Listening on port %d" % _server.port(), &"happy", Notice.Priority.LOW)
	else:
		_start_preview()
	if not PingConfig.screenshot_path.is_empty():
		_take_screenshot_later()


## `--preview=<state>`: hold one animation forever (no greeting, no wandering) to inspect it.
func _start_preview() -> void:
	var state: StringName = StringName(PingConfig.preview)
	var animation: StringName = _pack.resolve(state)
	print("PingPal preview: state '%s' -> animation '%s'" % [state, animation])
	_brain.react(state, 0.0)


func _take_screenshot_later() -> void:
	await get_tree().create_timer(PingConfig.screenshot_delay).timeout
	if PingConfig.screenshot_history:
		_open_history()
		await get_tree().create_timer(0.5).timeout
	var count: int = maxi(PingConfig.screenshot_count, 1)
	for index: int in count:
		var path: String = PingConfig.screenshot_path
		if count > 1:
			path = "%s_%02d.png" % [path.get_basename(), index]
		var err: Error = get_viewport().get_texture().get_image().save_png(path)
		print("PingPal screenshot %s (%s)" % [path, error_string(err)])
		if index < count - 1:
			await get_tree().create_timer(PingConfig.screenshot_interval).timeout
	get_tree().quit()


func _build_scene() -> void:
	_overlay = OverlayWindow.new()
	add_child(_overlay)
	_overlay.layout_changed.connect(_on_layout_changed)

	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_brain = CharacterBrain.new(_pack)
	_brain.speed_scale = PingConfig.pixel_scale
	_actor = CharacterActor.new()
	_stage.add_child(_actor)
	_actor.setup(_pack, _brain, PingConfig.pixel_scale)

	_hitbox = Control.new()
	_hitbox.mouse_filter = Control.MOUSE_FILTER_STOP
	_hitbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hitbox.gui_input.connect(_on_hitbox_input)
	_stage.add_child(_hitbox)

	_tray = StatusTray.new()
	_tray.clicked.connect(_open_history)
	_stage.add_child(_tray)

	_bubble = SpeechBubble.new()
	_bubble.dismissed.connect(PingHub.dismiss_current)
	_bubble.choice_picked.connect(_on_choice_picked)
	_stage.add_child(_bubble)

	_history = HistoryPanel.new(PingHub)
	_history.closed.connect(_close_history)
	_history.choice_picked.connect(_on_choice_picked)
	_stage.add_child(_history)

	_menu = ContextMenu.new()
	_menu.item_chosen.connect(_on_menu_item)
	_stage.add_child(_menu)


func _connect_hub() -> void:
	PingHub.notice_shown.connect(_on_notice_shown)
	PingHub.notice_hidden.connect(_on_notice_hidden)
	PingHub.source_changed.connect(_on_source_changed)
	PingHub.ambient_changed.connect(_brain.set_ambient)
	PingHub.history_changed.connect(_refresh_history)


func _start_server() -> void:
	_server = McpHttpServer.new()
	_server.protocol = McpProtocol.new(McpTools.new(PingHub))
	_server.auth_token = PingConfig.auth_token
	add_child(_server)
	_server.connection_closed.connect(PingHub.cancel_asks_owned_by)
	var err: Error = _server.start(PingConfig.port)
	if err != OK:
		var message: String = "Can't listen on port %d (%s). Is PingPal already running?" % [PingConfig.port, error_string(err)]
		push_error("PingPal: " + message)
		PingHub.notify("PingPal", message, &"sad", Notice.Priority.HIGH)
		return
	print("PingPal MCP server listening on http://%s:%d%s" % [McpHttpServer.BIND_ADDRESS, _server.port(), McpHttpServer.MCP_PATH])


# --- Layout ------------------------------------------------------------------------------------

func _on_layout_changed(logical_size: Vector2) -> void:
	_world = logical_size
	var half_width: float = _pack.frame_size.x * PingConfig.pixel_scale * 0.5
	var edge: float = PingConfig.edge_margin + half_width
	var right: float = _world.x - edge
	var left: float = maxf(edge, _world.x - PingConfig.wander_width)
	_actor.floor_y = _world.y - GROUND_MARGIN
	_brain.set_bounds(left, right)
	_brain.set_limits(edge, right)
	if not _placed:
		_placed = true
		_brain.x = lerpf(left, right, 0.7)


func _process(_delta: float) -> void:
	if _actor == null:
		return
	_layout()
	_overlay.set_clickable(_clickable_rects())


func _layout() -> void:
	var hit: Rect2 = _actor.hit_rect()
	_hitbox.position = hit.position
	_hitbox.size = hit.size
	var center_x: float = hit.get_center().x
	var top: float = hit.position.y - 8.0
	if _tray.visible:
		_tray.size = _tray.get_combined_minimum_size()
		_tray.position = Vector2(_clamp_x(center_x - _tray.size.x * 0.5, _tray.size.x), top - _tray.size.y)
		top = _tray.position.y - STACK_GAP
	var bubble_showing: bool = PingHub.current != null and not _history.visible
	_bubble.visible = bubble_showing
	if _history.visible:
		_history.size = _history.get_combined_minimum_size()
		_history.position = Vector2(_clamp_x(center_x - _history.size.x * 0.5, _history.size.x),
			maxf(top - _history.size.y - 6.0, 2.0))
	elif bubble_showing:
		_bubble.size = _bubble.get_combined_minimum_size()
		_bubble.position = Vector2(_clamp_x(center_x - _bubble.size.x * 0.5, _bubble.size.x),
			maxf(top - _bubble.size.y - SpeechBubble.TAIL_SIZE - 2.0, 2.0))
		var tail: float = center_x - _bubble.position.x
		if not is_equal_approx(tail, _bubble.tail_x):
			_bubble.tail_x = tail
			_bubble.queue_redraw()


func _clamp_x(x: float, width: float) -> float:
	return clampf(x, 4.0, maxf(_world.x - width - 4.0, 4.0))


func _clickable_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var hit: Rect2 = _actor.hit_rect()
	rects.append(hit.grow(2.0))
	if _tray.visible:
		rects.append(_tray.gui_rect())
	var card: Rect2 = Rect2()
	if _history.visible:
		card = _history.gui_rect()
	elif _bubble.visible:
		card = _bubble.gui_rect()
	if card.has_area():
		rects.append(card.grow(2.0))
		# Joins the card to the character so the tail and the gap between are drawn and clickable.
		var center_x: float = hit.get_center().x
		rects.append(Rect2(center_x - 12.0, card.end.y, 24.0, maxf(hit.position.y - card.end.y, 1.0)))
	if _menu.visible:
		rects.append(_menu.gui_rect())
	return rects


# --- Hub -> presentation ------------------------------------------------------------------------

func _on_notice_shown(notice: Notice) -> void:
	var effect: StringName = &""
	if notice.priority >= Notice.Priority.URGENT:
		effect = &"jump"
	elif notice.priority >= Notice.Priority.NORMAL:
		effect = &"hop"
	_brain.react(notice.mood_state(), 0.0, effect)
	if SHOW_ACCESSORIES and notice.source != null and notice.source.key != SourceRegistry.SYSTEM_KEY:
		_actor.show_accessory(notice.source)
	_bubble.show_notice(notice)


func _on_notice_hidden(_notice: Notice) -> void:
	if PingConfig.preview.is_empty():
		_brain.release()
	_actor.hide_accessory()
	_bubble.hide_bubble()


func _on_source_changed(_source: SourceInfo) -> void:
	_tray.show_sources(PingHub.active_sources())
	_refresh_history()


func _on_choice_picked(ask_id: int, index: int) -> void:
	PingHub.answer_ask(ask_id, index)
	_refresh_history()


# --- Input -------------------------------------------------------------------------------------

func _on_hitbox_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_pressed = true
				_dragging = false
				_press_x = _stage.get_local_mouse_position().x
			else:
				if _dragging:
					_brain.drop()
				elif _pressed:
					_on_character_clicked()
				_pressed = false
				_dragging = false
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_open_menu()
	elif event is InputEventMouseMotion and _pressed:
		var pointer_x: float = _stage.get_local_mouse_position().x
		if not _dragging and absf(pointer_x - _press_x) > 6.0:
			_dragging = true
		if _dragging:
			_brain.drag_to(pointer_x)


func _on_character_clicked() -> void:
	if _history.visible:
		_close_history()
	elif PingHub.current == null and not PingHub.pending_asks().is_empty():
		PingHub.reopen_asks()
	else:
		_open_history()


func _open_history() -> void:
	PingHub.acknowledge()
	_history.open()


func _close_history() -> void:
	_history.close()


func _refresh_history() -> void:
	if _history != null and _history.visible:
		_history.refresh()


func _open_menu() -> void:
	var mode_name: String = AppSettings.MODE_NAMES[(PingConfig.mode + 1) % AppSettings.MODE_NAMES.size()]
	var items: Array[Dictionary] = [
		{"id": &"history", "text": "History"},
		{"id": &"clear", "text": "Clear everything"},
		{"id": &"mode", "text": "Switch to %s mode" % mode_name},
		{"id": &"screen", "text": "Move to next screen"},
		{"id": &"quit", "text": "Quit PingPal"},
	]
	var pointer: Vector2 = _stage.get_local_mouse_position()
	_menu.open(items, pointer)
	_menu.position = Vector2(_clamp_x(pointer.x, _menu.size.x), maxf(pointer.y - _menu.size.y, 2.0))


func _on_menu_item(id: StringName) -> void:
	match id:
		&"history":
			_open_history()
		&"clear":
			PingHub.clear()
		&"mode":
			PingConfig.store("mode", (PingConfig.mode + 1) % AppSettings.MODE_NAMES.size())
			_overlay.apply()
		&"screen":
			_overlay.move_to_next_screen()
		&"quit":
			get_tree().quit()
