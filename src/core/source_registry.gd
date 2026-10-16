class_name SourceRegistry
extends RefCounted
## Turns whatever name an AI client gives ("Claude Code · api", "my-script") into a stable
## SourceInfo with a recognisable look: a color derived from the name and its first letter.
## Every distinct name is its own source, so there is no grouping by app or vendor.

const MAX_NAME_LENGTH: int = 80
const MAX_SOURCES: int = 32
const SYSTEM_KEY: String = "pingpal"

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
		source.color = Color("6fc7f2")
		source.glyph = "P"
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
	source.color = Color.from_hsv(float(absi(key.hash()) % 360) / 360.0, 0.55, 0.95)
	source.glyph = _glyph(display)
	return source


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
