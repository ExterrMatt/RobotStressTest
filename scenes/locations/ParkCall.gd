extends LocationBase
class_name ParkCall
## One-time phone call from the robot on the walk home through the park. Plays
## the first time, after the work-disruption call (where they stole the robot
## chest), that the player steals something at school or work (nanobots/scrap). She admits she can
## still track the player's phone, warns that patrol drones route through the
## park, and pushes them to connect the chest to her head with the laptop app.
##
## Main rolls nothing for this one: it wipes in from school/work whenever it's
## due (see Main._maybe_show_park_call) and finishes back into
## _on_location_finished, which then advances the phase. The patrol-drone
## encounter stays locked until this has played.

const PARK_BACKGROUND: String = "res://assets/textures/backgrounds/park.png"
## Looking straight up through the trees (the bird). Cut to on the page containing
## PARK_SKY_CUE (the phone is hidden while it's up), and back to the park on the
## next page.
const PARK_SKY_BACKGROUND: String = "res://assets/textures/backgrounds/park_sky.png"
## Lower-cased fragment of the line where the player looks up and sees the bird.
const PARK_SKY_CUE: String = "up at the sky"
## Same ringtone as the work-disruption call. Loops while the "phone buzzes"
## line is up and rings out its current pass once the player moves on.
const PHONE_RING_SOUND_PATH: String = "res://assets/sounds/ringtone/ringtone.mp3"
const PHONE_RING_VOLUME_SCALE: float = 0.5
## Lower-cased fragment marking the line where the phone starts ringing.
const PHONE_RING_CUE: String = "buzzes"
## Lower-cased fragment of the line where the player answers ("You: …Hello?"):
## the phone (PhoneOverlay) comes up front-side over the park.
const PHONE_ANSWER_CUE: String = "hello?"
## Lower-cased fragment of the line where she hangs up: the phone goes away.
const PHONE_HANG_UP_CUE: String = "hangs up"
## Outdoor bed under the whole park scene: the same loop as the morning bedroom
## (Main.BEDROOM_AMBIENCE_MORNING_PATH), 20% louder than the bedroom's 0.5.
const PARK_AMBIENCE_SOUND_PATH: String = "res://assets/sounds/bedroom/morning_bedroom.mp3"
const PARK_AMBIENCE_VOLUME_SCALE: float = 0.5 * 1.2

@onready var dialogue_box: DialogueBox = %DialogueBox

var _place: String = "work"
var _pages: Array = []
var _phone_ring_player: LoopingSfxPlayer = null
var _phone_overlay: PhoneOverlay = null
var _showing_sky: bool = false
## The phone view that was up before looking at the sky (-1 if it was hidden), so
## it comes back the same way when the view drops back to the park.
var _phone_view_before_sky: int = -1


func _ready() -> void:
	Dialogue.load_file("park", "res://data/dialogue/park.dlg")
	var main := get_tree().current_scene
	if main != null and main.has_method("consume_pending_park_place"):
		_place = String(main.consume_pending_park_place())
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()

	_show_park()
	start_ambient_loop(PARK_AMBIENCE_SOUND_PATH, PARK_AMBIENCE_VOLUME_SCALE)
	_setup_phone_overlay()
	_setup_phone_ring_audio()

	dialogue_box.finished.connect(_on_dialogue_finished)
	dialogue_box.page_advanced.connect(_on_page_advanced)
	_start()


func _start() -> void:
	GameState.robot_park_call_seen = true

	var fmt := {"place": _place, "player_name": GameState.get_player_name()}
	# She thanks the player instead if they already put the chest on her.
	var chest_key := "chest.attached" if GameState.get_attached_part_count("chest") > 0 else "chest.unattached"
	_pages.clear()
	_pages.append_array(Dialogue.get_pages("park", "call", fmt))
	_pages.append_array(Dialogue.get_pages("park", chest_key, fmt))
	_pages.append_array(Dialogue.get_pages("park", "closing", fmt))
	dialogue_box.play_pages(_pages)


func _show_park() -> void:
	_set_background(PARK_BACKGROUND)


func _set_background(path: String) -> void:
	var main := get_tree().current_scene
	if main == null or not ("scene_image" in main):
		return
	var tex := load(path) as Texture2D
	if tex != null:
		main.scene_image.texture = tex


## The phone sits over the park picture, hidden until the player answers.
func _setup_phone_overlay() -> void:
	var main := get_tree().current_scene
	if main == null or not main.has_method("show_scene_overlay"):
		return
	_phone_overlay = PhoneOverlay.new()
	main.show_scene_overlay(_phone_overlay)


func _setup_phone_ring_audio() -> void:
	_phone_ring_player = LoopingSfxPlayer.new()
	_phone_ring_player.name = "PhoneRingAudioPlayer"
	_phone_ring_player.configure(load(PHONE_RING_SOUND_PATH) as AudioStream, PHONE_RING_VOLUME_SCALE)
	# Parent the ring to the persistent root scene so its last pass rings out
	# even if the player leaves before it ends.
	var persistent: Node = get_tree().current_scene
	if persistent == null:
		persistent = get_tree().root
	persistent.add_child(_phone_ring_player)


func _on_page_advanced(index: int) -> void:
	if index < 0 or index >= _pages.size():
		return
	var text := ""
	for line in _pages[index]:
		text += String(line) + " "
	var lower := text.to_lower()
	# Straight cut up to the sky for the bird line (the phone drops out of shot),
	# and straight back down to the park, phone and all, after.
	if lower.contains(PARK_SKY_CUE):
		if not _showing_sky and _phone_overlay != null and is_instance_valid(_phone_overlay):
			_phone_view_before_sky = _phone_overlay.current_view()
			_phone_overlay.hide_phone()
		_showing_sky = true
		_set_background(PARK_SKY_BACKGROUND)
	elif _showing_sky:
		_showing_sky = false
		_show_park()
		if _phone_view_before_sky >= 0 and _phone_overlay != null and is_instance_valid(_phone_overlay):
			_phone_overlay.show_view(_phone_view_before_sky as PhoneOverlay.View)
		_phone_view_before_sky = -1
	if _phone_ring_player != null:
		if lower.contains(PHONE_RING_CUE):
			_phone_ring_player.start_loop()
		else:
			_phone_ring_player.finish_loop()
	if _phone_overlay != null and is_instance_valid(_phone_overlay):
		if lower.contains(PHONE_ANSWER_CUE):
			_phone_overlay.show_view(PhoneOverlay.View.FRONT)
		if lower.contains(PHONE_HANG_UP_CUE):
			_phone_overlay.hide_phone()


func _exit_tree() -> void:
	if _phone_ring_player != null and is_instance_valid(_phone_ring_player):
		_phone_ring_player.release_when_finished()


func _on_dialogue_finished() -> void:
	stop_ambient_loop()
	# Hand control back to Main, which advances the phase.
	finish(0, 0, 0, {}, false)
