class_name McpProtocol
extends RefCounted
## Transport-independent MCP (JSON-RPC 2.0) handling: sessions, initialize, tools/list,
## tools/call. The HTTP layer hands it parsed JSON and writes back whatever it returns.
##
## Implemented against the 2025-06-18 spec, and negotiates 2025-03-26 and 2024-11-05.

const SERVER_NAME: String = "pingpal"
const SERVER_TITLE: String = "PingPal"
const SERVER_VERSION: String = "0.1.0"
const LATEST_VERSION: String = "2025-06-18"
const SUPPORTED_VERSIONS: Array[String] = ["2025-06-18", "2025-03-26", "2024-11-05"]

const ERR_PARSE: int = -32700
const ERR_INVALID_REQUEST: int = -32600
const ERR_METHOD_NOT_FOUND: int = -32601
const ERR_INVALID_PARAMS: int = -32602
const ERR_INTERNAL: int = -32603

const MAX_SESSIONS: int = 256

const INSTRUCTIONS: String = """PingPal is a small desktop character that shows the human what you are up to, so they don't have to keep this app open.
- Call set_state(status="working") when you start a long task and set_state(status="done") when it finishes. Use "needs_input" or ask() only when you are really blocked on the human; "error" if something failed.
- Use notify() for a brief, friendly one-liner (under ~100 characters). Don't narrate every step; messages from several AIs share one screen.
- Every tool call needs a `source`: a name that identifies this session to the human (up to 80 characters). Use your session's title if you know it, otherwise describe the task or repo, for example "Fix login redirect". Each distinct name is its own entry (color, tray chip, status), so use exactly the same name on every call."""

var tools: McpTools
## session id -> {client_name, client_version, protocol_version}
var sessions: Dictionary = {}


func _init(p_tools: McpTools = null) -> void:
	tools = p_tools


## Handles one parsed JSON-RPC payload (a message or a batch). Returns the response to send
## (Dictionary or Array), or null when there is nothing to send (notifications / responses).
## `ctx` carries {session_id, conn_id}; on `initialize` it gains `new_session_id`.
func handle_payload(payload: Variant, ctx: Dictionary) -> Variant:
	if payload is Array:
		if payload.is_empty():
			return _error(null, ERR_INVALID_REQUEST, "Empty batch")
		var replies: Array = []
		for message: Variant in payload:
			var reply: Variant = await _handle_message(message, ctx)
			if reply != null:
				replies.append(reply)
		return replies if not replies.is_empty() else null
	return await _handle_message(payload, ctx)


## True for payloads that are only notifications/responses (the HTTP layer answers 202).
static func expects_reply(payload: Variant) -> bool:
	var messages: Array = payload if payload is Array else [payload]
	for message: Variant in messages:
		if not message is Dictionary:
			return true
		var is_response: bool = message.has("result") or message.has("error")
		var is_notification: bool = message.has("method") and message.get("id") == null
		if not is_response and not is_notification:
			return true
	return false


static func is_supported_version(version: String) -> bool:
	return SUPPORTED_VERSIONS.has(version)


func end_session(session_id: String) -> bool:
	return sessions.erase(session_id)


func _handle_message(message: Variant, ctx: Dictionary) -> Variant:
	if not message is Dictionary:
		return _error(null, ERR_INVALID_REQUEST, "Request must be a JSON object")
	var request: Dictionary = message
	if not request.has("method"):
		# A response to something we sent. We never send requests, so there is nothing to do.
		return null if request.has("result") or request.has("error") else \
			_error(request.get("id"), ERR_INVALID_REQUEST, "Missing method")
	var method: String = str(request["method"])
	var is_request: bool = request.has("id") and request["id"] != null
	if not is_request:
		_handle_notification(method, request.get("params"), ctx)
		return null
	var params: Variant = request.get("params", {})
	if params == null:
		params = {}
	if not params is Dictionary:
		return _error(request["id"], ERR_INVALID_PARAMS, "params must be an object")
	return await _dispatch(request["id"], method, params, ctx)


func _handle_notification(_method: String, _params: Variant, _ctx: Dictionary) -> void:
	# notifications/initialized and notifications/cancelled need no action: tool calls are short,
	# and an abandoned `ask` is withdrawn when its connection closes.
	pass


func _dispatch(id: Variant, method: String, params: Dictionary, ctx: Dictionary) -> Dictionary:
	match method:
		"initialize":
			return _initialize(id, params, ctx)
		"ping":
			return _result(id, {})
		"tools/list":
			return _result(id, {"tools": tools.definitions()})
		"tools/call":
			var tool_name: Variant = params.get("name")
			if not tool_name is String or (tool_name as String).is_empty():
				return _error(id, ERR_INVALID_PARAMS, "tools/call needs a tool name")
			var arguments: Variant = params.get("arguments", {})
			if arguments == null:
				arguments = {}
			if not arguments is Dictionary:
				return _error(id, ERR_INVALID_PARAMS, "arguments must be an object")
			var result: Dictionary = await tools.call_tool(tool_name, arguments, ctx)
			return _result(id, result)
		"resources/list":
			return _result(id, {"resources": []})
		"resources/templates/list":
			return _result(id, {"resourceTemplates": []})
		"prompts/list":
			return _result(id, {"prompts": []})
		"logging/setLevel":
			return _result(id, {})
	return _error(id, ERR_METHOD_NOT_FOUND, "Method not found: %s" % method)


func _initialize(id: Variant, params: Dictionary, ctx: Dictionary) -> Dictionary:
	var requested: String = str(params.get("protocolVersion", LATEST_VERSION))
	var version: String = requested if is_supported_version(requested) else LATEST_VERSION
	var client: Dictionary = params.get("clientInfo", {}) if params.get("clientInfo") is Dictionary else {}
	var client_name: String = SourceRegistry.clean_name(str(client.get("title", client.get("name", ""))))
	if client_name.is_empty():
		client_name = SourceRegistry.clean_name(str(client.get("name", "")))
	var session_id: String = _new_session_id()
	if sessions.size() >= MAX_SESSIONS:
		sessions.erase(sessions.keys()[0])
	sessions[session_id] = {
		"client_name": client_name,
		"client_version": str(client.get("version", "")),
		"protocol_version": version,
	}
	ctx["new_session_id"] = session_id
	return _result(id, {
		"protocolVersion": version,
		"capabilities": {"tools": {"listChanged": false}},
		"serverInfo": {"name": SERVER_NAME, "title": SERVER_TITLE, "version": SERVER_VERSION},
		"instructions": INSTRUCTIONS,
	})


static func _new_session_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


## Godot parses every JSON number as a float and would echo `1` back as `1.0`, which strict clients
## (Go, Rust) reject as a mismatched request id. Whole numbers are turned back into ints.
static func _echo_id(id: Variant) -> Variant:
	if id is float and is_finite(id) and absf(id) < 9.0e15 and id == floorf(id):
		return int(id)
	return id


static func _result(id: Variant, result: Dictionary) -> Dictionary:
	return {"jsonrpc": "2.0", "id": _echo_id(id), "result": result}


static func _error(id: Variant, code: int, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": _echo_id(id), "error": {"code": code, "message": message}}


static func parse_error() -> Dictionary:
	return _error(null, ERR_PARSE, "Parse error")
