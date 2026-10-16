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


func test_ask_buttons_answer_the_waiting_tool_call() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	var out: Dictionary = {}
	var runner: Callable = func() -> void:
		out["result"] = await PingHub.ask("Claude", "Deploy?", PackedStringArray(["Ship", "Wait"]))
	runner.call()
	PingHub.advance(1.0)
	await wait_frames(2)
	var buttons: Array[Node] = main._bubble.find_children("*", "Button", true, false)
	eq(buttons.size(), 2, "the bubble has a button per choice")
	(buttons[1] as Button).pressed.emit()
	eq(out["result"]["choice"], "Wait", "clicking a button resolves the ask")
	main.queue_free()


func test_unanswered_question_can_be_reopened_by_clicking_the_character() -> void:
	var main: Node = await _boot()
	PingHub.advance(10.0)
	var runner: Callable = func() -> void:
		await PingHub.ask("Claude", "Deploy?", PackedStringArray(["Ship", "Wait"]), 120.0)
	runner.call()
	PingHub.advance(1.0)
	PingHub.advance(NotificationManager.ASK_BUBBLE_SECONDS + 1.0)
	check(PingHub.current == null, "bubble timed out")
	_click(main, MOUSE_BUTTON_LEFT)
	PingHub.advance(1.0)
	check(PingHub.current != null and PingHub.current.is_ask(), "clicking brings the question back")
	PingHub.clear()
	main.queue_free()


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
