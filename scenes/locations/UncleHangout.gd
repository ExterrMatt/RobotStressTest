extends LocationBase
class_name UncleHangout
## Optional night cut-scene: the uncle pulls the player in for a few drinks
## before bed. He overdoes it and turns in early — so he won't peek out the
## window to check on the player during tonight's stress test (DayCycle sets
## `uncle_out_for_the_night`, which StressTest reads to skip its uncle alerts).
##
## Plays in the living room with the uncle in his blue tank top. Main rolls for
## it on the way into Night (see Main._maybe_show_night_hangout_event) and wipes
## into this scene like any other location; it finishes back into
## _on_location_finished, which then advances the phase.

const LIVING_ROOM_BACKGROUND: String = "res://assets/textures/backgrounds/living_room_evening.png"
const UNCLE_PORTRAIT_SCALE: float = 1.1

@onready var dialogue_box: DialogueBox = %DialogueBox


func _ready() -> void:
	Dialogue.load_file("uncle_hangout", "res://data/dialogue/uncle_hangout.dlg")
	var main := get_tree().current_scene
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()

	_show_living_room()
	_show_uncle_portrait()

	dialogue_box.finished.connect(_on_dialogue_finished)
	_start()


const SHORT_OPENERS: Array[String] = ["open_1", "open_2", "open_3"]


func _start() -> void:
	# He's turning in early tonight — the stress test will skip his window checks.
	DayCycle.uncle_out_for_the_night = true
	GameState.uncle_hangout_seen = true

	# Text lives in data/dialogue/uncle_hangout.dlg. A random short opener, then
	# the shared closing.
	# TODO(long version): the first-ever hang-out is meant to play a longer,
	# lore-heavy conversation; every one after that plays a short version. Only
	# the short version exists today. To add it, write a [long] section in
	# uncle_hangout.dlg and, when it's the player's first time (capture
	# GameState.uncle_hangout_seen BEFORE the line above flips it true), play
	# [long] instead of the random short opener.
	var opener: String = SHORT_OPENERS[randi() % SHORT_OPENERS.size()]
	var pages: Array = []
	pages.append_array(Dialogue.get_pages("uncle_hangout", opener))
	pages.append_array(Dialogue.get_pages("uncle_hangout", "closing"))
	dialogue_box.play_pages(pages)


func _show_living_room() -> void:
	var main := get_tree().current_scene
	if main == null or not ("scene_image" in main):
		return
	var tex := load(LIVING_ROOM_BACKGROUND) as Texture2D
	if tex != null:
		main.scene_image.texture = tex


func _show_uncle_portrait() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	# Blue tank top, one of the two variants at random.
	var tex := load(UncleWardrobe.random_texture(UncleWardrobe.BLUE_TANKTOP)) as Texture2D
	if tex == null:
		return
	if main.has_method("show_bottom_center_portrait"):
		main.show_bottom_center_portrait(tex, UNCLE_PORTRAIT_SCALE, "Uncle")
	elif main.has_method("show_teacher_portrait"):
		main.show_teacher_portrait(tex, "Uncle", "", false)


func _on_dialogue_finished() -> void:
	# Hand control back to Main, which advances the phase into Night.
	finish(0, 0, 0, {}, false)
