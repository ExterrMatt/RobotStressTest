extends LocationBase
class_name DroneEncounter
## Patrol-drone street inspection that plays after a regular school or work run.
##
## Loaded like any other dialogue location, so it inherits the normal framed
## presentation: the park background in the golden picture frame, the standard
## dialogue box, and the HUD. Main wipes into it from the previous scene and
## wipes out to the bedroom when it finishes.
##
## The drone is drawn over the scene image the same way the uncle/teacher
## portraits are — a bottom-centre stack of layers. A base sprite stays on;
## independent id / gun / light overlays composite on top (all 256x256, so they
## register). The dialogue branches on whether the player stole the previous
## scene's contraband, and layer changes are driven off the narrating page.

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

## The drone art is 256x256, but the top 64px are empty — every layer's content
## sits in the lower 256x192 window. All layers share that canvas, so cropping
## them to the same window keeps them in register while making the art read as
## 256x192. We then scale that window to fill the scene image top-to-bottom
## (like the Ms. Vey portrait), keeping aspect, anchored centre-bottom.
const DRONE_CROP_RECT: Rect2 = Rect2(0.0, 64.0, 256.0, 192.0)
## Drone height as a fraction of the scene-image height (1.0 = fills top to bottom).
const DRONE_FILL_SCALE: float = 1.0

# Suspicion thresholds that colour the drone's clean-scan sign-off line.
const SUSPICION_CRIMINAL: int = 50
const SUSPICION_ACKNOWLEDGED: int = 75

@onready var dialogue_box: DialogueBox = %DialogueBox

# --- inputs (pulled from Main at _ready) ---
var _place: String = "work"
var _contraband: String = ""

# --- drone layers (parented onto the scene image via show_scene_overlay) ---
var _overlay_root: Control = null
var _drone_stage: Control = null
var _layer_base: TextureRect = null
var _layer_id: TextureRect = null
var _layer_gun: TextureRect = null
var _layer_light: TextureRect = null

# Per-page callables, parallel to the pages handed to the DialogueBox. Kept
# untyped: Callable is not a valid typed-array element type in GDScript.
var _page_actions: Array = []
## Bumped whenever a new light action starts so a stale in-flight blink bails.
var _light_serial: int = 0


func _ready() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("consume_pending_drone_args"):
		var args: Dictionary = main.consume_pending_drone_args()
		_place = String(args.get("place", "work"))
		_contraband = String(args.get("contraband", ""))
	# No teacher/uncle portrait should linger under the drone.
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()

	_build_drone_overlay()
	if main != null and main.has_method("show_scene_overlay"):
		main.show_scene_overlay(_overlay_root)

	dialogue_box.finished.connect(_on_dialogue_finished)
	dialogue_box.page_advanced.connect(_on_page_advanced)
	_start()


# --- drone layer stack -------------------------------------------------------

func _build_drone_overlay() -> void:
	_overlay_root = Control.new()
	_overlay_root.name = "DroneOverlay"
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.resized.connect(_layout_drone)

	# The stack of layers, positioned bottom-centre in _layout_drone.
	_drone_stage = Control.new()
	_drone_stage.name = "DroneStage"
	_drone_stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_drone_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(_drone_stage)

	_layer_base = _make_layer("DroneBase", DRONE_BASE)
	_layer_id = _make_layer("DroneId", DRONE_ID)
	_layer_gun = _make_layer("DroneGun", DRONE_GUN)
	_layer_light = _make_layer("DroneLight", "")
	# Everything starts hidden — the drone flies in when the dialogue introduces
	# it (a couple of lines in); the claw/gun/light come on later still.
	_layer_base.visible = false
	_layer_id.visible = false
	_layer_gun.visible = false
	_layer_light.visible = false

	call_deferred("_layout_drone")


## One drone layer as a full-rect child of the stage so every layer maps onto
## the same box and composites in register. `path` may be empty (the light
## layer, whose texture is set per-frame).
func _make_layer(node_name: String, path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	if not path.is_empty() and ResourceLoader.exists(path):
		rect.texture = _cropped(load(path) as Texture2D)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drone_stage.add_child(rect)
	return rect


## Wrap a 256x256 drone texture so only the 256x192 content window shows. Every
## layer uses the same crop, so the composite stays aligned.
func _cropped(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = DRONE_CROP_RECT
	return atlas


## Size and place the drone stack bottom-centre over the scene image, matching
## the uncle/teacher portrait footprint.
func _layout_drone() -> void:
	if _overlay_root == null or _drone_stage == null:
		return
	var sz: Vector2 = _overlay_root.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var h: float = sz.y * DRONE_FILL_SCALE
	var w: float = h * (DRONE_CROP_RECT.size.x / DRONE_CROP_RECT.size.y)
	_drone_stage.position = Vector2((sz.x - w) * 0.5, sz.y - h)
	_drone_stage.size = Vector2(w, h)


# --- dialogue ----------------------------------------------------------------

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

	dialogue_box.play_pages(pages)


# _add_page keeps _page_actions aligned 1:1 with the pages array so
# _on_page_advanced can run the layer change for the page just shown.
func _add_page(pages: Array, lines: Array, action: Callable = Callable()) -> void:
	pages.append(lines)
	_page_actions.append(action)


func _append_opening(pages: Array) -> void:
	_add_page(pages, ["[i]The walk home is nice. It's a breath of fresh air after %s.[/i]" % _place])
	# The drone drops in as it hails the player.
	_add_page(pages, ["DRONE: HELLO CITIZEN. IDENTIFY YOURSELF."], _set_base.bind(true))
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
	# The drone leaves — hide it entirely (gun and all).
	_add_page(pages, ["[i]The drone flies away.[/i]"], _hide_drone)
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
	# The drone returns the ID and departs — hide the whole drone.
	_add_page(pages,
		["[i]It flies off.[/i]"],
		_hide_drone)
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


func _set_base(on: bool) -> void:
	if _layer_base != null:
		_layer_base.visible = on


## Hide the whole drone (base + every overlay) — used when it flies off.
func _hide_drone() -> void:
	_set_base(false)
	_set_id(false)
	_set_gun(false)
	_hide_light()


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
	if serial != _light_serial or _layer_light == null or not is_instance_valid(_layer_light):
		return

	_show_light(DRONE_LIGHT_2)
	await get_tree().create_timer(LIGHT_ANIM_SECONDS * LIGHT_PHASE_2).timeout
	if serial != _light_serial or _layer_light == null or not is_instance_valid(_layer_light):
		return

	_show_light(DRONE_LIGHT_1)
	await get_tree().create_timer(LIGHT_ANIM_SECONDS * LIGHT_PHASE_1).timeout
	if serial != _light_serial or _layer_light == null or not is_instance_valid(_layer_light):
		return

	_hide_light()


func _show_light(path: String) -> void:
	if _layer_light == null:
		return
	if ResourceLoader.exists(path):
		_layer_light.texture = _cropped(load(path) as Texture2D)
	_layer_light.visible = true


func _hide_light() -> void:
	if _layer_light == null:
		return
	_layer_light.visible = false
	_layer_light.texture = null


# --- completion --------------------------------------------------------------

func _on_dialogue_finished() -> void:
	# Hand control back to Main, which advances the phase (wiping to the
	# bedroom). The scene overlay is torn down automatically on location exit.
	finish(0, 0, 0, {}, false)
