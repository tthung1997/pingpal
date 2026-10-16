class_name OverlayWindow
extends Node
## Turns the app window into a desktop overlay: a borderless, transparent, always-on-top strip
## along the bottom of a screen, where clicks fall through to whatever is underneath except on
## the character and its UI.
##
## Approach borrowed from Tiny Ages' DesktopWindow: Godot's mouse passthrough accepts a single
## polygon, so the clickable area is the "skyline" of everything interactive: for each column,
## from the highest interactive pixel down to the lowest.
##
## Coordinates seen by the rest of the app are *logical* UI pixels; this class converts to
## physical pixels (the window's content scale factor) at the edge.

signal layout_changed(logical_size: Vector2)

var ui_scale: float = 1.0

var _logical_size: Vector2 = Vector2(640, 320)
var _regions_signature: int = 0
var _apply_serial: int = 0


func logical_size() -> Vector2:
	return _logical_size


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func apply() -> void:
	_apply_serial += 1
	var serial: int = _apply_serial
	if is_headless():
		layout_changed.emit(_logical_size)
		return
	var window: Window = get_window()
	window.mode = Window.MODE_WINDOWED
	window.borderless = true
	window.transparent = true
	window.unresizable = true
	window.always_on_top = PingConfig.always_on_top
	# The overlay should never steal keyboard focus from the app you are working in.
	window.unfocusable = true
	get_viewport().transparent_bg = true
	Engine.max_fps = PingConfig.fps_cap
	OS.low_processor_usage_mode = true
	ui_scale = maxf(1.0, snappedf(DisplayServer.screen_get_scale(window.current_screen), 0.25))
	window.content_scale_factor = ui_scale
	_place()
	# Window flag changes land asynchronously on some platforms, so settle geometry again.
	await get_tree().process_frame
	if serial != _apply_serial or not is_inside_tree():
		return
	_place()
	_regions_signature = 0


func move_to_next_screen() -> void:
	if is_headless():
		return
	var window: Window = get_window()
	window.current_screen = (window.current_screen + 1) % DisplayServer.get_screen_count()
	apply()


## Sets the areas (logical px, window-relative) that receive clicks; everything else passes
## through. Call every frame: it only touches the OS when the shape changes.
func set_clickable(rects: Array[Rect2]) -> void:
	if is_headless() or not PingConfig.click_through:
		return
	var signature: int = hash(ui_scale)
	for rect: Rect2 in rects:
		signature = hash([signature, roundi(rect.position.x), roundi(rect.position.y),
			roundi(rect.size.x), roundi(rect.size.y)])
	if signature == _regions_signature:
		return
	_regions_signature = signature
	get_window().mouse_passthrough_polygon = build_polygon(rects, _logical_size * ui_scale, ui_scale)


## The single polygon covering `rects` (logical px), in physical px for a window of `size`.
## Columns nobody covers collapse to a zero-height sliver on the bottom edge. With no rects at all
## it returns a 1px triangle, because an *empty* polygon would disable passthrough entirely.
static func build_polygon(rects: Array[Rect2], size: Vector2, scale_factor: float) -> PackedVector2Array:
	var width: int = ceili(size.x)
	var height: float = size.y
	if rects.is_empty() or width <= 0:
		return PackedVector2Array([Vector2(0, height), Vector2(1, height), Vector2(0, height - 1)])
	var tops: PackedFloat32Array = PackedFloat32Array()
	var bottoms: PackedFloat32Array = PackedFloat32Array()
	tops.resize(width)
	bottoms.resize(width)
	tops.fill(height)
	bottoms.fill(height)
	var covered: PackedByteArray = PackedByteArray()
	covered.resize(width)
	for rect: Rect2 in rects:
		if not rect.has_area():
			continue
		var top: float = clampf(rect.position.y * scale_factor, 0.0, height)
		var bottom: float = clampf(rect.end.y * scale_factor, 0.0, height)
		for x: int in range(clampi(floori(rect.position.x * scale_factor), 0, width),
				clampi(ceili(rect.end.x * scale_factor), 0, width)):
			tops[x] = minf(tops[x], top) if covered[x] == 1 else top
			bottoms[x] = maxf(bottoms[x], bottom) if covered[x] == 1 else bottom
			covered[x] = 1
	var top_edge: PackedVector2Array = PackedVector2Array()
	var bottom_edge: PackedVector2Array = PackedVector2Array()
	var run_start: int = 0
	for x: int in range(1, width + 1):
		if x < width and tops[x] == tops[run_start] and bottoms[x] == bottoms[run_start]:
			continue
		top_edge.append(Vector2(run_start, tops[run_start]))
		top_edge.append(Vector2(x, tops[run_start]))
		bottom_edge.append(Vector2(run_start, bottoms[run_start]))
		bottom_edge.append(Vector2(x, bottoms[run_start]))
		run_start = x
	bottom_edge.reverse()
	top_edge.append_array(bottom_edge)
	return top_edge


func _place() -> void:
	var window: Window = get_window()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	var height: int = roundi(PingConfig.strip_height * ui_scale)
	var size: Vector2i = Vector2i(usable.size.x, height)
	var position: Vector2i = Vector2i(usable.position.x, usable.end.y - height)
	_logical_size = Vector2(size) / ui_scale
	window.size = size
	window.position = position
	layout_changed.emit(_logical_size)
