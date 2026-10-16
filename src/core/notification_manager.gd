class_name NotificationManager
extends Node
## The brain behind "all notifications get seen": a priority queue of notices, one speech bubble
## at a time, with short durations that shrink under backlog and batching that folds a flood of
## low-priority updates into one summary ("3 agents finished").
##
## It also tracks each source's working/done/needs_input/error status (the status tray) and keeps
## a history so nothing is lost when a bubble times out.
##
## No rendering here. Presentation listens to the signals; time only moves through `advance()`,
## which `_process` drives, so tests can run it deterministically.

signal notice_shown(notice: Notice)
signal notice_hidden(notice: Notice)
signal source_changed(source: SourceInfo)
signal ambient_changed(ambient: StringName)
signal history_changed
signal cleared(source_key: String)

const MAX_QUEUE: int = 24
const MAX_HISTORY: int = 100
const MAX_TEXT_LENGTH: int = 280
const BATCH_MIN: int = 3
const GAP_SECONDS: float = 0.4
const DEDUP_SECONDS: float = 4.0
const ASK_BUBBLE_SECONDS: float = 12.0
const DEFAULT_ASK_TIMEOUT: float = 45.0
## Done/error chips fade on their own; working/needs_input only go stale after a long silence.
const DONE_FADE_SECONDS: float = 90.0
const ERROR_FADE_SECONDS: float = 600.0
const WORKING_STALE_SECONDS: float = 1800.0
const NEEDS_INPUT_STALE_SECONDS: float = 3600.0
const DONE_AMBIENT_SECONDS: float = 20.0

var registry: SourceRegistry = SourceRegistry.new()
## Newest last. Includes notices that were folded into a summary.
var history: Array[Notice] = []
## The notice whose bubble is up right now, or null.
var current: Notice = null

var _queue: Array[Notice] = []
var _pending_asks: Dictionary = {}
var _recent: Dictionary = {}
var _clock: float = 0.0
var _current_left: float = 0.0
var _gap_left: float = 0.0
var _next_id: int = 1
var _ambient: StringName = &""


func _process(delta: float) -> void:
	advance(delta)


func now() -> float:
	return _clock


func ambient() -> StringName:
	return _ambient


func queue_size() -> int:
	return _queue.size()


func pending_asks() -> Array[Notice]:
	var result: Array[Notice] = []
	for ask_id: Variant in _pending_asks:
		result.append(_pending_asks[ask_id])
	return result


## Sources that are doing something, most urgent first (the tray's contents).
func active_sources() -> Array[SourceInfo]:
	var result: Array[SourceInfo] = []
	for source: SourceInfo in registry.all():
		if source.status != SourceInfo.Status.IDLE:
			result.append(source)
	result.sort_custom(func(a: SourceInfo, b: SourceInfo) -> bool:
		return _status_rank(a.status) > _status_rank(b.status))
	return result


# --- Tool-facing API ---------------------------------------------------------------------------

func notify(source_name: String, text: String, mood: StringName = &"neutral",
		priority: Notice.Priority = Notice.Priority.NORMAL) -> Dictionary:
	var source: SourceInfo = registry.resolve(source_name)
	return _post(source, text, mood, priority, Notice.Kind.NOTIFY)


func set_state(source_name: String, status: StringName, text: String = "") -> Dictionary:
	var source: SourceInfo = registry.resolve(source_name)
	var new_status: int = SourceInfo.status_from_name(status)
	if new_status < 0:
		return {"error": "unknown status '%s'" % status}
	var previous: StringName = source.status_name()
	text = _clip(text)
	source.last_seen = _clock
	if new_status == source.status and text == source.status_text:
		return {"source": source.display_name, "status": status, "previous": previous, "changed": false}
	var changed: bool = new_status != source.status
	_apply_status(source, new_status as SourceInfo.Status, text)
	if changed:
		match new_status:
			SourceInfo.Status.DONE:
				_post(source, text if not text.is_empty() else "All done!", &"happy", Notice.Priority.NORMAL, Notice.Kind.DONE)
			SourceInfo.Status.NEEDS_INPUT:
				_post(source, text if not text.is_empty() else "I need your input.", &"alert", Notice.Priority.HIGH, Notice.Kind.NEEDS_INPUT)
			SourceInfo.Status.ERROR:
				_post(source, text if not text.is_empty() else "Something went wrong.", &"error", Notice.Priority.HIGH, Notice.Kind.ERROR)
	return {"source": source.display_name, "status": status, "previous": previous, "changed": changed}


## Shows a question and waits (this is a coroutine) for the user to pick a choice, up to
## `timeout` seconds. `owner` ties the question to a client connection so it can be withdrawn
## if the client hangs up.
func ask(source_name: String, question: String, choices: PackedStringArray,
		timeout: float = DEFAULT_ASK_TIMEOUT, owner: int = 0) -> Dictionary:
	var source: SourceInfo = registry.resolve(source_name)
	var notice: Notice = _make_notice(source, question, &"alert", Notice.Priority.HIGH, Notice.Kind.ASK)
	notice.choices = choices
	notice.owner = owner
	notice.deadline = _clock + clampf(timeout, 1.0, 600.0)
	_pending_asks[notice.id] = notice
	_apply_status(source, SourceInfo.Status.NEEDS_INPUT, notice.text)
	_enqueue(notice)
	return await notice.resolved


## The user picked a choice on a question's bubble.
func answer_ask(ask_id: int, index: int) -> bool:
	var notice: Notice = _pending_asks.get(ask_id)
	if notice == null or index < 0 or index >= notice.choices.size():
		return false
	_resolve_ask(notice, {"answered": true, "choice": notice.choices[index], "index": index})
	return true


## Re-shows unanswered questions whose bubble already timed out.
func reopen_asks() -> void:
	for notice: Notice in pending_asks():
		if notice != current and not _queue.has(notice):
			_queue.push_front(notice)
	_gap_left = 0.0


func cancel_asks_owned_by(owner: int) -> void:
	for notice: Notice in pending_asks():
		if notice.owner == owner:
			_resolve_ask(notice, {"answered": false, "reason": "cancelled"})


## The user waved a bubble away. Questions stay answerable from the history panel.
func dismiss_current() -> void:
	if current != null:
		_hide_current()


## The user glanced at the character: finished/failed chips have done their job.
func acknowledge() -> void:
	for source: SourceInfo in registry.all():
		if source.status == SourceInfo.Status.DONE or source.status == SourceInfo.Status.ERROR:
			_apply_status(source, SourceInfo.Status.IDLE, "")


## Clears one source's queue/bubble/status, or everything when `source_name` is empty.
func clear(source_name: String = "") -> Dictionary:
	var key: String = ""
	if not source_name.strip_edges().is_empty():
		key = registry.resolve(source_name).key
	var removed: int = 0
	for notice: Notice in _queue.duplicate():
		if key.is_empty() or notice.source.key == key:
			_queue.erase(notice)
			removed += 1
	for notice: Notice in pending_asks():
		if key.is_empty() or notice.source.key == key:
			_resolve_ask(notice, {"answered": false, "reason": "cleared"})
	if current != null and (key.is_empty() or current.source.key == key):
		_hide_current()
	for source: SourceInfo in registry.all():
		if (key.is_empty() or source.key == key) and source.status != SourceInfo.Status.IDLE:
			_apply_status(source, SourceInfo.Status.IDLE, "")
	cleared.emit(key)
	return {"cleared": removed, "scope": key if not key.is_empty() else "all"}


# --- Time --------------------------------------------------------------------------------------

func advance(delta: float) -> void:
	_clock += delta
	_expire()
	for notice: Notice in pending_asks():
		if _clock >= notice.deadline:
			_resolve_ask(notice, {"answered": false, "reason": "timeout"})
	if current != null:
		_current_left -= delta
		if _current_left <= 0.0:
			_hide_current()
	elif not _queue.is_empty():
		_gap_left -= delta
		if _gap_left <= 0.0:
			_show(_pop_next())


# --- Internals ---------------------------------------------------------------------------------

func _post(source: SourceInfo, text: String, mood: StringName, priority: Notice.Priority,
		kind: Notice.Kind) -> Dictionary:
	text = _clip(text)
	source.last_seen = _clock
	var dedup_key: String = "%s|%d|%s" % [source.key, kind, text]
	if _recent.has(dedup_key) and _clock - float(_recent[dedup_key]) < DEDUP_SECONDS:
		return {"source": source.display_name, "queued": false, "deduplicated": true}
	_recent[dedup_key] = _clock
	if _recent.size() > 64:
		_prune_recent()
	var notice: Notice = _make_notice(source, text, mood, priority, kind)
	_enqueue(notice)
	return {
		"source": source.display_name,
		"queued": true,
		"id": notice.id,
		"queue_length": _queue.size(),
	}


func _make_notice(source: SourceInfo, text: String, mood: StringName,
		priority: Notice.Priority, kind: Notice.Kind) -> Notice:
	var notice: Notice = Notice.new()
	notice.id = _next_id
	_next_id += 1
	notice.source = source
	notice.text = _clip(text)
	notice.mood = mood if Notice.MOOD_STATES.has(mood) else &"neutral"
	notice.priority = priority
	notice.kind = kind
	notice.clock_time = _clock
	notice.wall_time = Time.get_unix_time_from_system()
	source.notice_count += 1
	return notice


func _enqueue(notice: Notice) -> void:
	history.append(notice)
	if history.size() > MAX_HISTORY:
		history.pop_front()
	history_changed.emit()
	# Stable priority order: higher first, older first within a priority.
	var index: int = _queue.size()
	while index > 0 and _queue[index - 1].priority < notice.priority:
		index -= 1
	_queue.insert(index, notice)
	_trim_queue()
	if current != null and notice.priority >= Notice.Priority.HIGH and notice.priority > current.priority:
		_preempt()


func _trim_queue() -> void:
	while _queue.size() > MAX_QUEUE:
		var victim_index: int = -1
		for index: int in range(_queue.size() - 1, -1, -1):
			if not _queue[index].is_ask():
				victim_index = index
				break
		if victim_index < 0:
			return
		_queue.remove_at(victim_index)


## Urgent news cuts in. The interrupted notice goes back in the queue if it had barely started.
func _preempt() -> void:
	var interrupted: Notice = current
	var barely_shown: bool = _clock - interrupted.shown_clock < 1.0
	_hide_current()
	if barely_shown and not interrupted.is_ask():
		_queue.push_front(interrupted)
	_gap_left = 0.0


func _pop_next() -> Notice:
	if _queue.is_empty():
		return null
	if _queue[0].is_batchable():
		var group: Array[Notice] = []
		for notice: Notice in _queue:
			if notice.is_batchable():
				group.append(notice)
		if group.size() >= BATCH_MIN:
			for notice: Notice in group:
				_queue.erase(notice)
			return _summarize(group)
	return _queue.pop_front()


func _summarize(group: Array[Notice]) -> Notice:
	var names: PackedStringArray = PackedStringArray()
	var all_done: bool = true
	var top_priority: Notice.Priority = Notice.Priority.LOW
	for notice: Notice in group:
		if not names.has(notice.source.display_name):
			names.append(notice.source.display_name)
		all_done = all_done and notice.kind == Notice.Kind.DONE
		top_priority = maxi(top_priority, notice.priority) as Notice.Priority
	var summary: Notice = Notice.new()
	summary.id = 0
	summary.source = registry.system() if names.size() > 1 else group[0].source
	summary.kind = Notice.Kind.SUMMARY
	summary.priority = top_priority
	summary.mood = &"happy" if all_done else &"neutral"
	summary.clock_time = _clock
	summary.wall_time = Time.get_unix_time_from_system()
	summary.batched = group
	var who: String = ", ".join(names) if names.size() <= 3 else "%d sources" % names.size()
	if all_done:
		summary.text = "%d agents finished: %s" % [group.size(), who] if names.size() > 1 \
			else "%d tasks finished" % group.size()
	else:
		summary.text = "%d updates: %s" % [group.size(), who]
	return summary


func _show(notice: Notice) -> void:
	if notice == null:
		return
	current = notice
	notice.shown_clock = _clock
	notice.seen = true
	for item: Notice in notice.batched:
		item.seen = true
	_current_left = ASK_BUBBLE_SECONDS if notice.is_ask() else duration_for(notice, _queue.size())
	history_changed.emit()
	notice_shown.emit(notice)


func _hide_current() -> void:
	var finished: Notice = current
	current = null
	_gap_left = GAP_SECONDS
	if finished != null:
		notice_hidden.emit(finished)


## Bubble time: reading speed, shortened when others are waiting, lengthened for urgent news.
static func duration_for(notice: Notice, backlog: int) -> float:
	var seconds: float = clampf(1.6 + 0.05 * notice.text.length(), 2.5, 7.0)
	if notice.priority >= Notice.Priority.URGENT:
		seconds *= 1.4
	if backlog >= 4:
		seconds *= 0.5
	elif backlog >= 2:
		seconds *= 0.7
	return maxf(seconds, 1.6)


func _resolve_ask(notice: Notice, result: Dictionary) -> void:
	if not _pending_asks.has(notice.id):
		return
	_pending_asks.erase(notice.id)
	notice.answered = bool(result.get("answered", false))
	_queue.erase(notice)
	var source: SourceInfo = notice.source
	var still_waiting: bool = false
	for other: Notice in pending_asks():
		still_waiting = still_waiting or other.source == source
	if source.status == SourceInfo.Status.NEEDS_INPUT and not still_waiting:
		var next_status: SourceInfo.Status = SourceInfo.Status.WORKING if notice.answered else SourceInfo.Status.IDLE
		_apply_status(source, next_status, "")
	if current == notice:
		_hide_current()
	history_changed.emit()
	notice.resolved.emit(result)


func _apply_status(source: SourceInfo, status: SourceInfo.Status, text: String) -> void:
	source.status = status
	source.status_text = text
	source.status_since = _clock
	source.last_seen = _clock
	source_changed.emit(source)
	_recompute_ambient()


func _expire() -> void:
	for source: SourceInfo in registry.all():
		var age: float = _clock - source.status_since
		var expired: bool = false
		match source.status:
			SourceInfo.Status.DONE:
				expired = age > DONE_FADE_SECONDS
			SourceInfo.Status.ERROR:
				expired = age > ERROR_FADE_SECONDS
			SourceInfo.Status.WORKING:
				expired = age > WORKING_STALE_SECONDS
			SourceInfo.Status.NEEDS_INPUT:
				expired = age > NEEDS_INPUT_STALE_SECONDS and not _has_pending_ask(source)
		if expired:
			_apply_status(source, SourceInfo.Status.IDLE, "")
	_recompute_ambient()


func _has_pending_ask(source: SourceInfo) -> bool:
	for notice: Notice in pending_asks():
		if notice.source == source:
			return true
	return false


func _recompute_ambient() -> void:
	var ambient_now: StringName = &""
	var best_rank: int = 0
	for source: SourceInfo in registry.all():
		var rank: int = _status_rank(source.status)
		if source.status == SourceInfo.Status.DONE and _clock - source.status_since > DONE_AMBIENT_SECONDS:
			rank = 0
		if rank > best_rank:
			best_rank = rank
			ambient_now = source.status_name()
	if ambient_now != _ambient:
		_ambient = ambient_now
		ambient_changed.emit(_ambient)


static func _status_rank(status: SourceInfo.Status) -> int:
	match status:
		SourceInfo.Status.NEEDS_INPUT:
			return 4
		SourceInfo.Status.ERROR:
			return 3
		SourceInfo.Status.WORKING:
			return 2
		SourceInfo.Status.DONE:
			return 1
	return 0


func _prune_recent() -> void:
	for key: Variant in _recent.keys():
		if _clock - float(_recent[key]) >= DEDUP_SECONDS:
			_recent.erase(key)


static func _clip(text: String) -> String:
	var out: String = ""
	for index: int in mini(text.length(), MAX_TEXT_LENGTH):
		var code: int = text.unicode_at(index)
		out += " " if (code < 32 and code != 10) or code == 127 else text[index]
	out = out.strip_edges()
	if text.length() > MAX_TEXT_LENGTH:
		out += "…"
	return out
