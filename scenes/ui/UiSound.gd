extends RefCounted

const INACCESSIBLE_BUTTON_SOUND_PATH := "res://assets/sounds/menu_buttons/button_noise_inaccessable.mp3"


static func play_inaccessible_button(anchor: Node) -> void:
	if anchor == null or Engine.is_editor_hint():
		return

	var stream := load(INACCESSIBLE_BUTTON_SOUND_PATH) as AudioStream
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "InaccessibleButtonAudioPlayer"
	player.stream = stream
	anchor.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
