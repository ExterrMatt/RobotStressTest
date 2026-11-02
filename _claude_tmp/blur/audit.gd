extends Node
## Throwaway blur audit: boots Main, visits every location / minigame through the debug
## hooks and logs text drawn at a node scale > 1 with no oversampled font.

const OUT_DIR := "res://_claude_tmp/blur/out/"
var _main: Node
var _found: Dictionary = {}
var _script_draws: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	await _wait(0.5)
	_main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	await _wait(3.0)
	_main.call("_debug_give_all_items")
	_main.call("_debug_give_money")
	var target: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "bedroom"
	if target == "bedroom":
		await _step("bedroom", Callable())
	elif target == "laptop":
		await _step("laptop", _main.call.bind("_debug_open_laptop"), 7.0)
	elif target.begins_with("mg_"):
		var s: GDScript = load("res://scenes/minigames/%s.gd" % target.substr(3))
		await _step(target, _main.call.bind("_debug_open_minigame", s), 3.0)
	else:
		await _step(target, _jump.bind(target), 7.0)
		if target == "workshop":
			var ws: Node = _main.get("_current_location_node")
			await _step("workshop_minigame", ws.call.bind("_enter_minigame"), 6.0)
		if target in ["stress_test", "maintenance"]:
			await _step(target + "_laptop_overlay", _main.call.bind("_debug_open_laptop_overlay"), 5.0)
	_report()
	get_tree().quit()

func _jump(id: String) -> void:
	_main.call("_cancel_active_transitions")
	_main.call("_debug_open_location_by_id", StringName(id))

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _step(tag: String, action: Callable, settle: float = 5.0) -> void:
	print("[AUDIT] step ", tag)
	if action.is_valid():
		action.call()
	await _wait(settle)
	var cur: Node = _main.get("_current_location_node")
	print("[AUDIT]   current=", cur.scene_file_path if cur != null and is_instance_valid(cur) else "none")
	_audit(tag)
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + tag + ".png"))

func _audit(tag: String) -> void:
	_walk(get_tree().root, tag)

func _walk(n: Node, tag: String) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is CanvasItem:
		_check(n as CanvasItem, tag)
	for c in n.get_children():
		_walk(c, tag)

func _draws_text(ci: CanvasItem) -> String:
	if ci is Label: return "Label:" + (ci as Label).text.left(24) if (ci as Label).text != "" else ""
	if ci is RichTextLabel: return "RTL:" + (ci as RichTextLabel).get_parsed_text().left(24) if (ci as RichTextLabel).get_parsed_text() != "" else ""
	if ci is Button: return "Button:" + (ci as Button).text.left(24) if (ci as Button).text != "" else ""
	if ci is LineEdit or ci is TextEdit: return ci.get_class()
	var s: Script = ci.get_script()
	if s != null:
		var key := s.resource_path
		if not _script_draws.has(key):
			var src := s.source_code if s is GDScript else ""
			_script_draws[key] = src.contains("draw_string") or src.contains("draw_char") or src.contains("draw_multiline_string")
		if _script_draws[key]:
			return "draw_string(" + key.get_file() + ")"
	return ""

func _check(ci: CanvasItem, tag: String) -> void:
	var what := _draws_text(ci)
	if what == "":
		return
	var sc := ci.get_global_transform_with_canvas().get_scale()
	var s := maxf(absf(sc.x), absf(sc.y))
	if s <= 1.05:
		return
	var crisp := false
	if ci is Control:
		var item := "normal_font" if ci is RichTextLabel else "font"
		var f := (ci as Control).get_theme_font(item)
		if f is FontFile and (f as FontFile).oversampling > 0.0:
			crisp = absf((f as FontFile).oversampling - s * get_viewport().get_final_transform().get_scale().x) < 0.5
	var path := str(ci.get_path()).replace("/root/Main/", "")
	var key := tag + "|" + path
	if _found.has(key): return
	_found[key] = true
	print("[AUDIT] %s %s scale=%.2f crisp=%s  %s" % [tag, what, s, crisp, path])

func _report() -> void:
	print("[AUDIT] done")
