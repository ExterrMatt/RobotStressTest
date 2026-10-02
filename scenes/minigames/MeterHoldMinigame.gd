class_name MeterHoldMinigame
extends Minigame
## Four meters in the middle, one button in each corner. Hold a button to fill
## its meter and let go inside the marked target band. Meters fill fast and each
## one follows its own random fill pattern (speed + easing), so the timing changes
## from bar to bar and round to round. Letting go outside the band (or maxing the
## meter out) drains it back to empty to try again; a meter released inside the
## band locks green. Lock all four to win.

const METER_COUNT: int = 4
## Seconds a hold takes to fill the meter to the top, picked per meter per round.
const FILL_TIME_RANGE: Vector2 = Vector2(0.55, 1.25)
## Height of the target band as a fraction of the meter.
const TARGET_HEIGHT: float = 0.09
const TARGET_CENTER_RANGE: Vector2 = Vector2(0.3, 0.85)
const DRAIN_SPEED: float = 2.2
const BUTTON_RADIUS: float = 34.0

## Fill curves: each maps hold progress x (0..1 of the fill time) to a meter level.
## Several are deliberately non-monotonic or lumpy to keep the timing unpredictable.
enum Pattern { LINEAR, EASE_IN, EASE_OUT, S_CURVE, STEPS, WOBBLE, SURGE, STUTTER }

## Corner buttons in meter order (meters run left to right: TL, BL, TR, BR - the left
## buttons drive the left two meters, the right buttons the right two).
const CORNERS: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]
const METER_SYMBOLS: Array[int] = [Symbol.TRIANGLE, Symbol.STAR, Symbol.SQUARE, Symbol.DIAMOND]

var _level: Array[float] = []
var _locked: Array[bool] = []
var _draining: Array[bool] = []
var _target: Array[float] = []
var _fill_time: Array[float] = []
var _pattern: Array[int] = []
## Pattern-specific random parameters (wobble frequency, step count, ...).
var _param: Array[float] = []
var _held: int = -1
var _hold_t: float = 0.0


func _init() -> void:
	title = "POWER CALIBRATION"


func _setup_game() -> void:
	_level.clear(); _locked.clear(); _draining.clear()
	_target.clear(); _fill_time.clear(); _pattern.clear(); _param.clear()
	_held = -1
	var patterns: Array = Pattern.values()
	patterns.shuffle()
	for i in METER_COUNT:
		_level.append(0.0)
		_locked.append(false)
		_draining.append(false)
		_target.append(rng.randf_range(TARGET_CENTER_RANGE.x, TARGET_CENTER_RANGE.y))
		_fill_time.append(rng.randf_range(FILL_TIME_RANGE.x, FILL_TIME_RANGE.y))
		_pattern.append(int(patterns[i % patterns.size()]))
		_param.append(rng.randf())


## Meter level after holding for progress x (0..1+) under meter i's pattern.
func _curve(i: int, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var p := _param[i]
	match _pattern[i]:
		Pattern.LINEAR:
			return x
		Pattern.EASE_IN:
			return pow(x, 2.6)
		Pattern.EASE_OUT:
			return 1.0 - pow(1.0 - x, 2.6)
		Pattern.S_CURVE:
			return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
		Pattern.STEPS:
			# Jumps in discrete chunks with flat pauses between.
			var steps := 4.0 + floorf(p * 4.0)
			var k := floorf(x * steps)
			var f := fmod(x * steps, 1.0)
			return minf(1.0, (k + smoothstep(0.65, 1.0, f)) / steps)
		Pattern.WOBBLE:
			# Rises while oscillating - it can dip back out of the band.
			var freq := 2.0 + p * 2.0
			return clampf(x + 0.09 * sin(x * TAU * freq), 0.0, 1.0)
		Pattern.SURGE:
			# Shoots up, sags back, then climbs the rest of the way.
			var a := 0.55 + p * 0.2
			if x < 0.35:
				return a * smoothstep(0.0, 0.35, x)
			if x < 0.55:
				return lerpf(a, a - 0.25, smoothstep(0.35, 0.55, x))
			return lerpf(a - 0.25, 1.0, smoothstep(0.55, 1.0, x))
		Pattern.STUTTER:
			# Mostly linear with random-feeling hitches.
			return clampf(x + 0.06 * sin(x * 37.0 + p * 10.0) * sin(x * 11.0), 0.0, 1.0)
	return x


func _game_process(delta: float) -> void:
	for i in METER_COUNT:
		if _locked[i]:
			continue
		if i == _held:
			_hold_t += delta
			var x := _hold_t / _fill_time[i]
			_level[i] = _curve(i, x)
			if x >= 1.0:
				# Maxed out: auto-release as an overshoot.
				_release(true)
		elif _draining[i]:
			_level[i] = move_toward(_level[i], 0.0, delta * DRAIN_SPEED)
			if _level[i] <= 0.0:
				_draining[i] = false


func _in_target(i: int) -> bool:
	return absf(_level[i] - _target[i]) <= TARGET_HEIGHT * 0.5


func _release(force_fail: bool = false) -> void:
	if _held < 0:
		return
	var i := _held
	_held = -1
	if not force_fail and _in_target(i):
		_locked[i] = true
		if not _locked.has(false):
			_win()
	else:
		_draining[i] = true
		flash(COL_BAD)


# --- layout -----------------------------------------------------------------

func _button_center(i: int) -> Vector2:
	var r := content_rect(BUTTON_RADIUS + 14.0)
	var c := CORNERS[i]
	return r.position + r.size * c


func _meter_rect(i: int) -> Rect2:
	var area := content_rect(14.0)
	var total_w := minf(area.size.x * 0.42, 230.0)
	var gap := 14.0
	var w := (total_w - gap * (METER_COUNT - 1)) / METER_COUNT
	var h := area.size.y - 40.0
	var x0 := area.get_center().x - total_w * 0.5
	return Rect2(x0 + i * (w + gap), area.position.y + 4.0, w, h)


# --- input ------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for i in METER_COUNT:
				if _locked[i] or _draining[i]:
					continue
				if event.position.distance_to(_button_center(i)) <= BUTTON_RADIUS:
					_held = i
					_hold_t = 0.0
					return
		else:
			_release()


# --- drawing ----------------------------------------------------------------

func _draw_game() -> void:
	for i in METER_COUNT:
		_draw_meter(i)
		_draw_button(i)


func _draw_meter(i: int) -> void:
	var r := _meter_rect(i)
	board.draw_rect(r.grow(3.0), Color(0.05, 0.05, 0.06))
	board.draw_rect(r, Color(0.14, 0.15, 0.16))
	# Target band.
	var band_h := r.size.y * TARGET_HEIGHT
	var band_y := r.end.y - r.size.y * _target[i] - band_h * 0.5
	board.draw_rect(Rect2(r.position.x, band_y, r.size.x, band_h), Color(1, 1, 1, 0.18))
	board.draw_line(Vector2(r.position.x - 6, band_y), Vector2(r.end.x + 6, band_y), COL_TEXT, 2.0)
	board.draw_line(Vector2(r.position.x - 6, band_y + band_h), Vector2(r.end.x + 6, band_y + band_h), COL_TEXT, 2.0)
	# Fill.
	var col: Color = SYMBOL_COLORS[METER_SYMBOLS[i]]
	if _locked[i]:
		col = COL_GOOD
	elif _draining[i]:
		col = COL_BAD
	var fill_h := r.size.y * clampf(_level[i], 0.0, 1.0)
	board.draw_rect(Rect2(r.position.x + 3, r.end.y - fill_h, r.size.x - 6, fill_h), col)
	# Tick marks.
	for k in range(1, 10):
		var y := r.end.y - r.size.y * k / 10.0
		board.draw_line(Vector2(r.position.x, y), Vector2(r.position.x + 6, y), Color(1, 1, 1, 0.25), 1.0)
	draw_symbol(METER_SYMBOLS[i], Vector2(r.get_center().x, r.end.y + 22.0), 11.0, SYMBOL_COLORS[METER_SYMBOLS[i]])


func _draw_button(i: int) -> void:
	var c := _button_center(i)
	var pressed := i == _held
	var sym: int = METER_SYMBOLS[i]
	board.draw_circle(c + Vector2(0, 4), BUTTON_RADIUS, Color(0, 0, 0, 0.45))
	var face := Color(0.3, 0.31, 0.33)
	if _locked[i]:
		face = COL_GOOD.darkened(0.45)
	elif pressed:
		face = face.darkened(0.3)
	board.draw_circle(c + (Vector2(0, 3) if pressed else Vector2.ZERO), BUTTON_RADIUS, face)
	board.draw_arc(c + (Vector2(0, 3) if pressed else Vector2.ZERO), BUTTON_RADIUS, 0, TAU, 40, Color(0.08, 0.08, 0.09), 3.0)
	draw_symbol(sym, c + (Vector2(0, 3) if pressed else Vector2.ZERO), 16.0, SYMBOL_COLORS[sym])
