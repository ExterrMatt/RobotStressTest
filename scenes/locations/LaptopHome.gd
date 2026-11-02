extends Control
class_name LaptopHome
## The laptop desktop's home screen, ROBO-OS: a status header, the module tiles, a small
## live system monitor and a working shell prompt along the bottom. LaptopDesktop builds
## one from a list of entries; pressing a tile (or typing its name at the prompt) runs the
## entry's action.
##
## Entry: {"label": String, "icon": String, "action": Callable,
##         "desc": String (shown on the hint line while hovered),
##         "info": Callable -> String (the live line under the tile's name)}

const GlowingLabelScript: GDScript = preload("res://scenes/ui/GlowingLabel.gd")

const HOT: Color = Color(0.35, 1.0, 0.5, 0.95)
const DESKTOP_BG: Color = Color(0.02, 0.06, 0.03, 1.0)
const PHASE_NAMES: Array[String] = ["MORNING", "EVENING", "NIGHT"]
## The battery readout runs down over the day (a cosmetic nod to the time).
const BATTERY_BY_PHASE: Array[int] = [96, 71, 38]
## The side monitor shows only when the screen is at least this wide, so the tiles keep room.
const MONITOR_MIN_SCREEN_WIDTH: float = 330.0
const MONITOR_WIDTH: float = 74.0
## Seconds per boot line, and the gap between tiles fading in after it.
const BOOT_LINE_SECONDS: float = 0.07
const TILE_STAGGER_SECONDS: float = 0.06
const SHELL_HISTORY_LINES: int = 2

var entries: Array = []
## "home" etc - shown in the prompt line ("> home session - select a module").
var session: String = "home"
## Plays the short boot sequence the first time this screen becomes visible.
var play_intro: bool = false

## The shell's output, kept for the whole run so it's still there next time the laptop opens.
static var _shell_lines: PackedStringArray = PackedStringArray(["robo-os v0.2 ready. type 'help'."])
static var _shell_commands: PackedStringArray = PackedStringArray()

var _tiles: Array[HomeTile] = []
var _hint_label: Label = null
var _cursor_label: Label = null
var _shell_output: Label = null
var _shell_input: LineEdit = null
var _command_index: int = 0
var _monitor: Control = null
var _cpu_label: Label = null
var _temp_label: Label = null
var _spark: _Sparkline = null
var _bars: _Bars = null
var _signal: _Signal = null
var _boot_overlay: Control = null
var _intro_started: bool = false
var _rng := RandomNumberGenerator.new()
var _temp: float = 41.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_build()

	var tick := Timer.new()
	tick.wait_time = 0.25
	tick.autostart = true
	tick.timeout.connect(_on_tick)
	add_child(tick)
	_on_tick()

	if play_intro:
		_prepare_intro()


func _process(_delta: float) -> void:
	if _cursor_label != null:
		_cursor_label.visible = int(Time.get_ticks_msec() / 500) % 2 == 0
	if _monitor != null:
		_monitor.visible = size.x >= MONITOR_MIN_SCREEN_WIDTH
	if play_intro and not _intro_started and is_visible_in_tree():
		_intro_started = true
		_run_intro()


# =============================================================================
# LAYOUT
# =============================================================================

func _build() -> void:
	# The bottom keeps the full side margin so the shell sits as far off the frame's bottom
	# edge as off its left one; the body (tiles + monitor) gives up the height.
	var margin := LaptopUI.screen_margin(self, 8)
	margin.add_theme_constant_override("margin_top", 6)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	col.add_child(_build_header())

	# The hint line: the session prompt, or what the hovered module does.
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 0)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_row)
	_hint_label = LaptopUI.label("", 10, LaptopUI.DIM)
	hint_row.add_child(_hint_label)
	_cursor_label = LaptopUI.label("_", 10, LaptopUI.GREEN)
	hint_row.add_child(_cursor_label)
	_set_hint("")

	var divider := _Divider.new()
	divider.custom_minimum_size = Vector2(0, 4)
	col.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)

	var area := _TileArea.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(area)
	for entry in entries:
		var tile := HomeTile.new()
		tile.title = String(entry.get("label", "?"))
		tile.icon_texture = LaptopUI.icon_tex(String(entry.get("icon", "")))
		tile.pressed.connect(_launch.bind(entry))
		tile.mouse_entered.connect(_set_hint.bind(String(entry.get("desc", ""))))
		tile.mouse_exited.connect(_set_hint.bind(""))
		area.add_child(tile)
		_tiles.append(tile)

	_monitor = _build_monitor()
	body.add_child(_monitor)

	col.add_child(_build_shell())

	# The screen's frame, drawn over everything.
	var frame := _Frame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.set_script(GlowingLabelScript)
	title.text = "R O B O · O S"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", LaptopUI.GREEN)
	title.set("glow_color", Color(0.15, 1.0, 0.35, 1.0))
	title.set("glow_radius_px", 20.0)
	title.set("glow_strength", 1.2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)

	var version := LaptopUI.label("v0.2", 10, LaptopUI.DIM)
	version.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(version)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.0, 0.12, 0.05, 0.8)
	chip_style.border_color = LaptopUI.BORDER
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(2)
	chip_style.content_margin_left = 4
	chip_style.content_margin_right = 4
	chip_style.content_margin_top = 0
	chip_style.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.add_child(LaptopUI.label("SYS: ONLINE", 9, LaptopUI.GREEN))
	row.add_child(chip)

	var battery := _Battery.new()
	battery.percent = BATTERY_BY_PHASE[clampi(int(GameState.phase), 0, BATTERY_BY_PHASE.size() - 1)]
	battery.custom_minimum_size = Vector2(40, 12)
	battery.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(battery)

	_signal = _Signal.new()
	_signal.custom_minimum_size = Vector2(12, 10)
	_signal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_signal)
	return row


## The narrow system monitor on the right: CPU sparkline, a bar meter, temperature and how
## many limbs are prepared. Mostly for show, but the last line is real.
func _build_monitor() -> Control:
	var box := LaptopUI.box(Color(0.25, 0.8, 0.4, 0.6))
	box.custom_minimum_size = Vector2(MONITOR_WIDTH, 0)
	var sb := box.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)

	var title := LaptopUI.label("SYS MON", 9, LaptopUI.DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_cpu_label = _monitor_row(col, "CPU")
	_spark = _Sparkline.new()
	# Seeded with some history so the graph is never empty.
	for i in _Sparkline.HISTORY:
		_spark.push(_random_cpu() / 100.0)
	_spark.custom_minimum_size = Vector2(0, 18)
	_spark.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_spark)

	_bars = _Bars.new()
	_bars.custom_minimum_size = Vector2(0, 12)
	_bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_bars)

	_temp_label = _monitor_row(col, "TEMP")
	var limbs := _monitor_row(col, "LIMBS")
	limbs.text = "%d RDY" % GameState.prepared_limbs.size()
	return box


## A "NAME ...... value" line in the monitor; returns the value label.
func _monitor_row(col: VBoxContainer, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(LaptopUI.label(caption, 9, LaptopUI.DIM))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var value := LaptopUI.label("", 9, LaptopUI.GREEN)
	row.add_child(value)
	return value


## The shell: the last couple of output lines over a live prompt you can type commands into.
func _build_shell() -> Control:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := LaptopUI.panel_style(Color(0.25, 0.8, 0.4, 0.55))
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.content_margin_left = 5
	box.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)

	_shell_output = LaptopUI.label("", 9, LaptopUI.DIM)
	_shell_output.add_theme_constant_override("line_spacing", -2)
	_shell_output.clip_text = true
	_shell_output.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_shell_output)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(LaptopUI.label("%s@robo-os:~$" % _shell_user(), 10, LaptopUI.GREEN))

	_shell_input = LineEdit.new()
	_shell_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shell_input.placeholder_text = "type 'help'"
	_shell_input.max_length = 40
	_shell_input.context_menu_enabled = false
	_shell_input.caret_blink = true
	_shell_input.flat = true
	_shell_input.add_theme_font_size_override("font_size", 10)
	_shell_input.add_theme_color_override("font_color", LaptopUI.GREEN)
	_shell_input.add_theme_color_override("caret_color", LaptopUI.GREEN)
	_shell_input.add_theme_color_override("font_placeholder_color", Color(LaptopUI.DIM, 0.55))
	_shell_input.add_theme_color_override("selection_color", Color(0.2, 0.85, 0.4, 0.35))
	_shell_input.add_theme_constant_override("minimum_character_width", 4)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "focus", "read_only"]:
		_shell_input.add_theme_stylebox_override(state, empty)
	_shell_input.text_submitted.connect(_run_command)
	_shell_input.gui_input.connect(_on_shell_key)
	row.add_child(_shell_input)

	# Clicking anywhere on the shell box focuses the prompt.
	box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_shell_input.grab_focus())
	_command_index = _shell_commands.size()
	_refresh_shell()
	return box


# =============================================================================
# BEHAVIOUR
# =============================================================================

func _set_hint(desc: String) -> void:
	if _hint_label == null:
		return
	_hint_label.text = ("> " + desc) if desc != "" else ("> %s session — select a module" % session)


func _launch(entry: Dictionary) -> void:
	var action: Callable = entry.get("action", Callable())
	if action.is_valid():
		action.call()


## Refreshes the live bits: tile info lines, the monitor's readings, the signal bars.
func _on_tick() -> void:
	for i in _tiles.size():
		var info: Callable = entries[i].get("info", Callable())
		_tiles[i].info = String(info.call()) if info.is_valid() else ""
	var cpu := _random_cpu()
	if _spark != null:
		_spark.push(cpu / 100.0)
	if _cpu_label != null:
		_cpu_label.text = "%d%%" % int(cpu)
	if _bars != null:
		_bars.shuffle(_rng)
	_temp = clampf(_temp + _rng.randf_range(-0.6, 0.6), 38.0, 47.0)
	if _temp_label != null:
		_temp_label.text = "%dC" % int(_temp)
	if _signal != null and _rng.randf() < 0.3:
		_signal.strength = 3 if _rng.randf() < 0.4 else 4


func _random_cpu() -> float:
	return 18.0 + 60.0 * pow(_rng.randf(), 1.6)


# =============================================================================
# SHELL
# =============================================================================

func _shell_user() -> String:
	var user := GameState.get_player_name().to_lower().replace(" ", "")
	return user if user != "" else "guest"


func _echo(line: String) -> void:
	_shell_lines.append(line)
	while _shell_lines.size() > 40:
		_shell_lines.remove_at(0)
	_refresh_shell()


func _refresh_shell() -> void:
	if _shell_output == null:
		return
	var start := maxi(0, _shell_lines.size() - SHELL_HISTORY_LINES)
	var shown := _shell_lines.slice(start)
	while shown.size() < SHELL_HISTORY_LINES:
		shown.insert(0, "")
	_shell_output.text = "\n".join(shown)


## Up / Down walk back through the commands typed before.
func _on_shell_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := (event as InputEventKey).keycode
	if key != KEY_UP and key != KEY_DOWN:
		return
	if _shell_commands.is_empty():
		return
	_command_index = clampi(_command_index + (-1 if key == KEY_UP else 1), 0, _shell_commands.size())
	_shell_input.text = _shell_commands[_command_index] if _command_index < _shell_commands.size() else ""
	_shell_input.caret_column = _shell_input.text.length()
	_shell_input.accept_event()


func _run_command(raw: String) -> void:
	var text := raw.strip_edges()
	_shell_input.clear()
	if text == "":
		return
	_shell_commands.append(text)
	while _shell_commands.size() > 20:
		_shell_commands.remove_at(0)
	_command_index = _shell_commands.size()
	_echo("$ " + text)

	var words := text.to_lower().split(" ", false)
	var verb := words[0]
	var rest := " ".join(words.slice(1))
	match verb:
		"help", "?":
			_echo("open <module> | ls | status | whoami | date | clear")
			return
		"ls", "dir", "modules":
			_echo("  ".join(_module_names()))
			return
		"clear", "cls":
			_shell_lines.clear()
			_refresh_shell()
			return
		"whoami":
			_echo(GameState.get_player_name().to_lower())
			return
		"date", "time":
			var phase: int = clampi(int(GameState.phase), 0, PHASE_NAMES.size() - 1)
			_echo("day %d, %s" % [int(GameState.day), PHASE_NAMES[phase].to_lower()])
			return
		"status":
			_echo("robot: %d parts on | %d limbs ready | $%d"
					% [_attached_part_total(), GameState.prepared_limbs.size(), int(GameState.money)])
			return
		"sudo":
			_echo("guest is not in the sudoers file. this incident will be reported.")
			return
		"exit", "logout", "quit", "shutdown":
			_echo("close the lid to log out.")
			return
		"open", "run", "start", "cd", "launch":
			if rest == "":
				_echo("usage: open <module>")
				return
			_open_by_name(rest)
			return
	_open_by_name(text.to_lower(), "command not found: %s" % verb)


## Opens the module `target` names (its label, a prefix of it, or its number on screen).
func _open_by_name(target: String, not_found: String = "") -> void:
	var index := -1
	if target.is_valid_int():
		index = int(target) - 1
	else:
		for i in entries.size():
			if String(entries[i].get("label", "")).to_lower().begins_with(target):
				index = i
				break
	if index < 0 or index >= entries.size():
		_echo(not_found if not_found != "" else "no such module: %s" % target)
		return
	_echo("launching %s..." % String(entries[index].get("label", "")).to_lower())
	_shell_input.release_focus()
	_launch(entries[index])


func _module_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry in entries:
		names.append(String(entry.get("label", "")).to_lower())
	return names


func _attached_part_total() -> int:
	var total := 0
	for id in GameState.robot_parts.keys():
		total += GameState.get_attached_part_count(String(id))
	return total


# =============================================================================
# BOOT INTRO
# =============================================================================

## Hides the tiles until the boot lines have run, under an overlay that will show them.
func _prepare_intro() -> void:
	for tile in _tiles:
		tile.appear = 0.0
		tile.modulate.a = 0.0
	_boot_overlay = ColorRect.new()
	(_boot_overlay as ColorRect).color = DESKTOP_BG
	_boot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# A click skips straight to the desktop.
	_boot_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_finish_intro())
	add_child(_boot_overlay)
	var lines := LaptopUI.label("", 10, LaptopUI.GREEN)
	lines.name = "BootLines"
	lines.position = Vector2(10, 8)
	_boot_overlay.add_child(lines)


func _run_intro() -> void:
	if _boot_overlay == null:
		return
	var label := _boot_overlay.get_node("BootLines") as Label
	var boot := [
		"ROBO-OS v0.2 BIOS",
		"memory check ........ 640K OK",
		"mount /dev/robo0 .... OK",
		"link ................ LOCAL",
		"welcome back, %s." % _shell_user(),
	]
	var tween := create_tween()
	for i in boot.size():
		var shown := "\n".join(boot.slice(0, i + 1))
		tween.tween_callback(func() -> void: label.text = shown)
		tween.tween_interval(BOOT_LINE_SECONDS)
	tween.tween_interval(0.12)
	tween.tween_callback(_finish_intro)


func _finish_intro() -> void:
	if _boot_overlay == null:
		return
	var overlay := _boot_overlay
	_boot_overlay = null
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 0.0, 0.12)
	fade.tween_callback(overlay.queue_free)
	for i in _tiles.size():
		var tile := _tiles[i]
		var t := create_tween().set_parallel(true)
		t.tween_property(tile, "modulate:a", 1.0, 0.18).set_delay(0.05 + i * TILE_STAGGER_SECONDS)
		t.tween_property(tile, "appear", 1.0, 0.3).set_delay(0.05 + i * TILE_STAGGER_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# =============================================================================
# WIDGETS
# =============================================================================

## One module tile: corner brackets, a dot-grid and status light up top, the module's icon,
## its name and a live info line. Lights up (and a scan line runs down it) under the mouse.
class HomeTile extends Button:
	const NAME_FONT_SIZE: int = 11
	const NAME_MIN_FONT_SIZE: int = 7
	const INFO_FONT_SIZE: int = 8

	var title: String = ""
	var icon_texture: Texture2D = null
	var info: String = "":
		set(value):
			info = value
			if _info_label != null:
				_info_label.text = value
				_fit_labels()
	## 0 -> 1 as the tile arrives in the boot intro: the corner brackets close in on it.
	var appear: float = 1.0:
		set(value):
			appear = value
			queue_redraw()

	var _hot: float = 0.0
	var _scan: float = 0.0
	var _icon: TextureRect = null
	var _name_label: Label = null
	var _info_label: Label = null

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, empty)

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_top", 9)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(margin)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(col)

		_icon = TextureRect.new()
		_icon.texture = icon_texture
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.modulate = Color(0.8, 0.86, 0.8)
		_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_icon)

		_name_label = LaptopUI.label(title, NAME_FONT_SIZE, LaptopUI.GREEN)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.clip_text = true
		col.add_child(_name_label)
		_info_label = LaptopUI.label(info, INFO_FONT_SIZE, LaptopUI.DIM)
		_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info_label.clip_text = true
		_info_label.visible = info != ""
		col.add_child(_info_label)
		resized.connect(_fit_labels)

	## Shrinks the name's font (down to NAME_MIN_FONT_SIZE) until it fits the tile, so long
	## names on small tiles aren't cut off; the info line just hides if it won't fit.
	func _fit_labels() -> void:
		if _name_label == null or size.x <= 0.0:
			return
		var font := _name_label.get_theme_font("font")
		var room := size.x - 8.0
		var font_size := NAME_FONT_SIZE
		while font_size > NAME_MIN_FONT_SIZE \
				and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
			font_size -= 1
		if font_size != _name_label.get_theme_font_size("font_size"):
			_name_label.add_theme_font_size_override("font_size", font_size)
		_info_label.visible = info != "" \
				and font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_FONT_SIZE).x <= room

	func _process(delta: float) -> void:
		var target := 1.0 if is_hovered() else 0.0
		var was := _hot
		_hot = move_toward(_hot, target, delta * 8.0)
		if _hot > 0.0:
			_scan = fmod(_scan + delta * 26.0, maxf(size.y, 1.0))
			queue_redraw()
		elif was > 0.0:
			queue_redraw()
		if _hot != was:
			_icon.modulate = Color(0.8, 0.86, 0.8).lerp(Color.WHITE, _hot)
			_name_label.add_theme_color_override("font_color", LaptopUI.GREEN.lerp(LaptopUI.OK, _hot))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var down := button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		var fill := Color(0.0, 0.05, 0.025, 0.6).lerp(Color(0.02, 0.17, 0.08, 0.8), _hot)
		if down:
			fill = Color(0.04, 0.26, 0.12, 0.9)
		draw_rect(r, fill)
		draw_rect(r.grow(-0.5), LaptopUI.BORDER.lerp(HOT, _hot), false, 1.0)
		if _hot > 0.0:
			draw_rect(r.grow(-2.5), Color(0.35, 1.0, 0.5, 0.18 * _hot), false, 1.0)
			draw_rect(Rect2(1.0, _scan, size.x - 2.0, 1.0), Color(0.6, 1.0, 0.62, 0.1 * _hot))

		# Corner brackets just outside the border, closing in as the tile appears.
		var out := 2.0 + (1.0 - appear) * 10.0 + _hot
		var arm := 7.0
		var bracket := Color(LaptopUI.GREEN, appear).lerp(Color(0.8, 1.0, 0.8, appear), _hot)
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var sx := -1.0 if corner.x == 0 else 1.0
			var sy := -1.0 if corner.y == 0 else 1.0
			var p: Vector2 = corner * size + Vector2(sx, sy) * out
			draw_rect(Rect2(p.x - (0.0 if sx < 0 else arm), p.y - (0.0 if sy < 0 else 2.0), arm, 2.0).abs(), bracket)
			draw_rect(Rect2(p.x - (0.0 if sx < 0 else 2.0), p.y - (0.0 if sy < 0 else arm), 2.0, arm).abs(), bracket)

		# Dot grid top-left, a status light top-right (blinks while hovered).
		var dot := Color(LaptopUI.DIM, 0.8)
		for dx in 3:
			for dy in 2:
				draw_rect(Rect2(4.0 + dx * 3.0, 4.0 + dy * 3.0, 1.0, 1.0), dot)
		var light := Rect2(size.x - 8.0, 4.0, 4.0, 4.0)
		if _hot > 0.5 and int(Time.get_ticks_msec() / 250) % 2 == 0:
			draw_rect(light, LaptopUI.OK)
		else:
			draw_rect(light, Color(LaptopUI.DIM, 0.6), false, 1.0)


## Lays its tiles out in a centred grid: one row for up to four, else two rows; each tile
## as big as fits up to MAX_TILE, a short last row centred.
class _TileArea extends Container:
	const GAP: float = 9.0
	const MAX_TILE: Vector2 = Vector2(104.0, 92.0)
	## Room left round the grid for the tiles' corner brackets.
	const INSET: float = 4.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			_lay_out()

	func _lay_out() -> void:
		var tiles: Array[Control] = []
		for child in get_children():
			if child is Control and (child as Control).visible:
				tiles.append(child)
		var n := tiles.size()
		if n == 0:
			return
		var cols := n if n <= 4 else ceili(n / 2.0)
		var rows := ceili(float(n) / cols)
		var room := size - Vector2.ONE * INSET * 2.0
		var w := clampf((room.x - GAP * (cols - 1)) / cols, 8.0, MAX_TILE.x)
		var h := clampf((room.y - GAP * (rows - 1)) / rows, 8.0, MAX_TILE.y)
		var block := Vector2(w * cols + GAP * (cols - 1), h * rows + GAP * (rows - 1))
		var origin := ((size - block) * 0.5).floor()
		for i in n:
			var r := i / cols
			var c := i % cols
			var in_row := mini(cols, n - r * cols)
			var row_shift := (cols - in_row) * (w + GAP) * 0.5
			var pos := origin + Vector2(row_shift + c * (w + GAP), r * (h + GAP))
			fit_child_in_rect(tiles[i], Rect2(pos.floor(), Vector2(w, h).floor()))


## The header's rule: a bright lead-in, then a dim line with tick marks.
class _Divider extends Control:
	func _draw() -> void:
		var y := floorf(size.y * 0.5)
		var lead := floorf(size.x * 0.28)
		draw_rect(Rect2(0, y - 1.0, lead, 2.0), LaptopUI.GREEN)
		draw_rect(Rect2(lead + 3.0, y, size.x - lead - 3.0, 1.0), LaptopUI.BORDER)
		var x := size.x - 2.0
		for i in 12:
			draw_rect(Rect2(x, y - 2.0, 1.0, 2.0), Color(LaptopUI.DIM, 0.8))
			x -= 4.0


## The whole screen's frame: a thin inset border with bright corner notches.
class _Frame extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0)
		draw_rect(r, Color(LaptopUI.BORDER, 0.35), false, 1.0)
		var arm := 10.0
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var p: Vector2 = r.position + corner * r.size
			var sx := 1.0 if corner.x == 0 else -1.0
			var sy := 1.0 if corner.y == 0 else -1.0
			draw_rect(Rect2(p.x, p.y, sx * arm, sy * 1.0).abs(), LaptopUI.GREEN)
			draw_rect(Rect2(p.x, p.y, sx * 1.0, sy * arm).abs(), LaptopUI.GREEN)


## A battery outline with its charge in four cells and the percentage beside it.
class _Battery extends Control:
	var percent: int = 100

	func _draw() -> void:
		var body := Rect2(0.5, floorf(size.y * 0.5) - 3.5, 15.0, 8.0)
		draw_rect(body, LaptopUI.GREEN, false, 1.0)
		draw_rect(Rect2(body.end.x + 0.5, body.position.y + 2.5, 1.5, 3.0), LaptopUI.GREEN)
		var cells := clampi(ceili(percent / 25.0), 0, 4)
		var low := percent < 40
		for i in cells:
			draw_rect(Rect2(body.position.x + 1.5 + i * 3.25, body.position.y + 1.5, 2.5, 5.0),
					LaptopUI.ERR if low else LaptopUI.GREEN)
		var font := CrispText.font_for(self, get_theme_default_font())
		var fs := 9
		var baseline := (size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(body.end.x + 4.0, baseline), "%d%%" % percent,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LaptopUI.DIM)


## Signal-strength bars; `strength` of the four are lit.
class _Signal extends Control:
	var strength: int = 4:
		set(value):
			strength = value
			queue_redraw()

	func _draw() -> void:
		for i in 4:
			var h := 3.0 + i * 2.0
			var rect := Rect2(i * 3.0, size.y - h, 2.0, h)
			draw_rect(rect, LaptopUI.GREEN if i < strength else Color(LaptopUI.DIM, 0.35))


## A scrolling line graph with a soft fill under it.
class _Sparkline extends Control:
	const HISTORY: int = 24

	var _values: PackedFloat32Array = PackedFloat32Array()

	func push(value: float) -> void:
		_values.append(clampf(value, 0.0, 1.0))
		while _values.size() > HISTORY:
			_values.remove_at(0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.08, 0.03, 0.6))
		for gx in range(1, 4):
			draw_rect(Rect2(floorf(size.x * gx / 4.0), 0, 1, size.y), Color(LaptopUI.DIM, 0.15))
		if _values.size() < 2:
			return
		var step := size.x / (HISTORY - 1.0)
		var start := HISTORY - _values.size()
		var points := PackedVector2Array()
		for i in _values.size():
			points.append(Vector2((start + i) * step, size.y - 1.0 - _values[i] * (size.y - 2.0)))
		var fill := points.duplicate()
		fill.append(Vector2(points[points.size() - 1].x, size.y))
		fill.append(Vector2(points[0].x, size.y))
		draw_colored_polygon(fill, Color(0.2, 0.85, 0.4, 0.18))
		draw_polyline(points, LaptopUI.GREEN, 1.0)


## A little equaliser of bars that jump about each tick.
class _Bars extends Control:
	var _levels: PackedFloat32Array = PackedFloat32Array([0.4, 0.7, 0.5, 0.9, 0.3, 0.6, 0.8, 0.5])

	func shuffle(rng: RandomNumberGenerator) -> void:
		for i in _levels.size():
			_levels[i] = clampf(_levels[i] + rng.randf_range(-0.3, 0.3), 0.15, 1.0)
		queue_redraw()

	func _draw() -> void:
		var n := _levels.size()
		var w := (size.x - (n - 1)) / n
		for i in n:
			var h := maxf(1.0, floorf(_levels[i] * size.y))
			draw_rect(Rect2(floorf(i * (w + 1.0)), size.y - h, maxf(1.0, floorf(w)), h),
					LaptopUI.GREEN if _levels[i] < 0.85 else LaptopUI.OK)
