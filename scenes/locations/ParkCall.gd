extends LocationBase
class_name ParkCall
## One-time phone call from the robot on the walk home through the park. Plays
## the first time the player finishes school or work on a day AFTER the
## work-disruption call (where they stole the robot chest). She admits she can
## still track the player's phone, warns that patrol drones route through the
## park, and pushes them to connect the chest to her head with the laptop app.
##
## Main rolls nothing for this one: it wipes in from school/work whenever it's
## due (see Main._maybe_show_park_call) and finishes back into
## _on_location_finished, which then advances the phase. The patrol-drone
## encounter stays locked until this has played.

const PARK_BACKGROUND: String = "res://assets/textures/backgrounds/park.png"
## Same ringtone as the work-disruption call. Loops while the "phone buzzes"
## line is up and rings out its current pass once the player moves on.
const PHONE_RING_SOUND_PATH: String = "res://assets/sounds/ringtone/ringtone.mp3"
const PHONE_RING_VOLUME_SCALE: float = 0.5
## Lower-cased fragment marking the line where the phone starts ringing.
const PHONE_RING_CUE: String = "buzzes"

@onready var dialogue_box: DialogueBox = %DialogueBox

var _place: String = "work"
var _pages: Array = []
var _phone_ring_player: LoopingSfxPlayer = null


func _ready() -> void:
	Dialogue.load_file("park", "res://data/dialogue/park.dlg")
	var main := get_tree().current_scene
	if main != null and main.has_method("consume_pending_park_place"):
		_place = String(main.consume_pending_park_place())
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()

	_show_park()
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
	var main := get_tree().current_scene
	if main == null or not ("scene_image" in main):
		return
	var tex := load(PARK_BACKGROUND) as Texture2D
	if tex != null:
		main.scene_image.texture = tex


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
	if _phone_ring_player == null or index < 0 or index >= _pages.size():
		return
	var text := ""
	for line in _pages[index]:
		text += String(line) + " "
	if text.to_lower().contains(PHONE_RING_CUE):
		_phone_ring_player.start_loop()
	else:
		_phone_ring_player.finish_loop()


func _exit_tree() -> void:
	if _phone_ring_player != null and is_instance_valid(_phone_ring_player):
		_phone_ring_player.release_when_finished()


func _on_dialogue_finished() -> void:
	# Hand control back to Main, which advances the phase.
	finish(0, 0, 0, {}, false)
