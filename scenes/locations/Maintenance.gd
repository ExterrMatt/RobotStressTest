extends "res://scenes/locations/StubLocation.gd"
## Maintenance location.
##
## Behaves like the generic StubLocation (title, blurb, outcome buttons),
## but also drops the layered PersonalityTestRobot into the framed scene
## image so the robot appears on top of the maintenance background, using
## the exact same RobotLayer authoring path as PersonalityTraining.
##
## Adds an interactive hover-box over the robot: scans each body-layer
## texture to find the tight rectangle of non-transparent pixels (union
## across layers, shadow excluded), pads it with a configurable buffer,
## and listens for clicks. Clicking zooms the framed scene image so that
## the buffered bounds become the new top/bottom edges of the frame —
## achieved by setting scale + pivot_offset on the SceneImage (whose
## clip_contents is already true in Main.tscn), with no layout changes.
##
## Click routing follows the Store pattern: the location root is set to
## MOUSE_FILTER_IGNORE so it never eats clicks (which otherwise blocks
## the framed corner button from being clickable), and the hover-box
## hit-test is done in _input against its global rect — the SceneImage
## chain is too deep / z-stacked to rely on Control routing alone.

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")

## Pixel buffer added around the detected robot bounding box so the white
## border doesn't sit flush against the artwork. Measured in robot-local
## pixels (textures are 300x450 native, matching the robot Control's base
## size, so this is also "texture pixels"). Tweak in the inspector.
@export var robot_border_buffer: int = 10

## Threshold above which a pixel counts as "non-empty" when scanning the
## robot textures for their tight bounding box. Image.get_used_rect uses
## alpha > 0; we apply this as a secondary cutoff for soft edges.
@export_range(0.0, 1.0, 0.01) var robot_alpha_threshold: float = 0.05

## When true, the hover-border is drawn at all times (not just on hover).
## Flip this on in the inspector to confirm the rectangle's placement
## without having to hover, then flip it back off for the real in-game
## hover-only behavior.
@export var force_show_hover_border: bool = false

@onready var robot_layer: Control = $RobotLayer
@onready var robot: Control = $RobotLayer/PersonalityTestRobot
@onready var margin_container: MarginContainer = $MarginContainer

# Rectangle covering the visible robot pixels in robot-local coords
# (i.e. before the robot's own scale is applied). Cached on _ready since
# computing it scans every body-layer image.
var _robot_bbox_local: Rect2 = Rect2()

var _hover_box: Control = null
var _zoomed: bool = false

# Cached SceneImage state so we can return to the un-zoomed view when
# the player clicks again or leaves the location.
var _scene_image: TextureRect = null
var _default_pivot: Vector2 = Vector2.ZERO
var _default_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	super._ready()

	# Match the Store pattern: the location root spans the whole screen
	# with default STOP filter, which can swallow clicks heading for
	# Main's corner button or for our hover box. IGNORE means we render
	# but never consume input — children that want clicks (the outcome
	# buttons inside MarginContainer) still capture them on their own.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var main: Node = get_tree().current_scene
	if main and main.has_method("show_scene_overlay") and robot_layer:
		# interactive=true so SceneImage stops eating mouse events.
		main.show_scene_overlay(robot_layer, true)

	if main:
		_scene_image = main.get_node_or_null("%SceneImage") as TextureRect
		if _scene_image:
			_default_pivot = _scene_image.pivot_offset
			_default_scale = _scene_image.scale

	# Reparent the StubLocation UI (title, blurb, outcome buttons) on top
	# of SceneImage so they sit inside the picture frame instead of below
	# it in the off-screen area below the maintenance frame.
	_mount_ui_onto_scene_image()

	_robot_bbox_local = _compute_robot_pixel_bbox()
	_spawn_hover_box()


func _exit_tree() -> void:
	# Restore the framed scene image to its neutral transform so the
	# next location starts fresh.
	_reset_zoom()
	# The MarginContainer was reparented onto SceneImage; free it so it
	# doesn't linger across locations.
	if margin_container and is_instance_valid(margin_container) \
			and margin_container.get_parent() != self:
		margin_container.queue_free()


# --- UI relocation ---

func _mount_ui_onto_scene_image() -> void:
	# Lift the StubLocation MarginContainer (which holds title, blurb,
	# and outcome buttons) onto SceneImage so it overlays the framed
	# picture. Anchored full-rect with a high z_index so it sits above
	# the robot artwork.
	if _scene_image == null or margin_container == null:
		return
	var prev_parent: Node = margin_container.get_parent()
	if prev_parent:
		prev_parent.remove_child(margin_container)
	_scene_image.add_child(margin_container)
	margin_container.anchor_left = 0.0
	margin_container.anchor_top = 0.0
	margin_container.anchor_right = 1.0
	margin_container.anchor_bottom = 1.0
	margin_container.offset_left = 0.0
	margin_container.offset_top = 0.0
	margin_container.offset_right = 0.0
	margin_container.offset_bottom = 0.0
	margin_container.z_index = 50
	# Tighter inner margins than the StubLocation default so the buttons
	# fit cleanly inside the smaller picture frame area.
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_top", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_bottom", 24)
	# The MarginContainer and its non-Button descendants would otherwise
	# eat clicks across the whole picture frame at z=51 (z_index 50 +
	# SceneImage's z=1), blocking the corner Back button below. Buttons
	# keep their STOP filter so the outcome buttons still capture clicks.
	_set_passthrough_recursive(margin_container)


func _set_passthrough_recursive(node: Node) -> void:
	if node is Control and not (node is Button):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_passthrough_recursive(child)


# --- bounding-box detection ---

func _compute_robot_pixel_bbox() -> Rect2:
	# Union the opaque-pixel bounds of every body-layer texture (Shadow
	# excluded — it extends past the robot's feet and would inflate the
	# box). Each texture stretches to fill the robot Control's base size,
	# so we map texture pixels to robot-local space via a simple ratio.
	var bounds: Rect2 = Rect2()
	var found_any: bool = false
	for tr in _collect_texture_rects(robot):
		if tr.name == "Shadow":
			continue
		var tex: Texture2D = tr.texture
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		var used: Rect2i = _opaque_bounds(img, robot_alpha_threshold)
		if used.size == Vector2i.ZERO:
			continue
		var sx: float = robot.size.x / float(img.get_width())
		var sy: float = robot.size.y / float(img.get_height())
		var mapped: Rect2 = Rect2(
			used.position.x * sx,
			used.position.y * sy,
			used.size.x * sx,
			used.size.y * sy,
		)
		if not found_any:
			bounds = mapped
			found_any = true
		else:
			bounds = bounds.merge(mapped)
	return bounds


func _collect_texture_rects(node: Node) -> Array:
	var out: Array = []
	if node is TextureRect:
		out.append(node)
	for c in node.get_children():
		out.append_array(_collect_texture_rects(c))
	return out


# Tight bounding box of pixels in `img` whose alpha exceeds `threshold`.
# Returns Rect2i with zero size if nothing crosses the threshold.
func _opaque_bounds(img: Image, threshold: float) -> Rect2i:
	# Image.get_used_rect treats any alpha > 0 as opaque. That's enough
	# for clean PNG art with hard edges; for soft edges we tighten by
	# rescanning inside that initial rect against our own threshold.
	var initial: Rect2i = img.get_used_rect()
	if initial.size == Vector2i.ZERO:
		return initial
	if threshold <= 0.0:
		return initial

	var min_x: int = initial.position.x + initial.size.x
	var min_y: int = initial.position.y + initial.size.y
	var max_x: int = initial.position.x - 1
	var max_y: int = initial.position.y - 1
	var x_end: int = initial.position.x + initial.size.x
	var y_end: int = initial.position.y + initial.size.y
	for y in range(initial.position.y, y_end):
		for x in range(initial.position.x, x_end):
			if img.get_pixel(x, y).a > threshold:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


# --- hover box ---

func _spawn_hover_box() -> void:
	if _hover_box and is_instance_valid(_hover_box):
		_hover_box.queue_free()
		_hover_box = null

	if _robot_bbox_local.size == Vector2.ZERO:
		return

	# The hover box is purely visual — input is handled in our own
	# _input below so the deep SceneImage chain (z-indices, panel
	# nesting) doesn't get a chance to swallow clicks before reaching
	# it. mouse_filter IGNORE keeps it out of Godot's input routing.
	var box: Control = RobotHoverBox.new()
	var buffer: float = float(robot_border_buffer)
	box.position = _robot_bbox_local.position - Vector2(buffer, buffer)
	box.size = _robot_bbox_local.size + Vector2(buffer * 2.0, buffer * 2.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.force_visible = force_show_hover_border
	# HairFront has z_index=1; sit above every body layer.
	box.z_index = 100
	# Parented to the robot so it inherits the robot's offset+scale.
	robot.add_child(box)
	_hover_box = box


# Global click handler — same pattern Store uses for its item slots.
# Listening at _input bypasses the SceneImage chain's STOP filters and
# z_index priorities, so a click at the hover box's screen rect always
# reaches us regardless of where it sits in the Control tree.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _hover_box == null or not is_instance_valid(_hover_box):
		return
	if not _hover_box.visible or not _hover_box.is_visible_in_tree():
		return

	# If the picture-frame transition is mid-wipe, ignore clicks.
	var main: Node = get_tree().current_scene
	if main and "transition" in main:
		var tr = main.transition
		if tr and tr.has_method("is_playing") and tr.is_playing():
			return

	if _hover_box.get_global_rect().has_point(mb.global_position):
		_on_robot_box_pressed()
		get_viewport().set_input_as_handled()


# Drive the hover box's visible-on-hover state from our own hit test so
# we don't depend on Control mouse_entered/exited routing reaching it.
func _process(_delta: float) -> void:
	if _hover_box == null or not is_instance_valid(_hover_box):
		return
	if force_show_hover_border:
		_hover_box.force_visible = true
		_hover_box.set_hovered(true)
		return
	_hover_box.force_visible = false
	var hovered: bool = _hover_box.get_global_rect() \
		.has_point(_hover_box.get_global_mouse_position())
	_hover_box.set_hovered(hovered)


# --- zoom ---

func _on_robot_box_pressed() -> void:
	if _scene_image == null:
		return
	if _zoomed:
		_reset_zoom()
	else:
		_apply_zoom_to_robot()


func _apply_zoom_to_robot() -> void:
	# Compute the buffered robot rectangle in SceneImage local coords.
	# RobotLayer is anchored full-rect to SceneImage with zero offsets,
	# so it shares SceneImage's origin; the robot Control then sits at
	# `robot.position` with its own `robot.scale`.
	var buffer: float = float(robot_border_buffer)
	var origin_x: float = robot.position.x + (_robot_bbox_local.position.x - buffer) * robot.scale.x
	var origin_y: float = robot.position.y + (_robot_bbox_local.position.y - buffer) * robot.scale.y
	var rect_w: float = (_robot_bbox_local.size.x + buffer * 2.0) * robot.scale.x
	var rect_h: float = (_robot_bbox_local.size.y + buffer * 2.0) * robot.scale.y

	var img_w: float = _scene_image.size.x
	var img_h: float = _scene_image.size.y
	if rect_h <= 0.0 or img_h <= 0.0:
		return

	# Uniform scale so the buffered bbox spans the full frame height.
	var s: float = img_h / rect_h
	if is_equal_approx(s, 1.0):
		return

	# Pivot derivation: under Control's `scale` transform, a point P maps
	# to `pivot + s * (P - pivot)`. Solve for the pivot that sends the
	# bbox top edge to y=0 and the horizontal bbox center to x=img_w/2.
	var pivot_y: float = s * origin_y / (s - 1.0)
	var pivot_x: float = (s * (origin_x + rect_w * 0.5) - img_w * 0.5) / (s - 1.0)

	_scene_image.pivot_offset = Vector2(pivot_x, pivot_y)
	_scene_image.scale = Vector2(s, s)
	_zoomed = true


func _reset_zoom() -> void:
	if _scene_image == null or not is_instance_valid(_scene_image):
		return
	_scene_image.scale = _default_scale
	_scene_image.pivot_offset = _default_pivot
	_zoomed = false
