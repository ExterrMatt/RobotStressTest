class_name DroneRevealCutscene
extends Control
## The "carry her out of the shed" beat at the end of the robot's first-activation
## talk, where the player meets their first patrol drone.
##
## A 500x125 sliver of the stress-test shed (window wall, night darkness layers, no
## curtain, no lights-off layers) is rebuilt from the shed sprite sheet and laid over
## the main picture frame. The player holds her head up (head_up), lowers it
## (head_down + right_hand_down), the camera eases up to the drone hovering at the
## window, and the player slams the emergency button (right_hand_button_press),
## which plays the stress test's drone electrocution.
##
## IntroDialogue owns the timing; this node only exposes the visual beats.

const SHEET: Texture2D = preload("res://assets/textures/backgrounds/stress_test/stress_test_shed.png")
const DARK_OVER_BUTTON: Texture2D = preload("res://assets/textures/backgrounds/stress_test/dark_over_button.png")
const PULL_STRING: Texture2D = preload("res://assets/textures/icons/pull_string.png")
const DRONE_TEXTURE: Texture2D = preload("res://assets/textures/characters/drone/drone.png")
const DRONE_GUNS_TEXTURE: Texture2D = preload("res://assets/textures/characters/drone/guns.png")
const DRONE_ZAP_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/characters/drone/zap_1.png"),
	preload("res://assets/textures/characters/drone/zap_2.png"),
	preload("res://assets/textures/characters/drone/zap_3.png"),
]

## Size of the visible sliver, in shed-sheet pixels (matches the standard 500x125
## scene art, so it fills the picture frame exactly).
const VIEW_SIZE: Vector2 = Vector2(500.0, 125.0)
## Top-left of the sliver in shed-sheet pixels: holding her up in front of the window
## (the drone and the emergency button are in view behind her - the camera holds
## here through lowering her head, the guns and the button press)...
## x is the arms' left edge: the held-up arms (head_up) cover columns 639-1140 and the
## lowered ones (head_down + right_hand_down) 639-1138, so a 500px view from 639 is
## filled edge to edge in both poses, with no gap past either sleeve.
const HEAD_UP_VIEW: Vector2 = Vector2(639.0, 454.0)
## ...then, once the drone is gone, eases straight down to her face for the rest of
## the talk (same x, so the pan is purely vertical).
const SETTLE_VIEW: Vector2 = Vector2(639.0, 546.0)

## Where the stress test draws its patrol drone (drone.png and its zap frames), in
## shed-sheet pixels. Mirrors StressTest.tscn's PatrolDrone node (+600, +400).
const DRONE_RECT: Rect2 = Rect2(764.0, 364.0, 256.0, 256.0)
## The light's pull string at rest: 41 two-pixel links, then the 18px bulb.
## Mirrors StressTest.tscn's PullCord node at rest.
const PULL_STRING_POSITION: Vector2 = Vector2(993.5, 398.0)
const PULL_STRING_LINKS_HEIGHT: float = 82.0
const PULL_STRING_BULB_SIZE: Vector2 = Vector2(13.0, 18.0)

## Shed-sheet layers: [region in the packed sheet, position in the 1800x1800 cell].
## Copied from stress_test_shed.json (the JSON is not exported with the game) -
## re-copy these if the shed is re-exported and the packing changes.
const LAYERS: Dictionary = {
	&"shed_background": [Rect2(2380, 1371, 683, 288), Vector2(565, 397)],
	&"gas_thing_5": [Rect2(0, 1984, 153, 330), Vector2(556, 450)],
	&"window_og": [Rect2(372, 1551, 342, 159), Vector2(722, 430)],
	&"window": [Rect2(3682, 1982, 342, 159), Vector2(722, 430)],
	&"drone_dark_1": [Rect2(2295, 833, 219, 100), Vector2(782, 461)],
	&"drone_dark_2": [Rect2(1997, 2140, 219, 100), Vector2(784, 461)],
	&"drone_dark_3": [Rect2(1776, 2063, 221, 102), Vector2(782, 459)],
	&"drone_dark_4": [Rect2(4633, 2129, 221, 102), Vector2(782, 459)],
	&"dark_top": [Rect2(0, 0, 1398, 773), Vector2(165, 0)],
	&"dark_front": [Rect2(4241, 0, 726, 471), Vector2(528, 337)],
	&"dark_front_2": [Rect2(1804, 1371, 576, 441), Vector2(612, 337)],
	&"dark_front_gas": [Rect2(3480, 1951, 202, 317), Vector2(570, 493)],
	&"bulb_on": [Rect2(4967, 211, 31, 44), Vector2(890, 430)],
	&"light": [Rect2(1605, 2063, 171, 138), Vector2(821, 400)],
	&"button": [Rect2(1314, 773, 37, 50), Vector2(1063, 475)],
	&"button_pressed": [Rect2(1351, 773, 37, 50), Vector2(1063, 475)],
	&"head_up": [Rect2(4131, 1899, 502, 253), Vector2(639, 457)],
	&"head_down": [Rect2(908, 2004, 311, 152), Vector2(638, 548)],
	&"right_hand_down": [Rect2(573, 2049, 224, 129), Vector2(916, 576)],
	&"right_hand_button_press": [Rect2(4853, 1511, 148, 240), Vector2(1052, 465)],
}

## The zap plays its three arc frames over this long, then the drone vanishes.
## Matches StressTest's drone_zap_seconds.
@export var zap_seconds: float = 0.15
## Tint on the deployed guns so they sit inside the drone's dark shading. Matches
## StressTest's drone_guns_dim_modulate.
@export var guns_modulate: Color = Color(0.5, 0.5, 0.52, 1.0)

## Everything drawn in shed-sheet coordinates; moved and scaled to act as the camera.
var _world: Control = null
var _view_origin: Vector2 = HEAD_UP_VIEW
var _pan_tween: Tween = null

var _drone: TextureRect = null
var _drone_zap: TextureRect = null
var _drone_guns: TextureRect = null
var _drone_darks: Array[TextureRect] = []
var _button: TextureRect = null
var _button_pressed: TextureRect = null
var _head_up: TextureRect = null
var _head_down: TextureRect = null
var _right_hand_down: TextureRect = null
var _right_hand_button_press: TextureRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_head_up_pose()
	resized.connect(_apply_camera)
	_apply_camera()


func _process(_delta: float) -> void:
	# The picture frame can animate its size; keep the sliver fitted to it.
	_apply_camera()


## Her head held up in front of the window, both arms in view.
func show_head_up() -> void:
	_show_head_up_pose()


## Lower her head out of the way (head_down + right_hand_down).
func lower_head() -> void:
	_head_up.visible = false
	_head_down.visible = true
	_right_hand_down.visible = true
	_right_hand_button_press.visible = false


## Ease the camera back down to her face after the drone is driven off.
func pan_to_settle(duration: float) -> Tween:
	return _pan_to(SETTLE_VIEW, duration)


func _pan_to(target: Vector2, duration: float) -> Tween:
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_method(_set_view_origin, _view_origin, target, maxf(0.01, duration))
	return _pan_tween


## The drone deploys its guns at the player (the stress test's aiming pose, lights on).
func show_drone_guns() -> void:
	if _drone != null and _drone.visible:
		_drone_guns.visible = true


## Slam the emergency button: swap the right hand to its button-press pose, press the
## button and electrocute the drone (stress-test zap: arc frames 1 -> 2 -> 3, then gone).
func press_button() -> void:
	_right_hand_down.visible = false
	_right_hand_button_press.visible = true
	_button.visible = false
	_button_pressed.visible = true
	_play_drone_zap()


## Bring the hand back down off the button.
func release_button() -> void:
	_right_hand_button_press.visible = false
	_right_hand_down.visible = true
	_button_pressed.visible = false
	_button.visible = true


func _play_drone_zap() -> void:
	if _drone == null or not _drone.visible:
		return
	# The arc replaces the guns, like the stress test's zap state.
	_drone_guns.visible = false
	# While zapping, the stress test keeps dark_drone 1, 2 and 4 and drops 3.
	for i in _drone_darks.size():
		_drone_darks[i].visible = i != 2
	var frame_seconds := maxf(0.01, zap_seconds) / float(DRONE_ZAP_TEXTURES.size())
	for frame in DRONE_ZAP_TEXTURES:
		_drone_zap.texture = frame
		_drone_zap.visible = true
		await get_tree().create_timer(frame_seconds).timeout
		if not is_inside_tree():
			return
	_drone.visible = false
	_drone_zap.visible = false
	for dark in _drone_darks:
		dark.visible = false


func _show_head_up_pose() -> void:
	_head_up.visible = true
	_head_down.visible = false
	_right_hand_down.visible = false
	_right_hand_button_press.visible = false


func _set_view_origin(origin: Vector2) -> void:
	_view_origin = origin
	_apply_camera()


## Fit the 500x125 sliver into this control (keep aspect, centered - the same way the
## picture frame draws its 500x125 art) and slide the world so _view_origin is at the
## sliver's top-left.
func _apply_camera() -> void:
	if _world == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var view_scale := minf(size.x / VIEW_SIZE.x, size.y / VIEW_SIZE.y)
	var drawn := VIEW_SIZE * view_scale
	var inset := (size - drawn) * 0.5
	_world.scale = Vector2(view_scale, view_scale)
	_world.position = inset - _view_origin * view_scale


func _build() -> void:
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	_world = Control.new()
	_world.name = "World"
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)

	# Same stacking as StressTest.tscn: the room, the window, the drone and its dark
	# shading, the night darkness, then the bulb, its pull string and the button.
	_add_layer(&"shed_background")
	_add_layer(&"gas_thing_5")
	_add_layer(&"window_og")
	_add_layer(&"window")
	_drone = _add_texture("Drone", DRONE_TEXTURE, DRONE_RECT.position, DRONE_RECT.size)
	_drone_zap = _add_texture("DroneZap", DRONE_ZAP_TEXTURES[0], DRONE_RECT.position, DRONE_RECT.size)
	_drone_zap.visible = false
	_drone_guns = _add_texture("DroneGuns", DRONE_GUNS_TEXTURE, DRONE_RECT.position, DRONE_RECT.size)
	_drone_guns.modulate = guns_modulate
	_drone_guns.visible = false
	for layer in [&"drone_dark_1", &"drone_dark_2", &"drone_dark_3", &"drone_dark_4"]:
		_drone_darks.append(_add_layer(layer))
	_add_layer(&"dark_top")
	_add_layer(&"dark_front")
	_add_layer(&"dark_front_2")
	_add_layer(&"dark_front_gas")
	_add_layer(&"bulb_on")
	_add_layer(&"light")
	_add_pull_string()
	_button = _add_layer(&"button")
	_button_pressed = _add_layer(&"button_pressed")
	_button_pressed.visible = false
	var button_rect: Array = LAYERS[&"button"]
	_add_texture("DarkOverButton", DARK_OVER_BUTTON, button_rect[1], (button_rect[0] as Rect2).size)
	# The player's arms and her head sit in front of everything.
	_head_up = _add_layer(&"head_up")
	_head_down = _add_layer(&"head_down")
	_right_hand_down = _add_layer(&"right_hand_down")
	_right_hand_button_press = _add_layer(&"right_hand_button_press")


func _add_layer(layer: StringName) -> TextureRect:
	var entry: Array = LAYERS[layer]
	var region: Rect2 = entry[0]
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = region
	return _add_texture(String(layer), atlas, entry[1], region.size)


func _add_texture(node_name: String, texture: Texture2D, at: Vector2, rect_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = at
	rect.size = rect_size
	_world.add_child(rect)
	return rect


func _add_pull_string() -> void:
	var links := AtlasTexture.new()
	links.atlas = PULL_STRING
	links.region = Rect2(0.0, 0.0, PULL_STRING_BULB_SIZE.x, PULL_STRING_LINKS_HEIGHT)
	_add_texture("PullStringLinks", links, PULL_STRING_POSITION, links.region.size)
	var bulb := AtlasTexture.new()
	bulb.atlas = PULL_STRING
	bulb.region = Rect2(Vector2(0.0, PULL_STRING.get_height() - PULL_STRING_BULB_SIZE.y), PULL_STRING_BULB_SIZE)
	_add_texture("PullStringBulb", bulb, PULL_STRING_POSITION + Vector2(0.0, PULL_STRING_LINKS_HEIGHT), PULL_STRING_BULB_SIZE)
