extends Control
class_name SaveApp
## Laptop desktop app: the save slots (GameState.SAVE_SLOT_COUNT of them), each with a SAVE
## button that writes the full GameState snapshot there (GameState.save_game).
##
## The slot this run is in (GameState.current_save_slot) saves straight away. Any other slot
## that already holds a save asks first: its button turns into OVERWRITE?, and only a second
## press writes over it.

const CONFIRM_TEXT: String = "OVERWRITE?"
const SUMMARY_WIDTH: float = 150.0

var _rows: VBoxContainer = null
var _status: Label = null
## The slot whose button is showing CONFIRM_TEXT, or 0.
var _confirm_slot: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	LaptopUI.screen_margin(self).add_child(center)

	var box := LaptopUI.box()
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(300, 0)
	box.add_child(col)

	col.add_child(LaptopUI.label("// SAVE", 14, LaptopUI.GREEN))

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)

	_status = LaptopUI.label(_default_status(), 10, LaptopUI.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	_build_rows()


func _default_status() -> String:
	if GameState.current_save_slot > 0:
		return "Playing from save %d." % GameState.current_save_slot
	return "Pick a slot to save to."


func _build_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for save in GameState.list_save_slots():
		_rows.add_child(_build_row(save))


func _build_row(save: Dictionary) -> Control:
	var slot := int(save["slot"])
	var is_current := slot == GameState.current_save_slot
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := LaptopUI.label(String(save["name"]), 11, LaptopUI.OK if is_current else LaptopUI.GREEN)
	name_lbl.custom_minimum_size = Vector2(52, 0)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_lbl)

	var summary_text := "- empty -" if bool(save["empty"]) else String(save["summary"])
	var summary := LaptopUI.label(summary_text, 10, LaptopUI.GREEN if not bool(save["empty"]) else LaptopUI.DIM)
	summary.custom_minimum_size = Vector2(SUMMARY_WIDTH, 0)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(summary)

	var confirming := slot == _confirm_slot
	var btn := LaptopUI.button(CONFIRM_TEXT if confirming else "SAVE", 11)
	btn.custom_minimum_size = Vector2(78, 0)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if confirming:
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			btn.add_theme_color_override(key, LaptopUI.ERR)
	btn.pressed.connect(_on_save_pressed.bind(slot, bool(save["empty"])))
	row.add_child(btn)
	return row


func _on_save_pressed(slot: int, empty: bool) -> void:
	var needs_confirm := not empty and slot != GameState.current_save_slot
	if needs_confirm and _confirm_slot != slot:
		_confirm_slot = slot
		_set_status("Save %d has a save in it. Press again to overwrite." % slot, LaptopUI.ERR)
		_build_rows()
		return
	_confirm_slot = 0
	if GameState.save_game(slot):
		_set_status("Saved to save %d." % slot, LaptopUI.OK)
	else:
		_set_status("Save failed.", LaptopUI.ERR)
	_build_rows()


func _set_status(text: String, color: Color) -> void:
	_status.add_theme_color_override("font_color", color)
	_status.text = text
