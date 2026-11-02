class_name DroneRoute
extends RefCounted
## One patrol drone's approach, shown on the laptop's PATROL monitor: a random path
## across a grid of nodes from the police station (bottom-left) to home (top-right),
## timed so the drone reaches home exactly when it arrives at the window. It flies a
## fixed time per edge and pauses at a few checkpoints along the way; some checkpoints
## are hack attempts (see StressTest's drone hacks).
##
## Every time is an absolute night time (StressTest._night_elapsed), so a delay (stun) or
## a speed-up (hack boost) is just shift_after() on the remaining stops.

## Path nodes in grid coordinates (x = column, y = row, row 0 = top).
var path: Array[Vector2i] = []
## Night time the drone reaches / leaves path[k].
var arrive: Array[float] = []
var leave: Array[float] = []
## Path indices the drone pauses at.
var checkpoints: Array[int] = []
## The subset of checkpoints where it tries to hack the player.
var hack_checkpoints: Array[int] = []
## Hack checkpoints already dealt with (started, stunned, or missed), by path index.
var handled_hacks: Dictionary = {}


static func generate(rng: RandomNumberGenerator, grid_size: int, arrival_time: float,
		seconds_per_edge: float, checkpoint_count: int, pause_seconds: float,
		hack_chance: float, hack_pause_seconds: float, max_hacks: int) -> DroneRoute:
	var route := DroneRoute.new()
	route.path = _random_path(rng, grid_size)
	var n := route.path.size()

	# Checkpoints: interior nodes (not next to either end), at least two apart.
	var candidates: Array[int] = []
	for k in range(2, n - 2):
		candidates.append(k)
	_shuffle(rng, candidates)
	for k in candidates:
		if route.checkpoints.size() >= checkpoint_count:
			break
		var clear := true
		for c in route.checkpoints:
			if absi(c - k) < 2:
				clear = false
				break
		if clear:
			route.checkpoints.append(k)
	route.checkpoints.sort()
	# Hacks: never at the last stop before home, and at most max_hacks per route.
	for i in range(route.checkpoints.size() - 1):
		if route.hack_checkpoints.size() >= max_hacks:
			break
		if rng.randf() < hack_chance:
			route.hack_checkpoints.append(route.checkpoints[i])

	# Timeline, built backwards from the arrival at home.
	route.arrive.resize(n)
	route.leave.resize(n)
	route.arrive[n - 1] = arrival_time
	route.leave[n - 1] = arrival_time
	for k in range(n - 2, -1, -1):
		var pause := 0.0
		if route.hack_checkpoints.has(k):
			pause = hack_pause_seconds
		elif route.checkpoints.has(k):
			pause = pause_seconds
		route.leave[k] = route.arrive[k + 1] - seconds_per_edge
		route.arrive[k] = route.leave[k] - pause
	return route


## A random self-avoiding walk from the station to home that mostly leans toward home,
## so routes wander but stay readable. Falls back to a plain staircase.
static func _random_path(rng: RandomNumberGenerator, g: int) -> Array[Vector2i]:
	var start := Vector2i(0, g - 1)
	var goal := Vector2i(g - 1, 0)
	var max_nodes := (g - 1) * 2 + 1 + g + 1
	for _attempt in 80:
		var path: Array[Vector2i] = [start]
		var seen := {start: true}
		var cur := start
		while cur != goal and path.size() <= max_nodes:
			var options: Array[Vector2i] = []
			var toward: Array[Vector2i] = []
			for d in [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN]:
				var nxt: Vector2i = cur + d
				if nxt.x < 0 or nxt.y < 0 or nxt.x >= g or nxt.y >= g or seen.has(nxt):
					continue
				options.append(nxt)
				if _manhattan(nxt, goal) < _manhattan(cur, goal):
					toward.append(nxt)
			if options.is_empty():
				break
			var pool := toward if not toward.is_empty() and rng.randf() < 0.7 else options
			cur = pool[rng.randi() % pool.size()]
			path.append(cur)
			seen[cur] = true
		if cur == goal and path.size() <= max_nodes:
			return path
	var stairs: Array[Vector2i] = [start]
	var p := start
	while p != goal:
		p = p + (Vector2i.RIGHT if p.x < goal.x and (p.y == goal.y or rng.randf() < 0.5) else Vector2i.UP)
		stairs.append(p)
	return stairs


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _shuffle(rng: RandomNumberGenerator, arr: Array[int]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func arrival_time() -> float:
	return arrive[arrive.size() - 1]


## Index of the last node the drone has reached by time t (0 before it sets off).
func current_index(t: float) -> int:
	var k := 0
	for i in arrive.size():
		if t >= arrive[i]:
			k = i
	return k


## Index of the node the drone is sitting at (paused) at time t, or -1 while flying.
func paused_index(t: float) -> int:
	var k := current_index(t)
	if t >= arrive[k] and t < leave[k]:
		return k
	return -1


## Drone position in (fractional) grid coordinates at time t.
func position_at(t: float) -> Vector2:
	var n := path.size()
	if t <= leave[0]:
		return Vector2(path[0])
	for k in range(1, n):
		if t < arrive[k]:
			var span := maxf(0.001, arrive[k] - leave[k - 1])
			var f := clampf((t - leave[k - 1]) / span, 0.0, 1.0)
			return Vector2(path[k - 1]).lerp(Vector2(path[k]), f)
		if t < leave[k]:
			return Vector2(path[k])
	return Vector2(path[n - 1])


## Shifts everything from node k's departure onward by delta seconds (a stun delays,
## a negative delta hurries the drone along).
func shift_after(k: int, delta: float) -> void:
	leave[k] += delta
	for j in range(k + 1, path.size()):
		arrive[j] += delta
		leave[j] += delta
