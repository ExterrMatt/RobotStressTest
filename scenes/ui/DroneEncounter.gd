extends Control
class_name DroneEncounter
## Patrol-drone street inspection that plays after a regular school or work run.
##
## A short, self-contained cutscene over the park background. The drone is drawn
## as a stack of layers the same way the teacher/uncle portraits sit over the
## scene image: a base drone sprite that is ALWAYS on, plus independent overlays
## composited on top of it:
##   - id     (id.png)      the claw presenting the player's ID
##   - gun    (guns.png)    the drawn weapon
##   - light  (light_1/2)   the camera light, animated for scans / photos
## Each overlay shares the base drone's rect so it lines up; the base stays on
## underneath because the overlays only depict the claw / gun / light, not the
## whole drone.
##
## The dialogue branches on whether the player stole the previous scene's
## contraband. Layer changes are driven off the dialogue page that narrates
## them (ID handed over / returned, gun drawn, photo snapped).

signal finished

const DIALOGUE_BOX_SCENE: PackedScene = preload("res://scenes/ui/DialogueBox.tscn")

# --- assets ---
const BACKGROUND_PATH: String = "res://assets/textures/backgrounds/park.png"
const DRONE_BASE: String = "res://assets/textures/characters/drone/drone.png"
const DRONE_ID: String = "res://assets/textures/characters/drone/id.png"
const DRONE_GUN: String = "res://assets/textures/characters/drone/guns.png"
const DRONE_LIGHT_1: String = "res://assets/textures/characters/drone/light_1.png"
const DRONE_LIGHT_2: String = "res://assets/textures/characters/drone/light_2.png"
## Kept alongside the other drone art for a future feature (the drone actually
## firing); intentionally unused by this encounter.
const DRONE_GUN_SHOT: String = "res://assets/textures/characters/drone/guns_shot.png"

## Total length of a light blink (scan or photo).
const LIGHT_ANIM_SECONDS: float = 0.5
## The light animation is light_1 for the first 40%, light_2 for the middle 20%,
## then light_1 again for the final 40%.
const LIGHT_PHASE_1: float = 0.4
const LIGHT_PHASE_2: float = 0.2

## Vertical space (px) reserved at the bottom for the dialogue box; the drone is
## laid out above it.
const DIALOGUE_RESERVED: float = 235.0

# Suspicion thresholds that colour the drone's clean-scan sign-off line.
const SUSPICION_CRIMINAL: int = 50
const SUSPICION_ACKNOWLEDGED: int = 75

# --- inputs (set via configure() before the node enters the tree) ---
var _place: String = "work"
var _contraband: String = ""

# --- nodes ---
var _drone_stage: Control = null
var _layer_base: TextureRect = null
var _layer_id: TextureRect = null
var _layer_gun: TextureRect = null
var _layer_light: TextureRect = null
var _dialogue_box: DialogueBox = null

# Per-page callables, parallel to the pages handed to the DialogueBox. Entry i
# runs when page i begins (ID on/off, gun out, light blink...).
var _page_actions: Array[Callable] = []
## Bumped whenever a new light action starts so a stale in-flight blink bails.
var _light_serial: int = 0


## Called by Main before add_child so _ready has the branch inputs it needs.
## `place` is "school" or "work"; `contraband` is the stolen item's display
## name (empty when the player left clean).
func configure(place: String, contraband: String) -> void:
	_place = place
	_contraband = contraband


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	get_viewport().size_changed.connect(_layout_drone)
	_layout_drone()
	_start()


func _build_ui() -> void:
	# Solid fill behind the park in case the background ever fails to load.
	var back := ColorRect.new()
	back.name = "Backdrop"
	back.color = Color(0.02, 0.03, 0.05, 1.0)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	if ResourceLoader.exists(BACKGROUND_PATH):
		var bg := TextureRect.new()
		bg.name = "Background"
		bg.texture = load(BACKGROUND_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	# The drone "portrait": a stage rect (positioned in _layout_drone) holding
	# the base sprite and its overlays, all filling the stage so they align.
	_drone_stage = Control.new()
	_drone_stage.name = "DroneStage"
	_drone_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drone_stage)

	_layer_base = _make_layer("DroneBase", DRONE_BASE)
	_layer_id = _make_layer("DroneId", DRONE_ID)
	_layer_gun = _make_layer("DroneGun", DRONE_GUN)
	_layer_light = _make_layer("DroneLight", "")
	# Overlays start hidden; the base drone is always shown.
	_layer_id.visible = false
	_layer_gun.visible = false
	_layer_light.visible = false

	# Dialogue box pinned to the bottom.
	_dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as DialogueBox
	_dialogue_box.name = "DroneDialogue"
	_dialogue_box.anchor_left = 0.0
	_dialogue_box.anchor_right = 1.0
	_dialogue_box.anchor_top = 1.0
	_dialogue_box.anchor_bottom = 1.0
	_dialogue_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialogue_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialogue_box.offset_left = 80.0
	_dialogue_box.offset_right = -80.0
	_dialogue_box.offset_top = -(DIALOGUE_RESERVED - 15.0)
	_dialogue_box.offset_bottom = -40.0
	add_child(_dialogue_box)
	_dialogue_box.page_advanced.connect(_on_page_advanced)
	_dialogue_box.finished.connect(_on_dialogue_finished)


## Build one drone layer as a full-rect child of the stage so every layer maps
## onto the same box and composites in register. `path` may be empty for the
## light layer, whose texture is set per-frame.
func _make_layer(node_name: String, path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	if not path.is_empty() and ResourceLoader.exists(path):
		rect.texture = load(path) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drone_stage.add_child(rect)
	return rect


## Size and place the drone stage bottom-centre over the park, above the
## dialogue box — the same footprint the teacher/uncle portraits use.
func _layout_drone() -> void:
	if _drone_stage == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var aspect: float = 1.0
	var base_tex := load(DRONE_BASE) as Texture2D
	if base_tex != null and base_tex.get_size().y > 0.0:
		aspect = base_tex.get_size().x / base_tex.get_size().y

	var top_margin: float = 24.0
	var avail_h: float = maxf(1.0, vp.y - DIALOGUE_RESERVED - top_margin)
	var h: float = minf(vp.y * 0.6, avail_h)
	var w: float = h * aspect
	var max_w: float = vp.x * 0.9
	if w > max_w:
		w = max_w
		h = w / maxf(0.01, aspect)

	_drone_stage.anchor_left = 0.5
	_drone_stage.anchor_right = 0.5
	_drone_stage.anchor_top = 1.0
	_drone_stage.anchor_bottom = 1.0
	_drone_stage.offset_left = -w * 0.5
	_drone_stage.offset_right = w * 0.5
	_drone_stage.offset_top = -DIALOGUE_RESERVED - h
	_drone_stage.offset_bottom = -DIALOGUE_RESERVED


func _start() -> void:
	var stole := not _contraband.is_empty()
	var first_time := not GameState.drone_encounter_seen

	var pages: Array = []
	_page_actions.clear()
	_append_opening(pages)
	if stole:
		_append_caught_branch(pages)
	else:
		_append_clean_branch(pages, first_time)

	# Record that the encounter happened / how this inspection went. The clean
	# branch already read the pre-existing flags when picking its sign-off.
	GameState.drone_encounter_seen = true
	if stole:
		GameState.drone_ever_caught = true
		GameState.drone_caught_last_inspection = true
	else:
		GameState.drone_caught_last_inspection = false

	_dialogue_box.play_pages(pages)


# --- page assembly -----------------------------------------------------------
#
# _add_page keeps _page_actions aligned 1:1 with the pages array so
# _on_page_advanced can run the layer change for the page just shown.

func _add_page(pages: Array, lines: Array, action: Callable = Callable()) -> void:
	pages.append(lines)
	_page_actions.append(action)


func _append_opening(pages: Array) -> void:
	_add_page(pages, ["[i]The walk home is nice. It's a breath of fresh air after %s.[/i]" % _place])
	_add_page(pages, ["DRONE: HELLO CITIZEN. IDENTIFY YOURSELF."])
	_add_page(pages, ["You: Uh.. Hi. I'm %s." % GameState.get_player_name()])
	_add_page(pages, ["DRONE: PROVIDE IDENTIFICATION."])
	_add_page(pages, ["[i]The drone's camera locks onto your hand as you reach into your pocket.[/i]"])


func _append_caught_branch(pages: Array) -> void:
	# The player presents their ID (claw takes it) as the drone eyes the lump.
	_add_page(pages,
		["[i]As you reach your hand out to present your ID, you notice that the drone's camera is still pointed at a large lump in your pocket.[/i]"],
		_set_id.bind(true))
	_add_page(pages, ["DRONE: WHAT IS THAT IN YOUR POCKET? SHOW ME."])
	_add_page(pages, ["You: It's uhh... it's my... penis."])
	_add_page(pages, ["DRONE: ..."])
	_add_page(pages, ["You: ..."])
	# The drone draws its weapon — and keeps it drawn until it leaves.
	_add_page(pages,
		["DRONE: YOU HAVE THREE SECONDS TO IDENTIFY THE ITEM IN YOUR POCKET. 3... 2..."],
		_set_gun.bind(true))
	_add_page(pages, ["[i]You rip the %s out of your pocket and present it to the drone.[/i]" % _contraband])
	_add_page(pages, ["DRONE: THIS IS ILLEGAL CONTRABAND."])
	# Photo snap: the camera light blinks.
	_add_page(pages,
		["DRONE: YOU WILL BE FINED AND THIS INCIDENT WILL BE CATALOGUED IN YOUR RECORD."],
		_play_light_animation)
	# The drone drops the ID back — claw empties.
	_add_page(pages,
		["[i]It drops your id at your feet on the sidewalk.[/i]"],
		_set_id.bind(false))
	_add_page(pages, ["DRONE: THANK YOU FOR YOUR COOPERATION, CRIMINAL."])
	_add_page(pages, ["[i]The drone flies away.[/i]"])
	_add_page(pages, ["Thoughts: ...Damn."])


func _append_clean_branch(pages: Array, first_time: bool) -> void:
	# Camera sweeps the player — light blinks as it scans.
	_add_page(pages,
		["[i]As you reach for your wallet, you notice the drone's camera scanning you up and down.[/i]"],
		_play_light_animation)
	_add_page(pages, ["Thoughts: I shouldn't have any contraband on me... I think I'm safe."])
	# ID handed over.
	_add_page(pages,
		["[i]You hold out the id to the Patrol Drone.[/i]"],
		_set_id.bind(true))
	_add_page(pages, ["DRONE: EVERYTHING APPEARS TO BE IN ORDER. %s" % _clean_signoff()])
	# The drone returns the ID as it departs.
	_add_page(pages,
		["[i]It flies off.[/i]"],
		_set_id.bind(false))
	# The reflective beat only ever plays on the very first drone encounter.
	if first_time:
		_add_page(pages, ["Thoughts: That was stressful... Good thing I didn't steal anything."])


## The drone's clean-scan sign-off, escalating with the player's record. Read
## from the drone flags BEFORE this inspection updates them.
func _clean_signoff() -> String:
	if GameState.drone_caught_last_inspection or GameState.suspicion >= SUSPICION_ACKNOWLEDGED:
		return "YOUR COOPERATION IS ACKNOWLEDGED."
	if GameState.drone_ever_caught and GameState.suspicion >= SUSPICION_CRIMINAL:
		return "THANK YOU FOR YOUR COOPERATION, CRIMINAL."
	return "THANK YOU FOR YOUR COOPERATION, CITIZEN."


# --- layer control -----------------------------------------------------------

func _on_page_advanced(index: int) -> void:
	if index < 0 or index >= _page_actions.size():
		return
	var action: Callable = _page_actions[index]
	if action.is_valid():
		action.call()


func _set_id(on: bool) -> void:
	if _layer_id != null:
		_layer_id.visible = on


func _set_gun(on: bool) -> void:
	if _layer_gun != null:
		_layer_gun.visible = on


## Blink the camera light: light_1 (40%) -> light_2 (20%) -> light_1 (40%) ->
## off, across LIGHT_ANIM_SECONDS. Serial-guarded so a new blink or teardown
## cancels an in-flight one.
func _play_light_animation() -> void:
	_light_serial += 1
	var serial: int = _light_serial

	_show_light(DRONE_LIGHT_1)
	await get_tree().create_timer(LIGHT_ANIM_SECONDS * LIGHT_PHASE_1).timeout
	if serial != _light_serial or not is_inside_tree():
		return

	_show_light(DRONE_LIGHT_2)
	await get_tree().create_timer(LIGHT_ANIM_SECONDS * LIGHT_PHASE_2).timeout
	if serial != _light_serial or not is_inside_tree():
		return

	_show_light(DRONE_LIGHT_1)
	await get_tree().create_timer(LIGHT_ANIM_SECONDS * LIGHT_PHASE_1).timeout
	if serial != _light_serial or not is_inside_tree():
		return

	_hide_light()


func _show_light(path: String) -> void:
	if _layer_light == null:
		return
	if ResourceLoader.exists(path):
		_layer_light.texture = load(path) as Texture2D
	_layer_light.visible = true


func _hide_light() -> void:
	if _layer_light == null:
		return
	_layer_light.visible = false
	_layer_light.texture = null


# --- completion --------------------------------------------------------------

func _on_dialogue_finished() -> void:
	finished.emit()
