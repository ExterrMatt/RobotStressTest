extends Control
class_name ProfileApp
## Laptop desktop app: lets the player change their name. Writes through
## GameState.set_player_name (which normalizes it the same way the intro name prompt does).

var _field: LineEdit = null
var _status: Label = null
var _current: Label = null


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
	col.custom_minimum_size = Vector2(240, 0)
	box.add_child(col)

	col.add_child(LaptopUI.label("// IDENTITY", 14, LaptopUI.GREEN))
	_current = LaptopUI.label("Name: " + GameState.get_player_name(), 12, LaptopUI.DIM)
	col.add_child(_current)

	_field = LineEdit.new()
	_field.text = GameState.get_player_name()
	_field.max_length = 24
	_field.placeholder_text = "Enter a name"
	_field.add_theme_font_size_override("font_size", 13)
	_field.add_theme_color_override("font_color", LaptopUI.GREEN)
	_field.add_theme_color_override("caret_color", LaptopUI.GREEN)
	_field.add_theme_stylebox_override("normal", LaptopUI.panel_style())
	_field.add_theme_stylebox_override("focus", LaptopUI.panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	_field.text_submitted.connect(func(_t): _apply())
	col.add_child(_field)

	var confirm := LaptopUI.button("CONFIRM", 12)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_apply)
	col.add_child(confirm)

	_status = LaptopUI.label("", 11, LaptopUI.OK)
	col.add_child(_status)


func _apply() -> void:
	var proposed := GameState.normalize_player_name(_field.text)
	if proposed.is_empty():
		_status.add_theme_color_override("font_color", LaptopUI.ERR)
		_status.text = "Enter at least one letter."
		return
	GameState.set_player_name(_field.text)
	_field.text = GameState.get_player_name()
	_current.text = "Name: " + GameState.get_player_name()
	_status.add_theme_color_override("font_color", LaptopUI.OK)
	_status.text = "Saved as " + GameState.get_player_name() + "."
