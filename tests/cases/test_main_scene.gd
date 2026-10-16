extends TestCase
## Drives the real main scene headlessly with synthetic input.

const MAIN_SCENE: String = "res://src/main.tscn"


func _click(main: Node, button_index: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button_index
		event.pressed = pressed
		main._on_hitbox_input(event)


func _boot(keep_greeting: bool = false) -> Node:
	PingConfig.port = 0
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await wait_frames(3)
	if not keep_greeting:
		PingHub.clear()
		PingHub.history.clear()
	return main


func test_main_scene_boots_with_server_and_greeting() -> void:
	var main: Node = await _boot(true)
	check(main._server.is_running(), "MCP server is listening")
	check(main._server.port() > 0, "on a real port")
	check(main._actor != null and main._pack.is_valid(), "character is on stage")
	check(PingHub.history.size() >= 1, "it greets on startup")
	main.queue_free()


func test_clicking_the_character_toggles_history() -> void:
	var main: Node = await _boot()
	_click(main, MOUSE_BUTTON_LEFT)
	check(main._history.visible, "left click opens the history")
	_click(main, MOUSE_BUTTON_LEFT)
	check(not main._history.visible, "and closes it")
	main.queue_free()


func test_notice_shows_bubble_and_makes_character_react() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	PingHub.notify("Copilot", "Build finished")
	PingHub.advance(1.0)
	await wait_frames(2)
	check(main._bubble.visible, "bubble is up")
	eq(main._brain.mode, CharacterBrain.Mode.ATTENTION, "character gets attention")
	eq(main._brain.anim_state, &"attention", "with the one attention animation")
	var rects: Array[Rect2] = main._clickable_rects()
	check(rects.size() >= 3, "bubble and connector are clickable (%d rects)" % rects.size())
	PingHub.advance(30.0)
	await wait_frames(2)
	check(not main._bubble.visible, "bubble goes away on its own")
	main.queue_free()


func test_needs_input_shows_a_chip_and_attention_until_the_user_looks() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	PingHub.set_state("Refactor billing", &"needs_input", "Which branch should I use?")
	PingHub.advance(1.0)
	await wait_frames(2)
	check(main._bubble.visible, "the reason is in the bubble")
	check(main._tray.visible, "and a chip is up")
	eq(main._brain.mode, CharacterBrain.Mode.ATTENTION, "and the character asks for a look")
	PingHub.advance(60.0)
	await wait_frames(2)
	check(not main._bubble.visible, "the bubble times out")
	check(main._tray.visible, "but the chip stays")
	eq(main._brain.mode, CharacterBrain.Mode.ATTENTION, "and so does the attention")
	_click(main, MOUSE_BUTTON_LEFT)
	await wait_frames(2)
	check(not main._tray.visible, "opening the history clears the chip")
	eq(main._brain.mode, CharacterBrain.Mode.IDLE, "and the attention")
	main.queue_free()


func test_a_long_source_name_does_not_stretch_the_bubble_or_history() -> void:
	var registry: SourceRegistry = SourceRegistry.new()
	var long_name: String = "Refactor the billing module and its tests across the api and web apps"
	var notice: Notice = Notice.new()
	notice.source = registry.resolve(long_name)
	notice.text = "Hi"
	var bubble: SpeechBubble = SpeechBubble.new()
	tree.root.add_child(bubble)
	bubble.show_notice(notice)
	await wait_frames(2)
	var short_notice: Notice = Notice.new()
	short_notice.source = registry.resolve("Docs")
	short_notice.text = "Hi"
	var short_bubble: SpeechBubble = SpeechBubble.new()
	tree.root.add_child(short_bubble)
	short_bubble.show_notice(short_notice)
	await wait_frames(2)
	check(bubble.size.x < SpeechBubble.MAX_TEXT_WIDTH + 60.0, "the name is cut instead of widening the bubble (%s)" % bubble.size.x)
	check(bubble.size.x > short_bubble.size.x, "but a long name still gets more room than a short one")
	bubble.queue_free()
	short_bubble.queue_free()

	PingHub.clear()
	PingHub.history.clear()
	PingHub.set_state(long_name, &"working", "Writing tests")
	var history: HistoryPanel = HistoryPanel.new(PingHub)
	tree.root.add_child(history)
	history.open()
	await wait_frames(3)
	check(history.size.x < 460.0, "a long source name wraps in the history instead of widening it (%s)" % history.size.x)
	history.queue_free()
	PingHub.clear()


func test_attention_stays_until_the_user_checks_the_message() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	PingHub.notify("Copilot", "Build finished")
	PingHub.advance(1.0)
	await wait_frames(2)
	eq(main._brain.mode, CharacterBrain.Mode.ATTENTION, "a message gets attention")
	PingHub.advance(30.0)
	await wait_frames(2)
	check(not main._bubble.visible, "the bubble timed out")
	eq(main._brain.mode, CharacterBrain.Mode.ATTENTION, "but the character keeps asking for a look")
	_click(main, MOUSE_BUTTON_LEFT)
	check(main._history.visible, "clicking the character opens the history")
	eq(main._brain.mode, CharacterBrain.Mode.IDLE, "and checking the messages ends the attention")
	main.queue_free()


func test_clicking_the_bubble_ends_the_attention() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	PingHub.notify("Copilot", "Build finished")
	PingHub.advance(1.0)
	await wait_frames(2)
	eq(main._brain.mode, CharacterBrain.Mode.ATTENTION, "a message gets attention")
	main._bubble.dismissed.emit()
	eq(main._brain.mode, CharacterBrain.Mode.IDLE, "clicking the bubble reads it")
	main.queue_free()


func test_a_message_while_the_history_is_open_needs_no_attention() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	_click(main, MOUSE_BUTTON_LEFT)
	check(main._history.visible, "the history is open")
	PingHub.notify("Copilot", "Build finished")
	PingHub.advance(1.0)
	await wait_frames(2)
	eq(main._brain.mode, CharacterBrain.Mode.IDLE, "the user is already reading, so no attention is needed")
	main.queue_free()


func test_attention_resumes_after_dragging() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	PingHub.notify("Copilot", "Build finished")
	PingHub.advance(1.0)
	await wait_frames(2)
	main._brain.drag_to(main._brain.x + 30.0)
	eq(main._brain.mode, CharacterBrain.Mode.HELD, "dragging holds the character")
	PingHub.advance(30.0)
	await wait_frames(2)
	eq(main._brain.mode, CharacterBrain.Mode.HELD, "a timed-out bubble does not interrupt the drag")
	main._pressed = true
	main._dragging = true
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	main._on_hitbox_input(release)
	eq(main._brain.mode, CharacterBrain.Mode.ATTENTION, "after the drop the unread message still gets attention")
	main.queue_free()


func test_history_rows_set_the_source_apart_from_the_message() -> void:
	PingHub.clear()
	PingHub.history.clear()
	PingHub.notify("General chat", "Fun fact: flamingos are called a flamboyance")
	var history: HistoryPanel = HistoryPanel.new(PingHub)
	tree.root.add_child(history)
	history.open()
	await wait_frames(3)
	var name_label: Label = null
	var text_label: Label = null
	for node: Node in history.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text == "General chat":
			name_label = label
		elif label.text.begins_with("Fun fact"):
			text_label = label
	check(name_label != null, "the source name is its own label")
	check(text_label != null, "the message is its own label, without the name in front of it")
	if name_label != null and text_label != null:
		check(name_label.get_theme_color("font_color") != text_label.get_theme_color("font_color"),
			"the source is in its accent color, the message in the normal text color")
		check(name_label.get_theme_font_size("font_size") < text_label.get_theme_font_size("font_size"),
			"and the source is the smaller of the two")
		check(name_label.get_global_rect().position.y < text_label.get_global_rect().position.y,
			"the source sits above its message")
	history.queue_free()
	PingHub.clear()
	PingHub.history.clear()


func test_clear_everything_asks_first_and_then_empties_the_history_panel() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	PingHub.notify("Copilot", "Build finished")
	PingHub.set_state("Copilot", &"working")
	PingHub.advance(1.0)
	await wait_frames(2)
	_click(main, MOUSE_BUTTON_LEFT)
	check(main._history.visible, "the history is open")
	var shows_message: Callable = func() -> bool:
		return not main._history.find_children("*", "Label", true, false).filter(
			func(node: Node) -> bool: return (node as Label).text == "Build finished").is_empty()
	check(shows_message.call(), "and lists the message")

	main._on_menu_item(&"clear")
	check(main._confirm.visible, "choosing Clear everything asks first")
	eq(PingHub.history.size(), 1, "nothing has been deleted yet")
	check(main._clickable_rects().any(func(rect: Rect2) -> bool: return rect.encloses(main._confirm.gui_rect())),
		"the question is inside the clickable area, so it is drawn and clickable")

	main._confirm._cancel_button.pressed.emit()
	check(not main._confirm.visible, "Cancel closes the question")
	eq(PingHub.history.size(), 1, "and keeps everything")
	eq(PingHub.active_sources().size(), 1, "including the tray chip")

	main._on_menu_item(&"clear")
	main._confirm._confirm_button.pressed.emit()
	await wait_frames(3)
	check(not main._confirm.visible, "confirming closes the question")
	eq(PingHub.history.size(), 0, "and empties the history")
	check(not shows_message.call(), "the open history panel no longer shows it")
	eq(PingHub.active_sources().size(), 0, "and the tray chips are gone")
	main.queue_free()


func test_the_clear_question_cancels_itself() -> void:
	var card: ConfirmCard = ConfirmCard.new()
	tree.root.add_child(card)
	var outcome: Array[String] = []
	card.confirmed.connect(func() -> void: outcome.append("confirmed"))
	card.cancelled.connect(func() -> void: outcome.append("cancelled"))
	card.ask("Sure?", "Yes", Vector2(50, 100))
	check(card.visible, "it is up")
	card.tick(ConfirmCard.TIMEOUT_SECONDS - 1.0)
	check(card.visible, "it waits a while")
	card.tick(2.0)
	check(not card.visible, "then goes away on its own")
	eq(outcome, ["cancelled"] as Array[String], "counting as a cancel, never a confirm")
	card.tick(100.0)
	eq(outcome.size(), 1, "and only once")
	card.queue_free()


func test_right_click_opens_the_menu() -> void:
	var main: Node = await _boot()
	_click(main, MOUSE_BUTTON_RIGHT)
	check(main._menu.visible, "context menu opens")
	main.queue_free()


func test_switching_pack_from_menu_updates_character_and_persists_setting() -> void:
	var previous_pack: String = PingConfig.pack_id
	var main: Node = await _boot()
	_click(main, MOUSE_BUTTON_RIGHT)
	main._on_menu_item(&"pack:corgi_desk")
	eq(main._pack.id, "corgi_desk", "character switches in-game to corgi_desk")
	eq(PingConfig.pack_id, "corgi_desk", "PingConfig updates pack_id")
	var reloaded: AppSettings = AppSettings.new()
	reloaded.load_settings(PackedStringArray())
	eq(reloaded.pack_id, "corgi_desk", "next run remembers the selected pack from settings.cfg")
	reloaded.free()
	PingConfig.store("pack_id", previous_pack)
	main.queue_free()
