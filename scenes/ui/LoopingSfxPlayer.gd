extends AudioStreamPlayer
class_name LoopingSfxPlayer
## An AudioStreamPlayer that loops a one-shot stream by replaying it whenever it
## finishes, and can be told to END the loop *gracefully*: the pass that is
## currently sounding plays out to its natural end and simply isn't restarted —
## no abrupt cut.
##
## Use this (instead of an AudioStream with `loop = true`) whenever you want a
## looping sound to stop only on its own boundary. With stream-level looping the
## clip never emits `finished` and stop() would chop it mid-sample; here we drive
## the loop ourselves so finish_loop() can let the tail ring out.
##
## The assigned stream must have its own `loop` disabled (otherwise `finished`
## never fires); configure() enforces that defensively.

## Whether a finished pass should be replayed. Toggled off by finish_loop().
var _looping: bool = false
## Set by release_when_finished(): free this player once the current pass ends.
var _free_when_done: bool = false


func _ready() -> void:
	finished.connect(_on_finished)


## One-time setup: assign the stream (with its own looping forced off) and volume.
## Safe to call with a null stream — the player just becomes a silent no-op.
func configure(audio_stream: AudioStream, volume_scale: float) -> void:
	if audio_stream != null:
		_disable_stream_loop(audio_stream)
	stream = audio_stream
	volume_db = linear_to_db(volume_scale)


## Begin (or restart) the loop from the top. No-op if no stream is assigned.
func start_loop() -> void:
	if stream == null:
		return
	_looping = true
	if not playing:
		play()


## End the loop WITHOUT cutting the current pass: it rings out to its natural end
## and is not replayed. If nothing is sounding this is simply a quiet no-op.
func finish_loop() -> void:
	_looping = false


## End the loop and free this player once its current pass rings out (or right
## now, if nothing is sounding). Parent this player to a node that outlives the
## caller's scene (e.g. the persistent root scene) before using this, so the
## final pass keeps playing through a scene transition instead of being cut off
## when the caller is freed.
func release_when_finished() -> void:
	_looping = false
	if playing:
		_free_when_done = true
	else:
		queue_free()


## Hard stop: silence immediately and end the loop. For teardown where the sound
## SHOULD be cut, not the graceful "let it ring out" case above.
func stop_loop() -> void:
	_looping = false
	stop()


func _on_finished() -> void:
	if _looping:
		play()
	elif _free_when_done:
		queue_free()


func _disable_stream_loop(audio_stream: AudioStream) -> void:
	for property in audio_stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			audio_stream.set("loop", false)
			return
