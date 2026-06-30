extends Node
## Owns OS-window behaviour that should apply across every scene, independent
## of which location or menu is loaded:
##
##   * Display mode (windowed / windowed-fullscreen / fullscreen), driven by
##     GameState.window_mode and applied on startup and whenever it changes.
##   * Auto-pausing and muting the game while the application window is not
##     focused, so alt-tabbing away is not punishing and the game stops making
##     noise in the background.
##
## Registered in project.godot under [autoload] as WindowManager. Listed after
## GameState so GameState.window_mode is available in _ready().

## True when our own focus-loss is what paused the SceneTree. We only un-pause
## on focus-return if we were the ones who paused, so we never resume a pause
## that gameplay set on purpose (e.g. the StressTest failure overlay).
var _paused_for_focus_loss: bool = false

## Master-bus mute state captured just before we muted on focus loss. Restored
## verbatim on focus return so we never clobber a mute the player set.
var _prev_master_mute: bool = false
var _muted_for_focus_loss: bool = false


func _ready() -> void:
	# Keep processing while the tree is paused, otherwise we could not resume
	# ourselves after pausing on focus loss.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		_apply_window_mode(game_state.window_mode)
		game_state.window_mode_changed.connect(_apply_window_mode)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_focus_lost()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_focus_gained()


func _on_focus_lost() -> void:
	var tree := get_tree()
	if tree != null and not tree.paused:
		tree.paused = true
		_paused_for_focus_loss = true
	if not _muted_for_focus_loss:
		_prev_master_mute = AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, true)
		_muted_for_focus_loss = true


func _on_focus_gained() -> void:
	if _paused_for_focus_loss:
		var tree := get_tree()
		if tree != null:
			tree.paused = false
		_paused_for_focus_loss = false
	if _muted_for_focus_loss:
		AudioServer.set_bus_mute(0, _prev_master_mute)
		_muted_for_focus_loss = false


## Maps GameState.WindowMode values onto the engine's DisplayServer window
## modes. Godot's WINDOW_MODE_FULLSCREEN is a borderless full-screen window
## ("windowed fullscreen"); WINDOW_MODE_EXCLUSIVE_FULLSCREEN is true fullscreen.
func _apply_window_mode(mode: int) -> void:
	match mode:
		GameState.WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		GameState.WindowMode.WINDOWED_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
