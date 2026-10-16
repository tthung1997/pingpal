class_name SourceRegistry
extends RefCounted
## Turns whatever name an AI client gives ("claude-code", "Visual Studio Code", "my-script")
## into a stable SourceInfo with a recognisable look.

const MAX_NAME_LENGTH: int = 40
const MAX_SOURCES: int = 32
const SYSTEM_KEY: String = "pingpal"

const ACCESSORIES: Array[StringName] = [&"cap", &"bow", &"antenna", &"halo", &"crown", &"leaf"]

## Known clients get fixed looks. Order matters: the first family whose pattern appears in the
## lower-cased name wins ("claude code" must match claude before the generic "code").
const FAMILIES: Array[Dictionary] = [
	{"family": "claude", "patterns": ["claude"], "color": "d97757", "accessory": &"antenna"},
	{"family": "copilot", "patterns": ["copilot"], "color": "8957e5", "accessory": &"halo"},
	{"family": "codex", "patterns": ["codex", "openai", "chatgpt"], "color": "10a37f", "accessory": &"cap"},
	{"family": "gemini", "patterns": ["gemini"], "color": "4285f4", "accessory": &"crown"},
	{"family": "cursor", "patterns": ["cursor"], "color": "e0e0e0", "accessory": &"leaf"},
	{"family": "vscode", "patterns": ["vscode", "visual studio code", "vs code", "vs-code"], "color": "3794ff", "accessory": &"bow"},
	{"family": "terminal", "patterns": ["terminal", "shell", "curl", "powershell", "bash"], "color": "9aa5b1", "accessory": &"cap"},
]

var _sources: Dictionary = {}


## Returns the source for `raw_name`, creating it on first sight.
func resolve(raw_name: String) -> SourceInfo:
	var display: String = clean_name(raw_name)
	if display.is_empty():
		display = "Unknown"
	var key: String = display.to_lower()
	if _sources.has(key):
		return _sources[key]
	if _sources.size() >= MAX_SOURCES:
		_evict_one()
	var source: SourceInfo = _build(key, display)
	_sources[key] = source
	return source


## The synthetic source used for batched summaries and app messages.
func system() -> SourceInfo:
	if not _sources.has(SYSTEM_KEY):
		var source: SourceInfo = SourceInfo.new()
		source.key = SYSTEM_KEY
		source.display_name = "PingPal"
		source.family = SYSTEM_KEY
		source.color = Color("6fc7f2")
		source.glyph = "P"
		source.accessory = &"cap"
		_sources[SYSTEM_KEY] = source
	return _sources[SYSTEM_KEY]


func all() -> Array[SourceInfo]:
	var result: Array[SourceInfo] = []
	for key: Variant in _sources:
		if key != SYSTEM_KEY:
			result.append(_sources[key])
	return result


func find(key: String) -> SourceInfo:
	return _sources.get(key.to_lower())


func _build(key: String, display: String) -> SourceInfo:
	var source: SourceInfo = SourceInfo.new()
	source.key = key
	source.display_name = display
	var known: Dictionary = _match_family(key)
	if not known.is_empty():
		source.family = known["family"]
		source.color = Color(known["color"])
		source.accessory = known["accessory"]
	else:
		var hash_value: int = absi(key.hash())
		source.family = key
		source.color = Color.from_hsv(float(hash_value % 360) / 360.0, 0.55, 0.95)
		source.accessory = ACCESSORIES[floori(hash_value / 360.0) % ACCESSORIES.size()]
	source.glyph = _glyph(display)
	return source


func _match_family(key: String) -> Dictionary:
	for family: Dictionary in FAMILIES:
		for pattern: String in family["patterns"]:
			if key.contains(pattern):
				return family
	return {}


## Strips control characters (these end up on screen) and caps the length.
static func clean_name(raw_name: String) -> String:
	var out: String = ""
	for index: int in raw_name.length():
		var code: int = raw_name.unicode_at(index)
		out += " " if code < 32 or code == 127 else raw_name[index]
	out = " ".join(out.strip_edges().split(" ", false))
	if out.length() > MAX_NAME_LENGTH:
		out = out.substr(0, MAX_NAME_LENGTH - 1) + "…"
	return out


static func _glyph(display: String) -> String:
	for index: int in display.length():
		var character: String = display[index]
		if character.to_upper() != character.to_lower() or character.is_valid_int():
			return character.to_upper()
	return "?"


func _evict_one() -> void:
	var oldest: SourceInfo = null
	for key: Variant in _sources:
		var candidate: SourceInfo = _sources[key]
		if key == SYSTEM_KEY or candidate.status != SourceInfo.Status.IDLE:
			continue
		if oldest == null or candidate.last_seen < oldest.last_seen:
			oldest = candidate
	if oldest != null:
		_sources.erase(oldest.key)
