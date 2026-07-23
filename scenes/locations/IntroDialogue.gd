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

@onready var dialogue_box: DialogueBox = %DialogueBox

var _intro_key: String = ""
var _store_outro_home_visual_applied: bool = false
var _robot_eyes_open_applied: bool = false
var _robot_hello_page_index: int = ROBOT_FIRST_TALK_HELLO_PAGE_INDEX
var _name_prompt_panel: Control = null
var _name_line_edit: LineEdit = null


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
	dialogue_box.play_pages(Dialogue.get_pages("intro", _intro_key, _intro_format_vars()))


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
	_build_name_prompt_panel()
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
	_name_line_edit.placeholder_text = GameState.DEFAULT_PLAYER_NAME
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


func _accept_player_name() -> void:
	GameState.set_player_name(_name_line_edit.text)
	if _name_prompt_panel != null:
		_name_prompt_panel.visible = false
	dialogue_box.visible = true
	_apply_intro_visuals(_intro_key)
	# The name is often submitted by pressing Enter. In debug mode a held Enter
	# would otherwise seed a hold-skip and eat the uncle's first line, so make
	# this Enter act purely as a "click continue" on the newly shown dialogue.
	dialogue_box.suppress_next_enter_hold()
	dialogue_box.play_pages(Dialogue.get_pages("intro", _intro_key, _intro_format_vars()))


func _on_name_text_changed(new_text: String) -> void:
	var normalized := GameState.normalize_player_name(new_text)
	if normalized == new_text:
		return
	var caret_column := _name_line_edit.caret_column
	_name_line_edit.text = normalized
	_name_line_edit.caret_column = mini(caret_column, normalized.length())


func _on_dialogue_finished() -> void:
	finish(0, 0, 0, {}, false)


func _on_page_advanced(index: int) -> void:
	if _intro_key == "robot_first_talk":
		if not _robot_eyes_open_applied and index >= _robot_hello_page_index:
			_robot_eyes_open_applied = true
			_set_scene_image(ROBOT_EYES_OPEN_BACKGROUND_TEXTURE_PATH)
		return
	if _intro_key != "store_outro":
		return
	if _store_outro_home_visual_applied:
		return
	if index < STORE_OUTRO_HOME_PAGE_INDEX:
		return
	_store_outro_home_visual_applied = true
	var main := get_tree().current_scene
	if main != null and main.has_method("_play_transition_then"):
		main._play_transition_then(Callable(self, "_show_store_outro_home_visuals"))
	else:
		_show_store_outro_home_visuals()


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
