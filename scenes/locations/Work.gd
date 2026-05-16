extends LocationBase
## Work location.
##
## Converted from a StubLocation instance so we can drop in pixel-art
## decorations (the work table, the control panel that sits on top of it).
## Gameplay is unchanged: a list of outcome buttons configured via @export,
## each emitting finish() with its rewards, plus a Back button mounted in
## Main's bottom-right corner.
##
## Replace the buttons-as-outcomes flow with a real minigame when ready;
## the table + panel sprites can stay as the backdrop.

## Title shown at the top of the screen.
@export var title_text: String = "Work"

## Flavor blurb under the title.
@export_multiline var blurb_text: String = "Sort shapes. Watch the valves. Clean the vents."

## Buttons that appear at the bottom. Each represents a possible outcome.
## Same structure as StubLocation.outcomes so existing .tres-style data
## carries across:
##   { "label": String, "money": int, "suspicion": int, "anger": int,
##     "ingredients": Dictionary[String, int] }
@export var outcomes: Array = []


@onready var title_label: Label = %TitleLabel
@onready var blurb_label: Label = %BlurbLabel
@onready var button_container: HFlowContainer = %ButtonContainer


func _ready() -> void:
	title_label.text = title_text
	blurb_label.text = blurb_text

	# Build one button per outcome (same pattern as StubLocation).
	for child in button_container.get_children():
		child.queue_free()

	for outcome in outcomes:
		var btn := Button.new()
		btn.text = outcome.get("label", "(unlabeled)")
		btn.custom_minimum_size = Vector2(280, 48)
		btn.pressed.connect(_on_outcome_pressed.bind(outcome))
		button_container.add_child(btn)

	# Mount the back button inside Main's picture frame (bottom-right corner).
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
	# Free action — return to selection without advancing the phase.
	# (Main hides the corner button at the transition midpoint.)
	finish(0, 0, 0, {}, true)
