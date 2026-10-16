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
