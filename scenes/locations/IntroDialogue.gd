extends LocationBase

const ED_SHOP_BACKGROUND_TEXTURE_PATH := "res://assets/textures/backgrounds/ed_shop.png"
const LIVING_ROOM_BACKGROUND_TEXTURE_PATH := "res://assets/textures/backgrounds/living_room_evening.png"
const ROBOT_EYES_SHUT_BACKGROUND_TEXTURE_PATH := "res://assets/textures/backgrounds/robot_eyes_shut.png"
const ROBOT_EYES_OPEN_BACKGROUND_TEXTURE_PATH := "res://assets/textures/backgrounds/robot_eyes_open.png"
const UNCLE_PORTRAIT_SCALE: float = 1.1
const STORE_OUTRO_HOME_PAGE_INDEX: int = 2
## Fallback only. The page where the robot first says "hello" (and her eyes open)
## is found from the dialogue at runtime - see _compute_robot_hello_page_index -
## so the eyes stay in sync with her line no matter how many lines are added or
## removed before it. This constant is used only if that lookup finds nothing.
const ROBOT_FIRST_TALK_HELLO_PAGE_INDEX: int = 5
const ROBOT_FIRST_TALK_HELLO_MATCH: String = "hello"
## Intro steps that show the uncle at home in his blue shirt (a random one of the
## two blue-shirt variants is picked each time — see _apply_intro_visuals). The
## living-room store_outro scene uses the Hawaiian outfit instead.
const BLUE_SHIRT_UNCLE_STEPS: Array[String] = ["exposition", "evening_room"]

## SFX cued off store_outro prose. Each entry fires its sound(s) once, on the
## first page whose (lower-cased) text contains the cue. "sounds" is a sequence
## played back-to-back (each clip starts when the previous finishes):
##   - the player zips their bag shut back in Ed's shop,
##   - Ed leaves the room: the door closes, then he locks it behind him,
##   - the player drops the haul off at their uncle's,
##   - the uncle reaches over and opens the bag.
const DOOR_CLOSE_SOUND_PATH: String = "res://assets/sounds/door/door_close.mp3"
const DOOR_LOCK_SOUND_PATH: String = "res://assets/sounds/door/door_lock.mp3"
## Played when the player confirms their name: a knock, then (after a short delay)
## the door opening.
const NAME_CONFIRM_KNOCK_SOUND_PATH: String = "res://assets/sounds/door/door_knock.mp3"
const NAME_CONFIRM_DOOR_OPEN_SOUND_PATH: String = "res://assets/sounds/door/door_open_2.mp3"
const NAME_CONFIRM_DOOR_OPEN_DELAY_SECONDS: float = 0.75
const ZIP_CLOSING_SOUND_PATH: String = "res://assets/sounds/backpack/zip_closing.mp3"
const ZIP_OPENING_SOUND_PATH: String = "res://assets/sounds/backpack/zip_opening.mp3"
const BACKPACK_DROP_SOUND_PATH: String = "res://assets/sounds/backpack/backpack_drop.mp3"
## The bag-zip in Ed's shop is nudged slightly later so it doesn't land right on
## top of the door close/lock on the same line.
const ZIP_CLOSING_DELAY_SECONDS: float = 0.3
const STORE_OUTRO_SOUND_CUES: Array[Dictionary] = [
	{"cue": "zipping your bag", "sounds": [ZIP_CLOSING_SOUND_PATH], "delay": ZIP_CLOSING_DELAY_SECONDS},
	{"cue": "retreats", "sounds": [DOOR_CLOSE_SOUND_PATH, DOOR_LOCK_SOUND_PATH]},
	{"cue": "drop everything off", "sounds": [BACKPACK_DROP_SOUND_PATH]},
	{"cue": "reaches over to the backpack", "sounds": [ZIP_OPENING_SOUND_PATH]},
]

## Fluorescent-light buzz kept running through the store_outro's Ed's-shop pages
## (it started back in the Store scene) and stopped only once the scene actually
## leaves Ed's for the walk home. Mirrors Store.gd's constants — keep in sync.
const FLUORESCENT_LIGHT_SOUND_PATH: String = "res://assets/sounds/factory_noises/fluorescent_light.mp3"
const FLUORESCENT_LIGHT_VOLUME_SCALE: float = 0.60
## The shop door bell, rung again as the player leaves Ed's for the walk home
## (it also rings on entry, back in the Store scene).
const STORE_BELL_SOUND_PATH: String = "res://assets/sounds/store_bell/store_bell.mp3"

@onready var dialogue_box: DialogueBox = %DialogueBox

var _intro_key: String = ""
## Pages of the currently-playing intro dialogue, so a page_advanced index maps
## back to its prose (used to fire the door close on the "Ed leaves" line).
var _intro_pages: Array = []
## Cues from STORE_OUTRO_SOUND_CUES that have already fired, so each plays once.
var _store_outro_cues_played: Dictionary = {}
var _store_outro_home_visual_applied: bool = false
var _robot_eyes_open_applied: bool = false
var _robot_hello_page_index: int = ROBOT_FIRST_TALK_HELLO_PAGE_INDEX
var _name_prompt_panel: Control = null
var _name_line_edit: LineEdit = null
## A random name from GameState.DEFAULT_PLAYER_NAMES, chosen once when the prompt
## first appears. Shown as the input's placeholder and used as the name if the
## player leaves the field blank, so the suggestion, the confirmation question,
## and the committed name all agree.
var _suggested_default_name: String = ""
## The Yes / No confirmation reuses the school question's look: the question types
## out inside the DialogueBox and the answers appear as ChoiceButtons below it.
var _name_choice_grid: GridContainer = null
var _awaiting_name_confirmation: bool = false
## True from confirming the name until the uncle's dialogue actually starts (the
## door-open beat). The confirmation prompt is left hidden-but-active during this
## window; the flag stops a stray advance on it from ending the intro early.
var _pending_intro_dialogue: bool = false


func _ready() -> void:
	Dialogue.load_file("intro", "res://data/dialogue/intro.dlg")
	dialogue_box.finished.connect(_on_dialogue_finished)
	dialogue_box.page_advanced.connect(_on_page_advanced)
	_intro_key = GameState.intro_step
	if _intro_key.is_empty():
		_intro_key = "exposition"
	if _should_prompt_for_player_name():
		_show_player_name_prompt()
		return
	_apply_intro_visuals(_intro_key)
	# The store_outro opens still inside Ed's shop: pick the fluorescent buzz back
	# up (it was playing in the Store scene) and carry it until we leave for home.
	if _intro_key == "store_outro":
		start_ambient_loop(FLUORESCENT_LIGHT_SOUND_PATH, FLUORESCENT_LIGHT_VOLUME_SCALE)
	_intro_pages = Dialogue.get_pages("intro", _intro_key, _intro_format_vars())
	dialogue_box.play_pages(_intro_pages)


## Placeholders substituted into intro prose. {player_name} is the name the
## player entered (or the default); the robot's wakeup scene uses it.
func _intro_format_vars() -> Dictionary:
	return {"player_name": GameState.get_player_name()}


func _should_prompt_for_player_name() -> bool:
	return _intro_key == "exposition" and GameState.player_name.strip_edges().is_empty()


func _show_player_name_prompt() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()
	dialogue_box.visible = false
	# Pick the suggested name once so the placeholder and the blank-field fallback
	# stay consistent for the whole naming exchange.
	if _suggested_default_name.is_empty():
		_suggested_default_name = GameState.random_default_player_name()
	_build_name_prompt_panel()
	_name_line_edit.placeholder_text = _suggested_default_name
	_name_prompt_panel.visible = true
	_name_line_edit.text = ""
	_name_line_edit.call_deferred("grab_focus")


func _build_name_prompt_panel() -> void:
	if _name_prompt_panel != null:
		return
	var parent := dialogue_box.get_parent() as Control
	if parent == null:
		return

	# Match the DialogueBox's double golden border: an OrnateFrameOuter shell
	# (dark fill + gold border) wrapping an OrnateFrameInner (inner gold line).
	var panel := PanelContainer.new()
	panel.name = "NamePromptPanel"
	panel.theme_type_variation = &"OrnateFrameOuter"
	panel.custom_minimum_size = Vector2(0.0, 140.0)
	panel.visible = false

	var inner_frame := PanelContainer.new()
	inner_frame.name = "InnerFrame"
	inner_frame.theme_type_variation = &"OrnateFrameInner"
	panel.add_child(inner_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	inner_frame.add_child(vbox)

	var label := Label.new()
	label.text = dlg_line("intro", "name_prompt")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	_name_line_edit = LineEdit.new()
	# Placeholder is set to the randomly-chosen suggestion in _show_player_name_prompt.
	_name_line_edit.placeholder_text = _suggested_default_name
	_name_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_line_edit.add_theme_font_size_override("font_size", 28)
	_name_line_edit.text_changed.connect(_on_name_text_changed)
	_name_line_edit.text_submitted.connect(func(_text: String): _accept_player_name())
	row.add_child(_name_line_edit)

	var continue_button := Button.new()
	continue_button.text = "CONTINUE"
	# Same gold-bordered look as the store/maintenance/workshop LEAVE / END
	# buttons so the intro's continue reads as part of the same UI language.
	continue_button.theme_type_variation = &"GoldHudButton"
	continue_button.custom_minimum_size = Vector2(180.0, 48.0)
	continue_button.pressed.connect(_accept_player_name)
	row.add_child(continue_button)

	parent.add_child(panel)
	parent.move_child(panel, dialogue_box.get_index())
	_name_prompt_panel = panel


## Only the player's name (and its wrapping quotes) is tinted gold; the rest of
## the question stays the plain dialogue colour. Matches the school prompt tint.
const NAME_CONFIRM_GOLD_COLOR: String = "#e8c468"
## Choice-button sizing. The school's answers are full sentences at 36; these are
## single short words, so they're set larger to fill the button and read clearly.
const NAME_CONFIRM_CHOICE_HEIGHT: int = 110
const NAME_CONFIRM_CHOICE_FONT_SIZE: int = 52
const NAME_CONFIRM_CHOICE_GAP: float = 14.0
## The question's font ladder / layout, matched to the school question prompt.
const NAME_CONFIRM_PROMPT_FONT_LADDER: Array = [64, 48, 36, 24]
const NAME_CONFIRM_PROMPT_MAX_ROWS: int = 2
const NAME_CONFIRM_PROMPT_LINE_HEIGHT_FACTOR: float = 0.95
const NAME_CONFIRM_PROMPT_LINE_SEPARATION: int = -9


## The player submitted a name (via Enter or CONTINUE). Don't commit it yet -
## first ask them to confirm it with the Yes / No question.
func _accept_player_name() -> void:
	_show_name_confirmation()


## The name that will actually be used for the entered text: the normalized
## entry, or the randomly-suggested default when the field is left blank.
func _prospective_player_name() -> String:
	var normalized := GameState.normalize_player_name(_name_line_edit.text)
	return _suggested_default_name if normalized.is_empty() else normalized


## Show the "Is <name> your name?" question the same way the school shows its
## comprehension question: the line types out inside the DialogueBox (only the
## quoted name tinted gold), then Yes / No ChoiceButtons drop in beneath it.
func _show_name_confirmation() -> void:
	_awaiting_name_confirmation = true
	if _name_prompt_panel != null:
		_name_prompt_panel.visible = false
	dialogue_box.visible = true

	# The box was hidden while the player typed, so its label has no resolved
	# width yet. Auto-sizing now would measure a zero-width label and pick the
	# smallest font (the "tiny first time" bug), so let a couple of layout passes
	# run first. Bail if the player already backed out during the wait.
	await get_tree().process_frame
	await get_tree().process_frame
	if not _awaiting_name_confirmation:
		return

	var name_text := _prospective_player_name()
	# The gold, quoted name is substituted into the question so only it (and its
	# quotes) is tinted; the rest of the sentence stays the plain dialogue colour.
	var gold_name := "[color=%s]\"%s\"[/color]" % [NAME_CONFIRM_GOLD_COLOR, name_text]
	var prompt := "[center]%s[/center]" % dlg_line(
		"intro", "name_confirm", {"player_name": gold_name})
	dialogue_box.play_pages_autosized(
		[[prompt]],
		NAME_CONFIRM_PROMPT_FONT_LADDER,
		NAME_CONFIRM_PROMPT_MAX_ROWS,
		NAME_CONFIRM_PROMPT_LINE_HEIGHT_FACTOR,
		NAME_CONFIRM_PROMPT_LINE_SEPARATION
	)
	# Plain (un-tinted) version, used only to time how long the line takes to type.
	var plain := dlg_line("intro", "name_confirm", {"player_name": "\"%s\"" % name_text})
	_auto_advance_name_confirmation(plain)


## After the question finishes typing, reveal the Yes / No buttons (mirrors the
## school question's auto-advance from prompt to answer choices).
func _auto_advance_name_confirmation(plain_prompt: String) -> void:
	var type_duration: float = float(plain_prompt.length()) / dialogue_box.chars_per_second
	await get_tree().create_timer(type_duration + 1.0).timeout
	if not _awaiting_name_confirmation:
		return
	dialogue_box.hide_advance_arrow()
	_show_name_confirm_choices()


func _show_name_confirm_choices() -> void:
	_build_name_choice_grid()
	if _name_choice_grid == null:
		return
	_clear_name_choice_buttons()
	_name_choice_grid.visible = true

	var yes_btn := _build_name_choice_button("YES")
	yes_btn.pressed.connect(_on_name_confirmed)
	_name_choice_grid.add_child(yes_btn)

	var no_btn := _build_name_choice_button("NO")
	no_btn.pressed.connect(_on_name_rejected)
	_name_choice_grid.add_child(no_btn)

	call_deferred("_place_name_choice_grid_below_dialogue")

	# Debug: if the player is speed-holding Enter, auto-pick YES so the name
	# confirmation doesn't stall a held-Enter run. debug_enter_held() already
	# gates on debug mode.
	if debug_enter_held():
		_on_name_confirmed()


func _build_name_choice_grid() -> void:
	if _name_choice_grid != null:
		return
	_name_choice_grid = GridContainer.new()
	_name_choice_grid.name = "NameChoiceGrid"
	# Two columns so the pair stretches the full dialogue width, as the school's
	# two-choice post-class row does.
	_name_choice_grid.columns = 2
	_name_choice_grid.add_theme_constant_override("h_separation", int(NAME_CONFIRM_CHOICE_GAP))
	_name_choice_grid.add_theme_constant_override("v_separation", int(NAME_CONFIRM_CHOICE_GAP))
	_name_choice_grid.visible = false
	# Parented to the scene root (a plain Control) so it can be positioned freely
	# below the DialogueBox instead of being laid out by the VBox.
	add_child(_name_choice_grid)


## Copy of the school answer button so the Yes / No options read identically.
func _build_name_choice_button(label: String) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"ChoiceButton"
	btn.text = label
	btn.custom_minimum_size = Vector2(0, NAME_CONFIRM_CHOICE_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", NAME_CONFIRM_CHOICE_FONT_SIZE)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.clip_text = true
	return btn


func _clear_name_choice_buttons() -> void:
	if _name_choice_grid == null:
		return
	for child in _name_choice_grid.get_children():
		child.queue_free()


## Pin the choice grid directly beneath the DialogueBox, spanning its width -
## the same placement the school uses for its answer grid.
func _place_name_choice_grid_below_dialogue() -> void:
	if _name_choice_grid == null or not _awaiting_name_confirmation:
		return
	var parent_control := _name_choice_grid.get_parent() as Control
	if parent_control == null:
		return
	var parent_rect: Rect2 = parent_control.get_global_rect()
	var dialogue_rect: Rect2 = dialogue_box.get_global_rect()
	_name_choice_grid.position = Vector2(
		dialogue_rect.position.x - parent_rect.position.x,
		dialogue_rect.end.y - parent_rect.position.y + NAME_CONFIRM_CHOICE_GAP
	)
	_name_choice_grid.size.x = dialogue_rect.size.x


func _hide_name_confirm_choices() -> void:
	_clear_name_choice_buttons()
	if _name_choice_grid != null:
		_name_choice_grid.visible = false


## YES: commit the name and start the intro dialogue.
func _on_name_confirmed() -> void:
	_awaiting_name_confirmation = false
	_hide_name_confirm_choices()
	# Commit the confirmed name - the suggested default when the field was blank,
	# so the saved name matches the one shown in the confirmation question.
	GameState.set_player_name(_prospective_player_name())
	if _name_prompt_panel != null:
		_name_prompt_panel.visible = false
	# Hide the confirmation question and hold the uncle's first line back until he
	# actually walks into view (his line begins in _play_name_confirm_door_sfx).
	dialogue_box.visible = false
	_pending_intro_dialogue = true
	_intro_pages = Dialogue.get_pages("intro", _intro_key, _intro_format_vars())
	# Knock -> door opens -> uncle appears -> he starts speaking.
	_play_name_confirm_door_sfx()


## Knock, a beat, then the door opens - and the uncle only steps into view once
## the door-open sound is halfway through, not the instant it starts. His first
## line is withheld until that moment so he isn't heard talking before he shows.
func _play_name_confirm_door_sfx() -> void:
	play_oneshot_sound(NAME_CONFIRM_KNOCK_SOUND_PATH)
	await get_tree().create_timer(NAME_CONFIRM_DOOR_OPEN_DELAY_SECONDS).timeout
	play_oneshot_sound(NAME_CONFIRM_DOOR_OPEN_SOUND_PATH)
	var door_stream := load(NAME_CONFIRM_DOOR_OPEN_SOUND_PATH) as AudioStream
	var half_length: float = door_stream.get_length() * 0.5 if door_stream != null else 0.0
	if half_length > 0.0:
		await get_tree().create_timer(half_length).timeout
	# The uncle steps in, and only now does his first line begin.
	_apply_intro_visuals(_intro_key)
	dialogue_box.visible = true
	_pending_intro_dialogue = false
	# A held Enter (name submit / debug speed-through) would otherwise instantly
	# skip his first line, so make this Enter act purely as a "click continue".
	dialogue_box.suppress_next_enter_hold()
	dialogue_box.play_pages(_intro_pages)


## NO: drop the confirmation and return to the input so they can try again,
## keeping what they typed so a small fix doesn't mean retyping the whole thing.
func _on_name_rejected() -> void:
	_awaiting_name_confirmation = false
	_hide_name_confirm_choices()
	dialogue_box.visible = false
	if _name_prompt_panel != null:
		_name_prompt_panel.visible = true
		_name_line_edit.call_deferred("grab_focus")


func _on_name_text_changed(new_text: String) -> void:
	var normalized := GameState.normalize_player_name(new_text)
	if normalized == new_text:
		return
	var caret_column := _name_line_edit.caret_column
	_name_line_edit.text = normalized
	_name_line_edit.caret_column = mini(caret_column, normalized.length())


func _on_dialogue_finished() -> void:
	if _awaiting_name_confirmation:
		# The player clicked through the confirmation question before it finished
		# auto-advancing: reveal the Yes / No buttons instead of ending the intro.
		dialogue_box.hide_advance_arrow()
		_show_name_confirm_choices()
		return
	if _pending_intro_dialogue:
		# The name was confirmed but the uncle's dialogue hasn't started yet (the
		# door-open beat). Ignore a stray finish on the leftover confirmation prompt
		# so the intro isn't ended before it has really begun.
		return
	finish(0, 0, 0, {}, false)


func _on_page_advanced(index: int) -> void:
	if _intro_key == "robot_first_talk":
		if not _robot_eyes_open_applied and index >= _robot_hello_page_index:
			_robot_eyes_open_applied = true
			_set_scene_image(ROBOT_EYES_OPEN_BACKGROUND_TEXTURE_PATH)
		return
	if _intro_key != "store_outro":
		return
	_maybe_play_store_outro_sound_cues(index)
	if _store_outro_home_visual_applied:
		return
	if index < STORE_OUTRO_HOME_PAGE_INDEX:
		return
	_store_outro_home_visual_applied = true
	# We've now actually left Ed's shop for the walk home — ring the door bell on
	# the way out and kill the buzz.
	play_oneshot_sound(STORE_BELL_SOUND_PATH, GameState.DEFAULT_SFX_VOLUME_SCALE)
	stop_ambient_loop()
	var main := get_tree().current_scene
	if main != null and main.has_method("_play_transition_then"):
		main._play_transition_then(Callable(self, "_show_store_outro_home_visuals"))
	else:
		_show_store_outro_home_visuals()


## Fire any STORE_OUTRO_SOUND_CUES whose cue appears in the current page's prose
## (bag zip, Ed's door closing+locking, backpack drop, uncle opening the bag).
## Each cue plays once; a single page may trigger more than one (the opening line
## both zips the bag and closes+locks Ed's door).
func _maybe_play_store_outro_sound_cues(index: int) -> void:
	if index < 0 or index >= _intro_pages.size():
		return
	var text := page_to_text(_intro_pages[index]).to_lower()
	for entry in STORE_OUTRO_SOUND_CUES:
		var cue: String = entry["cue"]
		if _store_outro_cues_played.has(cue):
			continue
		if text.contains(cue):
			_store_outro_cues_played[cue] = true
			_fire_store_outro_cue(entry)


## Play a matched cue's sound sequence, honouring an optional per-cue "delay"
## (seconds) before it starts.
func _fire_store_outro_cue(entry: Dictionary) -> void:
	var delay: float = float(entry.get("delay", 0.0))
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	play_oneshot_sequence(entry["sounds"], GameState.DEFAULT_SFX_VOLUME_SCALE)


func _exit_tree() -> void:
	stop_ambient_loop()


func _apply_intro_visuals(key: String) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	if key == "store_outro":
		_set_scene_image(ED_SHOP_BACKGROUND_TEXTURE_PATH)
		if main.has_method("hide_teacher_portrait"):
			main.hide_teacher_portrait()
		return
	if key == "robot_first_talk":
		_robot_hello_page_index = _compute_robot_hello_page_index()
		_set_scene_image(ROBOT_EYES_SHUT_BACKGROUND_TEXTURE_PATH)
		if main.has_method("hide_teacher_portrait"):
			main.hide_teacher_portrait()
		return
	if BLUE_SHIRT_UNCLE_STEPS.has(key):
		# First time we see the uncle (home, morning/evening): blue shirt, one of
		# the two variants picked at random.
		_show_uncle_portrait(UncleWardrobe.random_texture(UncleWardrobe.BLUE_SHIRT))
		return
	if main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()


## Finds the page of robot_first_talk on which she first says "hello", so her
## eyes open exactly on that line. Scanning the dialogue (instead of hardcoding a
## page number) keeps the eyes in sync when lines are added or removed above it.
## Falls back to the authored constant if the line can't be found.
func _compute_robot_hello_page_index() -> int:
	var pages := Dialogue.get_pages("intro", "robot_first_talk")
	for i in pages.size():
		for line in pages[i]:
			if String(line).to_lower().contains(ROBOT_FIRST_TALK_HELLO_MATCH):
				return i
	return ROBOT_FIRST_TALK_HELLO_PAGE_INDEX


func _show_store_outro_home_visuals() -> void:
	# The living-room scene later in the intro: Hawaiian outfit, random variant.
	_set_scene_image(LIVING_ROOM_BACKGROUND_TEXTURE_PATH)
	_show_uncle_portrait(UncleWardrobe.random_texture(UncleWardrobe.HAWAIIAN))
	# Main owns the TV audio so it can carry it through the bedroom/Sleep scenes
	# that follow this one and stop it at the next location.
	var main := get_tree().current_scene
	if main != null and main.has_method("start_living_room_movie"):
		main.start_living_room_movie()


func _show_uncle_portrait(texture_path: String) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var tex := load(texture_path) as Texture2D
	if main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()
	if tex == null:
		return
	if main.has_method("show_bottom_center_portrait"):
		main.show_bottom_center_portrait(tex, UNCLE_PORTRAIT_SCALE, "Uncle")
	elif main.has_method("show_teacher_portrait"):
		main.show_teacher_portrait(tex, "Uncle", "", false)


func _set_scene_image(texture_path: String) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	if not ("scene_image" in main):
		return
	var tex := load(texture_path) as Texture2D
	if tex != null:
		main.scene_image.texture = tex
