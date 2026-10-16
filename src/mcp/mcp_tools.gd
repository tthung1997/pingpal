class_name McpTools
extends RefCounted
## The MCP tools PingPal exposes and what each does to the NotificationManager.
##
## Tool results follow MCP: {content: [{type: "text", text: ...}], isError}. Argument problems are
## reported as isError results (not protocol errors) so the calling model can read and fix them.

const SOURCE_SCHEMA: Dictionary = {
	"type": "string",
	"maxLength": 80,
	"description": "Who you are, e.g. 'Claude Code', 'Copilot', 'Codex'. Optional: defaults to your MCP client name. Add a short suffix to tell parallel agents apart, e.g. 'Claude Code · api'. Keep it stable between calls.",
}
const PRIORITIES: Array = ["low", "normal", "high", "urgent"]
const STATUSES: Array = ["working", "done", "needs_input", "error", "idle"]

var hub: NotificationManager


func _init(p_hub: NotificationManager = null) -> void:
	hub = p_hub


func definitions() -> Array:
	return [
		{
			"name": "notify",
			"title": "Show a short message",
			"description": "Make the character say something in a speech bubble and get the user's attention. Use for brief, glanceable updates (a sentence, under ~100 characters). Don't narrate every step.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"source": SOURCE_SCHEMA,
					"text": {"type": "string", "minLength": 1, "maxLength": 280, "description": "What to say. Short and friendly."},
					"priority": {"type": "string", "enum": PRIORITIES, "default": "normal", "description": "low: batched and brief. normal: queued. high: jumps the queue. urgent: interrupts whatever is showing; use rarely."},
				},
				"required": ["text"],
			},
			"annotations": {"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		},
		{
			"name": "set_state",
			"title": "Set your status",
			"description": "Report what you are doing so it shows in the status tray. Call with 'working' when you start a long task and 'done' when it finishes. Use 'needs_input' when blocked on the human, 'error' when something failed, 'idle' to clear yourself. Cheaper and less noisy than notify.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"source": SOURCE_SCHEMA,
					"status": {"type": "string", "enum": STATUSES, "description": "working | done | needs_input | error | idle"},
					"text": {"type": "string", "maxLength": 280, "description": "Optional one-line detail, shown for done / needs_input / error."},
				},
				"required": ["status"],
			},
			"annotations": {"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		},
		{
			"name": "ask",
			"title": "Ask the human a quick question",
			"description": "Show a question with 2-4 buttons and wait for the human to click one. Returns {answered, choice, index}, or {answered: false, reason} if it times out or is dismissed. Only for genuine decisions; the human may not be at the screen, so keep timeout_seconds modest and have a fallback.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"source": SOURCE_SCHEMA,
					"question": {"type": "string", "minLength": 1, "maxLength": 280},
					"choices": {"type": "array", "minItems": 2, "maxItems": 4, "items": {"type": "string", "minLength": 1, "maxLength": 40}, "default": ["Yes", "No"]},
					"timeout_seconds": {"type": "integer", "minimum": 5, "maximum": 600, "default": 45, "description": "How long to wait for an answer."},
				},
				"required": ["question"],
			},
			"annotations": {"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		},
		{
			"name": "clear",
			"title": "Clear messages and status",
			"description": "Remove your queued messages, bubble, pending questions and tray status. Pass all=true to clear every source.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"source": SOURCE_SCHEMA,
					"all": {"type": "boolean", "default": false, "description": "Clear every source, not just yours."},
				},
			},
			"annotations": {"readOnlyHint": false, "destructiveHint": true, "idempotentHint": true, "openWorldHint": false},
		},
	]


## Runs a tool. `ctx` carries {client_name, conn_id}. Always returns an MCP tool result.
func call_tool(tool_name: String, arguments: Dictionary, ctx: Dictionary) -> Dictionary:
	var schema: Dictionary = _schema_for(tool_name)
	if schema.is_empty():
		return _fail("Unknown tool '%s'" % tool_name)
	var problem: String = McpSchema.validate(arguments, schema)
	if not problem.is_empty():
		return _fail(problem)
	var args: Dictionary = McpSchema.with_defaults(arguments, schema)
	var source: String = _source(args, ctx)
	match tool_name:
		"notify":
			var priority: Notice.Priority = PRIORITIES.find(args["priority"]) as Notice.Priority
			return _ok(hub.notify(source, str(args["text"]), priority))
		"set_state":
			var result: Dictionary = hub.set_state(source, StringName(args["status"]), str(args.get("text", "")))
			return _fail(result["error"]) if result.has("error") else _ok(result)
		"ask":
			var choices: PackedStringArray = PackedStringArray(args["choices"])
			var answer: Dictionary = await hub.ask(source, str(args["question"]), choices,
				float(args["timeout_seconds"]), int(ctx.get("conn_id", 0)))
			return _ok(answer)
		"clear":
			return _ok(hub.clear("" if bool(args["all"]) else source))
	return _fail("Unknown tool '%s'" % tool_name)


func _schema_for(tool_name: String) -> Dictionary:
	for definition: Dictionary in definitions():
		if definition["name"] == tool_name:
			return definition["inputSchema"]
	return {}


func _source(args: Dictionary, ctx: Dictionary) -> String:
	var explicit: String = str(args.get("source", "")).strip_edges()
	if not explicit.is_empty():
		return explicit
	var client: String = str(ctx.get("client_name", "")).strip_edges()
	return client if not client.is_empty() else "Unknown"


static func _ok(payload: Dictionary) -> Dictionary:
	return {"content": [{"type": "text", "text": JSON.stringify(payload)}], "isError": false}


static func _fail(message: String) -> Dictionary:
	return {"content": [{"type": "text", "text": message}], "isError": true}
