extends LocationBase
## School scene with a teacher lecture, comprehension question, and a
## post-class branching choice (steal nanobots or leave quietly).
##
## Flow:
##   1. ENTER  - pick a random teacher + question, show lecture text.
##   2. QUESTION - show 3 answer buttons. One is correct.
##                 (Correct => electronics +1, suspicion -4)
##                 (Wrong   => nuts_bolts  +1, suspicion -2)
##   3. POST_CLASS - "class is over, what now?"
##                 (Steal   => +nanobots +1, +6 suspicion)
##                 (Leave   => no extra delta)
##   4. finish() with the combined result.
##
## The teacher portrait is shown by Main's framed image area, not by this
## scene - we call Main.show_teacher_portrait() so the teacher appears
## inside the classroom illustration at the top of the screen.
## Hiding the portrait is Main's responsibility too: it runs at the
## transition's midpoint as part of _apply_selection_screen_swap, so the
## portrait stays visible until the wipe is covering the frame.
##
## Reward numbers mirror the original StubLocation School outcomes so the
## game's pacing doesn't change.

# --- Phases of this scene's internal flow (not to be confused with
#     DayCycle.Phase, which is morning/evening/night) ---
enum SchoolPhase {
	LECTURE,
	QUESTION,
	POST_CLASS,
}

# --- Teacher + question data ---
#
# Each teacher has:
#   texture_path: portrait
#   intro:    short flavor line shown before the lecture (1-2 sentences)
#   questions: list of dicts { lecture, prompt, choices: [String x 3], correct: int }
#
# The correct answer must be findable in the lecture text - that's the
# learning loop. Wrong answers are plausible-but-wrong distractors.
const TEACHERS: Array = [
	{
		"id": "gym",
		"name": "Mr. Caldera",
		"subject": "Gym",
		"texture_path": "res://assets/textures/characters/teachers/Gym.png",
		"intro": "Drop your bags. Today we're talking about something every one of you will need: not pulling a muscle.",
		"questions": [
			{
				"lecture": "Warm-ups raise your muscle temperature and increase blood flow before exertion. A cold muscle is a brittle muscle - it tears under load that a warm one would shrug off. Five minutes of light cardio is enough to make a measurable difference. Skip the warm-up and you're betting your week on a coin flip.",
				"prompt": "Why do we warm up before exercise?",
				"choices": [
					"It burns extra calories before the workout",
					"It raises muscle temperature and blood flow",
					"It tightens the muscles for more power",
				],
				"correct": 1,
			},
			{
				"lecture": "When you sprint, your body switches to anaerobic energy production - burning glucose without oxygen. That's why you can only hold a top sprint for ten or fifteen seconds before your legs start screaming. Long, slow runs are aerobic; they use oxygen and last for hours. Different systems, different fuels.",
				"prompt": "What energy system does a short sprint mainly use?",
				"choices": [
					"Aerobic - it uses oxygen efficiently",
					"Anaerobic - it burns glucose without oxygen",
					"Lipolytic - it burns stored fat",
				],
				"correct": 1,
			},
			{
				"lecture": "Cooling down after exercise is just as important as warming up. Stopping suddenly lets blood pool in your legs and can make you light-headed. A gentle walk for a few minutes keeps the blood circulating and helps clear lactic acid out of the muscles. Lactic acid is what makes you sore the next day.",
				"prompt": "What does a proper cool-down help clear from your muscles?",
				"choices": [
					"Glucose",
					"Lactic acid",
					"Oxygen debt",
				],
				"correct": 1,
			},
		],
	},
	{
		"id": "history",
		"name": "Ms. Verriden",
		"subject": "History",
		"texture_path": "res://assets/textures/characters/teachers/History.png",
		"intro": "Settle down. Today's lesson is about a war nobody won, which makes it useful to remember.",
		"questions": [
			{
				"lecture": "The Thirty Years' War began in 1618 as a religious conflict between Catholic and Protestant states in the Holy Roman Empire. It widened into a power struggle that pulled in France, Sweden, Spain, and Denmark. By the time it ended in 1648 with the Peace of Westphalia, an estimated eight million people were dead, mostly from famine and disease rather than combat. Westphalia established the modern concept of state sovereignty.",
				"prompt": "What treaty ended the Thirty Years' War?",
				"choices": [
					"The Treaty of Versailles",
					"The Peace of Westphalia",
					"The Congress of Vienna",
				],
				"correct": 1,
			},
			{
				"lecture": "The printing press, invented by Johannes Gutenberg around 1440, made it possible to reproduce books cheaply for the first time in European history. Before that, every book had to be hand-copied by scribes, which is why literacy was a luxury. Within fifty years of the press's invention, an estimated twenty million printed books were in circulation. It is hard to overstate how much this single piece of technology rearranged power in Europe.",
				"prompt": "Who is credited with inventing the printing press around 1440?",
				"choices": [
					"Johannes Gutenberg",
					"Leonardo da Vinci",
					"Galileo Galilei",
				],
				"correct": 0,
			},
			{
				"lecture": "The Silk Road wasn't a single road - it was a network of overland and maritime trade routes connecting China to the Mediterranean. Goods moved in stages, passing through dozens of intermediaries, so a Roman buying Chinese silk almost never met a Chinese seller. Ideas, diseases, and religions traveled the same routes. The Black Death likely reached Europe in the 1340s via Silk Road trade hubs.",
				"prompt": "How did the Black Death likely arrive in Europe?",
				"choices": [
					"Through Viking raiders from the north",
					"Via Silk Road trade hubs",
					"On Spanish ships from the Americas",
				],
				"correct": 1,
			},
		],
	},
	{
		"id": "literature",
		"name": "Mr. Holloway",
		"subject": "Literature",
		"texture_path": "res://assets/textures/characters/teachers/Literature.png",
		"intro": "Open your readers. Today we're looking at how writers say things without saying them.",
		"questions": [
			{
				"lecture": "A metaphor is a direct comparison that says one thing IS another - 'the city is a furnace.' A simile is a comparison that uses 'like' or 'as' - 'the city is like a furnace.' Both create vivid imagery, but the metaphor commits more strongly. Beginning writers often overuse similes because they feel safer, but a well-placed metaphor lands harder.",
				"prompt": "What's the key difference between a metaphor and a simile?",
				"choices": [
					"A metaphor uses 'like' or 'as', a simile doesn't",
					"A simile uses 'like' or 'as', a metaphor doesn't",
					"They mean the same thing and are interchangeable",
				],
				"correct": 1,
			},
			{
				"lecture": "An unreliable narrator is one whose account of events the reader cannot fully trust. The unreliability might come from the narrator being a child, being mentally ill, lying on purpose, or simply being mistaken. Edgar Allan Poe used unreliable narrators famously in 'The Tell-Tale Heart.' The fun of these stories is reading between the lines to figure out what actually happened.",
				"prompt": "Which author is famous for using unreliable narrators in stories like 'The Tell-Tale Heart'?",
				"choices": [
					"Mark Twain",
					"Edgar Allan Poe",
					"Charles Dickens",
				],
				"correct": 1,
			},
			{
				"lecture": "Iambic pentameter is the rhythm Shakespeare used in most of his plays and sonnets. Each line has ten syllables arranged in five pairs, with the stress falling on the second syllable of each pair: da-DUM da-DUM da-DUM da-DUM da-DUM. It mimics natural English speech, which is partly why his lines still feel alive four hundred years later.",
				"prompt": "How many syllables are in a line of iambic pentameter?",
				"choices": [
					"Eight",
					"Ten",
					"Twelve",
				],
				"correct": 1,
			},
		],
	},
	{
		"id": "math",
		"name": "Dr. Sundgren",
		"subject": "Math",
		"texture_path": "res://assets/textures/characters/teachers/Math.png",
		"intro": "Phones away. Today we're proving something a Greek figured out two and a half thousand years ago.",
		"questions": [
			{
				"lecture": "The Pythagorean theorem applies to right triangles - triangles with one ninety-degree angle. It says that the square of the hypotenuse, the side opposite the right angle, equals the sum of the squares of the other two sides. We write it as a squared plus b squared equals c squared. It works for every right triangle, no exceptions, and it's the foundation of distance calculations in geometry.",
				"prompt": "The Pythagorean theorem applies to which kind of triangle?",
				"choices": [
					"Any triangle",
					"Equilateral triangles only",
					"Right triangles only",
				],
				"correct": 2,
			},
			{
				"lecture": "Pi is the ratio of a circle's circumference to its diameter, and the same value works for every circle no matter the size. Pi is irrational - its decimal expansion never ends and never repeats. We usually use 3.14 or 3.14159 for calculations, but mathematicians have computed pi to trillions of digits. None of those extra digits have ever shown a repeating pattern.",
				"prompt": "What does the number pi represent?",
				"choices": [
					"The area of a circle divided by its radius",
					"A circle's circumference divided by its diameter",
					"The angle of a full rotation in radians",
				],
				"correct": 1,
			},
			{
				"lecture": "A prime number is a whole number greater than one that is only divisible by one and itself. Two, three, five, seven, and eleven are the first five primes. Every other whole number can be built from primes by multiplication - this is called the fundamental theorem of arithmetic. Primes get rarer as numbers get larger, but they never stop appearing.",
				"prompt": "Which of these is NOT a prime number?",
				"choices": [
					"Seven",
					"Nine",
					"Eleven",
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
		"intro": "Goggles on the desk. Today's topic is the smallest building blocks we know about.",
		"questions": [
			{
				"lecture": "An atom has three kinds of particles. Protons carry a positive charge and live in the nucleus. Neutrons carry no charge and also live in the nucleus. Electrons carry a negative charge and orbit around the nucleus at much greater distances. The number of protons defines what element the atom is - change the proton count and you change the element entirely.",
				"prompt": "Which particle determines what element an atom is?",
				"choices": [
					"The neutron",
					"The proton",
					"The electron",
				],
				"correct": 1,
			},
			{
				"lecture": "Photosynthesis is how plants make their own food. They take in carbon dioxide from the air through tiny pores in their leaves, absorb water through their roots, and use sunlight to convert these into glucose. Oxygen is released as a byproduct, which is convenient for the rest of us. Without photosynthesis, almost no complex life on Earth would exist.",
				"prompt": "What gas do plants release as a byproduct of photosynthesis?",
				"choices": [
					"Carbon dioxide",
					"Nitrogen",
					"Oxygen",
				],
				"correct": 2,
			},
			{
				"lecture": "Newton's third law of motion says that for every action, there is an equal and opposite reaction. When you push off the ground to jump, the ground pushes back on you with the same force - that reaction is what actually lifts you. Rockets work the same way: hot gas is pushed out the back, and the rocket is pushed forward in response.",
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

# --- Scene refs ---
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var prompt_label: Label = %PromptLabel
@onready var choice_grid: GridContainer = %ChoiceGrid

# --- Run state ---
var _current_teacher: Dictionary = {}
var _current_question: Dictionary = {}
var _scene_phase: SchoolPhase = SchoolPhase.LECTURE

# Running totals that get applied on finish().
var _total_suspicion: int = 0
var _total_ingredients: Dictionary = {}


func _ready() -> void:
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
	dialogue_label.clear()
	dialogue_label.append_text("[i]%s[/i]\n\n%s" % [
		_current_teacher["intro"],
		_current_question["lecture"],
	])

	prompt_label.visible = false
	_clear_choice_buttons()
	choice_grid.visible = false
	_show_corner("CONTINUE")


# --- Question phase ---

func _enter_question() -> void:
	_scene_phase = SchoolPhase.QUESTION

	# Lecture stays visible; we add the prompt and choices below it.
	prompt_label.text = _current_question["prompt"]
	prompt_label.visible = true

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
	# Disable further input while we show feedback.
	for child in choice_grid.get_children():
		if child is Button:
			(child as Button).disabled = true

	var reward: Dictionary
	var feedback: String
	if picked == correct:
		reward = REWARD_CORRECT
		feedback = "[color=#7fdf7f]Correct.[/color] %s nods. \"Good. Pay attention to the rest of you.\"" % _current_teacher["name"]
	else:
		reward = REWARD_WRONG
		var correct_text: String = str(_current_question["choices"][correct])
		feedback = "[color=#df7f7f]Wrong.[/color] %s sighs. \"The answer was: %s. Try to keep up.\"" % [
			_current_teacher["name"],
			correct_text,
		]

	_accumulate_reward(reward)

	# Append feedback to the dialogue, then prompt the player to continue.
	dialogue_label.append_text("\n\n%s" % feedback)

	prompt_label.visible = false
	_show_corner("CLASS ENDS  →")


# --- Post-class phase ---

func _enter_post_class() -> void:
	_scene_phase = SchoolPhase.POST_CLASS

	dialogue_label.append_text("\n\n[i]The bell rings. Chairs scrape. Students start filing out.[/i]\n\n[i]The supply cabinet at the back is unlocked. You can see the small case of manufacturing nanobots inside. Nobody's looking right now.[/i]")

	prompt_label.text = "WHAT DO YOU DO?"
	prompt_label.visible = true

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


# --- Shared ---

func _on_continue_pressed() -> void:
	match _scene_phase:
		SchoolPhase.LECTURE:
			_enter_question()
		SchoolPhase.QUESTION:
			_enter_post_class()
		SchoolPhase.POST_CLASS:
			# Should never hit - corner button is hidden in this phase.
			_finish_school()


## Mount the bottom-right corner button on Main with `label`, bound to
## _on_continue_pressed. Main owns the button node; we just request it.
func _show_corner(label: String) -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("show_corner_button"):
		main.show_corner_button(label, _on_continue_pressed)


func _hide_corner() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()


func _finish_school() -> void:
	# NOTE: do NOT hide the teacher portrait here. Main hides it at the
	# transition's midpoint as part of _apply_selection_screen_swap, so the
	# portrait stays visible until the wipe is covering the frame. Hiding it
	# now would make the portrait vanish before the wipe even begins.
	finish(0, _total_suspicion, 0, _total_ingredients, false)


func _accumulate_reward(reward: Dictionary) -> void:
	_total_suspicion += int(reward.get("suspicion", 0))
	var ingredients: Dictionary = reward.get("ingredients", {})
	for ing_id in ingredients:
		var amt: int = int(ingredients[ing_id])
		_total_ingredients[ing_id] = int(_total_ingredients.get(ing_id, 0)) + amt


func _build_choice_button(label: String) -> Button:
	# Visually matches the home-screen "WHERE WILL YOU GO?" buttons.
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 40)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.clip_text = false
	return btn


func _clear_choice_buttons() -> void:
	for child in choice_grid.get_children():
		child.queue_free()
