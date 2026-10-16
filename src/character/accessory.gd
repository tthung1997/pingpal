class_name Accessory
extends Node2D
## A small hat/bow/antenna drawn on the character's head while a bubble from a source is up, so
## "who is talking" reads at a glance. Drawn with primitives so it works on any character pack.
## Local origin is the top of the head; units are art pixels (the parent scales them).

var _color: Color = Color.WHITE
var _kind: StringName = &"cap"


func show_for(source: SourceInfo) -> void:
	if source == null:
		visible = false
		return
	_color = source.color
	_kind = source.accessory
	visible = true
	queue_redraw()


func _draw() -> void:
	var dark: Color = _color.darkened(0.45)
	match _kind:
		&"cap":
			draw_rect(Rect2(-5, -4, 10, 4), _color)
			draw_rect(Rect2(-5, 0, 13, 1), dark)
		&"bow":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(-6, -5), Vector2(-6, 1)]), _color)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(6, -5), Vector2(6, 1)]), _color)
			draw_rect(Rect2(-1.5, -3.5, 3, 3), dark)
		&"antenna":
			draw_line(Vector2(0, 1), Vector2(0, -6), dark, 1.0)
			draw_circle(Vector2(0, -7), 2.5, _color)
		&"halo":
			draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.0, 0.35))
			draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 24, _color, 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"crown":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, 0), Vector2(-5, -5), Vector2(-2.5, -2.5), Vector2(0, -6),
				Vector2(2.5, -2.5), Vector2(5, -5), Vector2(5, 0)]), _color)
			draw_rect(Rect2(-5, -1, 10, 1), dark)
		&"leaf":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 0), Vector2(4, -3), Vector2(0, -8), Vector2(-4, -3)]), _color)
			draw_line(Vector2(0, 0), Vector2(0, -6), dark, 1.0)
