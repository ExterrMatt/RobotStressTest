extends LocationBase

@onready var blanket: TextureRect = %Blanket
@onready var blanket_bump: TextureRect = %BlanketBump

var _blanket_removed := false


func _on_bed_click_area_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	get_viewport().set_input_as_handled()
	if not _blanket_removed:
		_blanket_removed = true
		blanket.visible = false
		blanket_bump.visible = false
		return

	finish()
