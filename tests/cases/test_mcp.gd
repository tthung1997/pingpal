extends TestCase

const INIT_BODY: Dictionary = {
	"jsonrpc": "2.0", "id": 1, "method": "initialize",
	"params": {
		"protocolVersion": "2025-06-18", "capabilities": {},
		"clientInfo": {"name": "claude-code", "title": "Claude Code", "version": "1.2.3"},
	},
}


func _protocol() -> McpProtocol:
	return McpProtocol.new(McpTools.new(NotificationManager.new()))


func _rpc(id: Variant, method: String, params: Dictionary = {}) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "method": method, "params": params}


func _text(result: Dictionary) -> String:
	return str(result["content"][0]["text"])


# --- Protocol (no sockets) ---------------------------------------------------------------------

func test_initialize_negotiates_and_creates_session() -> void:
	var protocol: McpProtocol = _protocol()
	var ctx: Dictionary = {}
	var reply: Dictionary = await protocol.handle_payload(INIT_BODY, ctx)
	eq(reply["id"], 1, "id echoed")
	eq(reply["result"]["protocolVersion"], "2025-06-18", "echoes a supported version")
	check(reply["result"]["capabilities"].has("tools"), "advertises tools")
	eq(reply["result"]["serverInfo"]["name"], "pingpal", "server name")
	check(str(reply["result"]["instructions"]).length() > 20, "ships usage instructions for the model")
	check(ctx.has("new_session_id"), "a session was created")
	eq(protocol.sessions[ctx["new_session_id"]]["client_name"], "Claude Code", "client title becomes its name")

	var old: Dictionary = INIT_BODY.duplicate(true)
	old["params"]["protocolVersion"] = "2024-11-05"
	eq((await protocol.handle_payload(old, {}))["result"]["protocolVersion"], "2024-11-05", "negotiates older versions")
	old["params"]["protocolVersion"] = "1999-01-01"
	eq((await protocol.handle_payload(old, {}))["result"]["protocolVersion"], McpProtocol.LATEST_VERSION, "unknown version -> latest")


func test_tools_list_has_the_five_tools_with_schemas() -> void:
	var reply: Dictionary = await _protocol().handle_payload(_rpc(2, "tools/list"), {})
	var names: Array = []
	for tool_def: Dictionary in reply["result"]["tools"]:
		names.append(tool_def["name"])
		eq(tool_def["inputSchema"]["type"], "object", "%s has an object schema" % tool_def["name"])
		check(not str(tool_def["description"]).is_empty(), "%s has a description" % tool_def["name"])
	names.sort()
	eq(names, ["ask", "clear", "notify", "perform", "set_state"], "exactly the agreed tools")
	check(JSON.stringify(reply) != "", "the list is JSON-serializable")


func test_tool_calls_drive_the_hub() -> void:
	var hub: NotificationManager = NotificationManager.new()
	var protocol: McpProtocol = McpProtocol.new(McpTools.new(hub))
	var ctx: Dictionary = {}
	await protocol.handle_payload(INIT_BODY, ctx)
	ctx = {"session_id": ctx["new_session_id"]}

	var reply: Dictionary = await protocol.handle_payload(
		_rpc(3, "tools/call", {"name": "notify", "arguments": {"text": "hi there", "mood": "happy"}}), ctx)
	eq(reply["result"]["isError"], false, "notify succeeds")
	eq(hub.history[0].source.display_name, "Claude Code", "source comes from the session's client name")
	eq(hub.history[0].mood, &"happy", "mood passed through")

	reply = await protocol.handle_payload(
		_rpc(4, "tools/call", {"name": "notify", "arguments": {"text": "x", "source": "Codex"}}), ctx)
	eq(hub.history[1].source.display_name, "Codex", "an explicit source wins")

	reply = await protocol.handle_payload(
		_rpc(5, "tools/call", {"name": "set_state", "arguments": {"status": "working"}}), ctx)
	eq(JSON.parse_string(_text(reply["result"]))["status"], "working", "set_state reports the new status")
	eq(hub.ambient(), &"working", "hub is working")

	reply = await protocol.handle_payload(_rpc(6, "tools/call", {"name": "perform", "arguments": {"action": "dance"}}), ctx)
	eq(reply["result"]["isError"], false, "perform succeeds")

	reply = await protocol.handle_payload(_rpc(7, "tools/call", {"name": "clear", "arguments": {}}), ctx)
	eq(reply["result"]["isError"], false, "clear succeeds")
	eq(hub.ambient(), &"", "clear removed the caller's state")


func test_bad_arguments_are_tool_errors_not_protocol_errors() -> void:
	var protocol: McpProtocol = _protocol()
	var cases: Array[Dictionary] = [
		{"name": "notify", "arguments": {}},
		{"name": "notify", "arguments": {"text": "x", "mood": "furious"}},
		{"name": "notify", "arguments": {"text": 5}},
		{"name": "set_state", "arguments": {"status": "napping"}},
		{"name": "ask", "arguments": {"question": "q", "choices": ["only one"]}},
		{"name": "perform", "arguments": {"action": "fly", "seconds": 1}},
		{"name": "nope", "arguments": {}},
	]
	for params: Dictionary in cases:
		var reply: Dictionary = await protocol.handle_payload(_rpc(1, "tools/call", params), {})
		check(reply.has("result") and reply["result"]["isError"] == true, "%s is reported as isError" % JSON.stringify(params))


func test_protocol_errors() -> void:
	var protocol: McpProtocol = _protocol()
	eq((await protocol.handle_payload(_rpc(1, "does/not/exist"), {}))["error"]["code"], McpProtocol.ERR_METHOD_NOT_FOUND, "unknown method")
	eq((await protocol.handle_payload(_rpc(1, "tools/call", {}), {}))["error"]["code"], McpProtocol.ERR_INVALID_PARAMS, "missing tool name")
	eq((await protocol.handle_payload([], {}))["error"]["code"], McpProtocol.ERR_INVALID_REQUEST, "empty batch")
	eq((await protocol.handle_payload(5, {}))["error"]["code"], McpProtocol.ERR_INVALID_REQUEST, "non-object")
	eq(await protocol.handle_payload({"jsonrpc": "2.0", "method": "notifications/initialized"}, {}), null, "notifications get no reply")
	eq((await protocol.handle_payload(_rpc("abc", "ping"), {}))["id"], "abc", "string ids are echoed")


func test_batches() -> void:
	var reply: Variant = await _protocol().handle_payload([_rpc(1, "ping"), {"jsonrpc": "2.0", "method": "notifications/x"}, _rpc(2, "tools/list")], {})
	check(reply is Array and reply.size() == 2, "a batch answers each request but not the notification")


# --- HTTP (real loopback sockets) ---------------------------------------------------------------

func _start(token: String = "") -> Dictionary:
	var hub: NotificationManager = NotificationManager.new()
	var server: McpHttpServer = McpHttpServer.new()
	server.protocol = McpProtocol.new(McpTools.new(hub))
	server.auth_token = token
	tree.root.add_child(hub)
	tree.root.add_child(server)
	var err: Error = server.start(0)
	check(err == OK, "server should listen (%s)" % error_string(err))
	return {"hub": hub, "server": server, "port": server.port()}


func _stop(env: Dictionary) -> void:
	env["server"].stop()
	env["server"].queue_free()
	env["hub"].queue_free()


func _connect(port: int) -> StreamPeerTCP:
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", port)
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await tree.process_frame
	return peer


## Reads one HTTP response from `peer`.
func _read_response(peer: StreamPeerTCP, timeout_msec: int = 5000) -> Dictionary:
	var buf: PackedByteArray = PackedByteArray()
	var deadline: int = Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		var available: int = peer.get_available_bytes()
		if available > 0:
			buf.append_array(peer.get_data(available)[1])
		var text: String = buf.get_string_from_utf8()
		var split: int = text.find("\r\n\r\n")
		if split >= 0:
			var head: String = text.substr(0, split)
			var length: int = 0
			var headers: Dictionary = {}
			for line: String in head.split("\r\n").slice(1):
				var colon: int = line.find(":")
				headers[line.substr(0, colon).to_lower()] = line.substr(colon + 1).strip_edges()
			length = int(headers.get("content-length", "0"))
			var body: PackedByteArray = buf.slice(split + 4)
			if body.size() >= length:
				return {"status": int(head.split(" ")[1]), "headers": headers, "body": body.get_string_from_utf8()}
		await tree.process_frame
	return {"status": 0, "headers": {}, "body": ""}


func _raw_post(body: String, headers: Dictionary = {}, host: String = "127.0.0.1:7464") -> String:
	var lines: PackedStringArray = PackedStringArray(["POST /mcp HTTP/1.1", "Host: " + host,
		"Content-Type: application/json", "Content-Length: %d" % body.to_utf8_buffer().size()])
	for key: Variant in headers:
		lines.append("%s: %s" % [key, headers[key]])
	return "\r\n".join(lines) + "\r\n\r\n" + body


func _send(port: int, raw: String) -> Dictionary:
	var peer: StreamPeerTCP = await _connect(port)
	peer.put_data(raw.to_utf8_buffer())
	var response: Dictionary = await _read_response(peer)
	peer.disconnect_from_host()
	return response


func test_http_handshake_and_tool_call() -> void:
	var env: Dictionary = _start()
	var port: int = env["port"]
	var hub: NotificationManager = env["hub"]

	var init: Dictionary = await _send(port, _raw_post(JSON.stringify(INIT_BODY)))
	eq(init["status"], 200, "initialize -> 200")
	check(init["headers"]["content-type"].begins_with("application/json"), "JSON content type")
	var session: String = init["headers"].get("mcp-session-id", "")
	check(session.length() >= 16, "a session id is issued")
	eq(JSON.parse_string(init["body"])["result"]["serverInfo"]["name"], "pingpal", "initialize body")

	var note: Dictionary = await _send(port, _raw_post('{"jsonrpc":"2.0","method":"notifications/initialized"}', {"Mcp-Session-Id": session}))
	eq(note["status"], 202, "notification -> 202 Accepted")

	var list: Dictionary = await _send(port, _raw_post('{"jsonrpc":"2.0","id":2,"method":"tools/list"}', {"Mcp-Session-Id": session}))
	eq(JSON.parse_string(list["body"])["result"]["tools"].size(), 5, "tools/list over HTTP")

	var call: Dictionary = await _send(port, _raw_post(JSON.stringify(_rpc(3, "tools/call",
		{"name": "notify", "arguments": {"text": "over the wire", "mood": "excited"}})), {"Mcp-Session-Id": session}))
	eq(call["status"], 200, "tools/call -> 200")
	eq(JSON.parse_string(call["body"])["result"]["isError"], false, "tool succeeded")
	eq(hub.history.size(), 1, "the hub got the notice")
	eq(hub.history[0].source.display_name, "Claude Code", "attributed to the session's client")
	_stop(env)


func test_http_keep_alive_and_chunked_bodies() -> void:
	var env: Dictionary = _start()
	var peer: StreamPeerTCP = await _connect(env["port"])
	peer.put_data(_raw_post('{"jsonrpc":"2.0","id":1,"method":"ping"}').to_utf8_buffer())
	eq((await _read_response(peer))["status"], 200, "first request")
	peer.put_data(_raw_post('{"jsonrpc":"2.0","id":2,"method":"ping"}').to_utf8_buffer())
	eq((await _read_response(peer))["status"], 200, "second request on the same connection")

	var body: String = '{"jsonrpc":"2.0","id":3,"method":"ping"}'
	var chunked: String = "POST /mcp HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n" \
		+ "%x\r\n%s\r\n" % [10, body.substr(0, 10)] + "%x\r\n%s\r\n0\r\n\r\n" % [body.length() - 10, body.substr(10)]
	peer.put_data(chunked.to_utf8_buffer())
	var response: Dictionary = await _read_response(peer)
	eq(response["status"], 200, "chunked request is understood")
	eq(JSON.parse_string(response["body"])["id"], 3, "and answered")
	peer.disconnect_from_host()
	_stop(env)


func test_http_split_packets() -> void:
	var env: Dictionary = _start()
	var peer: StreamPeerTCP = await _connect(env["port"])
	var raw: String = _raw_post('{"jsonrpc":"2.0","id":9,"method":"ping"}')
	peer.put_data(raw.substr(0, 20).to_utf8_buffer())
	await wait_frames(3)
	peer.put_data(raw.substr(20, 40).to_utf8_buffer())
	await wait_frames(3)
	peer.put_data(raw.substr(60).to_utf8_buffer())
	eq((await _read_response(peer))["status"], 200, "a request dribbled in pieces is handled")
	peer.disconnect_from_host()
	_stop(env)


func test_http_rejects_bad_requests() -> void:
	var env: Dictionary = _start()
	var port: int = env["port"]
	eq((await _send(port, _raw_post("{not json")))["status"], 400, "bad JSON -> 400")
	eq((await _send(port, "GET /mcp HTTP/1.1\r\nHost: localhost\r\n\r\n"))["status"], 405, "GET -> 405 (no SSE stream)")
	eq((await _send(port, "GET /nope HTTP/1.1\r\nHost: localhost\r\n\r\n"))["status"], 404, "unknown path -> 404")
	eq((await _send(port, _raw_post("{}", {"Origin": "https://evil.example"})))["status"], 403, "foreign Origin -> 403")
	eq((await _send(port, _raw_post("{}", {}, "evil.example")))["status"], 403, "foreign Host -> 403 (DNS rebinding)")
	eq((await _send(port, _raw_post("{}", {"MCP-Protocol-Version": "1999-01-01"})))["status"], 400, "unsupported protocol header -> 400")
	eq((await _send(port, _raw_post('{"jsonrpc":"2.0","id":1,"method":"ping"}', {"Origin": "http://localhost:3000"})))["status"], 200, "localhost Origin is fine")
	eq((await _send(port, "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n"))["status"], 200, "health check")
	eq((await _send(port, "garbage\r\n\r\n"))["status"], 400, "garbage -> 400")
	_stop(env)


func test_http_bearer_token() -> void:
	var env: Dictionary = _start("s3cret")
	var port: int = env["port"]
	eq((await _send(port, _raw_post('{"jsonrpc":"2.0","id":1,"method":"ping"}')))["status"], 401, "no token -> 401")
	eq((await _send(port, _raw_post('{"jsonrpc":"2.0","id":1,"method":"ping"}', {"Authorization": "Bearer wrong"})))["status"], 401, "wrong token -> 401")
	eq((await _send(port, _raw_post('{"jsonrpc":"2.0","id":1,"method":"ping"}', {"Authorization": "Bearer s3cret"})))["status"], 200, "right token -> 200")
	_stop(env)


func test_http_ask_blocks_until_the_human_answers() -> void:
	var env: Dictionary = _start()
	var hub: NotificationManager = env["hub"]
	var peer: StreamPeerTCP = await _connect(env["port"])
	var call: Dictionary = _rpc(1, "tools/call", {"name": "ask", "arguments": {"source": "Claude", "question": "Deploy?", "choices": ["Ship", "Wait"]}})
	peer.put_data(_raw_post(JSON.stringify(call)).to_utf8_buffer())
	await wait_frames(10)
	eq(hub.pending_asks().size(), 1, "the question reached the screen")
	# Meanwhile other clients are still served.
	eq((await _send(env["port"], _raw_post('{"jsonrpc":"2.0","id":2,"method":"ping"}')))["status"], 200, "server stays responsive while a question is open")
	hub.answer_ask(hub.pending_asks()[0].id, 0)
	var response: Dictionary = await _read_response(peer)
	eq(response["status"], 200, "the held request completes")
	var result: Dictionary = JSON.parse_string(JSON.parse_string(response["body"])["result"]["content"][0]["text"])
	eq(result["choice"], "Ship", "with the human's choice")
	peer.disconnect_from_host()
	_stop(env)


func test_http_ask_is_withdrawn_when_the_client_hangs_up() -> void:
	var env: Dictionary = _start()
	var hub: NotificationManager = env["hub"]
	var server: McpHttpServer = env["server"]
	server.connection_closed.connect(hub.cancel_asks_owned_by)
	var peer: StreamPeerTCP = await _connect(env["port"])
	var call: Dictionary = _rpc(1, "tools/call", {"name": "ask", "arguments": {"question": "Deploy?"}})
	peer.put_data(_raw_post(JSON.stringify(call)).to_utf8_buffer())
	await wait_frames(10)
	eq(hub.pending_asks().size(), 1, "question is up")
	peer.disconnect_from_host()
	await wait_frames(20)
	eq(hub.pending_asks().size(), 0, "hanging up withdraws it")
	_stop(env)
