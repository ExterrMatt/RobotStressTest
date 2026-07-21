@tool
extends Control

signal configuration_changed

enum ClickAction {
	TOGGLE_VISIBILITY,
	PRIME_THEN_PLAY_ANIMATION,
}

## Stroke width of the hover border, in this control's local pixels.
@export var border_width: float = 2.0:
	set(value):
		border_width = value
		queue_redraw()

## Border color while hovered.
@export var border_color: Color = Color(1, 1, 1, 1):
	set(value):
		border_color = value
		queue_redraw()

## Drawn always when true, regardless of the hover state.
@export var force_visible: bool = false:
	set(value):
		force_visible = value
		queue_redraw()

## Draw the border while hovered or force-visible.
@export var show_border: bool = false:
	set(value):
		show_border = value
		_emit_configuration_changed()

## Larger priorities win when multiple active boxes affect the same node.
@export var priority: int = 0:
	set(value):
		priority = value
		_emit_configuration_changed()

## How the robot should treat clicks on this box.
@export var click_action: ClickAction = ClickAction.TOGGLE_VISIBILITY:
	set(value):
		click_action = value
		_emit_configuration_changed()

@export_multiline var hover_description: String = ""

## Runtime starts with this hover effect already active.
@export var active_by_default: bool = false:
	set(value):
		active_by_default = value
		_emit_configuration_changed()

@export_group("Editor Preview")
## Toggle this in the editor to preview this box's active visual state.
@export var editor_preview_active: bool = false:
	set(value):
		editor_preview_active = value
		_emit_configuration_changed()

## When previewing an animated box, show its loop frame instead of intro frame 0.
@export var editor_preview_loop_animation: bool = false:
	set(value):
		editor_preview_loop_animation = value
		_emit_configuration_changed()

@export_group("Visibility")
## Image nodes to hide while this box's effect is active.
## Paths are resolved from the robot/root node that owns the hover box.
@export var hidden_while_active_image_paths: Array[NodePath] = []:
	set(value):
		hidden_while_active_image_paths = value
		_emit_configuration_changed()

## Image nodes to show while this box's effect is active.
## Paths are resolved from the robot/root node that owns the hover box.
@export var shown_while_active_image_paths: Array[NodePath] = []:
	set(value):
		shown_while_active_image_paths = value
		_emit_configuration_changed()

@export_group("Layered Animation")
## Sprite2D nodes for the intro strip, in left-to-right column order.
@export var intro_animation_nodes: Array[NodePath] = []:
	set(value):
		intro_animation_nodes = value
		_emit_configuration_changed()

## Sprite2D nodes for the looping strip, in left-to-right column order.
@export var loop_animation_nodes: Array[NodePath] = []:
	set(value):
		loop_animation_nodes = value
		_emit_configuration_changed()

## Sprite2D nodes for the pre-outro strip, in left-to-right column order. When
## set, lowering the head from the loop plays this strip pre_outro_repeat times
## before the outro strip.
@export var pre_outro_animation_nodes: Array[NodePath] = []:
	set(value):
		pre_outro_animation_nodes = value
		_emit_configuration_changed()

## Sprite2D nodes for the outro strip, in left-to-right column order. Played once
## after the pre-outro repeats, then the animation ends.
@export var outro_animation_nodes: Array[NodePath] = []:
	set(value):
		outro_animation_nodes = value
		_emit_configuration_changed()

@export var animation_frame_size: Vector2i = Vector2i(250, 350):
	set(value):
		animation_frame_size = value
		_emit_configuration_changed()

@export_range(0.1, 60.0, 0.1) var animation_fps: float = 12.0
@export_range(1, 256, 1) var intro_frame_count: int = 1
@export_range(1, 256, 1) var loop_frame_count: int = 1
@export_range(1, 256, 1) var pre_outro_frame_count: int = 1
@export_range(1, 256, 1) var outro_frame_count: int = 1
## How many times the pre-outro strip plays before the outro strip.
@export_range(1, 16, 1) var pre_outro_repeat: int = 3
@export var loop_after_intro: bool = true

var _hovered: bool = false
var _runtime_active: bool = false


func _ready() -> void:
	_runtime_active = active_by_default
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	queue_redraw()


func set_runtime_active(value: bool) -> void:
	if _runtime_active == value:
		return
	_runtime_active = value


func toggle_runtime_active() -> void:
	set_runtime_active(not _runtime_active)


func is_effect_active() -> bool:
	if Engine.is_editor_hint():
		return editor_preview_active
	return _runtime_active


func has_image_toggle() -> bool:
	return not hidden_while_active_image_paths.is_empty() \
		or not shown_while_active_image_paths.is_empty() \
		or not intro_animation_nodes.is_empty() \
		or not loop_animation_nodes.is_empty()


func has_layered_animation() -> bool:
	return not intro_animation_nodes.is_empty() or not loop_animation_nodes.is_empty()


func get_all_managed_paths() -> Array[NodePath]:
	var merged: Array[NodePath] = []
	_append_unique_paths(merged, hidden_while_active_image_paths)
	_append_unique_paths(merged, shown_while_active_image_paths)
	_append_unique_paths(merged, intro_animation_nodes)
	_append_unique_paths(merged, loop_animation_nodes)
	_append_unique_paths(merged, pre_outro_animation_nodes)
	_append_unique_paths(merged, outro_animation_nodes)
	return merged


func has_outro() -> bool:
	return not outro_animation_nodes.is_empty() or not pre_outro_animation_nodes.is_empty()


func get_animation_phase_paths(phase: String) -> Array[NodePath]:
	if phase == "pre_outro" and not pre_outro_animation_nodes.is_empty():
		return pre_outro_animation_nodes
	if phase == "outro" and not outro_animation_nodes.is_empty():
		return outro_animation_nodes
	if phase == "loop" and not loop_animation_nodes.is_empty():
		return loop_animation_nodes
	return intro_animation_nodes


## Legacy compatibility: the robot now owns visibility resolution.
func toggle_images(_root: Node) -> bool:
	if not has_image_toggle():
		return false
	toggle_runtime_active()
	return true


func _append_unique_paths(target: Array[NodePath], paths: Array[NodePath]) -> void:
	for path in paths:
		if not target.has(path):
			target.append(path)


func _emit_configuration_changed() -> void:
	if is_inside_tree():
		configuration_changed.emit()
	queue_redraw()


func _draw() -> void:
	if not show_border:
		return
	if not (_hovered or force_visible):
		return
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
