class_name CharacterActor
extends Node2D
## Puts a CharacterPack and a CharacterBrain on screen: plays the animation the brain asks for
## and flips to face the direction the user drags it.
##
## Origin is the character's feet, so `position` is simply where it stands.

var pack: CharacterPack
var brain: CharacterBrain
var floor_y: float = 0.0

var _sprite: AnimatedSprite2D
var _animation: StringName = &""


func setup(p_pack: CharacterPack, p_brain: CharacterBrain, pixel_scale: int) -> void:
	pack = p_pack
	brain = p_brain
	scale = Vector2(pixel_scale, pixel_scale)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = pack.frames
	_sprite.centered = false
	_sprite.offset = -pack.anchor
	add_child(_sprite)
	_play(brain.anim_state)


## Hot-swaps the character pack on stage while keeping position and scale.
func set_pack(p_pack: CharacterPack) -> void:
	pack = p_pack
	_sprite.sprite_frames = pack.frames
	_sprite.offset = -pack.anchor
	_animation = &""
	_play(brain.anim_state)


func _process(delta: float) -> void:
	brain.update(delta)
	position = Vector2(brain.x, floor_y)
	_play(brain.anim_state)
	_sprite.scale.x = float(brain.facing)


## Where the character occupies the screen right now, in the parent's coordinates. It follows the
## visible pixels of the current frame, so empty parts of the frame never swallow clicks meant
## for the windows behind.
func hit_rect() -> Rect2:
	var used: Rect2i = pack.used_rect(_sprite.animation, _sprite.frame)
	var left: float = used.position.x - pack.anchor.x
	var right: float = used.end.x - pack.anchor.x
	if brain.facing < 0:
		var flipped: float = -left
		left = -right
		right = flipped
	var top: float = used.position.y - pack.anchor.y
	var bottom: float = used.end.y - pack.anchor.y
	var local: Rect2 = Rect2(left, top, right - left, bottom - top)
	return Rect2(position + local.position * scale, local.size * scale)


## The screen y of the top of the character at rest. Stays put while animations come and go, so
## the tray and bubble above the character do not jump with them.
func rest_top() -> float:
	return position.y + (pack.rest_top() - pack.anchor.y) * scale.y


func _play(state: StringName) -> void:
	var animation: StringName = pack.resolve(state)
	if animation == &"" or animation == _animation:
		return
	_animation = animation
	_sprite.play(animation)
