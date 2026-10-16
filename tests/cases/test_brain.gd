extends TestCase


func _brain(seed_value: int = 1) -> CharacterBrain:
	var brain: CharacterBrain = CharacterBrain.new(CharacterPack.load_by_id("pip"))
	brain.rng.seed = seed_value
	brain.set_limits(0.0, 600.0)
	brain.x = 300.0
	return brain


## Runs the brain and returns every anim_state it showed.
func _run(brain: CharacterBrain, seconds: float, step: float = 0.1) -> Dictionary:
	var seen: Dictionary = {}
	var elapsed: float = 0.0
	while elapsed < seconds:
		brain.update(step)
		seen[brain.anim_state] = true
		elapsed += step
	return seen


func test_idles_and_takes_random_breaks() -> void:
	var seen: Dictionary = _run(_brain(), 600.0)
	check(seen.has(&"idle"), "it idles")
	for break_state: StringName in [&"sleep", &"play", &"dance"]:
		check(seen.has(break_state), "it eventually plays the '%s' break" % break_state)
	check(not seen.has(&"attention"), "it never asks for attention on its own")


func test_breaks_are_short_and_return_to_idle() -> void:
	var brain: CharacterBrain = _brain()
	var low: float = float(brain.pack.behavior["break_seconds"][0])
	var high: float = float(brain.pack.behavior["break_seconds"][1])
	var break_started: float = -1.0
	var elapsed: float = 0.0
	var finished: int = 0
	while elapsed < 300.0:
		var before: CharacterBrain.Mode = brain.mode
		brain.update(0.05)
		elapsed += 0.05
		if before == CharacterBrain.Mode.IDLE and brain.mode == CharacterBrain.Mode.BREAK:
			break_started = elapsed
		elif before == CharacterBrain.Mode.BREAK and brain.mode == CharacterBrain.Mode.IDLE:
			var length: float = elapsed - break_started
			check(length >= low - 0.1 and length <= high + 0.1, "a break lasts %.2fs, within [%.1f, %.1f]" % [length, low, high])
			eq(brain.anim_state, &"idle", "and hands back to the idle loop")
			finished += 1
	check(finished >= 5, "several breaks happen over five minutes (%d)" % finished)


func test_no_break_repeats_back_to_back() -> void:
	var brain: CharacterBrain = _brain()
	var last: StringName = &""
	var elapsed: float = 0.0
	while elapsed < 1200.0:
		var before: CharacterBrain.Mode = brain.mode
		brain.update(0.1)
		elapsed += 0.1
		if before == CharacterBrain.Mode.IDLE and brain.mode == CharacterBrain.Mode.BREAK:
			check(brain.anim_state != last, "'%s' does not repeat immediately" % brain.anim_state)
			last = brain.anim_state


func test_a_pack_without_breaks_idles_forever() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/pip/pack.json"))
	(manifest["behavior"] as Dictionary).erase("breaks")
	var pack: CharacterPack = CharacterPack.new()
	pack.configure(manifest, ImageTexture.create_from_image(Image.create(128, 320, false, Image.FORMAT_RGBA8)))
	var brain: CharacterBrain = CharacterBrain.new(pack)
	var seen: Dictionary = _run(brain, 600.0)
	eq(seen.keys(), [&"idle"], "only idle is ever shown")


func test_the_character_never_moves_on_its_own() -> void:
	var brain: CharacterBrain = _brain()
	_run(brain, 600.0)
	eq(brain.x, 300.0, "x never changes")


func test_message_gets_attention_until_released() -> void:
	var brain: CharacterBrain = _brain()
	brain.react()
	eq(brain.mode, CharacterBrain.Mode.ATTENTION, "a message puts the character in ATTENTION")
	eq(brain.anim_state, &"attention", "it plays the one attention animation")
	var seen: Dictionary = _run(brain, 60.0)
	eq(seen.keys(), [&"attention"], "it is held for as long as the message is up")
	brain.release()
	eq(brain.mode, CharacterBrain.Mode.IDLE, "release returns to idle")
	eq(brain.anim_state, &"idle", "and the idle loop")


func test_message_interrupts_a_break() -> void:
	var brain: CharacterBrain = _brain()
	var elapsed: float = 0.0
	while brain.mode != CharacterBrain.Mode.BREAK and elapsed < 120.0:
		brain.update(0.1)
		elapsed += 0.1
	eq(brain.mode, CharacterBrain.Mode.BREAK, "a break starts")
	brain.react()
	eq(brain.anim_state, &"attention", "a message cuts the break short")
	brain.release()
	_run(brain, 1.0)
	eq(brain.anim_state, &"idle", "and no break starts right after it")


func test_dragging_holds_then_drops() -> void:
	var brain: CharacterBrain = _brain()
	brain.drag_to(50.0)
	eq(brain.mode, CharacterBrain.Mode.HELD, "dragging holds the character")
	eq(brain.x, 50.0, "it follows the pointer")
	eq(brain.anim_state, &"idle", "and shows the idle animation")
	_run(brain, 10.0)
	eq(brain.x, 50.0, "it stays where it was dropped")
	brain.drop()
	eq(brain.mode, CharacterBrain.Mode.IDLE, "dropping returns to idle")
