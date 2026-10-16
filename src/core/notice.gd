class_name Notice
extends RefCounted
## One thing the character may say: a message, a state-change announcement, a question or a
## batched summary. Also the unit the history panel lists.

## Emitted once, with {answered, choice?, index?, reason?}, when a question is settled.
signal resolved(result: Dictionary)

enum Priority { LOW, NORMAL, HIGH, URGENT }

enum Kind { NOTIFY, DONE, NEEDS_INPUT, ERROR, ASK, SUMMARY }

## How each mood is acted out; the pack resolves these states to real animations.
const MOOD_STATES: Dictionary = {
	&"neutral": &"wave",
	&"happy": &"happy",
	&"excited": &"excited",
	&"alert": &"alert",
	&"thinking": &"thinking",
	&"sad": &"sad",
	&"sleepy": &"sleepy",
	&"error": &"error",
}

var id: int = 0
var source: SourceInfo = null
var text: String = ""
var mood: StringName = &"neutral"
var priority: Priority = Priority.NORMAL
var kind: Kind = Kind.NOTIFY

## Wall-clock seconds, for the history panel.
var wall_time: float = 0.0
var clock_time: float = 0.0
var shown_clock: float = -1.0
var seen: bool = false

## Question fields.
var choices: PackedStringArray = PackedStringArray()
var deadline: float = 0.0
var owner: int = 0
var answered: bool = false

## For summaries: the individual notices that were folded into this one.
var batched: Array[Notice] = []


func is_ask() -> bool:
	return kind == Kind.ASK


func is_batchable() -> bool:
	return priority <= Priority.NORMAL and (kind == Kind.NOTIFY or kind == Kind.DONE)


func mood_state() -> StringName:
	return MOOD_STATES.get(mood, &"idle")


func to_dict() -> Dictionary:
	return {
		"id": id,
		"source": source.display_name if source != null else "",
		"text": text,
		"mood": mood,
		"priority": Priority.keys()[priority].to_lower(),
		"kind": Kind.keys()[kind].to_lower(),
		"seen": seen,
	}
