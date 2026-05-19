extends Control
class_name WorkshopPiece
## A draggable workshop piece — either an ingredient sitting in the
## tray / craft bin, or a leg-segment piece waiting to be placed on the
## assembly side.
##
## INPUT MODEL — important.
##
## We are reparented under SceneImage via Main.show_scene_overlay(). That
## sits at the bottom of a deep chain of PanelContainers, each with
## mouse_filter = STOP by default. Control's _gui_input routing dies in
## that chain, so we can't rely on it — neither for press nor release.
## This is the same problem Store.gd hit and solved by listening on
## _input (the global pipe) and hit-testing against global rects.
##
## Following that pattern: WorkshopPiece is purely visual. It exposes
## start_drag() / update_drag() / end_drag() methods that the host
## WorkshopMinigame calls from its own _input handler. No _gui_input,
## no _process tracking — everything is driven from outside.
##
## SHADOW MODEL — self_modulate vs modulate.
##
## Each shadow is rendered at self_modulate Color(1,1,1,0.5). That makes
## the shadow draw at 50% alpha against the background. Overlapping
## shadows don't compound their darkness in their intersection — both
## composite against the background at 50%, independently. modulate
## would multiply down to children, which would double-up. self_modulate
## is applied to this node's own draw, not propagated.

const SHADOW_MODULATE: Color = Color(1, 1, 1, 0.5)


## Identifier for THIS piece. Used inside the craft bin so the player can
## pick up an individual ingredient by name, and as the "piece id" inside
## a segment.
@export var item_id: StringName = &""

## If this piece is part of a multi-image leg segment, this is that
## segment's id. The assembly slot matches against this. Ingredients
## leave it empty.
@export var segment_id: StringName = &""

@export var texture: Texture2D
@export var shadow_texture: Texture2D

## Where the SPRITE is offset from this Control's top-left when placed
## into an assembly slot, so each piece of a multi-image segment can
## sit at its authored relative position. In the bin / tray this is 0.
var piece_offset: Vector2 = Vector2.ZERO

## Extra offset for the shadow, on top of piece_offset.
var shadow_offset: Vector2 = Vector2.ZERO

## Where to fly back to if the drop is invalid.
var home_parent: Control = null

## When true, can no longer be picked up. Set after placement.
var locked: bool = false


# --- internals ---

var _dragging: bool = false
## Offset from the piece's top-left to where the player grabbed it,
## in the piece's parent's local coords at grab time. We preserve this
## while dragging so the sprite doesn't jump to center under the cursor.
var _grab_offset: Vector2 = Vector2.ZERO

# Child rects cached so we don't find_child every frame.
var _sprite_rect: TextureRect = null
var _shadow_rect: TextureRect = null


func _ready() -> void:
	# IGNORE — we don't use Control routing at all. The host does
	# hit-testing against our global rect.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Build the shadow underneath, sprite on top.
	if shadow_texture:
		_shadow_rect = TextureRect.new()
		_shadow_rect.texture = shadow_texture
		_shadow_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shadow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow_rect.self_modulate = SHADOW_MODULATE
		add_child(_shadow_rect)

	if texture:
		_sprite_rect = TextureRect.new()
		_sprite_rect.texture = texture
		_sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sprite_rect)

	if texture and size == Vector2.ZERO:
		size = texture.get_size()
	_layout_children()


# --- external drag interface (called by WorkshopMinigame._input) ---

## Returns true if a left-press at `global_pos` should pick this piece
## up. The host calls this on every piece in z-order on click.
func hit_test(global_pos: Vector2) -> bool:
	if locked or not visible or not is_visible_in_tree():
		return false
	return get_global_rect().has_point(global_pos)


## Begin dragging. The host has already reparented us to whatever node
## should host the drag (the minigame root, typically) — we just record
## the grab offset so update_drag() can keep us under the cursor.
func start_drag(global_pos: Vector2) -> void:
	_dragging = true
	# get_local_mouse_position uses the current mouse; we want the
	# specific click point that was passed in. Compute equivalent in
	# our own local coords.
	_grab_offset = global_pos - global_position


func update_drag(global_pos: Vector2) -> void:
	if not _dragging:
		return
	# Place our top-left so the cursor stays at _grab_offset within us.
	# This works in global coords; setting global_position is fine even
	# under nested parents because Control handles the transform math.
	global_position = global_pos - _grab_offset


func end_drag() -> void:
	_dragging = false


func is_dragging() -> bool:
	return _dragging


# --- placement helpers ---

## Lock the piece at a fixed local position inside `slot`.
func place_in(slot: Control, at_position: Vector2) -> void:
	_dragging = false
	if get_parent() != slot:
		_reparent_keeping_global(slot)
	position = at_position


## Tween back to `home_parent`'s center. Used when a drop is invalid.
func snap_home() -> void:
	if home_parent == null:
		return
	if get_parent() != home_parent:
		_reparent_keeping_global(home_parent)
	var target: Vector2 = (home_parent.size - size) * 0.5
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, 0.18)


# --- internals ---

func _layout_children() -> void:
	if _sprite_rect:
		_sprite_rect.position = Vector2.ZERO
		_sprite_rect.size = size

	if _shadow_rect:
		_shadow_rect.position = shadow_offset
		_shadow_rect.size = size


func _reparent_keeping_global(new_parent: Control) -> void:
	var global_pos: Vector2 = global_position
	var current_parent: Node = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	new_parent.add_child(self)
	global_position = global_pos
