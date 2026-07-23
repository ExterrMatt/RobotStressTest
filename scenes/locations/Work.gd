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
const FACTORY_LIGHTS_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/factory_lights.png"
const FACTORY_HALLWAY_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/factory_hallway.png"
const FACTORY_BOX_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/factory_box.png"
const WORK_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/work.png"
const WORK_SCRAP_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/work_scrap.png"
## The work-disruption robot call (first upper-arm shift after the intro) plays
## over a placeholder background at this frame size until its own 500x125 art
## exists.
const WORK_DISRUPTION_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/scene_placeholder.png"
const WORK_DISRUPTION_FRAME_SIZE: Vector2 = Vector2(500.0, 125.0)
const DEFAULT_DIALOGUE_FRAME_SIZE: Vector2 = Vector2(900.0, 225.0)
const WORK_FRAME_SIZE: Vector2 = Vector2(800.0, 640.0)
const WORK_FRAME_OUTER_WIDTH: float = 800.0
const INTRO_HEAD_BOX_LOOK_PAGE_INDEX: int = 4
const WORK_TIME_LIMIT_SECONDS: float = 60.0

## Second Work minigame: assemble the robot's upper arm instead of sorting
## shapes. A normal (non-intro) shift randomly runs one or the other.
const ARM_MINIGAME_SCENE: PackedScene = preload("res://scenes/locations/WorkArmMinigame.tscn")

## Two-phase scene flow. The minigame runs in MINIGAME; the completion
## screen lives in COMPLETION_PROMPT (typing the gold question) and
## COMPLETION_CHOICES (buttons up, waiting on the player).
enum WorkPhase {
	INTRO_JOB,
	MINIGAME,
	INTRO_HEAD_BOX,
	COMPLETION_INTRO,
	COMPLETION_PROMPT,
	COMPLETION_CHOICES,
	WORK_DISRUPTION,   # scripted robot call after the first upper-arm shift
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
var _intro_work: bool = false
var _intro_box_open_visual_applied: bool = false
var _work_elapsed_seconds: float = 0.0
var _work_timed_out: bool = false
## When true, this shift runs the upper-arm assembly minigame instead of the
## shape-sorting one. Only ever set for a normal (non-intro) shift.
var _arm_variant: bool = false
var _arm_minigame: WorkArmMinigame = null


func _ready() -> void:
	Dialogue.load_file("work", "res://data/dialogue/work.dlg")
	# Completion-screen widgets are hidden until the minigame finishes.
	_set_node_visible(dialogue_box, false)
	_set_node_visible(choice_grid, false)
	_set_node_visible(furniture_layer, false)
	_set_node_visible(work_inventory, false)

	# Clear any leftover choice buttons from a previous run.
	_clear_choice_buttons()

	# Hook the box's finished signal so we can route to the choice phase
	# once the gold prompt is done typing out.
	dialogue_box.finished.connect(_on_dialogue_finished)
	dialogue_box.page_advanced.connect(_on_dialogue_page_advanced)

	_intro_work = _is_intro_work_scene()
	set_process(false)
	if _intro_work:
		_enter_intro_job()
		return

	# A normal shift randomly runs either the shape-sorting minigame or the
	# upper-arm assembly minigame. The intro shift always uses the shapes.
	_arm_variant = randi() % 2 == 0
	_show_work_minigame()


func _process(delta: float) -> void:
	if _scene_phase != WorkPhase.MINIGAME or _work_timed_out:
		return
	# Debug speedrun: a held Enter fills every slot with its matching piece so
	# the shift completes without manual dragging.
	if debug_enter_held():
		if _arm_variant:
			if _arm_minigame != null and is_instance_valid(_arm_minigame):
				_arm_minigame.debug_auto_solve()
		elif work_inventory != null and not work_inventory.is_complete():
			work_inventory.auto_solve()
	_work_elapsed_seconds += delta
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("set_work_hud_elapsed_seconds"):
		main.set_work_hud_elapsed_seconds(_work_elapsed_seconds)
	if not _intro_work and _work_elapsed_seconds >= WORK_TIME_LIMIT_SECONDS:
		_finish_work_timeout()


## Debug (number-6 key, routed from Main): drop every shape into its matching
## slot so the shift completes without manual dragging. Same effect as the
## held-Enter speedrun, but as a single keypress.
func debug_auto_solve() -> void:
	if _scene_phase != WorkPhase.MINIGAME:
		return
	if _arm_variant:
		if _arm_minigame != null and is_instance_valid(_arm_minigame):
			_arm_minigame.debug_auto_solve()
		return
	if work_inventory != null and not work_inventory.is_complete():
		work_inventory.auto_solve()


func _show_work_minigame() -> void:
	if _arm_variant:
		_show_arm_work_minigame()
		return

	var main: Node = get_tree().current_scene
	_scene_phase = WorkPhase.MINIGAME
	_work_timed_out = false
	_work_elapsed_seconds = 0.0
	_set_node_visible(color_background, true)
	_set_node_visible(furniture_layer, true)
	_set_node_visible(work_inventory, true)

	if main != null:
		if main.has_method("set_work_hud_timer_active"):
			main.set_work_hud_timer_active(true)
		if main.has_method("set_work_hud_elapsed_seconds"):
			main.set_work_hud_elapsed_seconds(0.0)
		_set_main_scene_image_and_frame(
			WORK_BACKGROUND_TEXTURE_PATH,
			WORK_FRAME_SIZE,
			WORK_FRAME_OUTER_WIDTH
		)
		call_deferred("_refresh_work_minigame_scene_image")

	# Hand the furniture layer off to Main so it sits inside the framed picture.
	if main and main.has_method("show_scene_overlay") and furniture_layer:
		main.show_scene_overlay(furniture_layer)

	# Hand the inventory columns off to Main so they sit in the side strips.
	if main and main.has_method("show_inventory_overlay") and work_inventory:
		main.show_inventory_overlay(work_inventory)

	# Listen for slot fills so we know when the puzzle is complete.
	if work_inventory:
		work_inventory.slots_changed.connect(_on_slots_changed)
	set_process(true)


## Upper-arm variant of the shift. Same Work chrome (factory background, frame,
## HUD timer) but the shape-sorting furniture/inventory are left hidden; instead
## a WorkArmMinigame supplies a table-top assembly area and two tall side
## containers of arm segments. Finishing routes to the same completion screen.
func _show_arm_work_minigame() -> void:
	var main: Node = get_tree().current_scene
	_scene_phase = WorkPhase.MINIGAME
	_work_timed_out = false
	_work_elapsed_seconds = 0.0
	_set_node_visible(color_background, true)
	# The shape-sorting furniture and inventory stay hidden this shift.
	_set_node_visible(furniture_layer, false)
	_set_node_visible(work_inventory, false)

	if main != null:
		if main.has_method("set_work_hud_timer_active"):
			main.set_work_hud_timer_active(true)
		if main.has_method("set_work_hud_elapsed_seconds"):
			main.set_work_hud_elapsed_seconds(0.0)
		_set_main_scene_image_and_frame(
			WORK_BACKGROUND_TEXTURE_PATH,
			WORK_FRAME_SIZE,
			WORK_FRAME_OUTER_WIDTH
		)
		call_deferred("_refresh_work_minigame_scene_image")

	_arm_minigame = ARM_MINIGAME_SCENE.instantiate() as WorkArmMinigame
	add_child(_arm_minigame)
	_arm_minigame.completed.connect(_on_arm_minigame_completed)

	# The table + assembly go on the framed picture; the two side containers go
	# in the strips beside it (like the shape minigame's inventory columns).
	if main != null and main.has_method("show_scene_overlay"):
		main.show_scene_overlay(_arm_minigame.furniture, true)
	if main != null and main.has_method("show_inventory_overlay"):
		main.show_inventory_overlay(_arm_minigame.side_containers)
	_arm_minigame.begin()

	set_process(true)


func _on_arm_minigame_completed() -> void:
	if _scene_phase != WorkPhase.MINIGAME:
		return
	if _arm_minigame != null and is_instance_valid(_arm_minigame):
		_arm_minigame.set_process(false)
		_arm_minigame.set_process_input(false)
	# The first upper-arm shift after the intro plays the scripted robot call
	# instead of the normal completion/steal screen: the arm gets stolen as part
	# of that call, so there's no separate scrap steal choice.
	if _should_play_work_disruption():
		_enter_work_disruption()
		return
	_enter_completion_screen()


## The scripted work-disruption call plays exactly once: the first time the
## player finishes the upper-arm assembly minigame after the intro has ended.
func _should_play_work_disruption() -> bool:
	return not _intro_work \
			and GameState.intro_completed \
			and not GameState.robot_work_disruption_seen


func _enter_intro_job() -> void:
	_scene_phase = WorkPhase.INTRO_JOB
	_show_intro_placeholder()
	_set_node_visible(dialogue_box, true)
	_set_node_visible(choice_grid, false)
	dialogue_box.play_pages(Dialogue.get_pages("work", "intro_job"))


func _show_intro_placeholder() -> void:
	_disable_work_hud_timer()
	set_process(false)
	_set_node_visible(color_background, false)
	_set_node_visible(furniture_layer, false)
	_set_node_visible(work_inventory, false)

	var main: Node = get_tree().current_scene
	if main == null:
		return
	if main.has_method("hide_scene_overlay"):
		main.hide_scene_overlay()
	if main.has_method("hide_inventory_overlay"):
		main.hide_inventory_overlay()
	if main.has_method("hide_corner_button"):
		main.hide_corner_button()
	_set_main_scene_image_and_frame(
		FACTORY_LIGHTS_BACKGROUND_TEXTURE_PATH,
		DEFAULT_DIALOGUE_FRAME_SIZE,
		_default_main_frame_outer_width(main)
	)


func _on_slots_changed(filled_count: int) -> void:
	# Show the finish/steal choices only when all four slots are filled.
	if filled_count >= 4 and work_inventory != null and work_inventory.is_complete():
		if _is_intro_work_scene():
			_intro_work = true
			_enter_intro_head_box()
			return
		_enter_completion_screen()


func _enter_intro_head_box() -> void:
	if _scene_phase != WorkPhase.MINIGAME:
		return

	_disable_work_hud_timer()
	set_process(false)
	_scene_phase = WorkPhase.INTRO_HEAD_BOX
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_play_transition_then"):
		main._play_transition_then(Callable(self, "_apply_intro_head_box"))
	else:
		_apply_intro_head_box()


func _apply_intro_head_box() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_scene_overlay"):
		main.hide_scene_overlay()
	if main and main.has_method("hide_inventory_overlay"):
		main.hide_inventory_overlay()
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()
	_set_node_visible(color_background, false)
	_set_main_scene_image_and_frame(
		FACTORY_HALLWAY_BACKGROUND_TEXTURE_PATH,
		DEFAULT_DIALOGUE_FRAME_SIZE,
		_default_main_frame_outer_width(main)
	)

	_scene_phase = WorkPhase.INTRO_HEAD_BOX
	_intro_box_open_visual_applied = false
	_set_node_visible(dialogue_box, true)
	_set_node_visible(choice_grid, false)
	dialogue_box.play_pages(Dialogue.get_pages("work", "intro_head_box"))


func _on_dialogue_page_advanced(index: int) -> void:
	if _scene_phase != WorkPhase.INTRO_HEAD_BOX:
		return
	if index == INTRO_HEAD_BOX_LOOK_PAGE_INDEX and not _intro_box_open_visual_applied:
		_intro_box_open_visual_applied = true
		var main: Node = get_tree().current_scene
		if main != null and main.has_method("_play_transition_then"):
			main._play_transition_then(_set_scene_image.bind(FACTORY_BOX_BACKGROUND_TEXTURE_PATH))
		else:
			_set_scene_image(FACTORY_BOX_BACKGROUND_TEXTURE_PATH)


func _set_scene_image(texture_path: String) -> void:
	_set_main_scene_image_and_frame(
		texture_path,
		DEFAULT_DIALOGUE_FRAME_SIZE,
		_default_main_frame_outer_width(get_tree().current_scene)
	)


func _set_main_scene_image_and_frame(
		texture_path: String,
		frame_size: Vector2,
		outer_width: float
) -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	if not ("scene_image" in main):
		return
	var texture := load(texture_path) as Texture2D
	if texture != null:
		main.scene_image.texture = texture
	if main.has_method("_animate_frame_to"):
		main._animate_frame_to(frame_size, outer_width)


func _default_main_frame_outer_width(main: Node) -> float:
	if main != null and "_default_frame_outer_width" in main:
		return main._default_frame_outer_width
	return DEFAULT_DIALOGUE_FRAME_SIZE.x


func _refresh_work_minigame_scene_image() -> void:
	if _scene_phase != WorkPhase.MINIGAME:
		return
	_set_main_scene_image_and_frame(
		WORK_BACKGROUND_TEXTURE_PATH,
		WORK_FRAME_SIZE,
		WORK_FRAME_OUTER_WIDTH
	)


func _enter_completion_screen() -> void:
	# Guard against re-entry if slots_changed fires more than once.
	if _scene_phase != WorkPhase.MINIGAME:
		return
	if _is_intro_work_scene():
		_intro_work = true
		_enter_intro_head_box()
		return

	_disable_work_hud_timer()
	set_process(false)
	_scene_phase = WorkPhase.COMPLETION_INTRO
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_play_transition_then"):
		main._play_transition_then(Callable(self, "_apply_completion_screen"))
	else:
		_apply_completion_screen()


## Tears down the in-frame minigame visuals (overlays, side containers, the arm
## controller node, the grey backdrop) so a dialogue screen has room below.
## Shared by the normal completion screen and the work-disruption call.
func _teardown_work_minigame_visuals() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_scene_overlay"):
		main.hide_scene_overlay()
	if main and main.has_method("hide_inventory_overlay"):
		main.hide_inventory_overlay()
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()

	# The arm minigame's furniture/side-container subtrees were freed by the
	# hide_* calls above; drop the now-empty controller node too.
	if _arm_minigame != null and is_instance_valid(_arm_minigame):
		_arm_minigame.queue_free()
	_arm_minigame = null

	# Drop the opaque grey backdrop so the dialogue screen matches School's
	# starfield-on-dark look. The minigame uses it to focus attention on the
	# work area; on the dialogue screen it would just be a distracting slab.
	_set_node_visible(color_background, false)


func _apply_completion_screen() -> void:
	_teardown_work_minigame_visuals()
	var main: Node = get_tree().current_scene

	# Show the scrap-focused work image for the completion dialogue and
	# steal-or-finish choice.
	_set_main_scene_image_and_frame(
		WORK_SCRAP_BACKGROUND_TEXTURE_PATH,
		DEFAULT_DIALOGUE_FRAME_SIZE,
		_default_main_frame_outer_width(main)
	)
	# We shrink the frame from the large minigame back to the standard size,
	# and the animated resize marks the new texture as "seen" — which defeats
	# the passive texture-swap watcher that would re-evaluate the presentation.
	# Re-run it explicitly so the standard scrap image drops into the full-bleed
	# look (gold corner pills) instead of the fallback HUD bar, matching School.
	if main and main.has_method("_apply_scene_presentation_mode"):
		main._apply_scene_presentation_mode()

	_enter_completion_intro()


# --- Work-disruption phase (scripted robot call after the arm shift) ---

func _enter_work_disruption() -> void:
	# One-time: mark it seen the moment it starts so it never replays.
	GameState.robot_work_disruption_seen = true
	_disable_work_hud_timer()
	set_process(false)
	_scene_phase = WorkPhase.WORK_DISRUPTION
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_play_transition_then"):
		main._play_transition_then(Callable(self, "_apply_work_disruption_screen"))
	else:
		_apply_work_disruption_screen()


func _apply_work_disruption_screen() -> void:
	_teardown_work_minigame_visuals()
	var main: Node = get_tree().current_scene
	# The call has its own unique 500x125 background; until that art exists it
	# runs over the generic placeholder.
	_set_main_scene_image_and_frame(
		WORK_DISRUPTION_BACKGROUND_TEXTURE_PATH,
		WORK_DISRUPTION_FRAME_SIZE,
		WORK_DISRUPTION_FRAME_SIZE.x
	)
	if main and main.has_method("_apply_scene_presentation_mode"):
		main._apply_scene_presentation_mode()

	_set_node_visible(choice_grid, false)
	_set_node_visible(dialogue_box, true)
	await get_tree().process_frame
	dialogue_box.play_pages(Dialogue.get_pages("work", "robot_work_disruption"))

# --- Completion intro phase (italic scene-setting before the prompt) ---
# --- Completion intro phase (italic scene-setting before the prompt) ---

func _enter_completion_intro() -> void:
	_scene_phase = WorkPhase.COMPLETION_INTRO
	_clear_choice_buttons()
	_set_node_visible(choice_grid, false)

	_set_node_visible(dialogue_box, true)
	await get_tree().process_frame
	dialogue_box.play_pages(Dialogue.get_pages("work", "completion"))


# --- Completion prompt phase (gold "What do you do?" types out) ---

func _enter_completion_prompt() -> void:
	_scene_phase = WorkPhase.COMPLETION_PROMPT
	_clear_choice_buttons()
	_set_node_visible(choice_grid, false)

	_set_node_visible(dialogue_box, true)
	var prompt_text: String = dlg_line("work", "completion.prompt")
	var gold_prompt: String = "[center][color=%s]%s[/color][/center]" % [PROMPT_COLOR, prompt_text]
	# Font ladder bumped by 6 from the base [48, 36, 24, 16].
	dialogue_box.play_pages_autosized([[gold_prompt]], [54, 42, 30, 22], 2)
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
	lock_entry_input()
	_clear_choice_buttons()
	_set_node_visible(choice_grid, true)

	var finish_btn := _build_choice_button(dlg_line("work", "completion.finish"))
	finish_btn.pressed.connect(_on_finish_pressed)
	choice_grid.add_child(finish_btn)

	var steal_btn := _build_choice_button(dlg_line("work", "completion.steal"))
	steal_btn.pressed.connect(_on_steal_pressed)
	choice_grid.add_child(steal_btn)


# --- Dialogue routing ---

func _on_dialogue_finished() -> void:
	match _scene_phase:
		WorkPhase.INTRO_JOB:
			_set_node_visible(dialogue_box, false)
			var main: Node = get_tree().current_scene
			if main != null and main.has_method("_play_transition_then"):
				main._play_transition_then(Callable(self, "_show_work_minigame"))
			else:
				_show_work_minigame()
		WorkPhase.INTRO_HEAD_BOX:
			_finish_intro_work()
		WorkPhase.COMPLETION_INTRO:
			_enter_completion_prompt()
		WorkPhase.COMPLETION_PROMPT:
			_show_completion_choices()
		WorkPhase.WORK_DISRUPTION:
			# The robot talked the player into pocketing the arm; the shift ends
			# there, with no separate scrap steal choice.
			_finish_work_arm_disruption()
		_:
			pass


func _exit_tree() -> void:
	_disable_work_hud_timer()
	var main: Node = get_tree().current_scene
	# If the next location already loaded (e.g. the drone encounter after a
	# shift), it owns the overlays now — don't wipe them on our deferred exit.
	if superseded_by_new_location(main):
		return
	if main and main.has_method("hide_scene_overlay"):
		main.hide_scene_overlay()
	if main and main.has_method("hide_inventory_overlay"):
		main.hide_inventory_overlay()


func _set_node_visible(node: CanvasItem, value: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.visible = value


# --- Button callbacks ---

func _on_finish_pressed() -> void:
	_finish_work(false)


func _on_steal_pressed() -> void:
	_finish_work(true)


# --- Helpers ---

func _finish_work(stole: bool) -> void:
	_disable_work_hud_timer()
	set_process(false)
	var money: int = int(REWARD_COMPLETE.get("money", 0))
	var suspicion: int = int(REWARD_COMPLETE.get("suspicion", 0))
	var ingredients: Dictionary = _copy_ingredients(REWARD_COMPLETE.get("ingredients", {}))

	if stole:
		money += int(REWARD_STEAL.get("money", 0))
		suspicion += int(REWARD_STEAL.get("suspicion", 0))
		_merge_ingredients(ingredients, REWARD_STEAL.get("ingredients", {}))

	var contraband := "scrap metal" if stole else ""
	finish(money, suspicion, 0, ingredients, false, contraband)


## Ends the work-disruption shift: the player completed the shift AND pocketed
## the upper arm the robot pointed out, so they get the normal completion reward
## plus the steal's suspicion, and carry the arm as contraband (the patrol drone
## branches on it). There is no scrap steal here - the arm is the only theft.
func _finish_work_arm_disruption() -> void:
	_disable_work_hud_timer()
	set_process(false)
	var money: int = int(REWARD_COMPLETE.get("money", 0))
	var suspicion: int = int(REWARD_COMPLETE.get("suspicion", 0)) + int(REWARD_STEAL.get("suspicion", 0))
	var ingredients: Dictionary = _copy_ingredients(REWARD_COMPLETE.get("ingredients", {}))
	finish(money, suspicion, 0, ingredients, false, "upper arm")


func _finish_work_timeout() -> void:
	if _work_timed_out:
		return
	_work_timed_out = true
	_disable_work_hud_timer()
	set_process(false)
	finish(0, 0, 0, {}, false)


func _finish_intro_work() -> void:
	_disable_work_hud_timer()
	set_process(false)
	var ingredients: Dictionary = {"head_segments": 1}
	finish(0, 0, 0, ingredients, false)


func _disable_work_hud_timer() -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("set_work_hud_timer_active"):
		main.set_work_hud_timer_active(false)


func _is_intro_work_scene() -> bool:
	if GameState.is_intro_step("work"):
		return true
	if bool(get_meta("intro_sequence_location", false)) and String(get_meta("intro_step", "")) == "work":
		return true
	var main := get_tree().current_scene
	if main != null \
			and main.has_method("is_intro_sequence_location_active") \
			and bool(main.call("is_intro_sequence_location_active", &"work")):
		return true
	return false


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
