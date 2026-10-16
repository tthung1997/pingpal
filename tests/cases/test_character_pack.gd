extends TestCase


func _sheet(width: int = 128, height: int = 320) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(width, height, false, Image.FORMAT_RGBA8))


func _manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://packs/pip/pack.json"))
	return parsed as Dictionary


func _configure(manifest: Dictionary) -> CharacterPack:
	var pack: CharacterPack = CharacterPack.new()
	pack.configure(manifest, _sheet())
	return pack


func test_bundled_pack_loads() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("pip")
	check(pack != null, "bundled pack 'pip' should load")
	if pack == null:
		return
	check(pack.is_valid(), "pip should be valid: %s" % ", ".join(pack.errors))
	eq(pack.frames.get_frame_count(&"idle"), 4, "idle has 4 frames")
	eq(pack.resolve(&"attention"), &"alert", "mapped state resolves to its animation")
	eq(pack.breaks(), [&"sleep", &"play", &"dance"] as Array[StringName], "breaks come from the manifest")


func test_every_bundled_pack_is_valid() -> void:
	var found: Dictionary = CharacterPack.discover()
	check(found.has("pip") and found.has("corgi") and found.has("corgi_desk"), "all bundled packs are discovered")
	for pack_id: String in found:
		var pack: CharacterPack = CharacterPack.load_dir(found[pack_id])
		check(pack.is_valid(), "%s should be valid: %s" % [pack_id, ", ".join(pack.errors)])
		eq(pack.id, pack_id, "%s: manifest id matches its folder" % pack_id)
		for state: StringName in CharacterPack.REQUIRED_STATES:
			check(pack.resolve(state) != &"", "%s resolves '%s'" % [pack_id, state])
		check(not pack.breaks().is_empty(), "%s has at least one break animation" % pack_id)


func test_corgi_desk_animations() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("corgi_desk")
	check(pack != null and pack.is_valid(), "corgi_desk loads")
	if pack == null:
		return
	eq(pack.frame_size, Vector2i(89, 131), "frame size matches the sheet")
	eq(pack.resolve(&"attention"), &"attention", "corgi_desk gets attention by raising its paw")
	eq(pack.breaks(), [&"bone", &"sleep"] as Array[StringName], "its breaks are bone and sleep")
	for animation: StringName in [&"idle", &"bone", &"sleep", &"attention"]:
		eq(pack.frames.get_frame_count(animation), 4, "%s has 4 frames" % animation)


func test_corgi_animations() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("corgi")
	check(pack != null and pack.is_valid(), "corgi loads")
	if pack == null:
		return
	eq(pack.frame_size, Vector2i(89, 131), "frame size matches the sheet")
	eq(pack.resolve(&"attention"), &"thinking", "the corgi gets attention with its thinking pose")
	eq(pack.breaks(), [&"sleep", &"happy", &"sad"] as Array[StringName], "its breaks are nap, happy and sad")
	for animation: StringName in [&"idle", &"sleep", &"thinking", &"happy", &"sad"]:
		eq(pack.frames.get_frame_count(animation), 4, "%s has 4 frames" % animation)


func test_frames_report_their_visible_pixels() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("corgi")
	var idle: Rect2i = pack.used_rect(&"idle", 0)
	check(idle.size.x > 20 and idle.size.y > 20, "idle has a body (%s)" % idle)
	check(idle.size.y < pack.frame_size.y, "and is smaller than the full frame, so the hit area can be tight")
	check(idle.end.y <= pack.frame_size.y and idle.end.x <= pack.frame_size.x, "inside the frame")
	var sleep: Rect2i = pack.used_rect(&"sleep", 0)
	check(sleep.size.y < idle.size.y, "a sleeping corgi is lower than a standing one")
	eq(pack.used_rect(&"idle", 99), Rect2i(Vector2i.ZERO, pack.frame_size), "unknown frames fall back to the whole frame")


func test_unknown_states_fall_back_to_idle() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("pip")
	eq(pack.resolve(&"no-such-state"), &"idle", "unknown states land on idle")


func test_a_pack_without_breaks_is_valid() -> void:
	var manifest: Dictionary = _manifest()
	(manifest["behavior"] as Dictionary).erase("breaks")
	var pack: CharacterPack = _configure(manifest)
	check(pack.is_valid(), "breaks are optional: %s" % ", ".join(pack.errors))
	check(pack.breaks().is_empty(), "so there are none")


func test_manifest_can_override_timing() -> void:
	var manifest: Dictionary = _manifest()
	manifest["behavior"] = {"idle_seconds": [1.0, 2.0]}
	var pack: CharacterPack = _configure(manifest)
	eq(pack.behavior["idle_seconds"], [1.0, 2.0], "idle_seconds is overridden")
	eq(pack.behavior["break_seconds"], [3.0, 6.0], "the rest keeps its default")


func test_invalid_manifests_report_errors() -> void:
	var manifest: Dictionary = _manifest()
	manifest["schema"] = 1
	check(not _configure(manifest).is_valid(), "the old schema is rejected")

	manifest = _manifest()
	(manifest["states"] as Dictionary).erase("attention")
	check(not _configure(manifest).is_valid(), "a pack without an attention animation is rejected")

	manifest = _manifest()
	(manifest["behavior"] as Dictionary)["breaks"] = ["no-such-break"]
	var pack: CharacterPack = _configure(manifest)
	check(not pack.is_valid(), "a break that maps to nothing is rejected")
	check(", ".join(pack.errors).contains("no-such-break"), "and the error names it")

	manifest = _manifest()
	pack = CharacterPack.new()
	pack.configure(manifest, _sheet(32, 32))
	check(not pack.is_valid(), "animations outside the sheet are rejected")
