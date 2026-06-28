extends "res://scenes/locations/StubLocation.gd"
## Personality Training location.
##
## Behaves like the generic StubLocation (title, blurb, outcome buttons),
## but also drops the layered PersonalityTestRobot into the framed scene
## image so the robot appears on top of the personality_test background.
##
## RobotLayer is a full-rect Control authored in PersonalityTraining.tscn
## purely so the robot can be positioned in the editor. At _ready it is
## handed to Main, which reparents it onto SceneImage and tears it down
## automatically when the location exits.

@onready var robot_layer: Control = $RobotLayer


func _ready() -> void:
	super._ready()

	var main: Node = get_tree().current_scene
	if main and main.has_method("show_scene_overlay") and robot_layer:
		main.show_scene_overlay(robot_layer)
