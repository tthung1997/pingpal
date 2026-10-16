class_name McpHttpServer
extends Node
## A tiny, loopback-only HTTP/1.1 server speaking MCP "streamable HTTP" on a single endpoint.
##
## Why hand-rolled instead of an addon: it is ~300 lines, has no native dependency, and MCP's
## request/response mode needs very little HTTP: POST a JSON-RPC message, get JSON back. We
## answer GET with 405 (no server-initiated SSE stream), which the spec explicitly permits.
##
## Hardening: binds 127.0.0.1 only, rejects non-local Host/Origin headers (DNS rebinding),
## optional bearer token, request/connection caps, idle timeouts, keep-alive, chunked bodies.
##
## Connections are polled from _process(); every request is answered immediately.

const BIND_ADDRESS: String = "127.0.0.1"
const MCP_PATH: String = "/mcp"
const MAX_HEADER_BYTES: int = 16384
const MAX_BODY_BYTES: int = 1048576
const MAX_CONNECTIONS: int = 32
const IDLE_TIMEOUT_MSEC: int = 60000
const LOCAL_HOSTS: Array[String] = ["127.0.0.1", "localhost", "[::1]", "::1"]
const REASONS: Dictionary = {
	200: "OK", 202: "Accepted", 204: "No Content", 400: "Bad Request", 401: "Unauthorized",
	403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed", 413: "Payload Too Large",
	431: "Request Header Fields Too Large", 500: "Internal Server Error",
}

class Conn extends RefCounted:
	var peer: StreamPeerTCP = null
	var buf: PackedByteArray = PackedByteArray()
	var scan_from: int = 0
	var head: Dictionary = {}
	var body_start: int = 0
	var sent_continue: bool = false
	var busy: bool = false
	var closed: bool = false
	var last_activity_msec: int = 0

var protocol: McpProtocol
## When non-empty, every request must carry `Authorization: Bearer <token>`.
var auth_token: String = ""

var _server: TCPServer = TCPServer.new()
var _conns: Array[Conn] = []


## Starts listening. Port 0 picks a free port (see `port()`).
func start(port_number: int) -> Error:
	return _server.listen(port_number, BIND_ADDRESS)


func stop() -> void:
	for conn: Conn in _conns.duplicate():
		_drop(conn)
	_server.stop()


func is_running() -> bool:
	return _server.is_listening()


func port() -> int:
	return _server.get_local_port()


func connection_count() -> int:
	return _conns.size()


func _process(_delta: float) -> void:
	if not _server.is_listening():
		return
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if _conns.size() >= MAX_CONNECTIONS:
			peer.disconnect_from_host()
			continue
		var conn: Conn = Conn.new()
		conn.peer = peer
		conn.last_activity_msec = Time.get_ticks_msec()
		_conns.append(conn)
	for conn: Conn in _conns.duplicate():
		_service(conn)


func _service(conn: Conn) -> void:
	if conn.closed:
		return
	conn.peer.poll()
	var status: StreamPeerTCP.Status = conn.peer.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTING:
		return
	var available: int = conn.peer.get_available_bytes() if status == StreamPeerTCP.STATUS_CONNECTED else 0
	if available > 0:
		var result: Array = conn.peer.get_data(available)
		if result[0] == OK:
			conn.buf.append_array(result[1])
			conn.last_activity_msec = Time.get_ticks_msec()
	if status != StreamPeerTCP.STATUS_CONNECTED:
		_drop(conn)
		return
	if not conn.busy:
		_try_parse(conn)
		if not conn.busy and Time.get_ticks_msec() - conn.last_activity_msec > IDLE_TIMEOUT_MSEC:
			_drop(conn)


func _drop(conn: Conn) -> void:
	if conn.closed:
		return
	conn.closed = true
	_conns.erase(conn)
	conn.peer.disconnect_from_host()


# --- HTTP parsing ------------------------------------------------------------------------------

func _try_parse(conn: Conn) -> void:
	if conn.head.is_empty():
		var end: int = _find_crlf(conn.buf, conn.scan_from, true)
		if end < 0:
			conn.scan_from = maxi(conn.buf.size() - 3, 0)
			if conn.buf.size() > MAX_HEADER_BYTES:
				_send(conn, 431, {}, "", true)
			return
		if end > MAX_HEADER_BYTES or not _parse_head(conn, end):
			_send(conn, 400 if end <= MAX_HEADER_BYTES else 431, {}, "", true)
			return
		conn.body_start = end + 4
	var headers: Dictionary = conn.head["headers"]
	if str(headers.get("expect", "")).to_lower() == "100-continue" and not conn.sent_continue:
		conn.sent_continue = true
		conn.peer.put_data("HTTP/1.1 100 Continue\r\n\r\n".to_utf8_buffer())
	var body: PackedByteArray = PackedByteArray()
	var consumed_to: int = conn.body_start
	if str(headers.get("transfer-encoding", "")).to_lower().contains("chunked"):
		var decoded: Dictionary = _decode_chunked(conn.buf, conn.body_start)
		match decoded["state"]:
			"incomplete":
				return
			"error":
				_send(conn, 400, {}, "", true)
				return
			"too_large":
				_send(conn, 413, {}, "", true)
				return
		body = decoded["body"]
		consumed_to = decoded["end"]
	else:
		var length_text: String = str(headers.get("content-length", "0"))
		if not length_text.is_valid_int() or int(length_text) < 0:
			_send(conn, 400, {}, "", true)
			return
		var length: int = int(length_text)
		if length > MAX_BODY_BYTES:
			_send(conn, 413, {}, "", true)
			return
		if conn.buf.size() < conn.body_start + length:
			return
		body = conn.buf.slice(conn.body_start, conn.body_start + length)
		consumed_to = conn.body_start + length
	var head: Dictionary = conn.head
	conn.buf = conn.buf.slice(consumed_to)
	conn.head = {}
	conn.scan_from = 0
	conn.sent_continue = false
	conn.busy = true
	_handle_request(conn, head, body)


func _parse_head(conn: Conn, end: int) -> bool:
	var text: String = conn.buf.slice(0, end).get_string_from_utf8()
	var lines: PackedStringArray = text.split("\r\n")
	var parts: PackedStringArray = lines[0].split(" ")
	if parts.size() != 3 or not parts[2].begins_with("HTTP/1."):
		return false
	var headers: Dictionary = {}
	for index: int in range(1, lines.size()):
		var colon: int = lines[index].find(":")
		if colon <= 0:
			return false
		headers[lines[index].substr(0, colon).strip_edges().to_lower()] = lines[index].substr(colon + 1).strip_edges()
	conn.head = {"method": parts[0], "target": parts[1], "version": parts[2], "headers": headers}
	return true


## Finds "\r\n" (or, with `double`, "\r\n\r\n") at or after `from`; -1 if absent.
static func _find_crlf(buf: PackedByteArray, from: int, double: bool = false) -> int:
	var last: int = buf.size() - (3 if double else 1)
	for index: int in range(from, last):
		if buf[index] == 13 and buf[index + 1] == 10:
			if not double or (buf[index + 2] == 13 and buf[index + 3] == 10):
				return index
	return -1


static func _decode_chunked(buf: PackedByteArray, start: int) -> Dictionary:
	var pos: int = start
	var out: PackedByteArray = PackedByteArray()
	while true:
		var line_end: int = _find_crlf(buf, pos)
		if line_end < 0:
			return {"state": "incomplete"}
		var size_text: String = buf.slice(pos, line_end).get_string_from_ascii().split(";")[0].strip_edges()
		if not size_text.is_valid_hex_number():
			return {"state": "error"}
		var size: int = size_text.hex_to_int()
		pos = line_end + 2
		if size == 0:
			while true:
				var trailer_end: int = _find_crlf(buf, pos)
				if trailer_end < 0:
					return {"state": "incomplete"}
				if trailer_end == pos:
					return {"state": "ok", "body": out, "end": pos + 2}
				pos = trailer_end + 2
		if out.size() + size > MAX_BODY_BYTES:
			return {"state": "too_large"}
		if buf.size() < pos + size + 2:
			return {"state": "incomplete"}
		out.append_array(buf.slice(pos, pos + size))
		pos += size + 2
	return {"state": "error"}


# --- Request handling --------------------------------------------------------------------------

func _handle_request(conn: Conn, head: Dictionary, body: PackedByteArray) -> void:
	var headers: Dictionary = head["headers"]
	var close: bool = str(headers.get("connection", "")).to_lower() == "close" or head["version"] == "HTTP/1.0"
	var path: String = str(head["target"]).split("?")[0]
	var method: String = head["method"]

	if not _is_local_host(str(headers.get("host", "localhost"))) \
			or (headers.has("origin") and not _is_local_origin(str(headers["origin"]))):
		_send(conn, 403, {}, _plain_error("Forbidden: PingPal only accepts local requests"), close)
		return
	if not auth_token.is_empty() and str(headers.get("authorization", "")) != "Bearer " + auth_token:
		_send(conn, 401, {"WWW-Authenticate": "Bearer"}, _plain_error("Unauthorized"), close)
		return

	if path == "/health" and method == "GET":
		var info: Dictionary = {"ok": true, "name": McpProtocol.SERVER_NAME,
			"version": McpProtocol.SERVER_VERSION, "sessions": protocol.sessions.size()}
		_send(conn, 200, {}, JSON.stringify(info), close)
		return
	if path != MCP_PATH and path != "/":
		_send(conn, 404, {}, _plain_error("Not found. The MCP endpoint is %s" % MCP_PATH), close)
		return

	match method:
		"POST":
			_handle_post(conn, headers, body, close)
		"DELETE":
			protocol.end_session(str(headers.get("mcp-session-id", "")))
			_send(conn, 200, {}, "", close)
		"OPTIONS":
			_send(conn, 204, {"Allow": "POST, DELETE, OPTIONS"}, "", close)
		_:
			_send(conn, 405, {"Allow": "POST, DELETE, OPTIONS"}, _plain_error("Method not allowed"), close)


func _handle_post(conn: Conn, headers: Dictionary, body: PackedByteArray, close: bool) -> void:
	var version: String = str(headers.get("mcp-protocol-version", ""))
	if not version.is_empty() and not McpProtocol.is_supported_version(version):
		_send(conn, 400, {}, JSON.stringify(McpProtocol._error(null, McpProtocol.ERR_INVALID_REQUEST,
			"Unsupported MCP-Protocol-Version '%s'" % version)), close)
		return
	var json: JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or json.data == null:
		_send(conn, 400, {}, JSON.stringify(McpProtocol.parse_error()), close)
		return
	# Unknown or missing session ids are tolerated (the server may have restarted since the client
	# initialized): a tool call carries everything it needs, including its `source`.
	var ctx: Dictionary = {"session_id": str(headers.get("mcp-session-id", ""))}
	var reply: Variant = protocol.handle_payload(json.data, ctx)
	var extra: Dictionary = {}
	if ctx.has("new_session_id"):
		extra["Mcp-Session-Id"] = ctx["new_session_id"]
	if reply == null or not McpProtocol.expects_reply(json.data):
		_send(conn, 202, extra, "", close)
	else:
		_send(conn, 200, extra, JSON.stringify(reply), close)


func _send(conn: Conn, status: int, extra_headers: Dictionary, body: String, close: bool) -> void:
	if conn.closed:
		return
	var payload: PackedByteArray = body.to_utf8_buffer()
	var lines: PackedStringArray = PackedStringArray([
		"HTTP/1.1 %d %s" % [status, REASONS.get(status, "Status")],
		"Content-Length: %d" % payload.size(),
		"Cache-Control: no-store",
		"Connection: %s" % ("close" if close else "keep-alive"),
	])
	if not body.is_empty():
		lines.append("Content-Type: application/json; charset=utf-8")
	for key: Variant in extra_headers:
		lines.append("%s: %s" % [key, extra_headers[key]])
	var message: PackedByteArray = ("\r\n".join(lines) + "\r\n\r\n").to_utf8_buffer()
	message.append_array(payload)
	conn.peer.put_data(message)
	conn.busy = false
	conn.last_activity_msec = Time.get_ticks_msec()
	if close:
		_drop(conn)


static func _plain_error(message: String) -> String:
	return JSON.stringify({"error": message})


static func _is_local_host(host_header: String) -> bool:
	var host: String = host_header.strip_edges().to_lower()
	if host.begins_with("["):
		var close_index: int = host.find("]")
		host = host.substr(0, close_index + 1) if close_index > 0 else host
	elif host.count(":") == 1:
		host = host.split(":")[0]
	return LOCAL_HOSTS.has(host)


static func _is_local_origin(origin: String) -> bool:
	var rest: String = origin.strip_edges().to_lower()
	var scheme_end: int = rest.find("://")
	if scheme_end < 0:
		return false
	rest = rest.substr(scheme_end + 3).split("/")[0]
	return _is_local_host(rest)
