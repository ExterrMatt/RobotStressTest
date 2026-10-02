extends LocationBase
## Night-bedroom prompt shown before the Sleep scene when the robot has a body:
## asks whether to bring her to bed, then hands off to the fullscreen Sleep scene
## (via Main.enter_sleep_from_prompt) with or without the robot in the bed.

const CHOICE_BUTTON_HEIGHT: int = 110
const CHOICE_FONT_SIZE: int = 36
const PROMPT_COLOR: String = "#e8c468"

enum PromptPhase {
	INTRO,
	PROMPT,
	CHOICES,
	DONE,
}

@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var choice_grid: GridContainer = %ChoiceGrid

var _scene_phase: PromptPhase = PromptPhase.INTRO


func _ready() -> void:
	Dialogue.load_file("sleep", "res://data/dialogue/sleep.dlg")

	choice_grid.visible = false
	_clear_choice_buttons()

	dialogue_box.finished.connect(_on_dialogue_finished)
	_hide_end_button()

	_scene_phase = PromptPhase.INTRO
	dialogue_box.visible = true
	dialogue_box.play_pages(Dialogue.get_pages("sleep", "intro"))


func _hide_end_button() -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("hide_corner_button"):
		main.hide_corner_button()
	if main != null and main.has_method("hide_large_scene_end_button"):
		main.hide_large_scene_end_button()


func _enter_prompt() -> void:
	_scene_phase = PromptPhase.PROMPT
	_clear_choice_buttons()
	choice_grid.visible = false

	dialogue_box.visible = true
	var prompt_text: String = dlg_line("sleep", "prompt")
	var gold_prompt: String = "[center][color=%s]%s[/color][/center]" % [PROMPT_COLOR, prompt_text]
	# Same font ladder as the Workshop's "What do you do?" prompt.
	dialogue_box.play_pages_autosized([[gold_prompt]], [54, 42, 30, 22], 2)
	_auto_advance_prompt(prompt_text)


func _auto_advance_prompt(prompt_text: String) -> void:
	var type_duration: float = float(prompt_text.length()) / dialogue_box.chars_per_second
	await get_tree().create_timer(type_duration + 1.0).timeout
	if _scene_phase != PromptPhase.PROMPT:
		return
	dialogue_box.hide_advance_arrow()
	_show_choices()


func _show_choices() -> void:
	_scene_phase = PromptPhase.CHOICES
	lock_entry_input()
	_clear_choice_buttons()
	choice_grid.visible = true

	var yes_btn := _build_choice_button(dlg_line("sleep", "prompt.yes"))
	yes_btn.pressed.connect(_on_choice_pressed.bind(true))
	choice_grid.add_child(yes_btn)

	var no_btn := _build_choice_button(dlg_line("sleep", "prompt.no"))
	no_btn.pressed.connect(_on_choice_pressed.bind(false))
	choice_grid.add_child(no_btn)


func _on_choice_pressed(bring_robot: bool) -> void:
	if _scene_phase != PromptPhase.CHOICES:
		return
	_scene_phase = PromptPhase.DONE
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("enter_sleep_from_prompt"):
		push_error("SleepPrompt: Main has no enter_sleep_from_prompt().")
		return
	main.call("enter_sleep_from_prompt", bring_robot)


# --- dialogue routing ---

func _on_dialogue_finished() -> void:
	match _scene_phase:
		PromptPhase.INTRO:
			_enter_prompt()
		PromptPhase.PROMPT:
			_show_choices()
		_:
			pass


func _build_choice_button(label: String) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"ChoiceButton"
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
