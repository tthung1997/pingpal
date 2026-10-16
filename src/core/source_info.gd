class_name SourceInfo
extends RefCounted
## One AI client/agent that talks to PingPal, with its look (color, glyph) and its current status.
## The look is derived from the source's name, so the same name always looks the same and a
## session picks its own look by choosing its name.

enum Status { IDLE, WORKING, DONE, NEEDS_INPUT, ERROR }

const STATUS_NAMES: Dictionary = {
	Status.IDLE: &"idle",
	Status.WORKING: &"working",
	Status.DONE: &"done",
	Status.NEEDS_INPUT: &"needs_input",
	Status.ERROR: &"error",
}

var key: String = ""
var display_name: String = ""
var color: Color = Color.WHITE
var glyph: String = "?"

var status: Status = Status.IDLE
var status_text: String = ""
## Manager clock time (seconds) of the last call of any kind from this source.
var last_seen: float = 0.0
var notice_count: int = 0


func status_name() -> StringName:
	return STATUS_NAMES[status]


static func status_from_name(value: StringName) -> int:
	for status_id: int in STATUS_NAMES:
		if STATUS_NAMES[status_id] == value:
			return status_id
	return -1
