class_name LaptopHackScreen
extends Control
## The laptop takeover shown while a patrol drone's hack is live (StressTest drone hacks).
## It covers whatever app was open with a red intrusion warning and a countdown to the
## power cut; BLOCK starts a random repair minigame right here on the laptop screen.
## Winning it emits `blocked`; losing (or backing out) returns to the warning so the
## player can try again while time remains. The stress test owns the clock (time_left)
## and frees this screen when the hack ends either way.

signal blocked

const COL_BG := Color(0.12, 0.0, 0.0, 1.0)
const COL_RED := Color(1.0, 0.3, 0.26)
const COL_TEXT := Color(1.0, 0.85, 0.82)

## Seconds until the hack lands, set every frame by the stress test.
var time_left: float = 0.0

var _warning: Control = null
var _countdown: Label = null
var _title: Label = null
var _game: Minigame = null
var _pulse: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Solid backdrop under both the warning and the minigame, hiding the app beneath.
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_warning = Control.new()
	_warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_warning)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.add_child(col)
	_title = _label("!! INTRUSION DETECTED !!", 16, COL_RED)
	col.add_child(_title)
	col.add_child(_label("PATROL DRONE IS HACKING YOUR GENERATOR", 11, COL_TEXT))
	_countdown = _label("", 13, COL_TEXT)
	col.add_child(_countdown)

	var block := Button.new()
	block.text = "BLOCK THE HACK"
	block.focus_mode = Control.FOCUS_NONE
	block.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	block.add_theme_font_size_override("font_size", 13)
	block.add_theme_color_override("font_color", COL_TEXT)
	block.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var sb := LaptopUI.panel_style(COL_RED if state == "normal" else Color.WHITE)
		sb.bg_color = Color(0.3, 0.02, 0.02)
		block.add_theme_stylebox_override(state, sb)
	block.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	block.pressed.connect(_start_block_game)
	col.add_child(block)


func _process(delta: float) -> void:
	_pulse += delta
	if _countdown != null:
		_countdown.text = "POWER CUT IN %ds" % ceili(time_left)
	if _title != null:
		_title.modulate.a = 0.55 + 0.45 * absf(sin(_pulse * 6.0))


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := LaptopUI.label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## BLOCK: play a random repair minigame on the laptop screen.
func _start_block_game() -> void:
	if _game != null and is_instance_valid(_game):
		return
	var games := _block_games()
	_game = games[randi() % games.size()].new()
	_game.title = "BLOCK HACK: " + _game.title
	_game.embedded = true
	_game.auto_close_on_result = true
	_game.closed.connect(_on_game_closed.bind(_game))
	_warning.visible = false
	add_child(_game)


## Repair minigames that can block a hack (the grid games are for limb moves).
func _block_games() -> Array[GDScript]:
	return [LeverSequenceMinigame, MeterHoldMinigame, WireConnectMinigame,
			ScrewTurnMinigame, MinefieldMinigame]


func _on_game_closed(game: Minigame) -> void:
	var won := game.solved
	_game = null
	_warning.visible = true
	if won:
		blocked.emit()
