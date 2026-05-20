@tool
extends Control
class_name WorkshopPiece
## Visual layer + draggable for ingredient tiles. Post-CRAFT, pieces get
## wrapped inside a WorkshopSegment which handles its own drag — see
## WorkshopMinigame._pick_up_segment / _pick_up_piece for the split.

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
@export var visual_offset: Vector2 = Vector2.ZERO:
	set(value):
		visual_offset = value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO
		queue_redraw()

@export var shadow_offset: Vector2 = Vector2.ZERO:
	set(value):
		shadow_offset = value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO
		queue_redraw()

@export var auto_center: bool = false:
	set(value):
		auto_center = value
		queue_redraw()


var piece_offset: Vector2 = Vector2.ZERO
var home_parent: Control = null
var locked: bool = false

var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var v_off: Vector2 = visual_offset if typeof(visual_offset) == TYPE_VECTOR2 else Vector2.ZERO
	var s_off: Vector2 = shadow_offset if typeof(shadow_offset) == TYPE_VECTOR2 else Vector2.ZERO

	var tex_pos: Vector2 = v_off
	if auto_center and texture:
		tex_pos = (size - texture.get_size()) / 2.0

	# Only draw the local shadow in the editor so authoring still looks right.
	# At runtime, WorkshopMinigame renders all shadows in a unified CanvasGroup.
	if shadow_texture and Engine.is_editor_hint():
		var s_pos: Vector2 = tex_pos
		if auto_center:
			s_pos = (size - shadow_texture.get_size()) / 2.0
		draw_texture(shadow_texture, s_pos + s_off, SHADOW_MODULATE)

	if texture:
		draw_texture(texture, tex_pos)


func hit_test(global_pos: Vector2) -> bool:
	if locked or not visible or not is_visible_in_tree():
		return false
	return get_global_rect().has_point(global_pos)


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
