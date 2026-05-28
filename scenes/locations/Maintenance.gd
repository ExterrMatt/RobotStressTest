extends "res://scenes/locations/StubLocation.gd"
## Maintenance location.
##
## Inherits StubLocation's title/blurb/outcome-button machinery, then mounts
## a PersonalityTestRobot inside SceneImage (via Main.show_scene_overlay)
## anchored to the bottom-center of the framed picture, so the same robot
## that's shown in Personality Training is also shown here.
##
## We use show_scene_overlay() rather than parenting under our own scene
## tree because that's the standard path Main uses for in-frame art (Work,
## Store): it reparents the node onto SceneImage, full-rect anchored, and
## auto-clears it when the location ends. We then re-anchor the robot to
## bottom-center inside that overlay wrapper.

const PERSONALITY_TEST_ROBOT_SCENE: PackedScene = preload(
	"res://scenes/locations/PersonalityTestRobot.tscn"
)

## Same scale used by PersonalityTraining.tscn so the robot reads at the
## same size across both scenes.
const ROBOT_SCALE: Vector2 = Vector2(1.6, 1.6)

## Base size of the PersonalityTestRobot Control (matches its
## custom_minimum_size of 300x450 in PersonalityTestRobot.tscn).
const ROBOT_BASE_SIZE: Vector2 = Vector2(300, 450)


func _ready() -> void:
	# Let StubLocation set up title, blurb, outcome buttons, and the
	# corner Back button.
	super._ready()

	_mount_robot()


func _mount_robot() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("show_scene_overlay"):
		push_warning("Maintenance: Main.show_scene_overlay() unavailable; robot not mounted.")
		return

	# Wrapper Control that show_scene_overlay() will anchor full-rect to
	# SceneImage. We position the robot inside this wrapper, so the robot
	# itself can be center-bottom anchored relative to the framed picture.
	var wrapper := Control.new()
	wrapper.name = "MaintenanceRobotLayer"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var robot: Control = PERSONALITY_TEST_ROBOT_SCENE.instantiate()
	robot.scale = ROBOT_SCALE
	# Layout the robot inside the wrapper with anchors pinned to
	# bottom-center. offset_left / offset_right are symmetric around the
	# horizontal anchor (0.5), so the robot is horizontally centered;
	# offset_bottom = 0 sits the bottom edge of the robot's local rect on
	# the bottom of the frame. Note: anchors use the robot's LOCAL rect
	# (300x450), the visual size is scaled by ROBOT_SCALE on top of that.
	robot.anchor_left = 0.5
	robot.anchor_top = 1.0
	robot.anchor_right = 0.5
	robot.anchor_bottom = 1.0
	# Center horizontally: shift left by half of the scaled width.
	var scaled_size: Vector2 = ROBOT_BASE_SIZE * ROBOT_SCALE
	robot.offset_left = -scaled_size.x * 0.5
	robot.offset_right = scaled_size.x * 0.5
	# Sit on the bottom edge: shift up by the full scaled height.
	robot.offset_top = -scaled_size.y
	robot.offset_bottom = 0.0

	wrapper.add_child(robot)

	# Hand the wrapper to Main; it reparents under SceneImage and
	# automatically tears it down on location exit.
	main.show_scene_overlay(wrapper, false)
