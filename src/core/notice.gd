class_name Notice
extends RefCounted
## One thing the character may say: a message, a state-change announcement, a question or a
## batched summary. Also the unit the history panel lists.

## Emitted once, with {answered, choice?, index?, reason?}, when a question is settled.
signal resolved(result: Dictionary)

enum Priority { LOW, NORMAL, HIGH, URGENT }

enum Kind { NOTIFY, DONE, NEEDS_INPUT, ERROR, ASK, SUMMARY }

var id: int = 0
var source: SourceInfo = null
var text: String = ""
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


func to_dict() -> Dictionary:
	return {
		"id": id,
		"source": source.display_name if source != null else "",
		"text": text,
		"priority": Priority.keys()[priority].to_lower(),
		"kind": Kind.keys()[kind].to_lower(),
		"seen": seen,
	}
