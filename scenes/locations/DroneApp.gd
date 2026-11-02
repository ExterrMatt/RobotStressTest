extends Control
class_name DroneApp
## Laptop desktop app: the patrol-drone early warning. A grid of nodes with the police
## station at the bottom-left and home at the top-right. Each drone flies its own random
## route (StressTest / DroneRoute) and reaches home the moment it arrives at the window;
## on the way it pauses at checkpoints (the diamonds), where it may try to hack you.
##
## While it is setting up a hack (red "HACK INCOMING"), clicking the drone here foils the
## hack and stuns it for a few seconds - the one thing this app can do to the game
## (StressTest.stun_patrol_drone). Everything else is read-only (get_drone_visual_state /
## get_drone_seconds_until_arrival / get_drone_route_info).

const DRONE_TEX_PATH: String = "res://assets/textures/characters/drone/drone.png"

## Under this many seconds out, the warning turns red and pulses.
const URGENT_SECONDS: float = 6.0
## Click slop around the drone icon.
const DRONE_CLICK_RADIUS: float = 22.0
const DRONE_ICON_SIZE: float = 28.0

## Live drone states (StressTest DRONE_*), plus NO_TEST when no stress test is running.
const NO_TEST: int = -1
const DRONE_NONE: int = 0
const DRONE_IDLE: int = 1
const DRONE_GUNS: int = 2
const DRONE_SHOT: int = 3
const DRONE_ZAP: int = 4
const STATE_LABELS := {
	DRONE_IDLE: "DRONE AT WINDOW - USE EMERGENCY POWER",
	DRONE_GUNS: "DRONE AIMING - USE EMERGENCY POWER",
	DRONE_SHOT: "FIRING",
	DRONE_ZAP: "DRONE DRIVEN OFF",
}
## StressTest HACK_* phases.
const HACK_NONE: int = 0
const HACK_BUFFER: int = 1
const HACK_LIVE: int = 2

const COL_DIM := Color(0.3, 0.85, 0.4, 0.3)
const COL_ROUTE := Color(0.35, 1.0, 0.5, 0.45)
const COL_HOT := Color(1.0, 0.4, 0.38)
const COL_DELIVERY := Color(0.45, 0.8, 1.0)

var _canvas: Control = null
var _status: Label = null
var _drone_tex: Texture2D = null
var _state: int = NO_TEST
## Seconds until the next arrival, or -1 when none is due (or one is already here).
var _eta: float = -1.0
var _route: Dictionary = {}
var _pulse: float = 0.0
## Where the drone was last drawn (canvas-local), for click hits.
var _drone_px: Vector2 = Vector2(-999, -999)
## Brief "STUNNED Xs" confirmation after a successful click.
var _stun_msg: String = ""
var _stun_msg_left: float = 0.0
## Night-store delivery drone (StressTest.get_delivery_info) and the route being drawn
## for it: press on it and drag along the grid.
var _delivery: Dictionary = {}
var _delivery_px: Vector2 = Vector2(-999, -999)
var _drawing: bool = false
var _draft: Array[Vector2i] = []
## Grid layout from the last draw, for mapping the mouse to nodes.
var _grid_pad: float = 24.0
var _grid_step: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(DRONE_TEX_PATH):
		_drone_tex = load(DRONE_TEX_PATH) as Texture2D

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	LaptopUI.screen_margin(self).add_child(col)
	col.add_child(LaptopUI.label("// PATROL MONITOR", 14, LaptopUI.GREEN))

	var box := LaptopUI.box()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	col.add_child(box)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_grid)
	_canvas.gui_input.connect(_on_canvas_input)
	box.add_child(_canvas)

	_status = LaptopUI.label("", 12, LaptopUI.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)


func _process(delta: float) -> void:
	_pulse += delta
	_stun_msg_left = maxf(0.0, _stun_msg_left - delta)
	_read_state()
	if _canvas != null:
		_canvas.queue_redraw()
		_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hack_phase() == HACK_BUFFER \
				else Control.CURSOR_ARROW
	if _status != null:
		_status.text = _status_text()
		var alert := _is_alert()
		var col := LaptopUI.ERR if alert else LaptopUI.DIM
		if alert:
			# Blink while the threat is real.
			col.a = 0.55 + 0.45 * absf(sin(_pulse * 6.0))
		_status.add_theme_color_override("font_color", col)


func _stress_test() -> Node:
	var st := get_tree().get_first_node_in_group("stress_test_scene")
	if st != null and is_instance_valid(st) and st.has_method("get_drone_visual_state"):
		return st
	return null


## Reads the live drone state, arrival countdown and route (NO_TEST when no stress test).
func _read_state() -> void:
	_state = NO_TEST
	_eta = -1.0
	_route = {}
	_delivery = {}
	var st := _stress_test()
	if st == null:
		return
	_state = int(st.call("get_drone_visual_state"))
	if st.has_method("get_drone_seconds_until_arrival"):
		_eta = float(st.call("get_drone_seconds_until_arrival"))
	if st.has_method("get_drone_route_info"):
		_route = st.call("get_drone_route_info")
	if st.has_method("get_delivery_info"):
		_delivery = st.call("get_delivery_info")


func _hack_phase() -> int:
	return int(_route.get("hack_phase", HACK_NONE))


func _inbound() -> bool:
	return _state == DRONE_NONE and _eta >= 0.0 and bool(_route.get("departed", false))


func _is_alert() -> bool:
	if _state in [DRONE_IDLE, DRONE_GUNS, DRONE_SHOT] or _hack_phase() != HACK_NONE:
		return true
	return _inbound() and _eta <= URGENT_SECONDS


func _status_text() -> String:
	if _state == NO_TEST:
		return "NO PATROL ACTIVE"
	var hack_left := ceili(float(_route.get("hack_time_left", 0.0)))
	if _hack_phase() == HACK_BUFFER:
		return "HACK INCOMING - CLICK THE DRONE TO STUN IT (%ds)" % hack_left
	if STATE_LABELS.has(_state):
		return String(STATE_LABELS[_state])
	if _hack_phase() == HACK_LIVE:
		return "HACK IN PROGRESS - BLOCK IT (%ds)" % hack_left
	if _stun_msg_left > 0.0:
		return _stun_msg
	if bool(_route.get("stunned", false)):
		return "DRONE STUNNED"
	if _inbound():
		var where := "AT CHECKPOINT" if bool(_route.get("paused", false)) else "INBOUND"
		return "DRONE %s - ARRIVING IN %ds" % [where, ceili(_eta)]
	if bool(_delivery.get("active", false)):
		return "DELIVERY EN ROUTE - DRAG IT TO PLOT A SAFE ROUTE HOME"
	if _eta < 0.0:
		return "ALL CLEAR - NO MORE PATROLS TONIGHT"
	return "PATROLLING - ALL CLEAR"


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _drawing:
		_extend_draft(event.position)
		accept_event()
		return
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		if _drawing:
			_drawing = false
			var st := _stress_test()
			if st != null and not _draft.is_empty() and st.has_method("set_delivery_path"):
				st.call("set_delivery_path", _draft)
			_draft.clear()
			accept_event()
		return
	# Press on the delivery drone: start drawing it a new route.
	if bool(_delivery.get("active", false)) and event.position.distance_to(_delivery_px) <= DRONE_CLICK_RADIUS:
		_drawing = true
		_draft.clear()
		accept_event()
		return
	if event.position.distance_to(_drone_px) > DRONE_CLICK_RADIUS:
		return
	var st := _stress_test()
	if st == null or not st.has_method("stun_patrol_drone"):
		return
	var stun := float(st.call("stun_patrol_drone"))
	if stun > 0.0:
		_stun_msg = "HACK FOILED - DRONE STUNNED FOR %.1fs" % stun
		_stun_msg_left = 2.5
	accept_event()


## Snaps the cursor to the nearest grid node and grows the draft route one edge at a time
## (like the slide-route minigame); dragging back over the previous node undoes a step.
func _extend_draft(mouse: Vector2) -> void:
	if _grid_step.x <= 0.0 or _grid_step.y <= 0.0:
		return
	var g := maxi(2, int(_route.get("grid", 5)))
	var f := (mouse - Vector2(_grid_pad, _grid_pad)) / _grid_step
	var node := Vector2i(roundi(f.x), roundi(f.y))
	if node.x < 0 or node.y < 0 or node.x >= g or node.y >= g:
		return
	# Only snap once the cursor is close to the node itself.
	if (Vector2(node) - f).length() > 0.35:
		return
	var anchor: Vector2i = _delivery.get("anchor", node)
	var last: Vector2i = _draft.back() if not _draft.is_empty() else anchor
	if node == last:
		return
	var before: Vector2i = anchor
	if _draft.size() >= 2:
		before = _draft[_draft.size() - 2]
	if not _draft.is_empty() and node == before:
		_draft.pop_back()
		return
	if absi(node.x - last.x) + absi(node.y - last.y) == 1:
		_draft.append(node)


func _draw_grid() -> void:
	var w := _canvas.size.x
	var h := _canvas.size.y
	if w <= 4.0 or h <= 4.0:
		return
	var g := maxi(2, int(_route.get("grid", 5)))
	var pad := 24.0
	var step := Vector2((w - pad * 2.0) / (g - 1), (h - pad * 2.0) / (g - 1))
	_grid_pad = pad
	_grid_step = step
	var to_px := func(p: Vector2) -> Vector2:
		return Vector2(pad, pad) + p * step

	# Grid nodes + edges.
	for ry in g:
		for cx in g:
			var p: Vector2 = to_px.call(Vector2(cx, ry))
			if cx < g - 1:
				_canvas.draw_line(p, to_px.call(Vector2(cx + 1, ry)), COL_DIM, 1.0)
			if ry < g - 1:
				_canvas.draw_line(p, to_px.call(Vector2(cx, ry + 1)), COL_DIM, 1.0)
	for ry in g:
		for cx in g:
			_canvas.draw_circle(to_px.call(Vector2(cx, ry)), 2.5, COL_DIM)

	var police: Vector2 = to_px.call(Vector2(0, g - 1))
	var home: Vector2 = to_px.call(Vector2(g - 1, 0))
	var alert := _is_alert()
	var hack := _hack_phase()

	# The drone's route and its checkpoints.
	var path: Array = _route.get("path", [])
	var drone_grid: Vector2 = _route.get("position", Vector2(0, g - 1))
	if path.size() >= 2:
		for i in range(path.size() - 1):
			_canvas.draw_line(to_px.call(Vector2(path[i])), to_px.call(Vector2(path[i + 1])), COL_ROUTE, 2.0)
		# Highlight the stretch already flown: every node reached, then on to the drone.
		var flown_col := Color(COL_HOT, 0.85) if alert else LaptopUI.GREEN
		var flown := clampi(int(_route.get("flown_index", 0)), 0, path.size() - 1)
		for i in flown:
			_canvas.draw_line(to_px.call(Vector2(path[i])), to_px.call(Vector2(path[i + 1])), flown_col, 3.0)
		_canvas.draw_line(to_px.call(Vector2(path[flown])), to_px.call(drone_grid), flown_col, 3.0)
		for k in _route.get("checkpoints", []):
			var c: Vector2 = to_px.call(Vector2(path[k]))
			var d := 6.0
			_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0),
					c + Vector2(0, d), c + Vector2(-d, 0)]), Color(1.0, 0.85, 0.3, 0.9))

	var font := CrispText.font_for(_canvas, ThemeDB.fallback_font)
	_canvas.draw_rect(Rect2(police - Vector2(6, 6), Vector2(12, 12)), Color(0.35, 0.7, 1.0, 0.9), true)
	_canvas.draw_string(font, police + Vector2(-10, 20), "STATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LaptopUI.DIM)
	_canvas.draw_rect(Rect2(home - Vector2(6, 6), Vector2(12, 12)), Color(0.45, 1.0, 0.55, 0.9), true)
	_canvas.draw_string(font, home + Vector2(-14, -10), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LaptopUI.GREEN)
	if _delivery.has("depot"):
		var depot_node: Vector2i = _delivery["depot"]
		var depot: Vector2 = to_px.call(Vector2(depot_node))
		_canvas.draw_rect(Rect2(depot - Vector2(6, 6), Vector2(12, 12)), COL_DELIVERY, true)
		# Label below on the bottom row (beside STATION), otherwise to the right.
		var label_off := Vector2(-14, 20) if depot_node.y == g - 1 else Vector2(10, 4)
		_canvas.draw_string(font, depot + label_off, "DEPOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_DELIVERY)

	# The drone.
	var pos: Vector2 = home if _state in [DRONE_IDLE, DRONE_GUNS, DRONE_SHOT, DRONE_ZAP] \
			else to_px.call(drone_grid)
	_drone_px = pos
	# Where the patrol drone plans to go next: chevrons marching along its next edge.
	if _route.has("next_node") and _state == DRONE_NONE:
		_draw_next_move_arrow(pos, to_px.call(Vector2(_route["next_node"])))
	if _state in [DRONE_IDLE, DRONE_GUNS, DRONE_SHOT]:
		var r := 10.0 + sin(_pulse * 12.0) * 3.0
		_canvas.draw_arc(home, r, 0.0, TAU, 24, Color(COL_HOT, 0.9), 2.0)
	if hack == HACK_BUFFER:
		# Signal waves off the drone: click it now.
		for i in 3:
			var ring := fmod(_pulse * 1.6 + i / 3.0, 1.0)
			_canvas.draw_arc(pos, 10.0 + ring * 18.0, 0.0, TAU, 24, Color(COL_HOT, 1.0 - ring), 2.0)
	if _inbound() and hack == HACK_NONE:
		_canvas.draw_string(font, pos + Vector2(16, 4), "%ds" % ceili(_eta), HORIZONTAL_ALIGNMENT_LEFT,
				-1, 12, LaptopUI.ERR if alert else LaptopUI.GREEN)
	var tint := Color(1, 1, 1, 1)
	if bool(_route.get("stunned", false)):
		tint = Color(0.55, 0.75, 1.0, 0.5 + 0.5 * absf(sin(_pulse * 10.0)))
	elif alert:
		tint = Color(1.0, 0.45, 0.42, 1.0)
	if _drone_tex != null:
		var s := DRONE_ICON_SIZE
		_canvas.draw_texture_rect(_drone_tex, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
	else:
		_canvas.draw_circle(pos, 6.0, tint)

	_draw_delivery(to_px, font)


## Animated chevrons from the patrol drone toward the node it heads to next.
func _draw_next_move_arrow(from: Vector2, to: Vector2) -> void:
	var d := to - from
	var length := d.length()
	if length < 6.0:
		return
	var dir := d / length
	var side := dir.orthogonal()
	var col := Color(1.0, 0.55, 0.3)
	for i in 3:
		var t := fmod(_pulse * 0.9 + i / 3.0, 1.0)
		var tip := from + dir * (14.0 + t * maxf(0.0, length - 18.0))
		var a := absf(sin(t * PI))
		_canvas.draw_polyline(PackedVector2Array([tip - dir * 6.0 + side * 5.0, tip, tip - dir * 6.0 - side * 5.0]),
				Color(col, a), 2.0, true)


## The delivery drone (a package-carrying drone in delivery blue), its planned route,
## and the route being drawn for it.
func _draw_delivery(to_px: Callable, font: Font) -> void:
	if not bool(_delivery.get("active", false)):
		_delivery_px = Vector2(-999, -999)
		return
	var pos: Vector2 = to_px.call(_delivery.get("position", Vector2.ZERO))
	_delivery_px = pos
	# Planned route: from the drone on through each queued node.
	var pts := PackedVector2Array([pos, to_px.call(Vector2(_delivery.get("anchor", Vector2i.ZERO)))])
	for n in _delivery.get("path", []):
		pts.append(to_px.call(Vector2(n)))
	if not _drawing:
		_dashed(pts, Color(COL_DELIVERY, 0.85))
	else:
		var draft := PackedVector2Array([pos, to_px.call(Vector2(_delivery.get("anchor", Vector2i.ZERO)))])
		for n in _draft:
			draft.append(to_px.call(Vector2(n)))
		_canvas.draw_polyline(draft, COL_DELIVERY, 3.0, true)
		for p in draft:
			_canvas.draw_circle(p, 3.5, COL_DELIVERY)
	# The drone itself: delivery-tinted with a little crate slung under it.
	var s := DRONE_ICON_SIZE * 0.85
	_canvas.draw_rect(Rect2(pos + Vector2(-5, 4), Vector2(10, 8)), Color(0.85, 0.65, 0.35))
	if _drone_tex != null:
		_canvas.draw_texture_rect(_drone_tex, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, COL_DELIVERY)
	else:
		_canvas.draw_circle(pos, 6.0, COL_DELIVERY)
	if not _drawing:
		var ring := 0.5 + 0.5 * sin(_pulse * 4.0)
		_canvas.draw_arc(pos, DRONE_CLICK_RADIUS - 4.0 + ring * 3.0, 0.0, TAU, 24, Color(COL_DELIVERY, 0.5), 1.5)
	# Label on whichever side has room.
	var label_x := -62.0 if pos.x > _canvas.size.x * 0.5 else 14.0
	_canvas.draw_string(font, pos + Vector2(label_x, -12), "DELIVERY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_DELIVERY)


func _dashed(pts: PackedVector2Array, col: Color) -> void:
	for i in range(pts.size() - 1):
		_canvas.draw_dashed_line(pts[i], pts[i + 1], col, 2.0, 6.0, true)
