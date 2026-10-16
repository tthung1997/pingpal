extends TestCase


func _hub() -> NotificationManager:
	return NotificationManager.new()


## Advances time and returns the notices shown, in order.
func _drain(hub: NotificationManager, seconds: float) -> Array[Notice]:
	var shown: Array[Notice] = []
	hub.notice_shown.connect(func(notice: Notice) -> void: shown.append(notice))
	var elapsed: float = 0.0
	while elapsed < seconds:
		hub.advance(0.1)
		elapsed += 0.1
	return shown


func _ask(hub: NotificationManager, out: Dictionary, source: String = "claude", timeout: float = 45.0) -> void:
	out["result"] = await hub.ask(source, "Ship it?", PackedStringArray(["Yes", "No"]), timeout, 7)


func test_higher_priority_goes_first() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "low one", Notice.Priority.LOW)
	hub.notify("b", "normal one", Notice.Priority.NORMAL)
	hub.notify("c", "high one", Notice.Priority.HIGH)
	var shown: Array[Notice] = _drain(hub, 30.0)
	eq(shown.size(), 3, "all three are eventually shown")
	eq(shown[0].text, "high one", "high priority first")
	eq(shown[1].text, "normal one", "then normal")
	eq(shown[2].text, "low one", "then low")


func test_flood_of_done_is_batched() -> void:
	var hub: NotificationManager = _hub()
	for name: String in ["Claude Code", "Copilot", "Codex", "VS Code"]:
		hub.set_state(name, &"done")
	var shown: Array[Notice] = _drain(hub, 30.0)
	eq(shown.size(), 1, "four finishes become one bubble")
	eq(shown[0].kind, Notice.Kind.SUMMARY, "it is a summary")
	check(shown[0].text.begins_with("4 agents finished"), "summary says how many (got '%s')" % shown[0].text)
	eq(shown[0].batched.size(), 4, "the individual notices are kept")
	check(hub.history.size() >= 4 and hub.history.all(func(n: Notice) -> bool: return n.seen), "history keeps them, marked seen")


func test_two_notices_are_not_batched() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "one")
	hub.notify("b", "two")
	eq(_drain(hub, 30.0).size(), 2, "below the batch threshold they show individually")


func test_high_priority_is_never_batched() -> void:
	var hub: NotificationManager = _hub()
	for index: int in 4:
		hub.notify("s%d" % index, "urgent-ish %d" % index, Notice.Priority.HIGH)
	eq(_drain(hub, 60.0).size(), 4, "important items are each seen")


func test_duplicates_are_dropped() -> void:
	var hub: NotificationManager = _hub()
	check(hub.notify("a", "same")["queued"], "first goes in")
	check(not hub.notify("a", "same")["queued"], "identical repeat is dropped")
	check(hub.notify("b", "same")["queued"], "same text from another source is kept")
	hub.advance(5.0)
	check(hub.notify("a", "same")["queued"], "allowed again after the dedup window")


func test_urgent_interrupts_current_bubble() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "A long-running chat message that is already on screen for a while now")
	hub.advance(0.1)
	eq(hub.current.text.begins_with("A long"), true, "first notice is showing")
	hub.advance(2.0)
	hub.notify("b", "fire!", Notice.Priority.URGENT)
	check(hub.current == null, "the old bubble was taken down")
	hub.advance(0.1)
	eq(hub.current.text, "fire!", "urgent shows immediately")


func test_bubble_time_shrinks_with_backlog() -> void:
	var notice: Notice = Notice.new()
	notice.text = "Build finished with 2 warnings in the api service"
	var alone: float = NotificationManager.duration_for(notice, 0)
	var busy: float = NotificationManager.duration_for(notice, 5)
	check(busy < alone, "backlog shortens bubbles (%f < %f)" % [busy, alone])
	check(busy >= 1.6, "but never below a readable minimum")
	notice.priority = Notice.Priority.URGENT
	check(NotificationManager.duration_for(notice, 0) > alone, "urgent lingers longer")


func test_status_tray() -> void:
	var hub: NotificationManager = _hub()
	hub.set_state("Claude Code", &"working")
	hub.set_state("Copilot", &"working", "indexing")
	eq(hub.active_sources().size(), 2, "both show in the tray")
	hub.set_state("Copilot", &"needs_input", "pick a branch")
	eq(hub.active_sources()[0].display_name, "Copilot", "the source needing you sorts first")
	hub.set_state("Copilot", &"idle")
	hub.set_state("Claude Code", &"done")
	hub.advance(NotificationManager.DONE_FADE_SECONDS + 1.0)
	eq(hub.active_sources().size(), 0, "done chips fade away")


func test_acknowledge_clears_done_but_not_needs_input() -> void:
	var hub: NotificationManager = _hub()
	hub.set_state("a", &"done")
	hub.set_state("b", &"error")
	hub.set_state("c", &"needs_input")
	hub.acknowledge()
	var left: Array[SourceInfo] = hub.active_sources()
	eq(left.size(), 1, "only the blocked source remains")
	eq(left[0].display_name, "c", "the one waiting on the human")


func test_set_state_rejects_unknown_status() -> void:
	check(_hub().set_state("a", &"dancing").has("error"), "unknown status is an error")


func test_ask_returns_the_clicked_choice() -> void:
	var hub: NotificationManager = _hub()
	var out: Dictionary = {}
	_ask(hub, out)
	hub.advance(0.5)
	check(hub.current != null and hub.current.is_ask(), "the question is on screen")
	eq(hub.active_sources()[0].status, SourceInfo.Status.NEEDS_INPUT, "asker shows as needing input")
	check(hub.answer_ask(hub.current.id, 1), "answering works")
	eq(out["result"]["choice"], "No", "the awaiting caller got the choice")
	eq(out["result"]["answered"], true, "marked answered")
	check(hub.current == null, "bubble is gone")
	eq(hub.active_sources()[0].status, SourceInfo.Status.WORKING, "asker goes back to working")


func test_ask_times_out_but_stays_answerable_until_then() -> void:
	var hub: NotificationManager = _hub()
	var out: Dictionary = {}
	_ask(hub, out, "claude", 30.0)
	hub.advance(0.5)
	hub.advance(NotificationManager.ASK_BUBBLE_SECONDS + 1.0)
	check(hub.current == null, "the bubble timed out")
	eq(hub.pending_asks().size(), 1, "but the question is still pending")
	hub.reopen_asks()
	hub.advance(0.5)
	check(hub.current != null and hub.current.is_ask(), "clicking the character brings it back")
	hub.advance(40.0)
	eq(out["result"]["answered"], false, "eventually times out")
	eq(out["result"]["reason"], "timeout", "with a reason")
	eq(hub.pending_asks().size(), 0, "nothing pending")


func test_ask_is_withdrawn_when_client_disconnects() -> void:
	var hub: NotificationManager = _hub()
	var out: Dictionary = {}
	_ask(hub, out)
	hub.advance(0.5)
	hub.cancel_asks_owned_by(7)
	eq(out["result"]["reason"], "cancelled", "the question is cancelled")
	check(hub.current == null, "and the bubble removed")


func test_clear_one_source_and_all() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "a1")
	hub.notify("a", "a2")
	hub.notify("b", "b1")
	hub.set_state("a", &"working")
	hub.set_state("b", &"working")
	hub.clear("a")
	eq(hub.active_sources().size(), 1, "only b is still active")
	var shown: Array[Notice] = _drain(hub, 20.0)
	check(shown.all(func(n: Notice) -> bool: return n.source.display_name == "b"), "a's messages never show")
	hub.set_state("a", &"working")
	hub.clear()
	eq(hub.active_sources().size(), 0, "clear() with no source wipes everything")


func test_every_message_gets_the_single_attention_animation() -> void:
	for pack_id: String in ["corgi", "pip"]:
		var pack: CharacterPack = CharacterPack.load_by_id(pack_id)
		check(pack.resolve(CharacterBrain.ATTENTION_STATE) != pack.resolve(&"idle"), "%s has a distinct attention animation" % pack_id)


func test_text_is_sanitized_and_capped() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "line\u0007break " + "x".repeat(400))
	var notice: Notice = hub.history[0]
	check(notice.text.length() <= NotificationManager.MAX_TEXT_LENGTH + 1, "capped")
	check(not notice.text.contains("\u0007"), "control characters removed")


func test_sources_get_stable_distinct_looks() -> void:
	var registry: SourceRegistry = SourceRegistry.new()
	var claude: SourceInfo = registry.resolve("claude-code")
	eq(claude.family, "claude", "recognised family")
	eq(registry.resolve("Claude Code · api").family, "claude", "variants share a family")
	eq(registry.resolve("Claude Code · api").color, claude.color, "and a color")
	check(registry.resolve("Claude Code · api") != claude, "but are separate sources")
	check(registry.resolve("Visual Studio Code").family == "vscode", "VS Code is recognised")
	check(registry.resolve("Codex").family == "codex", "Codex is recognised (not mistaken for generic 'code')")
	var mine: SourceInfo = registry.resolve("my-script")
	eq(registry.resolve("My-Script"), mine, "names are case-insensitive")
	eq(mine.glyph, "M", "glyph is the initial")
	eq(registry.resolve("  \u0001 ").display_name, "Unknown", "garbage names fall back")
