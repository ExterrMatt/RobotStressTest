extends RefCounted

## Central UI button sounds. Clips:
##   retro click (retro_select) - the accounted menu buttons (New Game, Quit, ...)
##   scene_select               - location/scene picks and every settings button
##   button_noise_...           - a button that is currently locked / unavailable
##   fallback (button_click)    - any button not otherwise accounted for
##
## Callers route through play_button(anchor, accessible, scene_select): pass the
## button's live availability and the clip it would use when available, and this
## picks the inaccessible clip whenever it is locked. That keeps a single call
## site correct even after a button is eventually unlocked - it starts playing its
## real sound automatically, with no code change.
const RETRO_CLICK_SOUND_PATH := "res://assets/sounds/menu_buttons/retro_select.mp3"
const SCENE_SELECT_SOUND_PATH := "res://assets/sounds/menu_buttons/scene_select.mp3"
const INACCESSIBLE_BUTTON_SOUND_PATH := "res://assets/sounds/menu_buttons/button_noise_inaccessable.mp3"
## The default click for any button the game doesn't explicitly account for.
const FALLBACK_CLICK_SOUND_PATH := "res://assets/sounds/menu_buttons/button_click.mp3"

## Per-clip volume trims, relative to the standard SFX level.
const RETRO_CLICK_VOLUME_SCALE := 0.2
const SCENE_SELECT_VOLUME_SCALE := 0.5

## The button click is pitched up or down by a random amount up to this fraction
## (±5%) on every press, so repeated clicks don't sound mechanically identical.
const BUTTON_CLICK_PITCH_VARIATION := 0.05

## Buttons wired to a specific UI sound set this meta so the global fallback
## (ButtonSounds autoload) skips them instead of also playing the default click.
const CUSTOM_META := "ui_sound_custom"


## Marks a button as having its own UI sound, so the fallback autoload leaves it
## alone. Safe to call any time before the button is pressed.
static func mark_has_custom_sound(button: Object) -> void:
	if button != null:
		button.set_meta(CUSTOM_META, true)


## The accounted menu-button click - a retro select blip, played quiet.
static func play_button_click(anchor: Node) -> void:
	_play(anchor, RETRO_CLICK_SOUND_PATH, RETRO_CLICK_VOLUME_SCALE, BUTTON_CLICK_PITCH_VARIATION)


## Location/scene pick or a settings button.
static func play_scene_select(anchor: Node) -> void:
	_play(anchor, SCENE_SELECT_SOUND_PATH, SCENE_SELECT_VOLUME_SCALE)


## A button that is currently locked/unavailable was pressed.
static func play_inaccessible_button(anchor: Node) -> void:
	_play(anchor, INACCESSIBLE_BUTTON_SOUND_PATH)


## Default click for any button not wired to a specific UI sound.
static func play_fallback_click(anchor: Node) -> void:
	_play(anchor, FALLBACK_CLICK_SOUND_PATH, 1.0, BUTTON_CLICK_PITCH_VARIATION)


## Generic entry point. `accessible` decides regular-vs-inaccessible; when
## accessible, `scene_select` chooses the scene-select clip over the plain click.
static func play_button(anchor: Node, accessible: bool, scene_select: bool = false) -> void:
	if not accessible:
		play_inaccessible_button(anchor)
	elif scene_select:
		play_scene_select(anchor)
	else:
		play_button_click(anchor)


## `pitch_variation` (0 = none) randomly pitches the clip up or down by up to that
## fraction, so the same click doesn't sound identical every press.
static func _play(anchor: Node, path: String, volume_scale: float = 1.0, pitch_variation: float = 0.0) -> void:
	if anchor == null or Engine.is_editor_hint():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	# Parent the one-shot to the window root, not the clicked control, so the clip
	# survives the scene change a button often triggers. ALWAYS process mode lets
	# it keep playing while the tree is paused (e.g. the pause-menu settings).
	var tree := anchor.get_tree()
	var host: Node = tree.root if tree != null else anchor
	var player := AudioStreamPlayer.new()
	player.name = "UiSoundPlayer"
	player.stream = stream
	player.volume_db = linear_to_db(GameState.DEFAULT_SFX_VOLUME_SCALE * volume_scale)
	if pitch_variation > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
