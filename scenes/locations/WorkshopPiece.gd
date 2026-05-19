@tool
extends Control
class_name WorkshopPiece

const SHADOW_MODULATE: Color = Color(1, 1, 1, 0.5)

@export var item_id: StringName = &""
@export var segment_id: StringName = &""

@export var texture: Texture2D:
	set(value):
		texture = value
		if texture and size == Vector2.ZERO:
			size = texture.get_size()
		queue_redraw()

@export var shadow_texture: Texture2D:
	set(value):
		shadow_texture = value
		queue_redraw()

@export_group("Offsets & Drawing")
## Use this to slide the texture around independently of the bounding box!
## With the new hitbox_rect below you can usually leave this at ZERO — it's
## only here for legacy nudging / artistic offsets.
@export var visual_offset: Vector2 = Vector2.ZERO:
	set(value):
		# Intercept and sanitize any nulls the editor tries to inject
		visual_offset = value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO
		queue_redraw()

@export var shadow_offset: Vector2 = Vector2.ZERO:
	set(value):
		shadow_offset = value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO
		queue_redraw()

## If true, ignores visual_offset and perfectly centers the image in the box.
@export var auto_center: bool = false:
	set(value):
		auto_center = value
		queue_redraw()

@export_group("Hitbox")
## The clickable region of this piece, in LOCAL coordinates (relative to
## this Control's top-left). Use this to tighten the click target around
## the non-transparent pixels of the texture WITHOUT touching the
## texture's position. Leave at the default Rect2() (size == 0,0) to fall
## back to the full Control rect — that preserves the old behavior so any
## piece you haven't tuned yet still works exactly like before.
##
## How to use:
##  1. Place all pieces layered on top of each other so they're perfectly
##     aligned. DO NOT touch position or visual_offset.
##  2. Select a piece in the editor.
##  3. Either click "Auto-Fit Hitbox To Texture" to snap the hitbox to
##     the texture's non-transparent bounds, or drag the values in this
##     Rect2 to tune by hand.
##  4. Turn on debug_draw_hitbox to see the box in-editor.
@export var hitbox_rect: Rect2 = Rect2():
	set(value):
		hitbox_rect = value if typeof(value) == TYPE_RECT2 else Rect2()
		queue_redraw()

## Show the hitbox as a colored outline in the editor and at runtime
## (useful while you're tuning; turn off for release).
@export var debug_draw_hitbox: bool = false:
	set(value):
		debug_draw_hitbox = value
		queue_redraw()

## Editor-only button: when toggled true, snap hitbox_rect to the
## non-transparent pixels of `texture` (in local coords, accounting for
## visual_offset / auto_center). Resets itself to false so it acts like
## a one-shot button.
@export var auto_fit_hitbox: bool = false:
	set(value):
		if value:
			_auto_fit_hitbox_to_texture()
		# Always leave the toggle off so it behaves like a button.
		auto_fit_hitbox = false

var piece_offset: Vector2 = Vector2.ZERO
var home_parent: Control = null
var locked: bool = false

var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Failsafes to guarantee we always have a valid Vector2 even if a null slipped through
	var v_off: Vector2 = visual_offset if typeof(visual_offset) == TYPE_VECTOR2 else Vector2.ZERO
	var s_off: Vector2 = shadow_offset if typeof(shadow_offset) == TYPE_VECTOR2 else Vector2.ZERO

	var tex_pos: Vector2 = v_off
	if auto_center and texture:
		tex_pos = (size - texture.get_size()) / 2.0

	if shadow_texture:
		var s_pos: Vector2 = tex_pos
		if auto_center:
			s_pos = (size - shadow_texture.get_size()) / 2.0
		draw_texture(shadow_texture, s_pos + s_off, SHADOW_MODULATE)

	if texture:
		draw_texture(texture, tex_pos)

	if debug_draw_hitbox:
		var r: Rect2 = _effective_local_hitbox()
		# Filled tint
		draw_rect(r, Color(0.2, 0.7, 1.0, 0.25), true)
		# Outline
		draw_rect(r, Color(0.1, 0.5, 1.0, 0.9), false, 1.0)


## Returns the hitbox in LOCAL coords. Falls back to the full Control rect
## when hitbox_rect hasn't been customized (size == 0,0).
func _effective_local_hitbox() -> Rect2:
	if hitbox_rect.size.x > 0.0 and hitbox_rect.size.y > 0.0:
		return hitbox_rect
	return Rect2(Vector2.ZERO, size)


## The hitbox transformed into global coords. Used by hit_test and by
## the drop slot if it wants tight checks. Cheaper than building a full
## Transform2D for what we need.
func get_global_hitbox() -> Rect2:
	var local: Rect2 = _effective_local_hitbox()
	var origin: Vector2 = get_global_transform().origin
	# Apply scale from global transform so this stays correct under
	# CanvasLayer/parent scaling (the WorkshopMinigame upscales).
	var xform: Transform2D = get_global_transform()
	var top_left: Vector2 = xform * local.position
	var bottom_right: Vector2 = xform * (local.position + local.size)
	return Rect2(top_left, bottom_right - top_left).abs()


func hit_test(global_pos: Vector2) -> bool:
	if locked or not visible or not is_visible_in_tree():
		return false
	return get_global_hitbox().has_point(global_pos)

func start_drag(global_pos: Vector2) -> void:
	_dragging = true
	_grab_offset = global_pos - global_position

func update_drag(global_pos: Vector2) -> void:
	if not _dragging:
		return
	global_position = global_pos - _grab_offset

func end_drag() -> void:
	_dragging = false

func is_dragging() -> bool:
	return _dragging

func place_in(slot: Control, at_position: Vector2) -> void:
	_dragging = false
	if get_parent() != slot:
		_reparent_keeping_global(slot)
	position = at_position

func snap_home() -> void:
	if home_parent == null:
		return
	if get_parent() != home_parent:
		_reparent_keeping_global(home_parent)
	var target: Vector2 = (home_parent.size - size) * 0.5
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, 0.18)

func _reparent_keeping_global(new_parent: Control) -> void:
	var global_pos: Vector2 = global_position
	var current_parent: Node = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	new_parent.add_child(self)
	global_position = global_pos


# -----------------------------------------------------------------------------
# Auto-fit hitbox to non-transparent pixels of the texture.
#
# We read the image data (Image.get_used_rect()) and compute the smallest
# rect that contains every pixel with alpha > 0. We then offset that into
# local coords by wherever the texture is drawn (visual_offset, or
# auto-centered). Result: a tight hitbox you can tweak from there.
# -----------------------------------------------------------------------------
func _auto_fit_hitbox_to_texture() -> void:
	if texture == null:
		push_warning("WorkshopPiece: auto_fit_hitbox pressed but no texture set.")
		return

	var img: Image = texture.get_image()
	if img == null:
		push_warning("WorkshopPiece: texture has no image data (is it imported as compressed without 'Detect 3D'? Try keeping it as Lossless or check 'Keep Image On Import').")
		return

	# In Godot 4, Image.get_used_rect() returns the smallest rect of
	# pixels with alpha > 0. For a fully-opaque image this is the whole
	# image; for textures with transparent borders (yours) it's the tight
	# bounding box around the visible art.
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		push_warning("WorkshopPiece: texture appears to be fully transparent — can't auto-fit.")
		return

	# Where the texture is actually drawn, in local coords:
	var tex_pos: Vector2 = visual_offset
	if auto_center:
		tex_pos = (size - texture.get_size()) / 2.0

	hitbox_rect = Rect2(
		tex_pos + Vector2(used.position),
		Vector2(used.size)
	)
	queue_redraw()
