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

## Which lesson this school visit is running:
##   INTRO            - the scripted history question during the intro.
##   CLASS_DISRUPTION - the scripted science lesson (robot phones during class),
##                      shown once, the first class after the intro ends.
##   NORMAL           - a random teacher and question, every class after that.
enum SchoolScenario { INTRO, CLASS_DISRUPTION, NORMAL }

# Each teacher entry pairs on-screen metadata with the DIALOGUE KEYS for its
# intro and its questions. NONE of the prose lives here - the intro, each
# question's lecture, its prompt, and its answer choices are all in
# res://data/dialogue/school.dlg. A question is referenced by its base key
# (e.g. "gym.warmup"); the .lecture / .prompt / .choices entries hang off it.
const TEACHERS: Array = [
	{
		"id": "gym",
		"name": "Mr. Caldera",
		"subject": "Gym",
		"texture_path": "res://assets/textures/characters/teachers/Gym.png",
		"intro_key": "gym.intro",
		"question_keys": ["gym.warmup", "gym.sprint"],
	},
	{
		"id": "science",
		"name": "Ms. Okorie",
		"subject": "Science",
		"texture_path": "res://assets/textures/characters/teachers/Science.png",
		"intro_key": "science.intro",
		"question_keys": ["science.atom", "science.photo", "science.newton"],
	},
	{
		"id": "history",
		"name": "Ms. Vey",
		"subject": "Automaton History",
		"texture_path": "res://assets/textures/characters/teachers/History1.png",
		"intro_key": "history.intro",
		"question_keys": ["history.automaton_war"],
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
const CHOICE_LINE_SPACING: int = -6
const QUESTION_CHOICE_GAP: float = 14.0
const QUESTION_DIALOGUE_LINE_HEIGHT_FACTOR: float = 0.95
const QUESTION_DIALOGUE_LINE_SEPARATION: int = -9
const MS_VEY_PORTRAIT_SCALE: float = 1.1

# Color for in-box prompts ("Which particle...", "What do you do?").
# Wrapped in BBCode so the gold tint goes only on the prompt, not on
# adjacent lecture text.
const PROMPT_COLOR: String = "#e8c468"
const DEFAULT_PLAYER_NAME: String = "Noah"
const INTRO_SCHOOL_STEP: String = "school_first"
const SCHOOL_CABINET_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/school_cabinet.png"
const DEFAULT_DIALOGUE_FRAME_SIZE: Vector2 = Vector2(900.0, 225.0)
const HISTORY_TEXTURE_DIR: String = "res://assets/textures/characters/teachers"
const HISTORY_TEXTURE_MAX_VARIANT: int = 15
const INTRO_HISTORY_TEACHER: Dictionary = {
	"id": "history_intro",
	"name": "Ms. Vey",
	"subject": "Automaton History",
	"texture_path": "res://assets/textures/characters/teachers/History1.png",
	"intro_key": "history.intro",
}
# The intro history lesson reuses the normal history question's lecture and
# choices, but shows the bolded title-case prompt in [history.automaton_war.intro_prompt].
const INTRO_HISTORY_QUESTION_KEY: String = "history.automaton_war"
const INTRO_HISTORY_PROMPT_KEY: String = "history.automaton_war.intro_prompt"

# The scripted class-disruption science lesson. Its lecture, prompt, choices,
# feedback and closing lines all live under the [class_disruption.*] keys in
# school.dlg. Ms. Okorie teaches it and it has no separate teacher-intro line.
const CLASS_DISRUPTION_KEY: String = "class_disruption"
const CLASS_DISRUPTION_TEACHER: Dictionary = {
	"id": "class_disruption",
	"name": "Ms. Okorie",
	"subject": "Science",
	"texture_path": "res://assets/textures/characters/teachers/Science.png",
}

# --- Scene refs ---
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var choice_grid: GridContainer = %ChoiceGrid

# --- Run state ---
var _current_teacher: Dictionary = {}
var _current_question: Dictionary = {}
var _scenario: SchoolScenario = SchoolScenario.NORMAL
var _scene_phase: SchoolPhase = SchoolPhase.LECTURE

# Running totals applied on finish().
var _total_suspicion: int = 0
var _total_ingredients: Dictionary = {}
## Set when the player takes the steal option; drives the drone-encounter branch.
var _stole_contraband: bool = false


func _ready() -> void:
	# Load the dialogue file once. The Dialogue autoload caches it.
	Dialogue.load_file("school", "res://data/dialogue/school.dlg")

	dialogue_box.finished.connect(_on_dialogue_finished)

	_pick_teacher_and_question()
	_enter_lecture()


## Debug speedrun: while Enter is held, auto-pick the question answer so the
## player never has to release Enter. Scoped to the intro history question only
## (every intro answer routes to the same feedback, so the first button is
## always a valid pick); normal school days keep their manual choices.
func _process(_delta: float) -> void:
	if not debug_enter_held():
		return
	if not _is_intro_school_first():
		return
	if _scene_phase != SchoolPhase.QUESTION_CHOICES:
		return
	for child in choice_grid.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).pressed.emit()
			return


## Debug (number-6 key, routed from Main): answer the current question as if the
## player clicked the correct choice, advancing straight into the feedback
## dialogue. Only acts while the answer buttons are up. During the intro history
## question every answer routes to the same feedback, so we click the first
## available button there.
func debug_auto_solve() -> void:
	if _scene_phase != SchoolPhase.QUESTION_CHOICES:
		return
	if _is_intro_school_first():
		for child in choice_grid.get_children():
			if child is Button and not (child as Button).disabled:
				(child as Button).pressed.emit()
				return
		return
	var correct_index: int = int(_current_question.get("correct", 0))
	_on_answer_pressed(correct_index, correct_index)


func _pick_teacher_and_question() -> void:
	if _is_intro_school_first():
		_scenario = SchoolScenario.INTRO
		_current_teacher = INTRO_HISTORY_TEACHER
		_current_question = _resolve_question(INTRO_HISTORY_QUESTION_KEY, INTRO_HISTORY_PROMPT_KEY)
	elif _should_play_class_disruption():
		_scenario = SchoolScenario.CLASS_DISRUPTION
		# One-time: mark it seen the moment it starts so it never replays.
		GameState.robot_class_disruption_seen = true
		_current_teacher = CLASS_DISRUPTION_TEACHER
		_current_question = _resolve_question(CLASS_DISRUPTION_KEY)
	else:
		_scenario = SchoolScenario.NORMAL
		_current_teacher = TEACHERS.pick_random()
		var question_keys: Array = _current_teacher["question_keys"]
		_current_question = _resolve_question(String(question_keys.pick_random()))

	var texture_path: String = _teacher_texture_path(_current_teacher)
	var tex: Texture2D = load(texture_path)
	if tex == null:
		push_warning("School: missing teacher texture %s" % texture_path)
	var main: Node = get_tree().current_scene
	if main and String(_current_teacher.get("name", "")) == "Ms. Vey" and main.has_method("show_bottom_center_portrait"):
		main.show_bottom_center_portrait(
			tex,
			MS_VEY_PORTRAIT_SCALE,
			_current_teacher["name"],
			_current_teacher["subject"]
		)
	elif main and main.has_method("show_teacher_portrait"):
		main.show_teacher_portrait(
			tex,
			_current_teacher["name"],
			_current_teacher["subject"],
			not _is_intro_school_first()
		)


## Builds the runtime question dict entirely from its .dlg entries, so every
## word (lecture, prompt, answers) stays editable in school.dlg. `base_key`
## locates <base>.lecture / <base>.prompt / <base>.choices; `prompt_key`
## overrides which prompt entry to show (the intro lesson uses the bolded
## [<base>.intro_prompt] variant of the same question).
func _resolve_question(base_key: String, prompt_key: String = "") -> Dictionary:
	if prompt_key == "":
		prompt_key = base_key + ".prompt"
	var fmt := _school_format_vars()
	var parsed: Dictionary = _dlg_choices(base_key + ".choices", fmt)
	return {
		"lecture_key": base_key + ".lecture",
		"prompt": _dlg_text(prompt_key, fmt),
		"choices": parsed["choices"],
		"correct": parsed["correct"],
	}


## Flattens a .dlg entry into a single string (its lines joined with spaces).
## Used for one-line prose such as a question prompt or a button label.
func _dlg_text(key: String, fmt: Dictionary = {}) -> String:
	var out: String = ""
	for page in Dialogue.get_pages("school", key, fmt):
		for line in page:
			if out != "":
				out += " "
			out += String(line)
	return out


## Reads a .dlg answer list (one choice per line). The correct answer is the
## line the author marked with a leading "*"; the marker is stripped from the
## shown text. Returns {"choices": Array[String], "correct": int}.
func _dlg_choices(key: String, fmt: Dictionary = {}) -> Dictionary:
	var choices: Array[String] = []
	var correct: int = 0
	for page in Dialogue.get_pages("school", key, fmt):
		for line in page:
			var text: String = String(line)
			if text.begins_with("*"):
				correct = choices.size()
				text = text.substr(1).strip_edges()
			choices.append(text)
	return {"choices": choices, "correct": correct}


func _teacher_texture_path(teacher: Dictionary) -> String:
	if _is_intro_school_first():
		return String(teacher["texture_path"])
	if String(teacher.get("id", "")) == "history":
		return _random_history_texture_path()
	return String(teacher["texture_path"])


func _random_history_texture_path() -> String:
	var candidates: Array[String] = []
	for n in range(1, HISTORY_TEXTURE_MAX_VARIANT + 1):
		if n == 2:
			continue
		var candidate := _history_texture_path(n)
		if ResourceLoader.exists(candidate):
			candidates.append(candidate)
	if not candidates.is_empty():
		return candidates.pick_random()
	return String(INTRO_HISTORY_TEACHER["texture_path"])


func _history_texture_path(number: int) -> String:
	return "%s/History%d.png" % [HISTORY_TEXTURE_DIR, number]


# --- Lecture phase ---

func _enter_lecture() -> void:
	_scene_phase = SchoolPhase.LECTURE
	_clear_choice_buttons()
	_hide_choice_grid()
	_hide_corner()

	# Build a pages list from the teacher's intro (if any) plus the lecture. The
	# class-disruption lesson has no separate teacher intro - its lecture already
	# opens the scene - so its teacher carries no intro_key.
	var pages: Array = []
	var fmt := _school_format_vars()
	if _current_teacher.has("intro_key"):
		pages.append_array(Dialogue.get_pages("school", _current_teacher["intro_key"], fmt))
	pages.append_array(Dialogue.get_pages("school", _current_question["lecture_key"], fmt))
	dialogue_box.play_pages(pages)


# --- Question phase ---

func _enter_question_prompt() -> void:
	_scene_phase = SchoolPhase.QUESTION_PROMPT
	_clear_choice_buttons()
	_hide_choice_grid()

	var prompt: String = _current_question["prompt"]
	var gold_prompt: String = "[center][color=%s]%s[/color][/center]" % [PROMPT_COLOR, prompt]
	dialogue_box.play_pages_autosized(
		[[gold_prompt]],
		[64, 48, 36, 24],
		2,
		QUESTION_DIALOGUE_LINE_HEIGHT_FACTOR,
		QUESTION_DIALOGUE_LINE_SEPARATION
	)
	_auto_advance_question_prompt(prompt)


func _auto_advance_question_prompt(prompt_text: String) -> void:
	var type_duration: float = float(prompt_text.length()) / dialogue_box.chars_per_second
	await get_tree().create_timer(type_duration + 1.0).timeout
	if _scene_phase != SchoolPhase.QUESTION_PROMPT:
		return
	dialogue_box.hide_advance_arrow()
	_show_question_choices()

func _show_question_choices() -> void:
	_scene_phase = SchoolPhase.QUESTION_CHOICES
	_hide_corner()
	_clear_choice_buttons()
	choice_grid.visible = true
	_place_choice_grid_below_dialogue()

	var choices: Array = _current_question["choices"]
	var correct_index: int = _current_question["correct"]
	# Randomize the on-screen order so the correct answer isn't always in the
	# same slot. Each button stays bound to its ORIGINAL choice index, so the
	# correctness check is unaffected by where it lands.
	var order: Array = range(choices.size())
	order.shuffle()
	for i in order:
		var btn := _build_choice_button(str(choices[i]))
		btn.pressed.connect(_on_answer_pressed.bind(i, correct_index))
		choice_grid.add_child(btn)
	call_deferred("_place_choice_grid_below_dialogue")


func _on_answer_pressed(picked: int, correct: int) -> void:
	for child in choice_grid.get_children():
		if child is Button:
			(child as Button).disabled = true

	if _is_intro_school_first():
		_animate_layout_change(func():
			_clear_choice_buttons()
			_hide_choice_grid()
		)
		_scene_phase = SchoolPhase.FEEDBACK
		dialogue_box.play_pages(Dialogue.get_pages("school", "history.automaton_war.feedback", _school_format_vars()))
		return

	var picked_correct: bool = (picked == correct)
	var reward: Dictionary = REWARD_CORRECT if picked_correct else REWARD_WRONG
	var feedback_pages: Array
	if _scenario == SchoolScenario.CLASS_DISRUPTION:
		# The disruption lesson has its own scripted correct/wrong feedback,
		# followed by the robot hanging up. After that it hands off to the SAME
		# post-class steal opportunity as an ordinary school day (bell, cabinet
		# background, nanobots) - see _enter_post_class_intro.
		var key := "class_disruption.feedback.correct" if picked_correct else "class_disruption.feedback.wrong"
		feedback_pages = Dialogue.get_pages("school", key, _school_format_vars())
		feedback_pages.append_array(Dialogue.get_pages("school", "class_disruption.after", _school_format_vars()))
	elif picked_correct:
		feedback_pages = Dialogue.get_pages("school", "feedback.correct", {
			"name": _current_teacher["name"],
		})
	else:
		feedback_pages = Dialogue.get_pages("school", "feedback.wrong", {
			"name": _current_teacher["name"],
			"correct": str(_current_question["choices"][correct]),
		})
	_accumulate_reward(reward)

	# Hide choices; the box takes over until it emits `finished` (which
	# routes us into the post-class intro).
	_animate_layout_change(func():
		_clear_choice_buttons()
		_hide_choice_grid()
	)

	_scene_phase = SchoolPhase.FEEDBACK
	dialogue_box.play_pages(feedback_pages)


# --- Post-class phase ---

func _enter_post_class_intro() -> void:
	_scene_phase = SchoolPhase.POST_CLASS_INTRO
	_hide_choice_grid()
	# Both the class disruption and an ordinary school day end on the same steal
	# opportunity: switch to the supply-cabinet background and play the [post_class]
	# lines before the "what do you do?" steal-or-leave prompt.
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_play_transition_then"):
		main._play_transition_then(Callable(self, "_show_school_cabinet_background_and_play_post_class"))
	else:
		_show_school_cabinet_background_and_play_post_class()


func _show_school_cabinet_background_and_play_post_class() -> void:
	_show_school_cabinet_background()
	dialogue_box.play_pages(Dialogue.get_pages("school", "post_class"))


func _enter_post_class_prompt() -> void:
	_scene_phase = SchoolPhase.POST_CLASS_PROMPT
	_hide_choice_grid()
	var prompt_text: String = _dlg_text("post_class.prompt")
	var gold_prompt: String = "[center][color=%s]%s[/color][/center]" % [PROMPT_COLOR, prompt_text]
	# Match the Workshop's "What do you do?" prompt: no line-height/separation
	# overrides (which shift the single line off-centre), and the font ladder
	# bumped by 6 from the base [48, 36, 24, 16].
	dialogue_box.play_pages_autosized([[gold_prompt]], [54, 42, 30, 22], 2)
	_auto_advance_post_class_prompt(prompt_text)


func _auto_advance_post_class_prompt(prompt_text: String) -> void:
	var type_duration: float = float(prompt_text.length()) / dialogue_box.chars_per_second
	await get_tree().create_timer(type_duration + 1.0).timeout
	if _scene_phase != SchoolPhase.POST_CLASS_PROMPT:
		return
	dialogue_box.hide_advance_arrow()
	_show_post_class_choices()
	
func _show_post_class_choices() -> void:
	_scene_phase = SchoolPhase.POST_CLASS_CHOICES
	_hide_corner()
	_animate_layout_change(func():
		_clear_choice_buttons()
		choice_grid.visible = true
		# Two choices: use two columns so the buttons stretch the full
		# dialogue width (the grid otherwise keeps its 3-column question
		# layout, leaving the pair filling only two-thirds).
		choice_grid.columns = 2

		var leave_btn := _build_choice_button(_dlg_text("post_class.leave"))
		leave_btn.pressed.connect(_on_leave_pressed)
		choice_grid.add_child(leave_btn)

		var steal_btn := _build_choice_button(_dlg_text("post_class.steal"))
		steal_btn.pressed.connect(_on_steal_pressed)
		choice_grid.add_child(steal_btn)
		_place_choice_grid_below_dialogue()
	)
	call_deferred("_place_choice_grid_below_dialogue")


func _on_leave_pressed() -> void:
	_finish_school()


func _on_steal_pressed() -> void:
	_accumulate_reward(REWARD_STEAL)
	_stole_contraband = true
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
			if _is_intro_school_first():
				_finish_school()
				return
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


func _hide_choice_grid() -> void:
	choice_grid.visible = false
	choice_grid.position = Vector2.ZERO


func _place_choice_grid_below_dialogue() -> void:
	if _scene_phase != SchoolPhase.QUESTION_CHOICES \
			and _scene_phase != SchoolPhase.POST_CLASS_CHOICES:
		return
	var parent_control := choice_grid.get_parent() as Control
	if parent_control == null:
		return
	var parent_rect: Rect2 = parent_control.get_global_rect()
	var dialogue_rect: Rect2 = dialogue_box.get_global_rect()
	choice_grid.position = Vector2(
		dialogue_rect.position.x - parent_rect.position.x,
		dialogue_rect.end.y - parent_rect.position.y + QUESTION_CHOICE_GAP
	)
	choice_grid.size.x = dialogue_rect.size.x


func _animate_layout_change(mutator: Callable) -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("animate_layout_change"):
		main.animate_layout_change(mutator)
	elif mutator.is_valid():
		mutator.call()


func _show_school_cabinet_background() -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return

	if main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()
	if "scene_image" in main:
		var cabinet: Texture2D = load(SCHOOL_CABINET_BACKGROUND_TEXTURE_PATH)
		if cabinet:
			main.scene_image.texture = cabinet
	if main.has_method("_animate_frame_to") and "_default_frame_outer_width" in main:
		main._animate_frame_to(DEFAULT_DIALOGUE_FRAME_SIZE, main._default_frame_outer_width)


func _finish_school() -> void:
	var contraband := "pile of nanobots" if _stole_contraband else ""
	finish(0, _total_suspicion, 0, _total_ingredients, false, contraband)


func _is_intro_school_first() -> bool:
	return GameState.is_intro_step(INTRO_SCHOOL_STEP)


## The scripted class-disruption lesson plays exactly once: the first class the
## player attends after the intro has ended.
func _should_play_class_disruption() -> bool:
	return GameState.intro_completed and not GameState.robot_class_disruption_seen


func _school_format_vars() -> Dictionary:
	var player_name := DEFAULT_PLAYER_NAME
	if GameState.has_method("get_player_name"):
		player_name = String(GameState.call("get_player_name"))
	return {
		"name": String(_current_teacher.get("name", "")),
		"player_name": player_name,
	}


func _accumulate_reward(reward: Dictionary) -> void:
	_total_suspicion += int(reward.get("suspicion", 0))
	var ingredients: Dictionary = reward.get("ingredients", {})
	for ing_id in ingredients:
		var amt: int = int(ingredients[ing_id])
		_total_ingredients[ing_id] = int(_total_ingredients.get(ing_id, 0)) + amt


func _build_choice_button(label: String) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"ChoiceButton"
	btn.text = label
	# Fixed height. SIZE_FILL (no SIZE_EXPAND) horizontally so the three
	# buttons share the row evenly; vertical shrink so the button stays
	# at exactly CHOICE_BUTTON_HEIGHT regardless of text length.
	btn.custom_minimum_size = Vector2(0, CHOICE_BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	btn.add_theme_constant_override("line_spacing", CHOICE_LINE_SPACING)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# If a long label can't fit at CHOICE_FONT_SIZE within the box,
	# Godot will clip it instead of expanding the button.
	btn.clip_text = true
	return btn


func _clear_choice_buttons() -> void:
	for child in choice_grid.get_children():
		child.queue_free()
