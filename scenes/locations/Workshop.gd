extends LocationBase
## Workshop location — craft ingredients into a leg, then jigsaw the leg
## segments into place.

const CHOICE_BUTTON_HEIGHT: int = 110
const CHOICE_FONT_SIZE: int = 36
const PROMPT_COLOR: String = "#e8c468"

# --- pan geometry ---
const PAN_FRAME_SCALE_MULTIPLIER: float = 1.075
const INTRO_PAN_SCALE: float = 1.8 * PAN_FRAME_SCALE_MULTIPLIER
const MINIGAME_PAN_SCALE: float = 1.6 * PAN_FRAME_SCALE_MULTIPLIER
const PAN_START_SHRINK_DURATION: float = 0.2

const PAN_IMAGE_PATHS: Array[String] = [
	"res://assets/textures/backgrounds/large_workshop.png",
	"res://assets/textures/icons/large_workshop.png",
	"res://assets/textures/backgrounds/workshop_pan.png",
	"res://assets/textures/icons/workshop_pan.png",
]

const PAN_WIDTH: float = 500.0
const PAN_SOURCE_HEIGHT: float = 650.0

const INTRO_REGION_Y: float = 0.0
const INTRO_REGION_HEIGHT: float = 125.0
const INTRO_FRAME_SIZE: Vector2 = Vector2(PAN_WIDTH * INTRO_PAN_SCALE, INTRO_REGION_HEIGHT * INTRO_PAN_SCALE)
const INTRO_FRAME_OUTER_WIDTH: float = PAN_WIDTH * INTRO_PAN_SCALE

const MINIGAME_REGION_HEIGHT: float = 400.0
const MINIGAME_REGION_Y: float = PAN_SOURCE_HEIGHT - MINIGAME_REGION_HEIGHT
const MINIGAME_FRAME_SIZE: Vector2 = Vector2(PAN_WIDTH * MINIGAME_PAN_SCALE, MINIGAME_REGION_HEIGHT * MINIGAME_PAN_SCALE)
const MINIGAME_FRAME_OUTER_WIDTH: float = PAN_WIDTH * MINIGAME_PAN_SCALE

const PAN_DURATION: float = 0.55
const PAN_TRANS: int = Tween.TRANS_QUAD
const PAN_EASE: int = Tween.EASE_IN_OUT

const WORKSHOP_MINIGAME_SCENE: PackedScene = preload("res://scenes/locations/WorkshopMinigame.tscn")

enum WorkshopPhase {
	INTRO,
	INTRO_PROMPT,
	INTRO_CHOICES,
	PROCEED_DIALOGUE,
	MINIGAME,
	TINKER_DIALOGUE,
}

@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var choice_grid: GridContainer = %ChoiceGrid

var _scene_phase: WorkshopPhase = WorkshopPhase.INTRO
var _minigame: Node = null
var _atlas: AtlasTexture = null
var _pan_tween: Tween = null
var _pan_controls_frame_size: bool = false
var _intro_workshop: bool = false

var _pan_t: float = 0.0:
	set(value):
		_pan_t = clamp(value, 0.0, 1.0)
		_apply_pan(_pan_t)


func _ready() -> void:
	Dialogue.load_file("workshop", "res://data/dialogue/workshop.dlg")

	choice_grid.visible = false
	_clear_choice_buttons()

	dialogue_box.finished.connect(_on_dialogue_finished)

	_install_pan_atlas()
	_pan_t = 0.0
	_intro_workshop = _is_intro_workshop_scene()
	_hide_end_button()

	_enter_intro()


# --- atlas + pan ---

func _install_pan_atlas() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not "scene_image" in main:
		return

	var source_tex: Texture2D = _load_pan_source()
	if source_tex == null:
		push_error("Workshop: NONE of the candidate pan source paths exist on disk.")
		return

	_atlas = AtlasTexture.new()
	_atlas.atlas = source_tex
	_atlas.region = Rect2(0, INTRO_REGION_Y, PAN_WIDTH, INTRO_REGION_HEIGHT)
	_atlas.filter_clip = true

	main.scene_image.texture = _atlas


func _load_pan_source() -> Texture2D:
	for path in PAN_IMAGE_PATHS:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex:
				return tex
	return null


func _apply_pan(t: float) -> void:
	if _atlas == null:
		return

	var y: float = lerp(INTRO_REGION_Y, MINIGAME_REGION_Y, t)
	var h: float = lerp(INTRO_REGION_HEIGHT, MINIGAME_REGION_HEIGHT, t)
	var scale_value: float = lerpf(INTRO_PAN_SCALE, MINIGAME_PAN_SCALE, t)
	
	_atlas.region = Rect2(0, y, PAN_WIDTH, h)

	var main: Node = get_tree().current_scene
	if main and "scene_image" in main:
		if not _pan_controls_frame_size:
			return
		var frame_size := Vector2(PAN_WIDTH * scale_value, h * scale_value)
		var outer_width := lerpf(INTRO_FRAME_OUTER_WIDTH, MINIGAME_FRAME_OUTER_WIDTH, t)
		if main.has_method("_set_frame_size_immediate_exact"):
			main._set_frame_size_immediate_exact(frame_size, outer_width)
		elif main.has_method("_set_frame_size_immediate"):
			main._set_frame_size_immediate(frame_size, outer_width)
		else:
			main.scene_image.custom_minimum_size = frame_size
			if "frame_outer" in main and main.frame_outer:
				main.frame_outer.custom_minimum_size.x = outer_width


func _start_pan_to_minigame(on_complete: Callable) -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()

	_pan_controls_frame_size = false
	await _shrink_to_pan_start()
	_pan_controls_frame_size = true
	_pan_t = 0.0
	_pan_tween = create_tween()
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_property(self, "_pan_t", 1.0, PAN_DURATION)
	if on_complete.is_valid():
		_pan_tween.finished.connect(on_complete)


func _shrink_to_pan_start() -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_animate_frame_to"):
		main._animate_frame_to(
			INTRO_FRAME_SIZE,
			INTRO_FRAME_OUTER_WIDTH,
			PAN_START_SHRINK_DURATION,
			false
		)
		await get_tree().create_timer(PAN_START_SHRINK_DURATION).timeout
	elif main != null and main.has_method("_set_frame_size_immediate_exact"):
		main._set_frame_size_immediate_exact(INTRO_FRAME_SIZE, INTRO_FRAME_OUTER_WIDTH)


# --- intro phase ---

func _enter_intro() -> void:
	_scene_phase = WorkshopPhase.INTRO
	dialogue_box.visible = true
	var dialogue_key := "intro_head" if _intro_workshop else "intro"
	dialogue_box.play_pages(Dialogue.get_pages("workshop", dialogue_key))


func _enter_intro_prompt() -> void:
	_scene_phase = WorkshopPhase.INTRO_PROMPT
	_clear_choice_buttons()
	choice_grid.visible = false

	dialogue_box.visible = true
	var prompt_text: String = "What do you do?"
	var gold_prompt: String = "[center][color=%s]%s[/color][/center]" % [PROMPT_COLOR, prompt_text]
	dialogue_box.play_pages_autosized([[gold_prompt]], [48, 36, 24, 16], 2)
	_auto_advance_intro_prompt(prompt_text)


func _auto_advance_intro_prompt(prompt_text: String) -> void:
	var type_duration: float = float(prompt_text.length()) / dialogue_box.chars_per_second
	await get_tree().create_timer(type_duration + 1.0).timeout
	if _scene_phase != WorkshopPhase.INTRO_PROMPT:
		return
	dialogue_box.hide_advance_arrow()
	_show_intro_choices()


func _show_intro_choices() -> void:
	_scene_phase = WorkshopPhase.INTRO_CHOICES
	lock_entry_input()
	_clear_choice_buttons()
	choice_grid.visible = true

	var tinker_btn := _build_choice_button("TINKER")
	tinker_btn.pressed.connect(_on_tinker_pressed)
	choice_grid.add_child(tinker_btn)

	var construct_btn := _build_choice_button("CONSTRUCT A LIMB")
	construct_btn.pressed.connect(_on_construct_limb_pressed)
	choice_grid.add_child(construct_btn)


# --- tinker path ---

func _on_tinker_pressed() -> void:
	_scene_phase = WorkshopPhase.TINKER_DIALOGUE
	_clear_choice_buttons()
	choice_grid.visible = false
	dialogue_box.play_pages(Dialogue.get_pages("workshop", "tinker"))


# --- proceed path ---

func _on_construct_limb_pressed() -> void:
	_scene_phase = WorkshopPhase.PROCEED_DIALOGUE
	_clear_choice_buttons()
	choice_grid.visible = false
	dialogue_box.play_pages(Dialogue.get_pages("workshop", "proceed"))


# --- minigame phase ---

func _enter_minigame() -> void:
	_scene_phase = WorkshopPhase.MINIGAME

	dialogue_box.visible = false
	choice_grid.visible = false
	_clear_choice_buttons()

	_start_pan_to_minigame(_on_pan_complete)


func _on_pan_complete() -> void:
	_pan_t = 1.0
	lock_entry_input()

	var main: Node = get_tree().current_scene

	_minigame = WORKSHOP_MINIGAME_SCENE.instantiate()
	if _intro_workshop and _minigame is WorkshopMinigame:
		(_minigame as WorkshopMinigame).forced_part_id = "head"
	
	# The UI was built for the 500x400 source region; scale it with the
	# final cropped background so the interaction layer stays locked to it.
	_minigame.scale = Vector2(MINIGAME_PAN_SCALE, MINIGAME_PAN_SCALE)
	
	if _minigame.has_signal("collected"):
		_minigame.collected.connect(_on_minigame_collected)
	if _minigame.has_signal("ended"):
		_minigame.ended.connect(_on_end_button_pressed)
	_configure_minigame_end_button()
	if main and main.has_method("show_scene_overlay"):
		main.show_scene_overlay(_minigame, true)


func _hide_end_button() -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("hide_corner_button"):
		main.hide_corner_button()


func _configure_minigame_end_button() -> void:
	if _minigame == null:
		return
	var end_button := _minigame.get_node_or_null("EndButton") as Button
	if end_button == null:
		return
	var available := not _intro_workshop
	end_button.visible = available
	end_button.disabled = not available


func _on_end_button_pressed() -> void:
	if _intro_workshop:
		return
	finish(0, 0, 0, {}, false)


func _on_minigame_collected(part_id: String) -> void:
	var ingredients: Dictionary = {part_id: 1}
	finish(
		0,
		0,
		0,
		ingredients,
		false,
	)


# --- dialogue routing ---

func _on_dialogue_finished() -> void:
	match _scene_phase:
		WorkshopPhase.INTRO:
			if _intro_workshop:
				_enter_minigame()
				return
			_enter_intro_prompt()
		WorkshopPhase.INTRO_PROMPT:
			_show_intro_choices()
		WorkshopPhase.PROCEED_DIALOGUE:
			_enter_minigame()
		WorkshopPhase.TINKER_DIALOGUE:
			finish(0, 0, 0, {}, true)
		_:
			pass
func _build_choice_button(label: String) -> Button:
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


func _is_intro_workshop_scene() -> bool:
	if bool(get_meta("intro_sequence_location", false)) and String(get_meta("intro_step", "")) == "workshop":
		return true
	var main := get_tree().current_scene
	if main != null \
			and main.has_method("is_intro_sequence_location_active") \
			and bool(main.call("is_intro_sequence_location_active", &"workshop")):
		return true
	return false
