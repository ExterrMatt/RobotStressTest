extends Control
class_name SaveApp
## Laptop desktop app: a SAVE GAME button. Writes the full GameState snapshot to disk
## (GameState.save_game) and reports the result.

var _status: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	LaptopUI.screen_margin(self).add_child(center)

	var box := LaptopUI.box()
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(220, 0)
	box.add_child(col)

	col.add_child(LaptopUI.label("// SAVE", 14, LaptopUI.GREEN))

	var save_btn := LaptopUI.button("SAVE GAME", 14)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_on_save)
	col.add_child(save_btn)

	_status = LaptopUI.label(_default_status(), 11, LaptopUI.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)


func _default_status() -> String:
	return "Progress on disk." if GameState.has_save() else "No save yet."


func _on_save() -> void:
	if GameState.save_game():
		_status.add_theme_color_override("font_color", LaptopUI.OK)
		_status.text = "Game saved."
	else:
		_status.add_theme_color_override("font_color", LaptopUI.ERR)
		_status.text = "Save failed."
