class_name CharacterPack
extends RefCounted
## A swappable character: a sprite sheet plus a JSON manifest that maps semantic states to
## animations on the sheet.
##
## A character only ever plays three kinds of animation:
##   idle       the main loop; shown whenever nothing else is going on
##   breaks     short, optional variations (a nap, a stretch, ...) the brain drops in at random
##              while idle; listed in `behavior.breaks`
##   attention  one neutral "look at me" animation for every new message, good news or bad
##
## The rest of the app only ever asks for a semantic state (`resolve(&"attention")`); a pack
## without a mapping for a state degrades to `idle` instead of breaking.

const SCHEMA_VERSION: int = 2
const MANIFEST_NAME: String = "pack.json"
const PACK_ROOTS: Array[String] = ["res://packs", "user://packs"]

## Every pack must animate these.
const REQUIRED_STATES: Array[StringName] = [&"idle", &"attention"]

const DEFAULT_BEHAVIOR: Dictionary = {
	"idle_seconds": [6.0, 14.0],
	"break_seconds": [3.0, 6.0],
	"breaks": [],
}

var id: String = ""
var display_name: String = ""
var root_dir: String = ""
var frame_size: Vector2i = Vector2i(32, 32)
## Where the character's feet touch the ground, in frame pixels.
var anchor: Vector2 = Vector2(16, 30)
var behavior: Dictionary = {}
var frames: SpriteFrames = null
var errors: PackedStringArray = PackedStringArray()

## Semantic state -> candidate animation names (first one that exists wins).
var _states: Dictionary = {}
## Animation name -> per-frame tight bounds of the visible pixels, in frame pixels.
var _used: Dictionary = {}
var _sheet_image: Image = null


func is_valid() -> bool:
	return errors.is_empty() and frames != null


## Where the visible pixels of one frame are, in frame pixels. Falls back to the whole frame.
func used_rect(animation: StringName, index: int) -> Rect2i:
	var list: Array = _used.get(animation, [])
	if index >= 0 and index < list.size():
		return list[index]
	return Rect2i(Vector2i.ZERO, frame_size)


## The break animations (semantic states) the brain may play while idle.
func breaks() -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Variant in behavior.get("breaks", []):
		result.append(StringName(str(item)))
	return result


func has_animation(animation: StringName) -> bool:
	return frames != null and frames.has_animation(animation)


## Maps a semantic state to a concrete animation name: the pack's own mapping first, then an
## animation of that very name, then `idle`. Returns an empty name only when the pack has no
## usable animation at all.
func resolve(state: StringName) -> StringName:
	for candidate: StringName in _states.get(state, []):
		if has_animation(candidate):
			return candidate
	if has_animation(state):
		return state
	for candidate: StringName in _states.get(&"idle", [&"idle"]):
		if has_animation(candidate):
			return candidate
	return &"idle" if has_animation(&"idle") else &""


## Lists packs found in the bundled and user pack folders (id -> directory). User packs
## override bundled ones with the same id.
static func discover() -> Dictionary:
	var found: Dictionary = {}
	for root: String in PACK_ROOTS:
		var dir: DirAccess = DirAccess.open(root)
		if dir == null:
			continue
		for entry: String in dir.get_directories():
			var path: String = "%s/%s" % [root, entry]
			if FileAccess.file_exists("%s/%s" % [path, MANIFEST_NAME]):
				found[entry] = path
	return found


## Loads a pack by id from the pack folders, or null if it is missing or invalid.
static func load_by_id(pack_id: String) -> CharacterPack:
	var found: Dictionary = discover()
	if not found.has(pack_id):
		return null
	var pack: CharacterPack = load_dir(found[pack_id])
	if not pack.is_valid():
		push_warning("PingPal: pack '%s' is invalid: %s" % [pack_id, "; ".join(pack.errors)])
		return null
	return pack


## Loads `dir/pack.json`. Always returns a pack; check `is_valid()` and `errors`.
static func load_dir(dir: String) -> CharacterPack:
	var pack: CharacterPack = CharacterPack.new()
	pack.root_dir = dir
	var manifest_path: String = "%s/%s" % [dir, MANIFEST_NAME]
	var text: String = FileAccess.get_file_as_string(manifest_path)
	if text.is_empty():
		pack.errors.append("cannot read %s" % manifest_path)
		return pack
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		pack.errors.append("%s is not a JSON object" % manifest_path)
		return pack
	var manifest: Dictionary = parsed
	var sheet_name: String = str(manifest.get("sheet", "sheet.png"))
	var sheet: Texture2D = _load_texture("%s/%s" % [dir, sheet_name])
	if sheet == null:
		pack.errors.append("cannot load sprite sheet %s" % sheet_name)
		return pack
	pack.configure(manifest, sheet)
	return pack


## Builds the pack from an already-parsed manifest and sheet. Used by the loader and by tests.
func configure(manifest: Dictionary, sheet: Texture2D) -> void:
	errors = PackedStringArray()
	if int(manifest.get("schema", 0)) != SCHEMA_VERSION:
		errors.append("unsupported schema %s (expected %d)" % [manifest.get("schema"), SCHEMA_VERSION])
		return
	id = str(manifest.get("id", "")).strip_edges()
	if id.is_empty() or not id.is_valid_filename():
		errors.append("manifest needs a simple string `id`")
		return
	display_name = str(manifest.get("name", id))
	frame_size = _vec2i(manifest.get("frame_size", [32, 32]), Vector2i(32, 32))
	anchor = Vector2(_vec2i(manifest.get("anchor", [frame_size.x / 2, frame_size.y - 2]), Vector2i(16, 30)))
	behavior = _merge_behavior(manifest.get("behavior", {}))
	frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_sheet_image = sheet.get_image()
	var animations: Variant = manifest.get("animations", {})
	if not animations is Dictionary or animations.is_empty():
		errors.append("manifest has no `animations`")
		return
	for key: Variant in animations:
		_add_animation(StringName(key), animations[key], sheet)
	var states: Variant = manifest.get("states", {})
	if states is Dictionary:
		for state: Variant in states:
			var target: Variant = states[state]
			var names: Array[StringName] = []
			for item: Variant in (target if target is Array else [target]):
				names.append(StringName(str(item)))
			_states[StringName(state)] = names
	for state: StringName in REQUIRED_STATES:
		if not _states.has(state) and not has_animation(state):
			errors.append("required state `%s` is not mapped to an animation" % state)
	if errors.is_empty():
		for state: StringName in breaks():
			if state == &"idle" or state == &"attention" or resolve(state) == resolve(&"idle"):
				errors.append("break `%s` is not mapped to a distinct animation" % state)
	for state: StringName in _states:
		for candidate: StringName in _states[state]:
			if not has_animation(candidate):
				errors.append("state `%s` points at missing animation `%s`" % [state, candidate])


func _add_animation(anim_name: StringName, spec: Variant, sheet: Texture2D) -> void:
	if not spec is Dictionary:
		errors.append("animation `%s` must be an object" % anim_name)
		return
	var row: int = int(spec.get("row", 0))
	var start: int = int(spec.get("start", 0))
	var count: int = maxi(int(spec.get("frames", 1)), 1)
	var needed: Vector2i = Vector2i((start + count) * frame_size.x, (row + 1) * frame_size.y)
	if row < 0 or start < 0 or needed.x > sheet.get_width() or needed.y > sheet.get_height():
		errors.append("animation `%s` is outside the %dx%d sheet" % [anim_name, sheet.get_width(), sheet.get_height()])
		return
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, maxf(float(spec.get("fps", 6.0)), 0.1))
	frames.set_animation_loop(anim_name, bool(spec.get("loop", true)))
	var bounds: Array[Rect2i] = []
	for index: int in count:
		var region: Rect2i = Rect2i((start + index) * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(region)
		frames.add_frame(anim_name, atlas)
		var used: Rect2i = Rect2i(Vector2i.ZERO, frame_size)
		if _sheet_image != null:
			used = _sheet_image.get_region(region).get_used_rect()
			if used.size == Vector2i.ZERO:
				used = Rect2i(Vector2i(anchor), Vector2i.ONE)
		bounds.append(used)
	_used[anim_name] = bounds


func _merge_behavior(overrides: Variant) -> Dictionary:
	var merged: Dictionary = DEFAULT_BEHAVIOR.duplicate(true)
	if overrides is Dictionary:
		for key: Variant in overrides:
			merged[key] = overrides[key]
	return merged


static func _vec2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func _load_texture(path: String) -> Texture2D:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D
		if imported != null:
			return imported
	# Not imported yet (fresh clone, headless run) or a user pack: read the PNG directly.
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null else null
