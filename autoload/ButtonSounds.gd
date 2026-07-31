extends Node

## Global fallback button click. Every button in the game gets the default click
## (button_click.mp3) on press UNLESS it is wired to a specific UI sound - those
## opt out with UiSound.mark_has_custom_sound (the CUSTOM_META meta), which is
## checked at press time so it doesn't matter whether the tag is set before or
## after the button enters the tree.
##
## Disabled buttons never emit "pressed", so their locked/inaccessible sound is
## still handled by the per-screen hooks (MainMenu / Main), not here.

const UI_SOUND := preload("res://scenes/ui/UiSound.gd")
const WIRED_META := "ui_sound_fallback_wired"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	# Buttons already present when this autoload starts (rare - autoloads load
	# before the main scene - but covers anything mounted early).
	_scan(get_tree().root)


func _on_node_added(node: Node) -> void:
	_register(node)


func _scan(node: Node) -> void:
	_register(node)
	for child in node.get_children():
		_scan(child)


func _register(node: Node) -> void:
	if not (node is BaseButton):
		return
	var button := node as BaseButton
	if button.has_meta(WIRED_META):
		return
	button.set_meta(WIRED_META, true)
	button.pressed.connect(func() -> void:
		if is_instance_valid(button) and not button.has_meta(UI_SOUND.CUSTOM_META):
			UI_SOUND.play_fallback_click(button)
	)
