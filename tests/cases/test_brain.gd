extends TestCase


func _brain(seed_value: int = 1) -> CharacterBrain:
	var brain: CharacterBrain = CharacterBrain.new(CharacterPack.load_by_id("pip"))
	brain.rng.seed = seed_value
	brain.set_bounds(0.0, 600.0)
	brain.x = 300.0
	return brain


func _run(brain: CharacterBrain, seconds: float, step: float = 0.1) -> Dictionary:
	var seen: Dictionary = {}
	var elapsed: float = 0.0
	while elapsed < seconds:
		brain.update(step)
		seen[CharacterBrain.Mode.keys()[brain.mode]] = true
		elapsed += step
	return seen


func test_idles_and_wanders_on_its_own() -> void:
	var seen: Dictionary = _run(_brain(), 300.0)
	check(seen.has("WANDER"), "pet wanders when left alone")
	check(seen.has("IDLE"), "pet idles")
	check(seen.has("SLEEP"), "pet eventually naps (after sleep_after_seconds)")


func test_wandering_stays_in_bounds_and_faces_travel() -> void:
	var brain: CharacterBrain = _brain()
	brain.set_bounds(100.0, 200.0)
	brain.x = 150.0
	var elapsed: float = 0.0
	while elapsed < 120.0:
		brain.update(0.05)
		elapsed += 0.05
		check(brain.x >= 100.0 and brain.x <= 200.0, "x stays in bounds (x=%f)" % brain.x)
		if brain.mode == CharacterBrain.Mode.WANDER:
			eq(brain.anim_state, &"walk", "wandering shows the walk state")


func test_avatar_never_walks() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/pip/pack.json"))
	manifest["kind"] = "avatar"
	manifest.erase("behavior")
	var pack: CharacterPack = CharacterPack.new()
	pack.configure(manifest, ImageTexture.create_from_image(Image.create(128, 320, false, Image.FORMAT_RGBA8)))
	var brain: CharacterBrain = CharacterBrain.new(pack)
	brain.set_bounds(0.0, 600.0)
	brain.x = 300.0
	var seen: Dictionary = _run(brain, 600.0)
	check(not seen.has("WANDER"), "avatar never enters WANDER")
	eq(brain.x, 300.0, "avatar does not move")


func test_message_interrupts_and_releases() -> void:
	var brain: CharacterBrain = _brain()
	brain.react(&"happy", 0.0, &"hop")
	eq(brain.mode, CharacterBrain.Mode.REACT, "a notice puts the character in REACT")
	eq(brain.anim_state, &"happy", "it acts out the requested state")
	_run(brain, 30.0)
	eq(brain.mode, CharacterBrain.Mode.REACT, "an unbounded reaction is held until released")
	brain.release()
	eq(brain.mode, CharacterBrain.Mode.IDLE, "release returns to idle")


func test_sleeping_character_startles_awake_then_reacts() -> void:
	var brain: CharacterBrain = _brain()
	var elapsed: float = 0.0
	while brain.mode != CharacterBrain.Mode.SLEEP and elapsed < 600.0:
		brain.update(0.1)
		elapsed += 0.1
	eq(brain.mode, CharacterBrain.Mode.SLEEP, "left alone long enough, it falls asleep")
	brain.react(&"happy", 0.0)
	eq(brain.anim_state, &"alert", "a sleeper is startled first")
	_run(brain, 1.0)
	eq(brain.anim_state, &"happy", "then shows the actual reaction")


func test_ambient_state_changes_behaviour() -> void:
	var brain: CharacterBrain = _brain()
	brain.set_ambient(&"working")
	eq(brain.anim_state, &"thinking", "idle while AIs are working looks like thinking")
	var seen: Dictionary = _run(brain, 400.0)
	check(not seen.has("SLEEP"), "it does not fall asleep while work is in progress")
	brain.set_ambient(&"needs_input")
	var reacted: bool = false
	for _i: int in 1200:
		brain.update(0.1)
		reacted = reacted or (brain.mode == CharacterBrain.Mode.REACT and brain.anim_state == &"alert")
	check(reacted, "it periodically calls for attention when input is needed")


func test_dragging_holds_then_drops() -> void:
	var brain: CharacterBrain = _brain()
	brain.drag_to(50.0)
	eq(brain.mode, CharacterBrain.Mode.HELD, "dragging holds the character")
	eq(brain.x, 50.0, "it follows the pointer")
	_run(brain, 10.0)
	eq(brain.x, 50.0, "it does not wander while held")
	brain.drop()
	eq(brain.mode, CharacterBrain.Mode.IDLE, "dropping returns to idle")
