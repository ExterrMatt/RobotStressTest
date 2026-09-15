extends Control
class_name StressHistoryApp
## Laptop desktop app: a log of the player's stress-test results, one row per night,
## day after day. Reads GameState.stress_test_history (recorded by StressTest when a
## night concludes).

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	LaptopUI.screen_margin(self).add_child(col)

	col.add_child(LaptopUI.label("// STRESS TEST LOG", 14, LaptopUI.GREEN))

	var box := LaptopUI.box()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box)

	var history: Array = GameState.stress_test_history
	if history.is_empty():
		var c := CenterContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(c)
		c.add_child(LaptopUI.label("— no stress tests logged yet —", 11, LaptopUI.DIM))
		return

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)

	# Newest first so the latest night is at the top.
	var n := history.size()
	for i in n:
		var entry: Dictionary = history[n - 1 - i]
		list.add_child(_make_row(entry, n - i))


func _make_row(entry: Dictionary, index: int) -> Control:
	var success := bool(entry.get("success", false))
	var box := LaptopUI.box(Color(0.35, 1.0, 0.5, 0.4) if success else Color(1.0, 0.45, 0.42, 0.5))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(LaptopUI.label("#%d · DAY %d" % [index, int(entry.get("day", 0))], 11, LaptopUI.DIM))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	top.add_child(LaptopUI.label("PASS" if success else "FAIL", 12, LaptopUI.OK if success else LaptopUI.ERR))

	v.add_child(LaptopUI.label("Power %d%%   Screws %d%%" % [int(entry.get("electricity", 0)), int(entry.get("screws", 0))], 10, LaptopUI.GREEN))
	if not success:
		var reason := String(entry.get("reason", ""))
		if reason != "":
			var r := LaptopUI.label(reason, 9, LaptopUI.DIM)
			r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			r.custom_minimum_size = Vector2(0, 0)
			v.add_child(r)
	return box
