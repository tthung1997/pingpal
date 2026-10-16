class_name McpSchema
extends RefCounted
## A small validator for the JSON Schema subset PingPal's tool definitions use (object, string,
## integer, number, boolean, array; enum, min/max, lengths, required, default). The tool schema
## is the single source of truth: it is what clients see in `tools/list` and what we enforce.


## Returns an error message, or "" when `value` satisfies `schema`.
static func validate(value: Variant, schema: Dictionary, path: String = "arguments") -> String:
	var type: String = str(schema.get("type", ""))
	match type:
		"object":
			if not value is Dictionary:
				return "%s must be an object" % path
			var properties: Dictionary = schema.get("properties", {})
			for required: String in schema.get("required", []):
				if not value.has(required) or value[required] == null:
					return "%s.%s is required" % [path, required]
			for key: Variant in value:
				if properties.has(key):
					var error: String = validate(value[key], properties[key], "%s.%s" % [path, key])
					if not error.is_empty():
						return error
		"string":
			if not value is String and not value is StringName:
				return "%s must be a string" % path
			var text: String = str(value)
			if schema.has("maxLength") and text.length() > int(schema["maxLength"]):
				return "%s must be at most %d characters" % [path, int(schema["maxLength"])]
			if schema.has("minLength") and text.strip_edges().length() < int(schema["minLength"]):
				return "%s must not be empty" % path
		"integer", "number":
			if not (value is int or value is float):
				return "%s must be a number" % path
			if type == "integer" and float(value) != floorf(float(value)):
				return "%s must be an integer" % path
			if schema.has("minimum") and float(value) < float(schema["minimum"]):
				return "%s must be >= %s" % [path, schema["minimum"]]
			if schema.has("maximum") and float(value) > float(schema["maximum"]):
				return "%s must be <= %s" % [path, schema["maximum"]]
		"boolean":
			if not value is bool:
				return "%s must be a boolean" % path
		"array":
			if not value is Array:
				return "%s must be an array" % path
			if schema.has("minItems") and value.size() < int(schema["minItems"]):
				return "%s needs at least %d items" % [path, int(schema["minItems"])]
			if schema.has("maxItems") and value.size() > int(schema["maxItems"]):
				return "%s allows at most %d items" % [path, int(schema["maxItems"])]
			if schema.has("items"):
				for index: int in value.size():
					var error: String = validate(value[index], schema["items"], "%s[%d]" % [path, index])
					if not error.is_empty():
						return error
	if schema.has("enum") and not (schema["enum"] as Array).has(str(value) if type == "string" else value):
		return "%s must be one of: %s" % [path, ", ".join(PackedStringArray(schema["enum"]))]
	return ""


## Copies `args` and fills in the schema's `default`s for missing properties.
static func with_defaults(args: Dictionary, schema: Dictionary) -> Dictionary:
	var result: Dictionary = args.duplicate()
	var properties: Dictionary = schema.get("properties", {})
	for key: String in properties:
		if not result.has(key) or result[key] == null:
			if properties[key].has("default"):
				result[key] = properties[key]["default"]
	return result
