extends SceneTree
## Headless test runner.
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Runs every public `test_*` method of every tests/cases/test_*.gd and exits non-zero on failure.

const CASES_DIR: String = "res://tests/cases"


func _initialize() -> void:
	# Deferred so the SceneTree is fully up (process frames, root) before tests start awaiting.
	_run.call_deferred()


func _run() -> void:
	var failed: int = 0
	var passed: int = 0
	var files: PackedStringArray = DirAccess.get_files_at(CASES_DIR)
	files.sort()
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		var script: GDScript = load("%s/%s" % [CASES_DIR, file])
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test_case: TestCase = script.new()
			test_case.tree = self
			await test_case.call(method_name)
			if test_case.failures.is_empty():
				passed += 1
				print("  ok    %s::%s (%d checks)" % [file, method_name, test_case.checks])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [file, method_name])
				for message: String in test_case.failures:
					print("        - %s" % message)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
