extends Control
class_name DroneApp
## Laptop desktop app: a simple patrol-drone monitor. A 3x3 grid of nodes with the police
## station at the bottom-left and home at the top-right; a drone icon advances along the
## diagonal between them to show how close the patrol drone is to firing.
##
## PURE VISUALIZATION - it only reads the live stress test's drone state
## (StressTest.get_drone_visual_state) and never changes anything. When no stress test is
## running it just shows the drone parked at the station.

const DRONE_TEX_PATH: String = "res://assets/textures/characters/drone/drone.png"

## Drone position along the police->home diagonal for each threat state (0 = station).
const THREAT_BY_STATE := {0: 0.0, 1: 0.55, 2: 0.8, 3: 1.0, 4: 1.0}
const STATE_LABELS := {
	-1: "NO PATROL ACTIVE",
	0: "PATROLLING",
	1: "DRONE INBOUND",
	2: "AIMING",
	3: "FIRING",
	4: "FIRING",
}

var _canvas: Control = null
var _status: Label = null
var _drone_tex: Texture2D = null
var _state: int = -1
var _pulse: float = 0.0


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
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_grid)
	box.add_child(_canvas)

	_status = LaptopUI.label("", 12, LaptopUI.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)


func _process(delta: float) -> void:
	_pulse += delta
	var st := _read_state()
	if st != _state:
		_state = st
	if _canvas != null:
		_canvas.queue_redraw()
	if _status != null:
		var firing := _state >= 3
		_status.text = String(STATE_LABELS.get(_state, "—"))
		_status.add_theme_color_override("font_color", LaptopUI.ERR if firing else LaptopUI.DIM)


## The live drone state, or -1 when no stress test is running.
func _read_state() -> int:
	var st := get_tree().get_first_node_in_group("stress_test_scene")
	if st != null and is_instance_valid(st) and st.has_method("get_drone_visual_state"):
		return int(st.call("get_drone_visual_state"))
	return -1


func _draw_grid() -> void:
	var w := _canvas.size.x
	var h := _canvas.size.y
	if w <= 4.0 or h <= 4.0:
		return
	var pad := 22.0
	var area := Vector2(w - pad * 2.0, h - pad * 2.0)
	var step := Vector2(area.x / 2.0, area.y / 2.0)
	# vertex (col,row) -> pixel; row 0 = top.
	var vtx := func(cx: int, ry: int) -> Vector2:
		return Vector2(pad + step.x * cx, pad + step.y * ry)

	var dim := Color(0.3, 0.85, 0.4, 0.35)
	var line := Color(0.35, 1.0, 0.5, 0.5)
	# Diagonal path police(0,2) -> home(2,0).
	var police: Vector2 = vtx.call(0, 2)
	var home: Vector2 = vtx.call(2, 0)
	_canvas.draw_line(police, home, line, 1.5)
	# Grid nodes + connecting edges.
	for ry in 3:
		for cx in 3:
			var p: Vector2 = vtx.call(cx, ry)
			if cx < 2:
				_canvas.draw_line(p, vtx.call(cx + 1, ry), dim, 1.0)
			if ry < 2:
				_canvas.draw_line(p, vtx.call(cx, ry + 1), dim, 1.0)
	for ry in 3:
		for cx in 3:
			_canvas.draw_circle(vtx.call(cx, ry), 2.5, dim)

	var font := ThemeDB.fallback_font
	# Police station marker (bottom-left).
	_canvas.draw_rect(Rect2(police - Vector2(6, 6), Vector2(12, 12)), Color(0.35, 0.7, 1.0, 0.9), true)
	_canvas.draw_string(font, police + Vector2(-10, 20), "STATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LaptopUI.DIM)
	# Home marker (top-right).
	_canvas.draw_rect(Rect2(home - Vector2(6, 6), Vector2(12, 12)), Color(0.45, 1.0, 0.55, 0.9), true)
	_canvas.draw_string(font, home + Vector2(-14, -10), "HOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LaptopUI.GREEN)

	# Drone position along the diagonal from its threat state.
	var t: float = float(THREAT_BY_STATE.get(maxi(_state, 0), 0.0))
	var pos: Vector2 = police.lerp(home, t)
	var firing := _state >= 3
	if firing:
		# pulse a warning ring at home
		var r := 10.0 + sin(_pulse * 12.0) * 3.0
		_canvas.draw_arc(home, r, 0.0, TAU, 24, Color(1.0, 0.35, 0.32, 0.9), 2.0)
	var tint := Color(1.0, 0.4, 0.38, 1.0) if firing else Color(1, 1, 1, 1)
	if _drone_tex != null:
		var s := 26.0
		_canvas.draw_texture_rect(_drone_tex, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
	else:
		_canvas.draw_circle(pos, 6.0, tint)
