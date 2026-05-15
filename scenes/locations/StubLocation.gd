extends LocationBase
## Generic stub for a minigame location.
##
## Until real minigames exist, each location is a screen with a few buttons
## representing possible outcomes ("good run", "bad run", "with stealing", etc).
## Each button's rewards are configured via @export below so we can tune
## per-location feel without changing code.
##
## The back action lives in Main's bottom-right corner button (inside the
## picture frame), mounted on _ready and torn down when the location ends
## or when the transition's midpoint clears it.
##
## Replace this entire script with a real minigame scene script when ready.

## Title shown at the top of the screen.
@export var title_text: String = "Stub Location"

## Flavor blurb under the title.
@export_multiline var blurb_text: String = "This activity isn't implemented yet."

## Texture slot for a background or robot illustration. Drop pixel art later.
@export var background_texture: Texture2D

## Buttons that appear at the bottom. Each represents a possible outcome.
## Structure: { "label": String, "money": int, "suspicion": int, "anger": int,
##              "ingredients": Dictionary[String, int] }
## Plain Array (not Array[Dictionary]) because inline dict-literals assigned in
## .tscn files don't carry the inner element type cleanly in Godot 4.2.
@export var outcomes: Array = []


@onready var title_label: Label = %TitleLabel
@onready var blurb_label: Label = %BlurbLabel
@onready var background_rect: TextureRect = %BackgroundRect
@onready var button_container: HFlowContainer = %ButtonContainer


func _ready() -> void:
	title_label.text = title_text
	blurb_label.text = blurb_text

	if background_texture:
		background_rect.texture = background_texture

	# Clear any placeholder children, then build one button per outcome.
	for child in button_container.get_children():
		child.queue_free()

	for outcome in outcomes:
		var btn := Button.new()
		btn.text = outcome.get("label", "(unlabeled)")
		btn.custom_minimum_size = Vector2(280, 48)
		btn.pressed.connect(_on_outcome_pressed.bind(outcome))
		button_container.add_child(btn)

	# Mount the back button inside the picture frame (bottom-right corner).
	var main: Node = get_tree().current_scene
	if main and main.has_method("show_corner_button"):
		main.show_corner_button("<- BACK", _on_back_pressed)


func _on_outcome_pressed(outcome: Dictionary) -> void:
	finish(
		outcome.get("money", 0),
		outcome.get("suspicion", 0),
		outcome.get("anger", 0),
		outcome.get("ingredients", {}),
		false,
	)


func _on_back_pressed() -> void:
	# Free action - return to selection without advancing the phase.
	# (Main hides the corner button at the transition midpoint.)
	finish(0, 0, 0, {}, true)
