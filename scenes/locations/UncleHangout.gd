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
	var main := get_tree().current_scene
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()

	_show_living_room()
	_show_uncle_portrait()

	dialogue_box.finished.connect(_on_dialogue_finished)
	_start()


func _start() -> void:
	# He's turning in early tonight — the stress test will skip his window checks.
	DayCycle.uncle_out_for_the_night = true
	GameState.uncle_hangout_seen = true

	# --- Dialogue --------------------------------------------------------------
	# TODO(long version): the first-ever hang-out is meant to play a longer,
	# lore-heavy conversation; every one after that plays a short version. Only
	# the short version exists today. To add the long version, branch on
	# `GameState.uncle_hangout_seen` BEFORE _start() flips it true (or capture it
	# first), and build the longer page list when it's the player's first time.
	var pages: Array = _short_opening_pages()
	_append_shared_closing(pages)
	dialogue_box.play_pages(pages)


## One of three short openers, picked at random, so repeat nights vary.
func _short_opening_pages() -> Array:
	var openers: Array = [
		[
			["Uncle: Hey Kid, have a drink with me."],
		],
		[
			["You hear a clinking come from the kitchen. Looking over, you see it's your uncle."],
			["Uncle: Hey Kid, have a few beers with me."],
		],
		[
			["You see your uncle opening up a bottle of whiskey."],
			["Uncle: Get over here kid, have some with me."],
		],
	]
	return openers[randi() % openers.size()]


## The tail every version shares: they drink, he gets too drunk and calls it a
## night, and the player realises they're free of his window checks tonight.
func _append_shared_closing(pages: Array) -> void:
	pages.append(["You both talk for a while... He drinks quite a bit."])
	pages.append(["Uncle: That's it, I'm callin' it a night."])
	pages.append(["He stands and stumbles in place."])
	pages.append(["Uncle: I'm exhausted... Seeya Kid."])
	pages.append(["Thoughts: He'll be out like a light for sure. I won't have to worry about him checking on me tonight."])


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
