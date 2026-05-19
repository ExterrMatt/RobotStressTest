extends LocationBase
## Workshop location — craft ingredients into a leg, then jigsaw the leg
## segments into place.

const REWARD_COLLECT: Dictionary = {
	"money": 0,
	"suspicion": 0,
	"ingredients": {"leg": 1},
}

const CHOICE_BUTTON_HEIGHT: int = 110
const CHOICE_FONT_SIZE: int = 36
const PROMPT_COLOR: String = "#e8c468"

# --- pan geometry ---
const SCALE_MULT: float = 1.8

const PAN_IMAGE_PATHS: Array[String] = [
	"res://assets/textures/backgrounds/large_workshop.png",
	"res://assets/textures/icons/large_workshop.png",
	"res://assets/textures/backgrounds/workshop_pan.png",
	"res://assets/textures/icons/workshop_pan.png",
]

const PAN_WIDTH: float = 500.0
const PAN_SOURCE_HEIGHT: float = 600.0

const INTRO_REGION_Y: float = 0.0
const INTRO_REGION_HEIGHT: float = 125.0

const MINIGAME_REGION_Y: float = PAN_SOURCE_HEIGHT - 400.0  # = 200
const MINIGAME_REGION_HEIGHT: float = 400.0

const PAN_DURATION: float = 0.3
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

	_enter_intro()


# --- atlas + pan ---

func _install_pan_atlas() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not "scene_image" in main:
		return

	# Take manual control of the frame size so Main's default tweens don't fight us
	if main.get("_frame_size_tween") is Tween and main._frame_size_tween.is_valid():
		main._frame_size_tween.kill()
	if main.get("_frame_outer_tween") is Tween and main._frame_outer_tween.is_valid():
		main._frame_outer_tween.kill()
	
	# Lock the outer frame to the upscaled width (900)
	if "frame_outer" in main and main.frame_outer:
		main.frame_outer.custom_minimum_size.x = PAN_WIDTH * SCALE_MULT

	var source_tex: Texture2D = _load_pan_source()
	if source_tex == null:
		push_error("Workshop: NONE of the candidate pan source paths exist on disk.")
		return

	_atlas = AtlasTexture.new()
	_atlas.atlas = source_tex
	_atlas.region = Rect2(0, INTRO_REGION_Y, PAN_WIDTH, INTRO_REGION_HEIGHT)
	_atlas.filter_clip = true

	main.scene_image.texture = _atlas
	# Set inner frame to 900x225 (500x125 * 1.8)
	main.scene_image.custom_minimum_size = Vector2(PAN_WIDTH * SCALE_MULT, INTRO_REGION_HEIGHT * SCALE_MULT)


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
	
	# The atlas region reads native 500x400 source pixels
	_atlas.region = Rect2(0, y, PAN_WIDTH, h)

	var main: Node = get_tree().current_scene
	if main and "scene_image" in main:
		# The visual container stays multiplied by 1.8
		main.scene_image.custom_minimum_size = Vector2(PAN_WIDTH * SCALE_MULT, h * SCALE_MULT)
		if "frame_outer" in main and main.frame_outer:
			main.frame_outer.custom_minimum_size.x = PAN_WIDTH * SCALE_MULT


func _start_pan_to_minigame(on_complete: Callable) -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()

	_pan_tween = create_tween()
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_property(self, "_pan_t", 1.0, PAN_DURATION)
	if on_complete.is_valid():
		_pan_tween.finished.connect(on_complete)


# --- intro phase ---

func _enter_intro() -> void:
	_scene_phase = WorkshopPhase.INTRO
	dialogue_box.visible = true
	dialogue_box.play_pages(Dialogue.get_pages("workshop", "intro"))


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
	_clear_choice_buttons()
	choice_grid.visible = true

	var tinker_btn := _build_choice_button("TINKER")
	tinker_btn.pressed.connect(_on_tinker_pressed)
	choice_grid.add_child(tinker_btn)

	var proceed_btn := _build_choice_button("PROCEED INTO WORKSHOP")
	proceed_btn.pressed.connect(_on_proceed_pressed)
	choice_grid.add_child(proceed_btn)


# --- tinker path ---

func _on_tinker_pressed() -> void:
	_scene_phase = WorkshopPhase.TINKER_DIALOGUE
	_clear_choice_buttons()
	choice_grid.visible = false
	dialogue_box.play_pages(Dialogue.get_pages("workshop", "tinker"))


# --- proceed path ---

func _on_proceed_pressed() -> void:
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

	var main: Node = get_tree().current_scene

	_minigame = WORKSHOP_MINIGAME_SCENE.instantiate()
	
	# --- THE MAGIC FIX ---
	# The UI was built for 500x400. To make it perfectly fit the 900x720 
	# upscaled background, we scale the entire UI layer by 1.8 before mounting it!
	_minigame.scale = Vector2(SCALE_MULT, SCALE_MULT)
	
	if _minigame.has_signal("collected"):
		_minigame.collected.connect(_on_minigame_collected)
	if main and main.has_method("show_scene_overlay"):
		main.show_scene_overlay(_minigame, true)


func _on_minigame_collected() -> void:
	var ingredients: Dictionary = _copy_ingredients(REWARD_COLLECT.get("ingredients", {}))
	finish(
		int(REWARD_COLLECT.get("money", 0)),
		int(REWARD_COLLECT.get("suspicion", 0)),
		0,
		ingredients,
		false,
	)


# --- dialogue routing ---

func _on_dialogue_finished() -> void:
	match _scene_phase:
		WorkshopPhase.INTRO:
			_enter_intro_prompt()
		WorkshopPhase.INTRO_PROMPT:
			_show_intro_choices()
		WorkshopPhase.PROCEED_DIALOGUE:
			_enter_minigame()
		WorkshopPhase.TINKER_DIALOGUE:
			finish(0, 0, 0, {}, true)
		_:
			pass


# --- helpers ---

func _copy_ingredients(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src:
		out[k] = int(src[k])
	return out


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
