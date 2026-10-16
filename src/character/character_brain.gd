class_name CharacterBrain
extends RefCounted
## The character's animation chain. It decides what the character plays and yields to messages.
##
## It is deliberately free of nodes and rendering: it owns position, facing and a *semantic*
## animation state, and the actor turns that into pixels. That keeps it unit-testable.
##
##   IDLE      loops the main idle animation for as long as nothing else happens
##   IDLE  ->  BREAK      after a random while, a short variation from the pack's `breaks`
##   BREAK ->  IDLE       when the break has run its course
##   any   ->  ATTENTION  a message is waiting for the user; one neutral animation, held until the
##                        user has checked everything (the app decides when, via `release()`)
##   ATTENTION -> IDLE    when nothing is left to check
##   any   ->  HELD -> IDLE   the user is dragging the character

enum Mode { IDLE, BREAK, ATTENTION, HELD }

const IDLE_STATE: StringName = &"idle"
const ATTENTION_STATE: StringName = &"attention"

var pack: CharacterPack
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var mode: Mode = Mode.IDLE
var x: float = 0.0
var facing: int = 1
var limit_min: float = 0.0
var limit_max: float = 400.0
## Semantic state the actor should show; resolved through the pack.
var anim_state: StringName = IDLE_STATE

var _time_left: float = 0.0
var _last_break: StringName = &""


func _init(p_pack: CharacterPack = null) -> void:
	pack = p_pack
	rng.randomize()
	_enter_idle()


## Switches to a different character pack without losing position or attention state.
func set_pack(p_pack: CharacterPack) -> void:
	pack = p_pack
	_last_break = &""
	if mode == Mode.ATTENTION:
		anim_state = ATTENTION_STATE
	else:
		_enter_idle()


## Widest the user may drag the character.
func set_limits(low: float, high: float) -> void:
	limit_min = low
	limit_max = maxf(high, low)
	x = clampf(x, limit_min, limit_max)


func update(delta: float) -> void:
	match mode:
		Mode.IDLE:
			_time_left -= delta
			if _time_left <= 0.0:
				_start_break()
		Mode.BREAK:
			_time_left -= delta
			if _time_left <= 0.0:
				_enter_idle()


## Something is waiting for the user: play the attention animation until `release()`. Interrupts
## whatever is playing, including a break. Safe to call again while already waiting.
func react() -> void:
	_hold(ATTENTION_STATE)


## Holds any state (used by `--preview` to inspect one animation).
func preview(state: StringName) -> void:
	_hold(state)


## Ends the attention animation (the user has checked everything).
func release() -> void:
	if mode == Mode.ATTENTION:
		_enter_idle()


func drag_to(new_x: float) -> void:
	mode = Mode.HELD
	anim_state = IDLE_STATE
	if new_x != x:
		facing = 1 if new_x > x else -1
	x = clampf(new_x, limit_min, limit_max)


func drop() -> void:
	if mode == Mode.HELD:
		_enter_idle()


func _hold(state: StringName) -> void:
	mode = Mode.ATTENTION
	anim_state = state


## Back to the idle loop for a fresh random stretch before the next break.
func _enter_idle() -> void:
	mode = Mode.IDLE
	anim_state = IDLE_STATE
	_time_left = _seconds("idle_seconds", [6.0, 14.0])


## Picks a random break, avoiding the one just played when there is a choice.
func _start_break() -> void:
	var options: Array[StringName] = pack.breaks() if pack != null else []
	if options.size() > 1:
		options.erase(_last_break)
	if options.is_empty():
		_enter_idle()
		return
	_last_break = options[rng.randi_range(0, options.size() - 1)]
	mode = Mode.BREAK
	anim_state = _last_break
	_time_left = _seconds("break_seconds", [3.0, 6.0])


func _seconds(key: String, fallback: Array) -> float:
	var range_seconds: Array = pack.behavior.get(key, fallback) if pack != null else fallback
	return rng.randf_range(float(range_seconds[0]), float(range_seconds[1]))
