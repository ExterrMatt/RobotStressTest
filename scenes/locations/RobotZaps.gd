class_name RobotZaps
extends Control
## Electrical shorts on the stress-test robot: little zap bolts that pop up on a random
## visible pixel of her body (like the loose screws) and keep jolting her awake until
## fixed. Clicking one emits zap_clicked; the stress test runs the fix minigame and calls
## remove_zap() once it's won.
##
## Zaps only land on parts of her in their default position that nothing is moving (see
## StressTestRobot.is_limb_in_default_position / is_limb_being_moved): never on a posed
## limb (arm out or up, leg out or raised, head raised), and never on one whose move
## minigame is up - once a limb is clicked to move, no zap can land on it until that
## minigame is lost or the limb is back in its default position. A zap whose limb then
## leaves its default position - or that a moved limb now lies over - is gone.
##
## Added at runtime as the robot's LAST child so its _input runs before the robot's own
## hover-box click handling (and the screw repairs'), letting a zap click win.

signal zap_clicked(zap_id: int)

## The raw parts a short can need (matches the night store's TONIGHT ONLY items).
const INGREDIENTS: Array[String] = ["scrap_metal", "nuts_bolts", "electronics"]
const ZAP_RADIUS: float = 9.0
const CLICK_RADIUS: float = 14.0
## Zaps keep at least this far apart (robot-local pixels).
const MIN_SPACING: float = 24.0

## Off while something else owns the mouse (a minigame, the laptop, the night ending).
var enabled: bool = true
## Active zaps: {id, pos (robot-local), ingredient, reduced_until (night time), limb (the
## one it sits on, "" for her body - see StressTestRobot.limb_of_layer)}.
var zaps: Array[Dictionary] = []
var _next_id: int = 1
var _pulse: float = 0.0
## Decoded texture images by texture, for the opaque-pixel test.
var _image_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_pulse += delta
	if not zaps.is_empty():
		drop_displaced()
		queue_redraw()


## Removes every zap that's no longer on a part of her in its default position: its limb
## has moved away, or a moved limb now lies over its spot.
func drop_displaced() -> void:
	var robot := get_parent() as Control
	if robot == null or zaps.is_empty():
		return
	var layers := _visible_layers(robot)
	for i in range(zaps.size() - 1, -1, -1):
		var z := zaps[i]
		var placed := _in_default_position(robot, String(z.get("limb", "")))
		if placed:
			var top := _top_layer_at(robot, layers, z["pos"])
			placed = top == null or _in_default_position(robot, _limb_of(robot, top))
		if not placed:
			zaps.remove_at(i)
			queue_redraw()


## Adds a zap needing `ingredient` on a random visible pixel of the robot - one whose
## part is at rest. Returns its id, or -1 if no free spot was found.
func spawn(ingredient: String, rng: RandomNumberGenerator) -> int:
	var robot := get_parent() as Control
	if robot == null:
		return -1
	var layers := _visible_layers(robot)
	for _attempt in 300:
		var p := Vector2(rng.randf_range(0.0, robot.size.x), rng.randf_range(0.0, robot.size.y))
		var crowded := false
		for z in zaps:
			if (z["pos"] as Vector2).distance_to(p) < MIN_SPACING:
				crowded = true
				break
		if crowded:
			continue
		# It lands on whatever part of her is drawn on top there.
		var layer := _top_layer_at(robot, layers, p)
		if layer == null:
			continue
		var limb := _limb_of(robot, layer)
		if not _in_default_position(robot, limb) or _being_moved(robot, limb):
			continue
		var id := _next_id
		_next_id += 1
		zaps.append({"id": id, "pos": p, "ingredient": ingredient, "reduced_until": -1.0, "limb": limb})
		queue_redraw()
		return id
	return -1


func remove_zap(zap_id: int) -> void:
	for i in zaps.size():
		if int(zaps[i]["id"]) == zap_id:
			zaps.remove_at(i)
			queue_redraw()
			return


func get_zap(zap_id: int) -> Dictionary:
	for z in zaps:
		if int(z["id"]) == zap_id:
			return z
	return {}


## Ordering a zap's part eases it off for a while (see StressTest.zap_reduced_seconds).
func reduce_for_ingredient(ingredient: String, until_time: float) -> void:
	for z in zaps:
		if String(z["ingredient"]) == ingredient:
			z["reduced_until"] = until_time


## Total awareness per second from every active zap at night time `now`.
func awareness_per_second(now: float, full_rate: float, reduced_rate: float) -> float:
	var total := 0.0
	for z in zaps:
		total += reduced_rate if now < float(z["reduced_until"]) else full_rate
	return total


## True while the mouse is over a zap, where a click opens its fix.
func is_mouse_over_zap() -> bool:
	if not enabled or zaps.is_empty() or not is_visible_in_tree():
		return false
	var local := get_local_mouse_position()
	for z in zaps:
		if (z["pos"] as Vector2).distance_to(local) <= CLICK_RADIUS:
			return true
	return false


func _input(event: InputEvent) -> void:
	if not enabled or zaps.is_empty() or not is_visible_in_tree():
		return
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := (make_input_local(event) as InputEventMouseButton).position
	for z in zaps:
		if (z["pos"] as Vector2).distance_to(local) <= CLICK_RADIUS:
			get_viewport().set_input_as_handled()
			zap_clicked.emit(int(z["id"]))
			return


func _draw() -> void:
	for z in zaps:
		var c: Vector2 = z["pos"]
		var flicker := 0.85 + 0.15 * sin(_pulse * 25.0 + float(z["id"]))
		var r := ZAP_RADIUS * flicker
		draw_circle(c, r * 1.6, Color(1.0, 0.95, 0.3, 0.18))
		var bolt := PackedVector2Array()
		for p in [Vector2(0.2, -1), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15),
				Vector2(-0.25, 1), Vector2(0.6, -0.2), Vector2(0.05, -0.2)]:
			bolt.append(c + p * r)
		draw_colored_polygon(bolt, Color(1.0, 0.88, 0.15))
		var outline := bolt.duplicate()
		outline.append(bolt[0])
		draw_polyline(outline, Color(0.1, 0.07, 0.0), 1.5, true)


# --- opaque-pixel test ----------------------------------------------------------

## The robot's visible static texture layers (TextureRects anywhere under it), the one
## drawn on top first.
func _visible_layers(robot: Control) -> Array[TextureRect]:
	var found: Array = []
	for node in robot.find_children("*", "TextureRect", true, false):
		var tr := node as TextureRect
		if tr != null and tr.texture != null and tr.is_visible_in_tree() and tr.size.x > 0.0 and tr.size.y > 0.0:
			found.append([_draw_z(tr), found.size(), tr])
	# Higher z draws on top; at the same z, later in the tree does.
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	var out: Array[TextureRect] = []
	for entry in found:
		out.append(entry[2])
	return out


## The z a canvas item is drawn at (its own z, plus its parents' while it's relative).
func _draw_z(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return z


## The top visible layer with a solid pixel at robot-local point p, or null.
func _top_layer_at(robot: Control, layers: Array[TextureRect], p: Vector2) -> TextureRect:
	var global_p := robot.get_global_transform() * p
	for tr in layers:
		var lp := tr.get_global_transform().affine_inverse() * global_p
		if lp.x < 0.0 or lp.y < 0.0 or lp.x >= tr.size.x or lp.y >= tr.size.y:
			continue
		var tex := tr.texture
		var px := Vector2i((lp / tr.size * tex.get_size()).floor())
		if _alpha_at(tex, px) > 0.5:
			return tr
	return null


## Which limb of hers `layer` belongs to ("" = her body, or a robot that doesn't say).
func _limb_of(robot: Node, layer: Node) -> String:
	if robot != null and robot.has_method("limb_of_layer"):
		return String(robot.call("limb_of_layer", layer))
	return ""


func _in_default_position(robot: Node, limb: String) -> bool:
	if robot != null and robot.has_method("is_limb_in_default_position"):
		return bool(robot.call("is_limb_in_default_position", limb))
	return true


func _being_moved(robot: Node, limb: String) -> bool:
	return robot != null and robot.has_method("is_limb_being_moved") \
			and bool(robot.call("is_limb_being_moved", limb))


func _alpha_at(tex: Texture2D, px: Vector2i) -> float:
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var in_region := px - Vector2i(at.margin.position)
		var region := Rect2i(at.region)
		if in_region.x < 0 or in_region.y < 0 or in_region.x >= region.size.x or in_region.y >= region.size.y:
			return 0.0
		var atlas_img := _image_of(at.atlas)
		if atlas_img == null:
			return 0.0
		var q := region.position + in_region
		if q.x >= atlas_img.get_width() or q.y >= atlas_img.get_height():
			return 0.0
		return atlas_img.get_pixelv(q).a
	var img := _image_of(tex)
	if img == null or px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
		return 0.0
	return img.get_pixelv(px).a


func _image_of(tex: Texture2D) -> Image:
	if tex == null:
		return null
	if not _image_cache.has(tex):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_image_cache[tex] = img
	return _image_cache[tex]
