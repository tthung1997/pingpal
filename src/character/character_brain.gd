class_name CharacterBrain
extends RefCounted
## The character's idle state machine. It decides what the character does when nobody is
## talking to it (wander, nap, play, fidget) and yields to messages.
##
## It is deliberately free of nodes and rendering: it owns position, facing and a *semantic*
## animation state, and the actor turns that into pixels. That keeps it unit-testable.
##
##   IDLE <-> WANDER / PLAY / SLEEP          chosen by weighted dice, tuned by the pack's `behavior`
##   any  -> REACT                           a notice or an AI-requested action took over
##   REACT -> IDLE                           when the reaction ends and nothing is queued
##   any  -> HELD -> IDLE                    the user is dragging the character

enum Mode { IDLE, WANDER, SLEEP, PLAY, REACT, HELD }

## AI-requestable actions: state to animate, seconds, and a procedural effect for the actor.
const ACTIONS: Dictionary = {
	&"wave": {"state": &"wave", "seconds": 2.5, "effect": &""},
	&"jump": {"state": &"happy", "seconds": 1.2, "effect": &"jump"},
	&"cheer": {"state": &"happy", "seconds": 2.5, "effect": &"jump"},
	&"spin": {"state": &"happy", "seconds": 1.2, "effect": &"spin"},
	&"dance": {"state": &"dance", "seconds": 4.0, "effect": &""},
	&"play": {"state": &"play", "seconds": 4.0, "effect": &""},
	&"think": {"state": &"thinking", "seconds": 3.0, "effect": &""},
	&"alert": {"state": &"alert", "seconds": 2.0, "effect": &"hop"},
	&"sad": {"state": &"sad", "seconds": 3.0, "effect": &""},
}
## Actions that change the idle state machine itself rather than play a one-off animation.
const MODE_ACTIONS: Array[StringName] = [&"idle", &"wander", &"sleep", &"wake"]

const MAX_QUEUED_ACTIONS: int = 4
const STARTLE_SECONDS: float = 0.6
const MIN_WANDER_DISTANCE: float = 48.0

var pack: CharacterPack
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var mode: Mode = Mode.IDLE
var x: float = 0.0
var facing: int = 1
var min_x: float = 0.0
var max_x: float = 400.0
## Walking speed multiplier (the actor passes its pixel scale so the sprite does not moonwalk).
var speed_scale: float = 1.0
## Semantic state the actor should show; resolved through the pack.
var anim_state: StringName = &"idle"
var effect: StringName = &""
## Bumps whenever a reaction starts, so the actor can restart one-shot effects.
var effect_serial: int = 0
## What the AIs are collectively up to: &"", &"working", &"needs_input", &"error" or &"done".
var ambient: StringName = &""

var _time_left: float = 1.0
var _target_x: float = 0.0
var _since_event: float = 0.0
var _holding: bool = false
var _queue: Array[Dictionary] = []


func _init(p_pack: CharacterPack = null) -> void:
	pack = p_pack
	rng.randomize()


func set_bounds(low: float, high: float) -> void:
	min_x = low
	max_x = maxf(high, low)
	x = clampf(x, min_x, max_x)


func is_reacting() -> bool:
	return mode == Mode.REACT


func set_ambient(value: StringName) -> void:
	if value == ambient:
		return
	ambient = value
	if mode == Mode.IDLE:
		anim_state = _idle_state()
		# Needing attention should not wait for a long idle timer to run out.
		if ambient == &"needs_input" or ambient == &"error":
			_time_left = minf(_time_left, 1.0)


func update(delta: float) -> void:
	_since_event += delta
	match mode:
		Mode.HELD:
			pass
		Mode.REACT:
			if not _holding:
				_time_left -= delta
				if _time_left <= 0.0:
					_end_reaction()
		Mode.WANDER:
			_walk(delta)
		_:
			_time_left -= delta
			if _time_left <= 0.0:
				_pick_next()


## A notice took over the character. `seconds <= 0` holds the pose until `release()`.
## Interrupts whatever is playing; a sleeping character startles awake first.
func react(state: StringName, seconds: float, p_effect: StringName = &"") -> void:
	var item: Dictionary = {"state": state, "seconds": seconds, "effect": p_effect}
	var was_asleep: bool = mode == Mode.SLEEP
	_since_event = 0.0
	if was_asleep and state != &"alert":
		_queue.push_front(item)
		_start_reaction({"state": &"alert", "seconds": STARTLE_SECONDS, "effect": &"hop"})
	else:
		_start_reaction(item)


## Ends a held reaction (the bubble went away).
func release() -> void:
	if mode == Mode.REACT and _holding:
		_end_reaction()


## Runs an AI-requested action. One-off animations queue behind a running reaction.
## Returns false for an unknown action.
func perform(action: StringName, seconds: float = 0.0) -> bool:
	if MODE_ACTIONS.has(action):
		_perform_mode_action(action, seconds)
		return true
	if not ACTIONS.has(action):
		return false
	var spec: Dictionary = ACTIONS[action]
	var item: Dictionary = {
		"state": spec["state"],
		"seconds": seconds if seconds > 0.0 else float(spec["seconds"]),
		"effect": spec["effect"],
	}
	_since_event = 0.0
	if mode == Mode.REACT or mode == Mode.HELD:
		if _queue.size() < MAX_QUEUED_ACTIONS:
			_queue.append(item)
	elif mode == Mode.SLEEP:
		_queue.push_back(item)
		_start_reaction({"state": &"alert", "seconds": STARTLE_SECONDS, "effect": &"hop"})
	else:
		_start_reaction(item)
	return true


func drag_to(new_x: float) -> void:
	mode = Mode.HELD
	anim_state = &"happy"
	effect = &""
	_holding = false
	if new_x != x:
		facing = 1 if new_x > x else -1
	x = clampf(new_x, min_x, max_x)


func drop() -> void:
	if mode == Mode.HELD:
		_enter_idle(1.0)


func _perform_mode_action(action: StringName, seconds: float) -> void:
	_queue.clear()
	_since_event = 0.0
	match action:
		&"idle":
			_enter_idle(seconds if seconds > 0.0 else _idle_seconds())
		&"wander":
			if pack != null and pack.wanders():
				_start_wander()
			else:
				_enter_idle(_idle_seconds())
		&"sleep":
			_enter_sleep(seconds if seconds > 0.0 else rng.randf_range(20.0, 45.0))
			_since_event = 1.0e9
		&"wake":
			if mode == Mode.SLEEP:
				_enter_idle(1.0)


func _start_reaction(item: Dictionary) -> void:
	mode = Mode.REACT
	anim_state = item["state"]
	effect = item["effect"]
	effect_serial += 1
	var seconds: float = float(item["seconds"])
	_holding = seconds <= 0.0
	_time_left = seconds


func _end_reaction() -> void:
	if not _queue.is_empty():
		_start_reaction(_queue.pop_front())
		return
	_enter_idle(0.8)


func _enter_idle(seconds: float) -> void:
	mode = Mode.IDLE
	_holding = false
	effect = &""
	anim_state = _idle_state()
	_time_left = seconds


func _enter_sleep(seconds: float) -> void:
	mode = Mode.SLEEP
	anim_state = &"sleep"
	effect = &""
	_time_left = seconds


func _idle_state() -> StringName:
	return &"thinking" if ambient == &"working" else &"idle"


func _idle_seconds() -> float:
	var range_seconds: Array = _behavior("idle_seconds", [2.0, 6.0])
	return rng.randf_range(float(range_seconds[0]), float(range_seconds[1]))


func _behavior(key: String, fallback: Variant) -> Variant:
	if pack == null:
		return fallback
	return pack.behavior.get(key, fallback)


## Dice roll for what to do next, shaped by the pack's weights and by what the AIs are doing.
func _weights() -> Dictionary:
	var weights: Dictionary = {}
	var configured: Dictionary = _behavior("weights", {"idle": 1.0})
	for key: Variant in configured:
		weights[StringName(key)] = float(configured[key])
	if pack == null or not pack.wanders() or max_x - min_x < MIN_WANDER_DISTANCE:
		weights[&"wander"] = 0.0
	var sleepy: bool = _since_event >= float(_behavior("sleep_after_seconds", 45.0))
	if not sleepy or not (ambient == &"" or ambient == &"done"):
		weights[&"sleep"] = 0.0
	match ambient:
		&"working":
			weights[&"play"] = 0.0
			weights[&"idle"] = float(weights.get(&"idle", 0.0)) + 4.0
		&"needs_input", &"error":
			weights[&"play"] = 0.0
			weights[&"wander"] = float(weights.get(&"wander", 0.0)) * 0.3
			weights[&"attention"] = 6.0
		&"done":
			weights[&"emote"] = 3.0
	return weights


func _pick_next() -> void:
	var weights: Dictionary = _weights()
	var total: float = 0.0
	for key: Variant in weights:
		total += maxf(float(weights[key]), 0.0)
	var choice: StringName = &"idle"
	if total > 0.0:
		var roll: float = rng.randf() * total
		for key: Variant in weights:
			roll -= maxf(float(weights[key]), 0.0)
			if roll <= 0.0:
				choice = key
				break
	match choice:
		&"wander":
			_start_wander()
		&"play":
			mode = Mode.PLAY
			anim_state = &"play"
			effect = &""
			_time_left = rng.randf_range(3.0, 6.0)
		&"sleep":
			_enter_sleep(rng.randf_range(20.0, 60.0))
		&"attention":
			_start_reaction({
				"state": &"sad" if ambient == &"error" else &"alert",
				"seconds": 2.0,
				"effect": &"hop",
			})
		&"emote":
			_start_reaction({"state": &"happy", "seconds": 1.6, "effect": &"hop"})
		_:
			_enter_idle(_idle_seconds())


func _start_wander() -> void:
	var low: float = min_x
	var high: float = max_x
	var target: float = x
	for attempt: int in 6:
		target = rng.randf_range(low, high)
		if absf(target - x) >= MIN_WANDER_DISTANCE:
			break
	if absf(target - x) < 1.0:
		_enter_idle(_idle_seconds())
		return
	mode = Mode.WANDER
	_target_x = target
	facing = 1 if target > x else -1
	anim_state = &"walk"
	effect = &""
	var speed: float = maxf(float(_behavior("speed", 22.0)) * speed_scale, 1.0)
	_time_left = absf(target - x) / speed * 1.5 + 1.0


func _walk(delta: float) -> void:
	var speed: float = maxf(float(_behavior("speed", 22.0)) * speed_scale, 1.0)
	var step: float = speed * delta
	_time_left -= delta
	if absf(_target_x - x) <= step or _time_left <= 0.0:
		x = clampf(_target_x if absf(_target_x - x) <= step else x, min_x, max_x)
		_enter_idle(_idle_seconds())
		return
	x += signf(_target_x - x) * step
