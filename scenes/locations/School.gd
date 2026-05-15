extends LocationBase
## School scene with a teacher lecture, comprehension question, and a
## post-class branching choice (steal nanobots or leave quietly).
##
## TEXT SYSTEM
## -----------
## All dialogue prose lives in res://data/dialogue/school.dlg (a plain-text
## file you can edit by hand - see that file for format docs).
##
## This script just picks which keys to play and feeds them into a shared
## DialogueBox widget. The box handles letter-by-letter typing, page
## advance, the "▼" arrow indicator, and Shift-to-fast-forward.
##
## Flow:
##   1. LECTURE       - DialogueBox plays the teacher intro + lecture pages.
##                      When the box emits `finished`, we advance to QUESTION.
##   2. QUESTION      - choice buttons appear under the box.
##   3. FEEDBACK      - DialogueBox plays correct/wrong feedback pages.
##   4. POST_CLASS    - DialogueBox plays the steal-or-leave setup, then
##                      choice buttons appear.

enum SchoolPhase {
	LECTURE,           # lecture pages typing out
	QUESTION_PROMPT,   # question line typing out in the dialogue box
	QUESTION_CHOICES,  # buttons up, waiting on player click
	FEEDBACK,          # correct/wrong feedback pages typing out
	POST_CLASS_INTRO,  # bell-rings / cabinet pages typing out
	POST_CLASS_PROMPT, # "what do you do?" typing out in the dialogue box
	POST_CLASS_CHOICES,# steal/leave buttons up
}

# Each teacher entry pairs metadata with the DIALOGUE KEY for the intro and
# one entry per question. The lecture prose itself lives in the .dlg file.
const TEACHERS: Array = [
	{
		"id": "gym",
		"name": "Mr. Caldera",
		"subject": "Gym",
		"texture_path": "res://assets/textures/characters/teachers/Gym.png",
		"intro_key": "gym.intro",
		"questions": [
			{
				"lecture_key": "gym.warmup.lecture",
				"prompt": "Why do we warm up before exercise?",
				"choices": [
					"It burns extra calories before the workout",
					"It raises muscle temperature and blood flow",
					"It tightens the muscles for more power",
				],
				"correct": 1,
			},
			{
				"lecture_key": "gym.sprint.lecture",
				"prompt": "What energy system does a short sprint mainly use?",
				"choices": [
					"Aerobic - uses lots of oxygen",
					"Anaerobic - burns glucose without oxygen",
					"Photosynthesis",
				],
				"correct": 1,
			},
		],
	},
	{
		"id": "science",
		"name": "Ms. Okorie",
		"subject": "Science",
		"texture_path": "res://assets/textures/characters/teachers/Science.png",
		"intro_key": "science.intro",
		"questions": [
			{
				"lecture_key": "science.atom.lecture",
				"prompt": "Which particle determines what element an atom is?",
				"choices": [
					"The neutron",
					"The proton",
					"The electron",
				],
				"correct": 1,
			},
			{
				"lecture_key": "science.photo.lecture",
				"prompt": "What gas do plants release as a byproduct of photosynthesis?",
				"choices": [
					"Carbon dioxide",
					"Nitrogen",
					"Oxygen",
				],
				"correct": 2,
			},
			{
				"lecture_key": "science.newton.lecture",
				"prompt": "What does Newton's third law of motion state?",
				"choices": [
					"Objects in motion stay in motion",
					"Force equals mass times acceleration",
					"Every action has an equal and opposite reaction",
				],
				"correct": 2,
			},
		],
	},
]

# Reward values (mirror the original StubLocation outcomes).
const REWARD_CORRECT: Dictionary = {
	"suspicion": -4,
	"ingredients": {"electronics": 1},
}
const REWARD_WRONG: Dictionary = {
	"suspicion": -2,
	"ingredients": {"nuts_bolts": 1},
}
const REWARD_STEAL: Dictionary = {
	"suspicion": 6,
	"ingredients": {"nanobots": 1},
}

# Choice button sizing. Buttons get a FIXED height so a long choice doesn't
# make its button taller than the others - the font size shrinks instead.
const CHOICE_BUTTON_HEIGHT: int = 110
const CHOICE_FONT_SIZE: int = 36

# Color for in-box prompts ("Which particle...", "What do you do?").
# Wrapped in BBCode so the gold tint goes only on the prompt, not on
# adjacent lecture text.
const PROMPT_COLOR: String = "#e8c468"

# --- Scene refs ---
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var choice_grid: GridContainer = %ChoiceGrid

# --- Run state ---
var _current_teacher: Dictionary = {}
var _current_question: Dictionary = {}
var _scene_phase: SchoolPhase = SchoolPhase.LECTURE

# Running totals applied on finish().
var _total_suspicion: int = 0
var _total_ingredients: Dictionary = {}


func _ready() -> void:
	# Load the dialogue file once. The Dialogue autoload caches it.
	Dialogue.load_file("school", "res://data/dialogue/school.dlg")

	dialogue_box.finished.connect(_on_dialogue_finished)

	_pick_teacher_and_question()
	_enter_lecture()


func _pick_teacher_and_question() -> void:
	_current_teacher = TEACHERS.pick_random()
	var questions: Array = _current_teacher["questions"]
	_current_question = questions.pick_random()

	var tex: Texture2D = load(_current_teacher["texture_path"])
	if tex == null:
		push_warning("School: missing teacher texture %s" % _current_teacher["texture_path"])
	var main: Node = get_tree().current_scene
	if main and main.has_method("show_teacher_portrait"):
		main.show_teacher_portrait(tex, _current_teacher["name"], _current_teacher["subject"])


# --- Lecture phase ---

func _enter_lecture() -> void:
	_scene_phase = SchoolPhase.LECTURE
	_clear_choice_buttons()
	choice_grid.visible = false
	_hide_corner()

	# Build a pages list by concatenating the intro pages and the lecture
	# pages. Each is already a Array[Array[String]].
	var pages: Array = []
	pages.append_array(Dialogue.get_pages("school", _current_teacher["intro_key"]))
	pages.append_array(Dialogue.get_pages("school", _current_question["lecture_key"]))
	dialogue_box.play_pages(pages)


# --- Question phase ---

## Type the question prompt out in the dialog box as the most recent line.
## When the box emits `finished`, _show_question_choices wires up the buttons.
## Uses autosize so the prompt is as eye-catching as the box width allows.
func _enter_question_prompt() -> void:
	_scene_phase = SchoolPhase.QUESTION_PROMPT
	_clear_choice_buttons()
	choice_grid.visible = false

	var prompt: String = _current_question["prompt"]
	var gold_prompt: String = "[center][color=%s]%s[/color][/center]" % [PROMPT_COLOR, prompt]
	dialogue_box.play_pages_autosized([[gold_prompt]], [64, 48, 36, 24], 2)


func _show_question_choices() -> void:
	_scene_phase = SchoolPhase.QUESTION_CHOICES
	_hide_corner()
	_clear_choice_buttons()
	choice_grid.visible = true

	var choices: Array = _current_question["choices"]
	var correct_index: int = _current_question["correct"]
	for i in choices.size():
		var btn := _build_choice_button(str(choices[i]))
		btn.pressed.connect(_on_answer_pressed.bind(i, correct_index))
		choice_grid.add_child(btn)


func _on_answer_pressed(picked: int, correct: int) -> void:
	for child in choice_grid.get_children():
		if child is Button:
			(child as Button).disabled = true

	var picked_correct: bool = (picked == correct)
	var reward: Dictionary
	var feedback_pages: Array
	if picked_correct:
		reward = REWARD_CORRECT
		feedback_pages = Dialogue.get_pages("school", "feedback.correct", {
			"name": _current_teacher["name"],
		})
	else:
		reward = REWARD_WRONG
		feedback_pages = Dialogue.get_pages("school", "feedback.wrong", {
			"name": _current_teacher["name"],
			"correct": str(_current_question["choices"][correct]),
		})
	_accumulate_reward(reward)

	# Hide choices; the box takes over until it emits `finished` (which
	# routes us into the post-class intro).
	_clear_choice_buttons()
	choice_grid.visible = false

	_scene_phase = SchoolPhase.FEEDBACK
	dialogue_box.play_pages(feedback_pages)


# --- Post-class phase ---

func _enter_post_class_intro() -> void:
	_scene_phase = SchoolPhase.POST_CLASS_INTRO
	dialogue_box.play_pages(Dialogue.get_pages("school", "post_class"))


func _enter_post_class_prompt() -> void:
	_scene_phase = SchoolPhase.POST_CLASS_PROMPT
	var gold_prompt: String = "[center][color=%s]What do you do?[/color][/center]" % PROMPT_COLOR
	dialogue_box.play_pages_autosized([[gold_prompt]], [48, 36, 24, 16], 2)


func _show_post_class_choices() -> void:
	_scene_phase = SchoolPhase.POST_CLASS_CHOICES
	_hide_corner()
	_clear_choice_buttons()
	choice_grid.visible = true

	var leave_btn := _build_choice_button("LEAVE QUIETLY")
	leave_btn.pressed.connect(_on_leave_pressed)
	choice_grid.add_child(leave_btn)

	var steal_btn := _build_choice_button("STEAL NANOBOTS")
	steal_btn.pressed.connect(_on_steal_pressed)
	choice_grid.add_child(steal_btn)


func _on_leave_pressed() -> void:
	_finish_school()


func _on_steal_pressed() -> void:
	_accumulate_reward(REWARD_STEAL)
	_finish_school()


# --- Dialogue routing ---
#
# Whenever the dialog box finishes typing out its current run, we use
# _scene_phase to decide what comes next.

func _on_dialogue_finished() -> void:
	match _scene_phase:
		SchoolPhase.LECTURE:
			_enter_question_prompt()
		SchoolPhase.QUESTION_PROMPT:
			_show_question_choices()
		SchoolPhase.FEEDBACK:
			_enter_post_class_intro()
		SchoolPhase.POST_CLASS_INTRO:
			_enter_post_class_prompt()
		SchoolPhase.POST_CLASS_PROMPT:
			_show_post_class_choices()
		_:
			pass


# --- Helpers ---

func _hide_corner() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()


func _finish_school() -> void:
	finish(0, _total_suspicion, 0, _total_ingredients, false)


func _accumulate_reward(reward: Dictionary) -> void:
	_total_suspicion += int(reward.get("suspicion", 0))
	var ingredients: Dictionary = reward.get("ingredients", {})
	for ing_id in ingredients:
		var amt: int = int(ingredients[ing_id])
		_total_ingredients[ing_id] = int(_total_ingredients.get(ing_id, 0)) + amt


func _build_choice_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	# Fixed height. SIZE_FILL (no SIZE_EXPAND) horizontally so the three
	# buttons share the row evenly; vertical shrink so the button stays
	# at exactly CHOICE_BUTTON_HEIGHT regardless of text length.
	btn.custom_minimum_size = Vector2(0, CHOICE_BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# If a long label can't fit at CHOICE_FONT_SIZE within the box,
	# Godot will clip it instead of expanding the button.
	btn.clip_text = true
	return btn


func _clear_choice_buttons() -> void:
	for child in choice_grid.get_children():
		child.queue_free()
