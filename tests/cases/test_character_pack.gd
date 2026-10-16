extends TestCase


func _sheet(width: int = 128, height: int = 320) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(width, height, false, Image.FORMAT_RGBA8))


func _manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://packs/pip/pack.json"))
	return parsed as Dictionary


func test_bundled_pack_loads() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("pip")
	check(pack != null, "bundled pack 'pip' should load")
	if pack == null:
		return
	check(pack.is_valid(), "pip should be valid: %s" % ", ".join(pack.errors))
	eq(pack.kind, CharacterPack.Kind.PET, "pip is a pet-kind pack")
	check(pack.wanders(), "a pet wanders")
	eq(pack.frames.get_frame_count(&"walk"), 4, "walk has 4 frames")
	eq(pack.resolve(&"happy"), &"happy", "mapped state resolves to its animation")


func test_every_bundled_pack_is_valid() -> void:
	var found: Dictionary = CharacterPack.discover()
	check(found.has("pip") and found.has("corgi"), "both bundled packs are discovered")
	for pack_id: String in found:
		var pack: CharacterPack = CharacterPack.load_dir(found[pack_id])
		check(pack.is_valid(), "%s should be valid: %s" % [pack_id, ", ".join(pack.errors)])
		eq(pack.id, pack_id, "%s: manifest id matches its folder" % pack_id)
		for state: StringName in CharacterPack.REQUIRED_STATES + [&"excited", &"error", &"sleepy", &"neutral"]:
			check(pack.resolve(state) != &"", "%s resolves '%s'" % [pack_id, state])


func test_corgi_is_a_wandering_pet_with_the_shared_animations() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("corgi")
	check(pack != null and pack.is_valid(), "corgi loads")
	if pack == null:
		return
	eq(pack.kind, CharacterPack.Kind.PET, "the corgi is a pet")
	check(pack.wanders(), "so it wanders")
	eq(pack.frame_size, Vector2i(89, 131), "frame size matches the sheet")
	for animation: StringName in [&"idle", &"walk", &"sleep", &"thinking", &"happy", &"alert", &"sad"]:
		eq(pack.frames.get_frame_count(animation), 4, "%s has 4 frames" % animation)


## A pack for a character that never walks (a person at a desk, a robot) needs no walk animation.
func test_a_pack_that_does_not_wander_needs_no_walk() -> void:
	var manifest: Dictionary = _manifest()
	manifest["kind"] = "avatar"
	manifest.erase("behavior")
	(manifest["animations"] as Dictionary).erase("walk")
	(manifest["states"] as Dictionary).erase("walk")
	var pack: CharacterPack = CharacterPack.new()
	pack.configure(manifest, _sheet())
	check(pack.is_valid(), "avatar without walk is valid: %s" % ", ".join(pack.errors))
	eq(pack.resolve(&"walk"), &"idle", "walk falls back to idle")

	manifest["kind"] = "pet"
	pack = CharacterPack.new()
	pack.configure(manifest, _sheet())
	check(not pack.is_valid(), "but a pet that wanders without a walk animation is rejected")
	check(", ".join(pack.errors).contains("walk"), "and the error says why")


func test_frames_report_their_visible_pixels() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("corgi")
	var idle: Rect2i = pack.used_rect(&"idle", 0)
	check(idle.size.x > 20 and idle.size.y > 20, "idle has a body (%s)" % idle)
	check(idle.size.y < pack.frame_size.y, "and is smaller than the full frame, so the hit area can be tight")
	check(idle.end.y <= pack.frame_size.y and idle.end.x <= pack.frame_size.x, "inside the frame")
	var sleep: Rect2i = pack.used_rect(&"sleep", 0)
	check(sleep.size.y < idle.size.y, "a sleeping corgi is lower than a standing one")
	eq(pack.used_rect(&"idle", 99), Rect2i(Vector2i.ZERO, pack.frame_size), "unknown frames fall back to the whole frame")


func test_missing_states_fall_back() -> void:
	var pack: CharacterPack = CharacterPack.load_by_id("pip")
	eq(pack.resolve(&"excited"), &"happy", "excited falls back to happy")
	eq(pack.resolve(&"error"), &"sad", "error falls back to sad")
	eq(pack.resolve(&"sleepy"), &"sleep", "sleepy falls back to sleep")
	eq(pack.resolve(&"no-such-state"), &"idle", "unknown states land on idle")


func test_avatar_stays_put() -> void:
	var manifest: Dictionary = _manifest()
	manifest["kind"] = "avatar"
	manifest.erase("behavior")
	var pack: CharacterPack = CharacterPack.new()
	pack.configure(manifest, _sheet())
	check(pack.is_valid(), "avatar manifest should be valid: %s" % ", ".join(pack.errors))
	check(not pack.wanders(), "avatars do not wander by default")
	eq(float(pack.behavior["weights"]["wander"]), 0.0, "avatar wander weight is zero")


func test_manifest_can_override_behavior() -> void:
	var manifest: Dictionary = _manifest()
	manifest["kind"] = "avatar"
	manifest["behavior"] = {"wander": true, "speed": 40}
	var pack: CharacterPack = CharacterPack.new()
	pack.configure(manifest, _sheet())
	check(pack.wanders(), "explicit wander=true overrides the avatar default")


func test_invalid_manifests_report_errors() -> void:
	var manifest: Dictionary = _manifest()
	manifest["schema"] = 99
	var pack: CharacterPack = CharacterPack.new()
	pack.configure(manifest, _sheet())
	check(not pack.is_valid(), "wrong schema is rejected")

	manifest = _manifest()
	(manifest["states"] as Dictionary).erase("sleep")
	(manifest["animations"] as Dictionary).erase("sleep")
	pack = CharacterPack.new()
	pack.configure(manifest, _sheet())
	check(not pack.is_valid(), "a pack missing a required state is rejected")

	manifest = _manifest()
	pack = CharacterPack.new()
	pack.configure(manifest, _sheet(32, 32))
	check(not pack.is_valid(), "animations outside the sheet are rejected")
