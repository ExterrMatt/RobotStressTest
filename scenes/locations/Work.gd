extends LocationBase
## Work location — drag-shapes minigame.
##
## Player fills all four DropSlots in the work panel with their matching
## DraggableItems. Once complete, two buttons appear: finish normally, or
## pocket some extra scrap (more money & ingredients, more suspicion).

## Reward for completing the shift normally.
const REWARD_COMPLETE: Dictionary = {
	"money": 30,
	"suspicion": -1,
	"ingredients": {"scrap_metal": 1, "synth_skin": 1},
}

## Extra reward layered on top of REWARD_COMPLETE if the player steals.
const REWARD_STEAL: Dictionary = {
	"money": 0,
	"suspicion": 4,
	"ingredients": {"scrap_metal": 1},
}

const CHOICE_BUTTON_HEIGHT: int = 64
const CHOICE_FONT_SIZE: int = 28


@onready var title_label: Label = %TitleLabel
@onready var blurb_label: Label = %BlurbLabel
@onready var button_container: HFlowContainer = %ButtonContainer
## Furniture subtree built in Work.tscn for editor previewing; handed to
## Main at _ready so it renders inside the framed picture.
@onready var furniture_layer: Control = $FurnitureLayer
## Inventory subtree; reparented onto Main at runtime so its columns sit
## in the dark areas flanking the picture frame.
@onready var work_inventory: WorkInventory = $WorkInventory


func _ready() -> void:
	title_label.visible = false
	blurb_label.visible = false
	button_container.visible = false

	# Clear any leftover children of the button container.
	for child in button_container.get_children():
		child.queue_free()

	var main: Node = get_tree().current_scene

	# Hand the furniture layer off to Main so it sits inside the framed picture.
	if main and main.has_method("show_scene_overlay") and furniture_layer:
		main.show_scene_overlay(furniture_layer)

	# Hand the inventory columns off to Main so they sit in the side strips.
	if main and main.has_method("show_inventory_overlay") and work_inventory:
		main.show_inventory_overlay(work_inventory)

	# Listen for slot fills so we know when the puzzle is complete.
	if work_inventory:
		work_inventory.slots_changed.connect(_on_slots_changed)

	# Mount the back button inside Main's picture frame (bottom-right corner).
	if main and main.has_method("show_corner_button"):
		main.show_corner_button("<- BACK", _on_back_pressed)


func _on_slots_changed(filled_count: int) -> void:
	# Show the finish/steal choices only when all four slots are filled.
	if filled_count >= 4 and work_inventory.is_complete():
		_show_completion_choices()
	else:
		# Player pulled an item back out — hide the choices again.
		button_container.visible = false
		for child in button_container.get_children():
			child.queue_free()


func _show_completion_choices() -> void:
	# Rebuild fresh in case this fires more than once.
	for child in button_container.get_children():
		child.queue_free()

	var finish_btn := _build_choice_button("FINISH SHIFT")
	finish_btn.pressed.connect(_on_finish_pressed)
	button_container.add_child(finish_btn)

	var steal_btn := _build_choice_button("POCKET A SCRAP")
	steal_btn.pressed.connect(_on_steal_pressed)
	button_container.add_child(steal_btn)

	button_container.visible = true


func _on_finish_pressed() -> void:
	_finish_work(false)


func _on_steal_pressed() -> void:
	_finish_work(true)


func _on_back_pressed() -> void:
	# Free action — return to selection without advancing the phase.
	finish(0, 0, 0, {}, true)


# --- Helpers ---

func _finish_work(stole: bool) -> void:
	var money: int = int(REWARD_COMPLETE.get("money", 0))
	var suspicion: int = int(REWARD_COMPLETE.get("suspicion", 0))
	var ingredients: Dictionary = _copy_ingredients(REWARD_COMPLETE.get("ingredients", {}))

	if stole:
		money += int(REWARD_STEAL.get("money", 0))
		suspicion += int(REWARD_STEAL.get("suspicion", 0))
		_merge_ingredients(ingredients, REWARD_STEAL.get("ingredients", {}))

	finish(money, suspicion, 0, ingredients, false)


func _copy_ingredients(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src:
		out[k] = int(src[k])
	return out


func _merge_ingredients(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		dst[k] = int(dst.get(k, 0)) + int(src[k])


func _build_choice_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(280, CHOICE_BUTTON_HEIGHT)
	btn.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	return btn
