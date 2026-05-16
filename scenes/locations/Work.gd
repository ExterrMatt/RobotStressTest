extends LocationBase
## Work location — drag-shapes minigame.
##
## Player fills all four DropSlots in the work panel with their matching
## DraggableItems. Once complete, the in-frame minigame visuals are torn
## down and the player gets a School-style "What do you do?" prompt with
## a finish/steal choice (more money & ingredients, more suspicion).

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

# Choice button sizing — matches School so the work completion screen
# reads as the same visual beat. Fixed height; long labels shrink rather
# than balloon the row.
const CHOICE_BUTTON_HEIGHT: int = 110
const CHOICE_FONT_SIZE: int = 36

# Gold color for the in-box prompt ("What do you do?"). Matches School.
const PROMPT_COLOR: String = "#e8c468"

## Two-phase scene flow. The minigame runs in MINIGAME; the completion
## screen lives in COMPLETION_PROMPT (typing the gold question) and
## COMPLETION_CHOICES (buttons up, waiting on the player).
enum WorkPhase {
	MINIGAME,
	COMPLETION_INTRO,
	COMPLETION_PROMPT,
	COMPLETION_CHOICES,
}


@onready var color_background: ColorRect = $ColorBackground
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var choice_grid: GridContainer = %ChoiceGrid
## Furniture subtree built in Work.tscn for editor previewing; handed to
## Main at _ready so it renders inside the framed picture.
@onready var furniture_layer: Control = $FurnitureLayer
## Inventory subtree; reparented onto Main at runtime so its columns sit
## in the dark areas flanking the picture frame.
@onready var work_inventory: WorkInventory = $WorkInventory

var _scene_phase: WorkPhase = WorkPhase.MINIGAME


func _ready() -> void:
	Dialogue.load_file("work", "res://data/dialogue/work.dlg")
	# Completion-screen widgets are hidden until the minigame finishes.
	dialogue_box.visible = false
	choice_grid.visible = false

	# Clear any leftover choice buttons from a previous run.
	_clear_choice_buttons()

	# Hook the box's finished signal so we can route to the choice phase
	# once the gold prompt is done typing out.
	dialogue_box.finished.connect(_on_dialogue_finished)

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
		_enter_completion_screen()


func _enter_completion_screen() -> void:
	# Guard against re-entry if slots_changed fires more than once.
	if _scene_phase != WorkPhase.MINIGAME:
		return

	var main: Node = get_tree().current_scene

	# Tear down the in-frame minigame visuals so the buttons have room below.
	if main and main.has_method("hide_scene_overlay"):
		main.hide_scene_overlay()
	if main and main.has_method("hide_inventory_overlay"):
		main.hide_inventory_overlay()
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()

	# Drop the opaque grey backdrop so the completion screen matches School's
	# starfield-on-dark look. The minigame uses it to focus attention on the
	# work area; on the completion screen it would just be a distracting slab.
	if color_background:
		color_background.visible = false

	# Swap the picture to the shared scene placeholder and shrink the frame
	# back to default so the dialogue box and buttons below the picture come
	# into view.
	if main and "scene_image" in main:
		var placeholder: Texture2D = load("res://assets/textures/backgrounds/scene_placeholder.png")
		if placeholder:
			main.scene_image.texture = placeholder
	if main and main.has_method("_animate_frame_size_to"):
		main._animate_frame_size_to(Vector2(900, 225))

	_enter_completion_intro()
	
# --- Completion intro phase (italic scene-setting before the prompt) ---

func _enter_completion_intro() -> void:
	_scene_phase = WorkPhase.COMPLETION_INTRO
	_clear_choice_buttons()
	choice_grid.visible = false

	dialogue_box.visible = true
	await get_tree().process_frame
	dialogue_box.play_pages(Dialogue.get_pages("work", "completion"))


# --- Completion prompt phase (gold "What do you do?" types out) ---

func _enter_completion_prompt() -> void:
	_scene_phase = WorkPhase.COMPLETION_PROMPT
	_clear_choice_buttons()
	choice_grid.visible = false

	dialogue_box.visible = true
	var prompt_text: String = "What do you do?"
	var gold_prompt: String = "[center][color=%s]%s[/color][/center]" % [PROMPT_COLOR, prompt_text]
	dialogue_box.play_pages_autosized([[gold_prompt]], [48, 36, 24, 16], 2)
	_auto_advance_completion_prompt(prompt_text)


func _auto_advance_completion_prompt(prompt_text: String) -> void:
	# Wait for the typewriter to finish, then 1s of read time.
	var type_duration: float = float(prompt_text.length()) / dialogue_box.chars_per_second
	await get_tree().create_timer(type_duration + 1.0).timeout
	if _scene_phase != WorkPhase.COMPLETION_PROMPT:
		return
	dialogue_box.hide_advance_arrow()
	_show_completion_choices()
	
# --- Completion choices phase (finish / steal buttons) ---

func _show_completion_choices() -> void:
	_scene_phase = WorkPhase.COMPLETION_CHOICES
	_clear_choice_buttons()
	choice_grid.visible = true

	var finish_btn := _build_choice_button("FINISH SHIFT")
	finish_btn.pressed.connect(_on_finish_pressed)
	choice_grid.add_child(finish_btn)

	var steal_btn := _build_choice_button("POCKET A SCRAP")
	steal_btn.pressed.connect(_on_steal_pressed)
	choice_grid.add_child(steal_btn)


# --- Dialogue routing ---

func _on_dialogue_finished() -> void:
	match _scene_phase:
		WorkPhase.COMPLETION_INTRO:
			_enter_completion_prompt()
		WorkPhase.COMPLETION_PROMPT:
			_show_completion_choices()
		_:
			pass


# --- Button callbacks ---

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
	# Mirrors School._build_choice_button so the two completion screens
	# present identically. Fixed height + EXPAND_FILL horizontally so the
	# two buttons share the row evenly; text shrinks/clips on overflow
	# rather than ballooning a single button.
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, CHOICE_BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.clip_text = true
	return btn


func _clear_choice_buttons() -> void:
	for child in choice_grid.get_children():
		child.queue_free()
