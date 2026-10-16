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


func test_attention_lasts_until_the_user_checks_the_message() -> void:
	var hub: NotificationManager = _hub()
	check(not hub.needs_attention(), "nothing to check at first")
	hub.notify("a", "hello")
	check(hub.needs_attention(), "a waiting message needs attention")
	hub.advance(0.1)
	check(hub.current != null, "it is on screen")
	hub.advance(NotificationManager.duration_for(hub.current, 0) + 1.0)
	check(hub.current == null, "the bubble timed out")
	check(hub.needs_attention(), "but the message is still unread")
	hub.acknowledge()
	check(not hub.needs_attention(), "opening the history reads it")


func test_clicking_a_bubble_reads_it() -> void:
	var hub: NotificationManager = _hub()
	var changes: Array[int] = [0]
	hub.read_state_changed.connect(func() -> void: changes[0] += 1)
	hub.notify("a", "hello")
	hub.advance(0.1)
	hub.dismiss_current()
	check(not hub.needs_attention(), "waving the bubble away counts as reading it")
	check(changes[0] > 0, "and listeners are told")


func test_reading_a_summary_reads_everything_folded_into_it() -> void:
	var timed_out: NotificationManager = _hub()
	var clicked: NotificationManager = _hub()
	for hub: NotificationManager in [timed_out, clicked]:
		for name: String in ["a", "b", "c"]:
			hub.notify(name, "done with " + name)
		hub.advance(0.1)
		eq(hub.current.kind, Notice.Kind.SUMMARY, "the three became one summary")
	timed_out.advance(30.0)
	check(timed_out.needs_attention(), "a summary that timed out keeps the attention")
	clicked.dismiss_current()
	check(not clicked.needs_attention(), "clicking the summary reads each notice folded into it")


func test_needs_input_keeps_attention_until_the_user_checks_it() -> void:
	var hub: NotificationManager = _hub()
	hub.set_state("a", &"needs_input", "Which branch should I use?")
	hub.advance(0.1)
	eq(hub.current.text, "Which branch should I use?", "the reason is what the bubble says")
	hub.advance(30.0)
	check(hub.current == null and hub.needs_attention(), "the bubble timed out but the user has not looked yet")
	eq(hub.active_sources().size(), 1, "and the chip is still up")
	hub.acknowledge()
	check(not hub.needs_attention(), "opening the history settles it")
	eq(hub.active_sources().size(), 0, "and clears the chip: the user knows and will go to the session")


func test_a_needs_input_chip_never_expires_on_its_own() -> void:
	var hub: NotificationManager = _hub()
	hub.set_state("a", &"needs_input", "Which branch?")
	hub.set_state("b", &"working")
	hub.advance(7 * 24 * 3600.0)
	var names: Array[String] = []
	for source: SourceInfo in hub.active_sources():
		names.append(source.display_name)
	eq(names, ["a"] as Array[String], "after a week away only the stale working chip is gone, not the one waiting for you")


func test_clear_reads_that_sources_messages_only() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "from a")
	hub.advance(0.1)
	hub.advance(30.0)
	hub.notify("b", "from b")
	hub.advance(1.0)
	hub.advance(30.0)
	hub.clear("b")
	check(hub.needs_attention(), "a's message is still unread")
	hub.clear("a")
	check(not hub.needs_attention(), "clearing a reads it too")


func test_the_mcp_clear_keeps_the_history_but_the_user_can_wipe_it() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "one")
	hub.notify("b", "two")
	hub.set_state("a", &"working")
	hub.advance(0.1)
	hub.clear()
	eq(hub.history.size(), 2, "an AI clearing its messages leaves the user's history alone")
	check(not hub.needs_attention(), "but nothing is left to check")
	var changes: Array[int] = [0]
	hub.history_changed.connect(func() -> void: changes[0] += 1)
	hub.clear_history()
	eq(hub.history.size(), 0, "the user's clear empties the history")
	check(changes[0] > 0, "and listeners are told")
	check(not hub.needs_attention(), "with nothing left to check")


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
	eq(hub.active_sources().size(), 1, "an idle source leaves the tray, a finished one stays")
	hub.acknowledge()
	eq(hub.active_sources().size(), 0, "until the user looks")


func test_done_and_error_chips_wait_for_the_user_however_long_it_takes() -> void:
	var hub: NotificationManager = _hub()
	hub.set_state("a", &"done", "All green")
	hub.set_state("b", &"error", "Build failed")
	hub.advance(7 * 24 * 3600.0)
	eq(hub.active_sources().size(), 2, "after a week away both are still there")
	hub.acknowledge()
	eq(hub.active_sources().size(), 0, "and one look clears them")


func test_a_working_chip_survives_while_its_session_keeps_reporting() -> void:
	var hub: NotificationManager = _hub()
	var stale: float = NotificationManager.WORKING_STALE_SECONDS
	hub.set_state("a", &"working", "Running tests")
	hub.set_state("b", &"working")
	hub.advance(stale * 0.7)
	hub.set_state("a", &"working", "Running tests")
	hub.notify("b", "still here")
	hub.advance(stale * 0.7)
	eq(hub.active_sources().size(), 2, "a repeated status or any message counts as the session being alive")
	hub.advance(stale * 0.7)
	eq(hub.active_sources().size(), 0, "and once it falls silent for the whole window the chip goes")


func test_acknowledge_clears_the_chips_that_ask_for_a_look() -> void:
	var hub: NotificationManager = _hub()
	hub.set_state("a", &"done")
	hub.set_state("b", &"error")
	hub.set_state("c", &"needs_input")
	hub.set_state("d", &"working")
	hub.acknowledge()
	var left: Array[SourceInfo] = hub.active_sources()
	eq(left.size(), 1, "only the chip that is not about you remains")
	eq(left[0].display_name, "d", "the one still working")


func test_set_state_rejects_unknown_status() -> void:
	check(_hub().set_state("a", &"dancing").has("error"), "unknown status is an error")


func test_a_working_chip_still_goes_stale() -> void:
	var hub: NotificationManager = _hub()
	hub.set_state("a", &"working")
	hub.advance(NotificationManager.WORKING_STALE_SECONDS + 1.0)
	eq(hub.active_sources().size(), 0, "a crashed agent does not spin forever")


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
	for pack_id: String in ["corgi", "corgi_desk", "pip"]:
		var pack: CharacterPack = CharacterPack.load_by_id(pack_id)
		check(pack.resolve(CharacterBrain.ATTENTION_STATE) != pack.resolve(&"idle"), "%s has a distinct attention animation" % pack_id)


func test_text_is_sanitized_and_capped() -> void:
	var hub: NotificationManager = _hub()
	hub.notify("a", "line\u0007break " + "x".repeat(400))
	var notice: Notice = hub.history[0]
	check(notice.text.length() <= NotificationManager.MAX_TEXT_LENGTH + 1, "capped")
	check(not notice.text.contains("\u0007"), "control characters removed")


func test_long_source_names_are_kept_up_to_the_limit() -> void:
	var registry: SourceRegistry = SourceRegistry.new()
	var title: String = "Add contributor guide for character packs"
	eq(registry.resolve(title).display_name, title, "a 41-character session title is kept whole")
	var shared: String = "Refactor the billing module and its tests, part "
	check(registry.resolve(shared + "one") != registry.resolve(shared + "two"),
		"names that differ after the 40th character are separate sources")
	var too_long: String = "x".repeat(SourceRegistry.MAX_NAME_LENGTH + 20)
	var cut: String = registry.resolve(too_long).display_name
	eq(cut.length(), SourceRegistry.MAX_NAME_LENGTH, "anything past the limit is cut with an ellipsis")
	check(cut.ends_with("…"), "and says so")


func test_sources_get_stable_distinct_looks() -> void:
	var registry: SourceRegistry = SourceRegistry.new()
	var api: SourceInfo = registry.resolve("Copilot · api")
	var web: SourceInfo = registry.resolve("Copilot · web")
	check(api != web, "sessions with different names are separate sources")
	check(api.color != web.color, "and look different even when they share a prefix")
	eq(api.glyph, "C", "glyph is the initial")
	eq(SourceRegistry.new().resolve("Copilot · api").color, api.color, "the same name always gets the same color")
	var mine: SourceInfo = registry.resolve("my-script")
	eq(registry.resolve("My-Script"), mine, "names are case-insensitive")
	eq(mine.glyph, "M", "glyph is the initial")
	eq(registry.resolve("  \u0001 ").display_name, "Unknown", "garbage names fall back")
