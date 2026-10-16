extends SceneTree
## Generates the placeholder character pack "Pip" (packs/pip/sheet.png).
##
## Run from the project root:
##   godot --headless --path . --script res://tools/make_placeholder_pack.gd
##
## Layout: one animation per row, FRAMES frames per row, FRAME px square.
## The row order here must match packs/pip/pack.json.

const FRAME: int = 32
const FRAMES: int = 4
const ROWS: Array[StringName] = [
	&"idle", &"walk", &"sleep", &"play", &"happy", &"alert", &"thinking", &"sad", &"wave", &"dance",
]
const OUT_PATH: String = "res://packs/pip/sheet.png"

const OUTLINE := Color("2a3556")
const BODY := Color("6fc7f2")
const BELLY := Color("a9e3fb")
const CHEEK := Color("ff9db4")
const EYE := Color("1d2440")
const WHITE := Color("ffffff")
const ALERT_RED := Color("ff5a4d")
const FOOT := Color("2a3556")
const BALL := Color("ffcf5c")

var _image: Image


func _init() -> void:
	_image = Image.create(FRAME * FRAMES, FRAME * ROWS.size(), false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 0))
	for row: int in ROWS.size():
		for frame: int in FRAMES:
			_draw_frame(ROWS[row], frame, Vector2i(frame * FRAME, row * FRAME))
	var path: String = ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = _image.save_png(path)
	print("wrote %s (%s)" % [OUT_PATH, error_string(err)])
	quit(0 if err == OK else 1)


func _draw_frame(anim: StringName, f: int, o: Vector2i) -> void:
	var bob: int = 0
	var squash: int = 0
	var lean: int = 0
	var eyes: StringName = &"open"
	var mouth: StringName = &"smile"
	var foot_a: int = 0
	var foot_b: int = 0
	var extra: StringName = &""
	match anim:
		&"idle":
			squash = [0, 1, 0, -1][f]
			eyes = &"closed" if f == 3 else &"open"
		&"walk":
			bob = [0, -1, 0, -1][f]
			lean = [1, 0, -1, 0][f]
			foot_a = [-3, 0, 3, 0][f]
			foot_b = -foot_a
		&"sleep":
			squash = [0, 1, 1, 0][f]
			eyes = &"closed"
			mouth = &"flat"
			extra = &"zzz"
		&"play":
			bob = [0, -3, -5, -2][f]
			eyes = &"happy"
			mouth = &"open"
			squash = [2, 0, 0, 0][f]
			foot_a = [0, -2, -2, 0][f]
			foot_b = foot_a
			extra = &"ball"
		&"happy":
			bob = [0, -3, 0, -3][f]
			squash = [1, -1, 1, -1][f]
			eyes = &"happy"
			mouth = &"open"
		&"alert":
			lean = [0, 1, 0, -1][f]
			eyes = &"wide"
			mouth = &"o"
			extra = &"bang"
			squash = -1
		&"thinking":
			eyes = &"up"
			mouth = &"flat"
			extra = &"dots"
			lean = 1
		&"sad":
			squash = [-1, -1, -2, -1][f]
			eyes = &"sad"
			mouth = &"frown"
			extra = &"tear" if f >= 2 else &""
		&"wave":
			extra = &"wave"
		&"dance":
			bob = [0, -2, 0, -2][f]
			lean = [-2, 0, 2, 0][f]
			eyes = &"happy"
			mouth = &"open"
			foot_a = [0, 2, 0, -2][f]
			foot_b = -foot_a
	_draw_blob(o, bob, squash, lean, eyes, mouth, foot_a, foot_b)
	_draw_extra(o, extra, f, lean)


func _draw_blob(o: Vector2i, bob: int, squash: int, lean: int, eyes: StringName, mouth: StringName, foot_a: int, foot_b: int) -> void:
	var cx: float = 16.0 + lean
	var rx: float = 11.0 + squash * 0.5
	var ry: float = 10.0 - squash
	var cy: float = 29.0 - ry - 1.0 + bob
	# Feet first, so the body overlaps them.
	_ellipse(o, 11.0 + lean * 0.5 + foot_a * 0.5, 29.0 + minf(foot_a, 0.0) * 0.5, 3.5, 2.0, FOOT)
	_ellipse(o, 21.0 + lean * 0.5 + foot_b * 0.5, 29.0 + minf(foot_b, 0.0) * 0.5, 3.5, 2.0, FOOT)
	_ellipse(o, cx, cy, rx + 1.0, ry + 1.0, OUTLINE)
	_ellipse(o, cx, cy, rx, ry, BODY)
	_ellipse(o, cx, cy + ry * 0.35, rx * 0.62, ry * 0.5, BELLY)
	_rect(o, int(cx) - 8, int(cy) + 1, 2, 2, CHEEK)
	_rect(o, int(cx) + 6, int(cy) + 1, 2, 2, CHEEK)
	_draw_eyes(o, int(cx), int(cy) - 2, eyes)
	_draw_mouth(o, int(cx), int(cy) + 3, mouth)


func _draw_eyes(o: Vector2i, cx: int, y: int, kind: StringName) -> void:
	for side: int in [-1, 1]:
		var x: int = cx + side * 4
		match kind:
			&"open":
				_rect(o, x - 1, y - 1, 3, 4, EYE)
				_rect(o, x - 1, y - 1, 1, 1, WHITE)
			&"closed":
				_rect(o, x - 1, y + 1, 3, 1, EYE)
			&"happy":
				_rect(o, x - 1, y + 1, 1, 1, EYE)
				_rect(o, x, y, 1, 1, EYE)
				_rect(o, x + 1, y + 1, 1, 1, EYE)
			&"wide":
				_rect(o, x - 2, y - 2, 5, 6, WHITE)
				_rect(o, x - 2, y - 2, 5, 1, EYE)
				_rect(o, x - 2, y + 3, 5, 1, EYE)
				_rect(o, x - 2, y - 2, 1, 6, EYE)
				_rect(o, x + 2, y - 2, 1, 6, EYE)
				_rect(o, x, y, 1, 2, EYE)
			&"up":
				_rect(o, x - 1, y - 2, 3, 4, EYE)
				_rect(o, x, y - 2, 1, 1, WHITE)
			&"sad":
				_rect(o, x - 1, y, 3, 3, EYE)
				_rect(o, x - 1, y, 1, 1, WHITE)
				_rect(o, x - 1, y - 2, 3, 1, OUTLINE)


func _draw_mouth(o: Vector2i, cx: int, y: int, kind: StringName) -> void:
	match kind:
		&"smile":
			_rect(o, cx - 2, y, 1, 1, EYE)
			_rect(o, cx - 1, y + 1, 3, 1, EYE)
			_rect(o, cx + 2, y, 1, 1, EYE)
		&"flat":
			_rect(o, cx - 1, y + 1, 3, 1, EYE)
		&"open":
			_rect(o, cx - 2, y, 5, 1, EYE)
			_rect(o, cx - 1, y + 1, 3, 2, EYE)
			_rect(o, cx - 1, y + 2, 3, 1, ALERT_RED)
		&"o":
			_rect(o, cx - 1, y, 3, 3, EYE)
		&"frown":
			_rect(o, cx - 1, y, 3, 1, EYE)
			_rect(o, cx - 2, y + 1, 1, 1, EYE)
			_rect(o, cx + 2, y + 1, 1, 1, EYE)


func _draw_extra(o: Vector2i, kind: StringName, f: int, lean: int) -> void:
	match kind:
		&"zzz":
			for i: int in mini(f + 1, 3):
				var zx: int = 22 + i * 3
				var zy: int = 9 - i * 4
				_rect(o, zx, zy, 3, 1, EYE)
				_rect(o, zx + 2, zy + 1, 1, 1, EYE)
				_rect(o, zx + 1, zy + 2, 1, 1, EYE)
				_rect(o, zx, zy + 3, 3, 1, EYE)
		&"bang":
			_rect(o, 15, 1, 3, 7, ALERT_RED)
			_rect(o, 15, 10, 3, 3, ALERT_RED)
		&"dots":
			for i: int in 3:
				if i <= f % 4:
					_rect(o, 11 + i * 4, 4, 2, 2, EYE)
		&"tear":
			_rect(o, 12 + lean, 20 + (f - 2) * 3, 2, 3, Color("59b5ff"))
		&"ball":
			var by: float = 24.0 + [0, 2, 3, 1][f]
			_ellipse(o, 27.0, by, 3.0, 3.0, OUTLINE)
			_ellipse(o, 27.0, by, 2.0, 2.0, BALL)
		&"wave":
			var up: float = [0.0, -3.0, 0.0, -3.0][f]
			_ellipse(o, 28.0, 19.0 + up, 3.0, 4.0, OUTLINE)
			_ellipse(o, 28.0, 19.0 + up, 2.0, 3.0, BODY)


func _rect(o: Vector2i, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy: int in h:
		for xx: int in w:
			_put(o, x + xx, y + yy, c)


func _ellipse(o: Vector2i, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y: int in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x: int in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx: float = (x + 0.5 - cx) / rx
			var dy: float = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_put(o, x, y, c)


func _put(o: Vector2i, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= FRAME or y >= FRAME:
		return
	_image.set_pixel(o.x + x, o.y + y, c)
