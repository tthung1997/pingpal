class_name CharacterActor
extends Node2D
## Puts a CharacterPack and a CharacterBrain on screen: plays the animation the brain asks for,
## flips to face the direction of travel and adds small procedural effects (hop, jump, spin) so
## even a pack with few animations feels lively.
##
## Origin is the character's feet, so `position` is simply where it stands.

const HOP_HEIGHT: float = 4.0
const JUMP_HEIGHT: float = 11.0
const HOP_SECONDS: float = 0.7
const JUMP_PERIOD: float = 0.6
const SPIN_PERIOD: float = 0.8

var pack: CharacterPack
var brain: CharacterBrain
var floor_y: float = 0.0

var _sprite: AnimatedSprite2D
var _accessory: Accessory
var _animation: StringName = &""
var _effect_time: float = 0.0
var _effect_serial: int = -1


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
	_accessory = Accessory.new()
	_accessory.position = pack.head - pack.anchor
	_accessory.visible = false
	add_child(_accessory)
	_play(brain.anim_state)


func show_accessory(source: SourceInfo) -> void:
	_accessory.show_for(source)


func hide_accessory() -> void:
	_accessory.visible = false


func _process(delta: float) -> void:
	brain.update(delta)
	position = Vector2(brain.x, floor_y)
	_play(brain.anim_state)
	if brain.effect_serial != _effect_serial:
		_effect_serial = brain.effect_serial
		_effect_time = 0.0
	_effect_time += delta
	_apply_effect()


## Where the character occupies the screen, in the parent's coordinates.
func hit_rect() -> Rect2:
	var size: Vector2 = Vector2(pack.frame_size) * scale
	return Rect2(position - pack.anchor * scale, size)


## Top of the head in the parent's coordinates.
func head_point() -> Vector2:
	return position + (pack.head - pack.anchor) * scale


func _play(state: StringName) -> void:
	var animation: StringName = pack.resolve(state)
	if animation == &"" or animation == _animation:
		return
	_animation = animation
	_sprite.play(animation)


func _apply_effect() -> void:
	var lift: float = 0.0
	var squeeze: float = 1.0
	match brain.effect:
		&"hop":
			if _effect_time < HOP_SECONDS:
				lift = absf(sin(_effect_time / (HOP_SECONDS * 0.5) * PI)) * HOP_HEIGHT
		&"jump":
			lift = absf(sin(_effect_time / JUMP_PERIOD * PI)) * JUMP_HEIGHT
		&"spin":
			squeeze = cos(_effect_time / SPIN_PERIOD * TAU * 2.0)
	_sprite.position.y = -lift
	_sprite.scale.x = float(brain.facing) * (squeeze if absf(squeeze) > 0.12 else 0.12)
