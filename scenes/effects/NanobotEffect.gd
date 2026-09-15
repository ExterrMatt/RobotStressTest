extends Control
class_name NanobotEffect
## A one-shot "nanobots spreading over the robot" effect, spawned at the exact point the
## nanobot item was dropped.
##
## What it does, in plain terms:
## - A circle grows from the drop point out to `max_radius` over `lifetime_seconds`, eased
##   by `expansion_s_curve`.
## - A crowd of little "nanobot" pixels lives ONLY on the moving ring of that circle, so
##   they chase the expanding edge. They wander and reproduce (spawn neighbours) to make an
##   organic, Game-of-Life-ish wave rather than a clean ring.
## - Their colours come from the nanobot item's own art, jittered by `nanobot_color_variation`.
## - The number of them alive follows a rise-then-fall curve: it climbs to a peak at
##   `peak_fraction` of the lifetime (the "50%" point) and then falls back to zero, with
##   separate S-curves for the rise (`spawn_s_curve`) and the fall (`decay_s_curve`).
## - Optionally clipped to the robot's silhouette so the nanobots only crawl over the robot.
##
## Coordinate space: the effect is placed as a sibling of the robot with the robot's exact
## transform, so its local space is the robot's pixel space - one unit is one robot pixel.
## `start()` is given the drop point already converted into that space.

const NANOBOT_TEXTURE_PATH: String = "res://assets/textures/icons/nanobots.png"
## Fallback palette if the nanobot art can't be read, so the effect still shows something.
const FALLBACK_PALETTE: Array[Color] = [
	Color(0.45, 1.0, 0.75),
	Color(0.30, 0.85, 1.0),
	Color(0.70, 1.0, 0.55),
]

## How the nanobots are produced and move.
enum EmissionMode {
	RING,   ## They ride the expanding circle's edge (uses the Population Curve group).
	BORDER, ## The circle emits them onto its border, explosive then tapering (Border Spawner group).
	PILE,   ## A solid pile is dropped and erodes from the OUTSIDE in (Pile Mode group).
}

@export_group("Mode")
## How the nanobots are produced and move:
## - Ring: they ride the expanding circle's edge.
## - Border Spawner: the circle emits them onto its border, explosive then tapering.
## - Pile: a solid pile is dropped and erodes from the OUTSIDE in - the outer nanobots
##   escape and spread outward first while the ones trapped in the middle wait their turn.
@export var emission_mode: EmissionMode = EmissionMode.PILE

@export_group("Circle")
## Seconds the whole effect lasts before it frees itself.
@export var lifetime_seconds: float = 2.5
## Radius (in robot pixels) the ring grows to by the end of its life. (Ring / Border modes.)
@export var max_radius: float = 140.0
## Width (robot pixels) of the ring band the nanobots are allowed to live in. (Ring mode.)
@export var ring_thickness: float = 14.0
## S-curve of the circle's motion: 1 = linear (constant speed), higher eases in and out
## harder. Drives the ring's expansion (Ring / Border) and the pile's erosion (Pile).
@export_range(1.0, 8.0, 0.1) var expansion_s_curve: float = 3.0

@export_group("Nanobots")
## Most nanobot pixels alive at once: the peak of the population curve in ring mode, and a
## hard cap on the live count in spawner mode.
@export_range(0, 3000, 1) var nanobot_amount: int = 240
## Size (robot pixels) of each nanobot pixel drawn. Raise to match a chunkier pixel look.
@export_range(1.0, 8.0, 0.5) var nanobot_pixel_size: float = 2.0
## How far each nanobot's colour is jittered from the item's palette. 0 = exact palette
## colours; 1 = strong hue / brightness variation.
@export_range(0.0, 1.0, 0.01) var nanobot_color_variation: float = 0.25
## How fast the nanobots wander and spread as they move (robot px/sec-ish): the outward
## escape speed in pile mode, and the wander speed in the other modes.
@export_range(0.0, 600.0, 1.0) var nanobot_movement_speed: float = 140.0
## Random +/- fraction on each individual nanobot's speed (both its movement and its pile
## milling), so they don't all move in lockstep. 0 = everyone at the exact speed above;
## 0.5 = speeds spread from 50% to 150% per nanobot.
@export_range(0.0, 1.0, 0.01) var nanobot_speed_variation: float = 0.35
## Chance a new nanobot is born next to an existing one (Game-of-Life-like growth) instead
## of at a random spot on the ring. Higher clumps them into spreading patches. (Ring mode.)
@export_range(0.0, 1.0, 0.01) var nanobot_reproduction_chance: float = 0.6
## Base seconds each individual nanobot pixel lives before it dies (and, in ring mode, is
## replaced). Shorter than the whole effect makes the ring shimmer instead of sitting still.
@export var nanobot_lifetime_seconds: float = 0.7
## Random +/- seconds added to each nanobot's lifetime, so they don't all die at once -
## this is what breaks up the too-uniform look. 0 = every nanobot lives exactly the base.
@export var nanobot_lifetime_variation: float = 0.4
## Clip the nanobots to the robot's silhouette so they only spread across the robot itself.
@export var clip_to_robot: bool = true

@export_group("Border Spawner")
## Nanobots emitted per second at the explosive start (Border Spawner mode); tapers to zero
## across the lifetime, shaped by Decay S Curve.
@export_range(0.0, 5000.0, 10.0) var nanobot_spawn_rate: float = 700.0
## How far (robot pixels) each emitted nanobot can land inside or outside the exact circle
## border (Border Spawner mode), so the edge scatters instead of being a clean line.
@export_range(0.0, 60.0, 0.5) var nanobot_spawn_position_variation: float = 8.0

@export_group("Pile Mode")
## Radius (robot pixels) of the solid pile of nanobots dropped at the release point.
@export_range(1.0, 80.0, 1.0) var pile_radius: float = 18.0
## Fraction of the lifetime over which the pile fully erodes from its outer edge inward.
## The outermost nanobots escape immediately; the centre releases at this point. Kept below
## 1.0 so the last, innermost nanobots still have time to spread out and fade before the end.
@export_range(0.05, 1.0, 0.01) var pile_release_fraction: float = 0.6
## How fast the nanobots still trapped in the pile mill around while they wait (robot px/sec
## of internal jitter). They can churn their way to the surface and escape. 0 = the pile
## sits perfectly still until the front reaches each one.
@export_range(0.0, 200.0, 1.0) var pile_mixing_speed: float = 30.0
## Thickness (robot px) of the outer shell allowed to escape at once: any nanobot within this
## much of the eroding surface leaves. Thicker = more nanobots go together, so the pile
## disperses faster. 0 = a razor-thin peeling surface.
@export_range(0.0, 40.0, 0.5) var pile_release_thickness: float = 4.0

@export_group("Population Curve")
## Fraction of the lifetime at which the nanobot count peaks (ring mode). Before it the
## count rises; after it the count falls to zero. 0.5 = the most nanobots at the halfway
## point. Ignored in spawner mode (production always peaks at the start there).
@export_range(0.05, 0.95, 0.01) var peak_fraction: float = 0.5
## S-curve of the rise from none up to the peak, ring mode (1 = linear, higher eases harder).
@export_range(1.0, 8.0, 0.1) var spawn_s_curve: float = 2.0
## S-curve of the fall from the peak back down to none. Also shapes the spawner's taper from
## its explosive start (1 = linear, higher eases harder).
@export_range(1.0, 8.0, 0.1) var decay_s_curve: float = 2.0

## Robot this effect is clipped to (for the silhouette mask + pixel ratio). Optional.
var robot: Node = null

var _origin: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _running: bool = false
var _palette: Array[Color] = []
## Each cell: {"angle","radial","pos","color","age","life"}. In ring mode "pos" is recomputed
## from the ring each frame (cells chase the ring); in spawner mode "pos" is fixed at spawn
## and the cell just ages and fades where it landed.
var _cells: Array = []
## Fractional carry-over of emitted nanobots between frames (spawner mode).
var _emit_accumulator: float = 0.0
var _rng := RandomNumberGenerator.new()
## Silhouette mask + the local-space -> mask-pixel scale, cached at start().
var _mask: Image = null
var _local_to_mask: Vector2 = Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Draw above the robot art.
	z_index = 50
	set_process(false)


## Begin the effect at `origin_local` (the drop point, already in this node's local /
## robot-pixel space). Call after the node has been added to the tree and given the
## robot's transform.
func start(origin_local: Vector2) -> void:
	_origin = origin_local
	_elapsed = 0.0
	_cells.clear()
	_emit_accumulator = 0.0
	_rng.randomize()
	_build_palette()
	_grab_mask()
	if emission_mode == EmissionMode.PILE:
		_seed_pile()
	_running = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var life := maxf(0.01, lifetime_seconds)
	if _elapsed >= life:
		queue_free()
		return

	var t := clampf(_elapsed / life, 0.0, 1.0)
	var ring_radius := max_radius * _s_ease(t, expansion_s_curve)
	_update_cells(delta, ring_radius, t)
	queue_redraw()


func _draw() -> void:
	if not _running:
		return
	var half := nanobot_pixel_size * 0.5
	var size_vec := Vector2(nanobot_pixel_size, nanobot_pixel_size)
	for cell in _cells:
		var pos: Vector2 = cell["pos"]
		# Fade each nanobot out as it ages, so deaths read as a fade rather than a pop.
		var fade: float = clampf(1.0 - cell["age"] / maxf(0.001, cell["life"]), 0.0, 1.0)
		var col: Color = cell["color"]
		col.a *= fade
		draw_rect(Rect2(pos - Vector2(half, half), size_vec), col, true)


# --- simulation -----------------------------------------------------------

## One frame of the sim: age + move + cull every nanobot, then (for the modes that keep
## producing) add new ones. Pile mode seeds everything up front, so it only ages/releases.
func _update_cells(delta: float, ring_radius: float, t: float) -> void:
	var band := maxf(0.5, ring_thickness) * 0.5
	# Pile mode: the erosion front shrinks from the pile's edge inward, releasing outer
	# nanobots first. Everything at/outside the front has already escaped.
	var front_radius := 0.0
	if emission_mode == EmissionMode.PILE:
		var rel := clampf(t / maxf(0.01, pile_release_fraction), 0.0, 1.0)
		front_radius = pile_radius * (1.0 - _s_ease(rel, expansion_s_curve))

	var kept: Array = []
	for cell in _cells:
		var alive := true
		match emission_mode:
			EmissionMode.PILE:
				alive = _update_pile_cell(cell, delta, front_radius)
			EmissionMode.BORDER:
				alive = _update_border_cell(cell, delta)
			_:
				alive = _update_ring_cell(cell, delta, ring_radius, band)
		if alive:
			kept.append(cell)
	_cells = kept

	match emission_mode:
		EmissionMode.BORDER:
			_emit_from_border(delta, ring_radius, t)
		EmissionMode.RING:
			_refill_ring(ring_radius, t, band)
		_:
			pass


## Pile nanobot: while trapped it mills around inside the pile; it escapes once it sits on
## (or within pile_release_thickness of) the eroding surface, then flies outward and fades.
## Returns false once it dies or leaves the robot.
func _update_pile_cell(cell: Dictionary, delta: float, front_radius: float) -> bool:
	var speed: float = nanobot_movement_speed * cell["speed_mult"]
	if not cell["released"]:
		# Mill around inside the pile so it churns instead of sitting still, staying inside
		# the pile disc. Inner and outer nanobots alike keep shuffling.
		if pile_mixing_speed > 0.0:
			var moved: Vector2 = cell["pos"] + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) \
				* pile_mixing_speed * cell["speed_mult"] * delta
			var off := moved - _origin
			if off.length() > pile_radius:
				off = off.normalized() * pile_radius
			cell["pos"] = _origin + off
		# A nanobot that churns onto a transparent pixel (an edge, or the hair, which is cut
		# out of the mask) is killed instantly, even while still in the pile.
		if clip_to_robot and not _on_silhouette(cell["pos"]):
			return false
		# Escape when this nanobot is on the eroding surface (or within the release shell).
		# Using its current distance means the mixing can carry a middle nanobot out to the
		# edge and let it slip free early.
		var r: float = (cell["pos"] - _origin).length()
		if front_radius > r + pile_release_thickness:
			return true
		cell["released"] = true
		var out_dir: Vector2 = cell["pos"] - _origin
		if out_dir.length() > 0.001:
			cell["dir"] = out_dir.normalized()
	cell["age"] += delta
	if cell["age"] >= cell["life"]:
		return false
	# Fly outward, with a little wander so the trails aren't dead-straight radial lines.
	cell["pos"] += cell["dir"] * speed * delta
	cell["pos"] += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) \
		* speed * 0.25 * delta
	return not (clip_to_robot and not _on_silhouette(cell["pos"]))


## Border-spawner nanobot: stays where it landed, wandering a little, ageing and fading.
func _update_border_cell(cell: Dictionary, delta: float) -> bool:
	cell["age"] += delta
	if cell["age"] >= cell["life"]:
		return false
	if nanobot_movement_speed > 0.0:
		cell["pos"] += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) \
			* nanobot_movement_speed * cell["speed_mult"] * delta
	return not (clip_to_robot and not _on_silhouette(cell["pos"]))


## Ring nanobot: chases the expanding ring, drifting along and across the band, ageing/fading.
func _update_ring_cell(cell: Dictionary, delta: float, ring_radius: float, band: float) -> bool:
	cell["age"] += delta
	if cell["age"] >= cell["life"]:
		return false
	var speed: float = nanobot_movement_speed * cell["speed_mult"]
	var angle_drift := speed * delta / maxf(1.0, ring_radius)
	var radial_drift := speed * delta
	cell["angle"] += _rng.randf_range(-angle_drift, angle_drift)
	cell["radial"] = clampf(cell["radial"] + _rng.randf_range(-radial_drift, radial_drift), -band, band)
	cell["pos"] = _origin + Vector2(cos(cell["angle"]), sin(cell["angle"])) \
		* maxf(0.0, ring_radius + cell["radial"])
	return not (clip_to_robot and not _on_silhouette(cell["pos"]))


## Seeds a solid disc of nanobots (area-uniform) at the drop point - the pile that will then
## erode from the outside in.
func _seed_pile() -> void:
	var attempts := 0
	var max_attempts := nanobot_amount * 6
	while _cells.size() < nanobot_amount and attempts < max_attempts:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		# sqrt keeps the disc area-uniform (not clustered in the centre).
		var pos := _origin + Vector2(cos(angle), sin(angle)) * (pile_radius * sqrt(_rng.randf()))
		if clip_to_robot and not _on_silhouette(pos):
			continue
		_cells.append(_make_pile_cell(angle, pos))


func _make_pile_cell(angle: float, pos: Vector2) -> Dictionary:
	var life := maxf(0.05, nanobot_lifetime_seconds \
		+ _rng.randf_range(-nanobot_lifetime_variation, nanobot_lifetime_variation))
	return {
		"pos": pos,
		# Fallback escape direction (its spot in the pile); overridden at release by the
		# nanobot's actual position, which mixing may have moved.
		"dir": Vector2(cos(angle), sin(angle)),
		"color": _random_nanobot_color(),
		"released": false,
		"age": 0.0,
		"life": life,
		"speed_mult": _random_speed_mult(),
	}


## Spawner mode: emit nanobots onto the circle's border, at a rate that is explosive at the
## start (t = 0) and tapers to zero by the end (shaped by decay_s_curve). Each lands within
## nanobot_spawn_position_variation of the border and then lives out its own lifetime.
func _emit_from_border(delta: float, ring_radius: float, t: float) -> void:
	var front := 1.0 - _s_ease(t, decay_s_curve)  # 1 at the start, 0 at the end.
	_emit_accumulator += nanobot_spawn_rate * front * delta
	var count := int(floor(_emit_accumulator))
	if count <= 0:
		return
	_emit_accumulator -= float(count)
	var spawned := 0
	var attempts := 0
	var max_attempts := maxi(8, count * 6)
	while spawned < count and attempts < max_attempts and _cells.size() < nanobot_amount:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radial := _rng.randf_range(-nanobot_spawn_position_variation, nanobot_spawn_position_variation)
		var pos := _origin + Vector2(cos(angle), sin(angle)) * maxf(0.0, ring_radius + radial)
		if clip_to_robot and not _on_silhouette(pos):
			continue
		_cells.append(_make_cell(angle, radial, pos, _random_nanobot_color()))
		spawned += 1


## Ring mode: keep the number of nanobots on the ring at the population target for this
## instant (rise to a peak at peak_fraction, then fall), respawning any that just died.
func _refill_ring(ring_radius: float, t: float, band: float) -> void:
	var target := mini(int(round(_population_envelope(t) * float(nanobot_amount))), nanobot_amount)
	while _cells.size() > target and _cells.size() > 0:
		_cells.remove_at(_rng.randi_range(0, _cells.size() - 1))
	var attempts := 0
	var max_attempts := maxi(16, (target - _cells.size()) * 6)
	while _cells.size() < target and attempts < max_attempts:
		attempts += 1
		var cell := _spawn_ring_candidate(ring_radius, band)
		if clip_to_robot and not _on_silhouette(cell["pos"]):
			continue
		_cells.append(cell)


## A ring-mode nanobot - usually a neighbour of an existing one (reproduction) so they grow
## in organic patches, otherwise a fresh spot anywhere on the ring.
func _spawn_ring_candidate(ring_radius: float, band: float) -> Dictionary:
	var angle: float
	var radial: float
	var color: Color
	if _cells.size() > 0 and _rng.randf() < nanobot_reproduction_chance:
		var parent: Dictionary = _cells[_rng.randi_range(0, _cells.size() - 1)]
		angle = parent["angle"] + _rng.randf_range(-0.15, 0.15)
		radial = clampf(parent["radial"] + _rng.randf_range(-band, band), -band, band)
		color = _jittered_color(parent["color"])
	else:
		angle = _rng.randf_range(0.0, TAU)
		radial = _rng.randf_range(-band, band)
		color = _random_nanobot_color()
	var pos := _origin + Vector2(cos(angle), sin(angle)) * maxf(0.0, ring_radius + radial)
	return _make_cell(angle, radial, pos, color)


## Builds one nanobot with a randomly-varied individual lifetime.
func _make_cell(angle: float, radial: float, pos: Vector2, color: Color) -> Dictionary:
	var life := maxf(0.05, nanobot_lifetime_seconds \
		+ _rng.randf_range(-nanobot_lifetime_variation, nanobot_lifetime_variation))
	return {"angle": angle, "radial": radial, "pos": pos, "color": color, "age": 0.0, "life": life,
		"speed_mult": _random_speed_mult()}


## Per-nanobot speed multiplier, randomly varied by nanobot_speed_variation so no two move at
## quite the same rate. Never drops to zero.
func _random_speed_mult() -> float:
	return maxf(0.05, 1.0 + _rng.randf_range(-nanobot_speed_variation, nanobot_speed_variation))


# --- population curve -----------------------------------------------------

## Fraction (0..1) of `nanobot_amount` that should be alive at lifetime fraction `t`:
## rises to 1.0 at `peak_fraction` (via `spawn_s_curve`), then falls back to 0.0 by the end
## (via `decay_s_curve`).
func _population_envelope(t: float) -> float:
	var peak := clampf(peak_fraction, 0.01, 0.99)
	if t <= peak:
		return _s_ease(t / peak, spawn_s_curve)
	return 1.0 - _s_ease((t - peak) / (1.0 - peak), decay_s_curve)


## Symmetric ease-in-out. k = 1 is linear; larger k makes a stronger S. Always maps
## 0 -> 0 and 1 -> 1.
func _s_ease(x: float, k: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if k <= 1.0:
		return x
	var a := pow(x, k)
	var b := pow(1.0 - x, k)
	if a + b <= 0.0:
		return x
	return a / (a + b)


# --- colour ---------------------------------------------------------------

func _random_nanobot_color() -> Color:
	if _palette.is_empty():
		return _jittered_color(FALLBACK_PALETTE[_rng.randi_range(0, FALLBACK_PALETTE.size() - 1)])
	return _jittered_color(_palette[_rng.randi_range(0, _palette.size() - 1)])


## Nudges a base colour by up to `nanobot_color_variation` in hue, saturation and value.
func _jittered_color(base: Color) -> Color:
	if nanobot_color_variation <= 0.0:
		return base
	var v := nanobot_color_variation
	var h := wrapf(base.h + _rng.randf_range(-0.5, 0.5) * v, 0.0, 1.0)
	var s := clampf(base.s + _rng.randf_range(-0.5, 0.5) * v, 0.0, 1.0)
	var val := clampf(base.v + _rng.randf_range(-0.5, 0.5) * v, 0.05, 1.0)
	var c := Color.from_hsv(h, s, val)
	c.a = base.a
	return c


## Samples the nanobot art into a small palette of its distinct opaque colours.
func _build_palette() -> void:
	_palette.clear()
	if not ResourceLoader.exists(NANOBOT_TEXTURE_PATH, "Texture2D"):
		return
	var tex := load(NANOBOT_TEXTURE_PATH) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var seen := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			# Quantise so near-identical pixels collapse into one palette entry.
			var key := Vector3i(int(c.r * 8.0), int(c.g * 8.0), int(c.b * 8.0))
			if seen.has(key):
				continue
			seen[key] = true
			_palette.append(Color(c.r, c.g, c.b, 1.0))
	if _palette.size() > 24:
		_palette.shuffle()
		_palette.resize(24)


# --- silhouette mask ------------------------------------------------------

func _grab_mask() -> void:
	_mask = null
	if not clip_to_robot or robot == null or not is_instance_valid(robot):
		return
	if not robot.has_method("get_opaque_mask"):
		return
	_mask = robot.get_opaque_mask()
	var robot_size: Vector2 = (robot as Control).size if robot is Control else Vector2.ZERO
	if _mask != null and robot_size.x > 0.0 and robot_size.y > 0.0:
		# Map local (robot-pixel) coordinates to mask pixels using the mask's own size, so
		# the mask can be any resolution.
		_local_to_mask = Vector2(float(_mask.get_width()) / robot_size.x, float(_mask.get_height()) / robot_size.y)


func _on_silhouette(local_pos: Vector2) -> bool:
	if _mask == null:
		return true
	var mx := int(local_pos.x * _local_to_mask.x)
	var my := int(local_pos.y * _local_to_mask.y)
	if mx < 0 or my < 0 or mx >= _mask.get_width() or my >= _mask.get_height():
		return false
	return _mask.get_pixel(mx, my).r > 0.5
