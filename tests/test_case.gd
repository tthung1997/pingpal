class_name TestCase
extends RefCounted
## Base class for test cases. Public methods named `test_*` are run by tests/run_tests.gd and may
## be coroutines (use `await tree.process_frame` to let nodes run).

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()
var checks: int = 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func eq(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


## Runs `frames` process frames so nodes under test get their _process() calls.
func wait_frames(frames: int) -> void:
	for _i: int in frames:
		await tree.process_frame
