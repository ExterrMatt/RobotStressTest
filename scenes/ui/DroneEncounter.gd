extends Control
class_name DroneEncounter
## Patrol-drone street inspection that plays after a regular school or work run.
##
## A short, self-contained cutscene: a placeholder "walk home" background with a
## layered drone sprite on top and a DialogueBox along the bottom. The dialogue
## branches on whether the player stole the previous scene's contraband:
##   - stole   -> the drone spots the lump, draws on the player, and catalogues
##                the contraband (drone_3 gun-out, drone_4 photo-snap).
##   - clean   -> the drone scans and waves the player on, with a sign-off line
##                whose tone escalates with the player's record / suspicion.
##
## ART IS PLACEHOLDER. The background and the drone_1..4 sprites do not exist in
## the project yet, so missing textures fall back to a labelled box that names
## the intended sprite state. Drop the real art in at the paths below and the
## choreography works unchanged.

signal finished

const DIALOGUE_BOX_SCENE: PackedScene = preload("res://scenes/ui/DialogueBox.tscn")

# --- placeholder asset paths (swap in real art later) ---
const BACKGROUND_PATH: String = "res://assets/textures/backgrounds/drone_walk_home.png"
const DRONE_DEFAULT: String = "res://assets/textures/characters/drone/drone_1.png"
const DRONE_SCAN_OK: String = "res://assets/textures/characters/drone/drone_2.png"
const DRONE_GUN: String = "res://assets/textures/characters/drone/drone_3.png"
const DRONE_PHOTO: String = "res://assets/textures/characters/drone/drone_4.png"

## How long the one-shot sprite "flashes" (photo snap / scan) hold before
## reverting to the resting sprite.
const FLASH_SECONDS: float = 0.5

# Suspicion thresholds that colour the drone's clean-scan sign-off line.
const SUSPICION_CRIMINAL: int = 50
const SUSPICION_ACKNOWLEDGED: int = 75

# --- inputs (set via configure() before the node enters the tree) ---
var _place: String = "work"
var _contraband: String = ""

# --- nodes ---
var _drone_rect: TextureRect = null
var _drone_placeholder: Label = null
var _dialogue_box: DialogueBox = null

# --- per-page choreography, parallel to the pages handed to the DialogueBox ---
var _page_actions: Array = []   # each entry: {} or {"sprite": path/caption, "flash": {...}}
var _flash_serial: int = 0


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
	_start()


func _build_ui() -> void:
	# Opaque backdrop so the torn-down location never peeks through.
	var back := ColorRect.new()
	back.name = "Backdrop"
	back.color = Color(0.02, 0.03, 0.05, 1.0)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	# Placeholder scene background (missing texture just leaves the dark fill).
	if ResourceLoader.exists(BACKGROUND_PATH):
		var bg := TextureRect.new()
		bg.name = "Background"
		bg.texture = load(BACKGROUND_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	# The drone sprite, centred above the dialogue box.
	_drone_rect = TextureRect.new()
	_drone_rect.name = "DroneSprite"
	_drone_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drone_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drone_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drone_rect.offset_top = 60.0
	_drone_rect.offset_bottom = -260.0
	_drone_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drone_rect)

	# Fallback caption shown when a drone texture is missing so the sprite state
	# is still visible while testing with placeholder art.
	_drone_placeholder = Label.new()
	_drone_placeholder.name = "DronePlaceholder"
	_drone_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drone_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drone_placeholder.add_theme_font_size_override("font_size", 40)
	_drone_placeholder.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.85))
	_drone_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drone_placeholder.offset_top = 60.0
	_drone_placeholder.offset_bottom = -260.0
	_drone_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drone_placeholder)

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
	_dialogue_box.offset_top = -220.0
	_dialogue_box.offset_bottom = -40.0
	add_child(_dialogue_box)
	_dialogue_box.page_advanced.connect(_on_page_advanced)
	_dialogue_box.finished.connect(_on_dialogue_finished)


func _start() -> void:
	_set_drone_sprite(DRONE_DEFAULT, "drone_1 · idle")

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
# _on_page_advanced can look up the sprite change for the page just shown.

func _add_page(pages: Array, lines: Array, action: Dictionary = {}) -> void:
	pages.append(lines)
	_page_actions.append(action)


func _append_opening(pages: Array) -> void:
	_add_page(pages, ["[i]The walk home is nice. It's a breath of fresh air after %s.[/i]" % _place])
	_add_page(pages, ["DRONE: HELLO CITIZEN. IDENTIFY YOURSELF."])
	_add_page(pages, ["You: Uh.. Hi. I'm %s." % GameState.get_player_name()])
	_add_page(pages, ["DRONE: PROVIDE IDENTIFICATION."])
	_add_page(pages, ["[i]The drone's camera locks onto your hand as you reach into your pocket.[/i]"])


func _append_caught_branch(pages: Array) -> void:
	_add_page(pages, ["[i]As you reach your hand out to present your ID, you notice that the drone's camera is still pointed at a large lump in your pocket.[/i]"])
	_add_page(pages, ["DRONE: WHAT IS THAT IN YOUR POCKET? SHOW ME."])
	_add_page(pages, ["You: It's uhh... it's my... penis."])
	_add_page(pages, ["DRONE: ..."])
	_add_page(pages, ["You: ..."])
	# Drone draws its weapon.
	_add_page(pages,
		["DRONE: YOU HAVE THREE SECONDS TO IDENTIFY THE ITEM IN YOUR POCKET. 3... 2..."],
		{"sprite": DRONE_GUN, "caption": "drone_3 · gun out"})
	_add_page(pages, ["[i]You rip the %s out of your pocket and present it to the drone.[/i]" % _contraband])
	_add_page(pages, ["DRONE: THIS IS ILLEGAL CONTRABAND."])
	# Photo snap: drone_4 for FLASH_SECONDS, then back to drone_3.
	_add_page(pages,
		["DRONE: YOU WILL BE FINED AND THIS INCIDENT WILL BE CATALOGUED IN YOUR RECORD."],
		{"flash": {
			"tex": DRONE_PHOTO, "caption": "drone_4 · photo",
			"back": DRONE_GUN, "back_caption": "drone_3 · gun out",
		}})
	_add_page(pages, ["[i]It drops your id at your feet on the sidewalk.[/i]"])
	_add_page(pages, ["DRONE: THANK YOU FOR YOUR COOPERATION, CRIMINAL."])
	_add_page(pages, ["[i]The drone flies away.[/i]"])
	_add_page(pages, ["Thoughts: ...Damn."])


func _append_clean_branch(pages: Array, first_time: bool) -> void:
	_add_page(pages, ["[i]As you reach for your wallet, you notice the drone's camera scanning you up and down.[/i]"])
	_add_page(pages, ["Thoughts: I shouldn't have any contraband on me... I think I'm safe."])
	_add_page(pages, ["[i]You hold out the id to the Patrol Drone.[/i]"])
	# Scan-OK blip: drone_2 for FLASH_SECONDS, then back to drone_1. The drone's
	# sign-off is appended to this same spoken line.
	_add_page(pages,
		["DRONE: EVERYTHING APPEARS TO BE IN ORDER. %s" % _clean_signoff()],
		{"flash": {
			"tex": DRONE_SCAN_OK, "caption": "drone_2 · scan OK",
			"back": DRONE_DEFAULT, "back_caption": "drone_1 · idle",
		}})
	_add_page(pages, ["[i]It flies off.[/i]"])
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


# --- sprite control ----------------------------------------------------------

func _on_page_advanced(index: int) -> void:
	if index < 0 or index >= _page_actions.size():
		return
	var action: Dictionary = _page_actions[index]
	if action.has("sprite"):
		_set_drone_sprite(String(action["sprite"]), String(action.get("caption", "")))
	if action.has("flash"):
		_flash_drone_sprite(action["flash"])


func _flash_drone_sprite(flash: Dictionary) -> void:
	_set_drone_sprite(String(flash.get("tex", "")), String(flash.get("caption", "")))
	_flash_serial += 1
	var serial := _flash_serial
	await get_tree().create_timer(FLASH_SECONDS).timeout
	# Ignore if a newer flash/sprite change superseded this one, or we're gone.
	if serial != _flash_serial or not is_inside_tree():
		return
	_set_drone_sprite(String(flash.get("back", "")), String(flash.get("back_caption", "")))


func _set_drone_sprite(path: String, caption: String) -> void:
	# A newer explicit sprite change cancels any pending flash-revert.
	_flash_serial += 1
	if not path.is_empty() and ResourceLoader.exists(path):
		_drone_rect.texture = load(path) as Texture2D
		_drone_rect.visible = true
		_drone_placeholder.visible = false
	else:
		# Placeholder art missing — show the intended sprite state as text.
		_drone_rect.texture = null
		_drone_rect.visible = false
		_drone_placeholder.text = "[ DRONE ]\n%s" % (caption if not caption.is_empty() else "placeholder")
		_drone_placeholder.visible = true


# --- completion --------------------------------------------------------------

func _on_dialogue_finished() -> void:
	finished.emit()
