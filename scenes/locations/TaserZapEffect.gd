class_name TaserZapEffect
extends Control
## The taser going off on the maintenance robot: jagged pixel bolts crackle out from where
## it touched her, redrawn every few hundredths of a second, while she flickers bright,
## then it all fades out and the effect frees itself.
##
## Laid over the robot with the robot's transform (as the nanobot effect is), so its local
## space is her pixel space; start() takes the touch point in that space.

const DURATION: float = 0.55
## How often the bolts jump to a new shape.
const RESHAPE_SECONDS: float = 0.05
const BOLT_COUNT: int = 6
## A bolt's reach and how many kinks it has (robot pixels).
const BOLT_LENGTH_RANGE: Vector2 = Vector2(14.0, 34.0)
const BOLT_SEGMENTS: int = 5
const BOLT_JITTER: float = 5.0
const CORE_COLOR: Color = Color(1.0, 1.0, 1.0)
const GLOW_COLOR: Color = Color(0.45, 0.85, 1.0, 0.55)
## The robot's flicker: this bright at its peak, FLICKERS times over DURATION.
const ROBOT_FLASH: Color = Color(1.7, 1.75, 2.1)
const FLICKERS: int = 3

## The robot she's drawn on (flickers with the zap).
var robot: CanvasItem = null

var _origin: Vector2 = Vector2.ZERO
var _bolts: Array[PackedVector2Array] = []
var _age: float = 0.0
var _since_reshape: float = 0.0
var _robot_modulate: Color = Color.WHITE
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()


func start(local_point: Vector2) -> void:
	_origin = local_point.floor() + Vector2(0.5, 0.5)
	_age = 0.0
	_reshape()
	if robot != null and is_instance_valid(robot):
		_robot_modulate = robot.modulate


func _process(delta: float) -> void:
	_age += delta
	_since_reshape += delta
	if _since_reshape >= RESHAPE_SECONDS:
		_since_reshape = 0.0
		_reshape()
	if robot != null and is_instance_valid(robot):
		# A few hard flickers rather than a smooth glow.
		var phase := fmod(_age / DURATION * FLICKERS, 1.0)
		var lit := phase < 0.5 and _age < DURATION
		robot.modulate = _robot_modulate * ROBOT_FLASH if lit else _robot_modulate
	queue_redraw()
	if _age >= DURATION:
		if robot != null and is_instance_valid(robot):
			robot.modulate = _robot_modulate
		queue_free()


func _reshape() -> void:
	_bolts.clear()
	for i in BOLT_COUNT:
		var angle := TAU * (float(i) + _rng.randf_range(-0.35, 0.35)) / BOLT_COUNT
		var reach := _rng.randf_range(BOLT_LENGTH_RANGE.x, BOLT_LENGTH_RANGE.y)
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.orthogonal()
		var bolt := PackedVector2Array([_origin])
		for s in range(1, BOLT_SEGMENTS + 1):
			var along := reach * float(s) / BOLT_SEGMENTS
			var point := _origin + direction * along + side * _rng.randf_range(-BOLT_JITTER, BOLT_JITTER)
			bolt.append(point.floor() + Vector2(0.5, 0.5))
		_bolts.append(bolt)


func _draw() -> void:
	var fade := clampf(1.0 - (_age / DURATION - 0.6) / 0.4, 0.0, 1.0)
	for bolt in _bolts:
		draw_polyline(bolt, Color(GLOW_COLOR, GLOW_COLOR.a * fade), 3.0)
	for bolt in _bolts:
		draw_polyline(bolt, Color(CORE_COLOR, fade), 1.0)
	draw_circle(_origin, 2.5, Color(CORE_COLOR, fade))
