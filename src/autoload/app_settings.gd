class_name AppSettings
extends Node
## User-facing settings: where the window sits, which character, which port the MCP server uses.
##
## Precedence: command-line flags > user://settings.cfg > defaults. Flags are never written back
## to the file, so `pingpal --port=9000` does not permanently change your port.
##
## Flags: --port=N  --mode=strip|corner|window  --pack=ID  --scale=N  --token=SECRET
##        --no-always-on-top  --no-click-through

enum Mode { STRIP, CORNER, WINDOW }

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "pingpal"
const DEFAULT_PORT: int = 7464 # "PING" on a phone keypad
const DEFAULT_PACK: String = "pip"
const MODE_NAMES: Array[String] = ["strip", "corner", "window"]

var port: int = DEFAULT_PORT
var mode: Mode = Mode.STRIP
var pack_id: String = DEFAULT_PACK
## Whole-number magnification of the character art.
var pixel_scale: int = 3
var always_on_top: bool = true
var click_through: bool = true
var fps_cap: int = 30
## When set, MCP clients must send `Authorization: Bearer <token>`.
var auth_token: String = ""
## Overlay size in UI pixels: the strip's height, and the corner window's width.
var strip_height: int = 320
var corner_width: int = 480
## Keeps the character this far from the window edge so it does not hide under screen corners.
var edge_margin: int = 16

## Values stored in the settings file (only these are saved).
var _stored: Dictionary = {}


func _ready() -> void:
	load_settings(OS.get_cmdline_user_args() + OS.get_cmdline_args())


func load_settings(args: PackedStringArray) -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		for key: String in file.get_section_keys(SECTION):
			_stored[key] = file.get_value(SECTION, key)
			_assign(key, _stored[key])
	for arg: String in args:
		_apply_flag(arg)


## Changes a setting and remembers it across runs.
func store(key: String, value: Variant) -> void:
	_assign(key, value)
	_stored[key] = get(key)
	var file: ConfigFile = ConfigFile.new()
	file.load(SETTINGS_PATH)
	for stored_key: String in _stored:
		file.set_value(SECTION, stored_key, _stored[stored_key])
	file.save(SETTINGS_PATH)


func _apply_flag(arg: String) -> void:
	if not arg.begins_with("--"):
		return
	var body: String = arg.substr(2)
	var key: String = body
	var value: String = ""
	var equals: int = body.find("=")
	if equals >= 0:
		key = body.substr(0, equals)
		value = body.substr(equals + 1)
	match key:
		"port", "mode", "pack", "scale", "token":
			_assign("auth_token" if key == "token" else "pixel_scale" if key == "scale" \
				else "pack_id" if key == "pack" else key, value)
		"no-always-on-top":
			always_on_top = false
		"no-click-through":
			click_through = false


## Coerces and range-checks a value before accepting it; bad input keeps the previous value.
func _assign(key: String, value: Variant) -> void:
	match key:
		"port":
			var number: int = int(str(value)) if str(value).is_valid_int() else -1
			if number >= 0 and number <= 65535:
				port = number
		"mode":
			var index: int = MODE_NAMES.find(str(value).to_lower())
			if index < 0 and value is int and value >= 0 and value < MODE_NAMES.size():
				index = value
			if index >= 0:
				mode = index as Mode
		"pack_id":
			if str(value).is_valid_filename():
				pack_id = str(value)
		"pixel_scale":
			var number: int = int(str(value)) if str(value).is_valid_int() else 0
			if number >= 1 and number <= 8:
				pixel_scale = number
		"always_on_top":
			always_on_top = bool(value)
		"click_through":
			click_through = bool(value)
		"fps_cap":
			fps_cap = clampi(int(value), 5, 120)
		"auth_token":
			auth_token = str(value)
