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

# --- drone placement (editor-tweakable) --------------------------------------
# Select the DroneEncounter root in the scene and edit these in the Inspector to
# move and resize the drone over the framed scene image, the same way the
# StressTest scene exposes its own drone. The defaults reproduce the original
# centre-bottom, full-height placement, so leaving them alone changes nothing.
@export_group("Drone Placement")
## Drone height as a fraction of the scene-image height (1.0 = fills top to
## bottom). The width follows from the art's 256x192 aspect, so this is the
## drone's overall size dial.
@export_range(0.1, 3.0, 0.01) var drone_scale: float = 1.0:
	set(value):
		drone_scale = value
		_layout_drone()
## Where inside the scene image the drone is anchored, as fractions of the image
## (0,0 = top-left, 1,1 = bottom-right). The default (0.5, 1.0) pins the drone
## centre-bottom.
@export var drone_anchor: Vector2 = Vector2(0.5, 1.0):
	set(value):
		drone_anchor = value
		_layout_drone()
## Extra pixel nudge applied after the fractional placement (post-scale).
@export var drone_offset: Vector2 = Vector2.ZERO:
	set(value):
		drone_offset = value
		_layout_drone()

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
	Dialogue.load_file("drone", "res://data/dialogue/drone.dlg")
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
	var h: float = sz.y * drone_scale
	var w: float = h * (DRONE_CROP_RECT.size.x / DRONE_CROP_RECT.size.y)
	# Anchor point 0..1 maps onto the free space so 0.5,1.0 == centre-bottom.
	_drone_stage.position = Vector2((sz.x - w) * drone_anchor.x, (sz.y - h) * drone_anchor.y) + drone_offset
	_drone_stage.size = Vector2(w, h)


# --- dialogue ----------------------------------------------------------------

func _start() -> void:
	var stole := not _contraband.is_empty()
	# First encounter plays the full conversation; every one after is the short
	# version, so the player isn't made to sit through the whole bit each time.
	var first_time := not GameState.drone_encounter_seen

	# Text lives in data/dialogue/drone.dlg; only the drone's layer changes stay
	# here, mapped to the page index within each section. The sign-off/contraband
	# text is substituted in. _clean_signoff() is read now, before the flags below
	# update, so it reflects the record as it stood coming into this inspection.
	var fmt := {
		"place": _place,
		"name": GameState.get_player_name(),
		"contraband": _contraband,
		"signoff": _clean_signoff(),
	}

	var pages: Array = []
	_page_actions.clear()
	if first_time:
		# The drone drops in on the opening's first DRONE line.
		_append_section(pages, "opening", fmt, {1: _set_base.bind(true)})
		if stole:
			_append_section(pages, "caught", fmt, {
				0: _set_id.bind(true),     # claw takes the ID as it eyes the lump
				5: _set_gun.bind(true),    # weapon drawn, stays drawn until it leaves
				8: _play_light_animation,  # photo snap
				9: _set_id.bind(false),    # drops the ID back
				11: _hide_drone,           # flies away — hide gun and all
			})
		else:
			_append_section(pages, "clean", fmt, {
				0: _play_light_animation,  # camera sweep
				2: _set_id.bind(true),     # ID handed over
				4: _hide_drone,            # flies off
			})
	else:
		_append_section(pages, "opening_short", fmt, {1: _set_base.bind(true)})
		if stole:
			_append_section(pages, "caught_short", fmt, {
				0: _set_id.bind(true),
				1: _set_gun.bind(true),
				3: _play_light_animation,
				4: _set_id.bind(false),
				6: _hide_drone,
			})
		else:
			_append_section(pages, "clean_short", fmt, {
				0: _play_light_animation,
				1: _set_id.bind(true),
				3: _hide_drone,
			})

	# Record that the encounter happened / how this inspection went.
	GameState.drone_encounter_seen = true
	if stole:
		GameState.drone_ever_caught = true
		GameState.drone_caught_last_inspection = true
		# Being flagged as a criminal is a special occasion: it permanently
		# raises the suspicion floor by 5 and adds 15 temporary suspicion on top.
		GameState.add_suspicion(15, 5)
	else:
		GameState.drone_caught_last_inspection = false

	dialogue_box.play_pages(pages)


## Append a drone.dlg section's pages, keeping _page_actions aligned 1:1 so
## _on_page_advanced runs the right layer change for each page. `actions` maps a
## page index WITHIN the section to the callable to run when it is shown.
func _append_section(pages: Array, section_key: String, fmt: Dictionary, actions: Dictionary) -> void:
	var section_pages: Array = Dialogue.get_pages("drone", section_key, fmt)
	for i in section_pages.size():
		pages.append(section_pages[i])
		_page_actions.append(actions.get(i, Callable()))


## The drone's clean-scan sign-off, escalating with the player's record. Read
## from the drone flags BEFORE this inspection updates them.
func _clean_signoff() -> String:
	if GameState.drone_caught_last_inspection or GameState.suspicion >= SUSPICION_ACKNOWLEDGED:
		return dlg_line("drone", "signoff.acknowledged")
	if GameState.drone_ever_caught and GameState.suspicion >= SUSPICION_CRIMINAL:
		return dlg_line("drone", "signoff.criminal")
	return dlg_line("drone", "signoff.citizen")


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
