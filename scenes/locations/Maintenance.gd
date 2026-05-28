extends "res://scenes/locations/StubLocation.gd"
## Maintenance location.
##
## Behaves like the generic StubLocation (title, blurb, outcome buttons),
## but also drops the layered PersonalityTestRobot into the framed scene
## image so the robot appears on top of the maintenance background, using
## the exact same RobotLayer authoring path as PersonalityTraining.

@onready var robot_layer: Control = $RobotLayer


func _ready() -> void:
	super._ready()

	var main: Node = get_tree().current_scene
	if main and main.has_method("show_scene_overlay") and robot_layer:
		main.show_scene_overlay(robot_layer)
