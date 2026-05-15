extends Resource
class_name LocationData
## Resource describing a game location.
##
## Create one .tres per location in res://resources/locations/. Each is loaded
## by Main at startup to populate the activity-selection UI.
##
## allowed_phases lists DayCycle.Phase values where this location is selectable.
## scene_path points at the location's .tscn. icon is a texture slot for the
## activity-selection button (drop pixel art in later).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

## Which phases this location can be visited in.
## Plain Array (not Array[int]) for .tres compatibility - typed arrays in
## resource files have inconsistent syntax across Godot 4.x point releases.
@export var allowed_phases: Array = []

## The .tscn that gets instantiated when the player picks this location.
@export_file("*.tscn") var scene_path: String = ""

## Activity-button icon. Pixel art goes here later.
@export var icon: Texture2D

## Image shown in the top frame on the main screen while this
## location is active. Optional — falls back to the default placeholder.
@export var preview_texture: Texture2D

## Preferred size of the framed scene image while this location is active.
## Leave at (0, 0) to use the default (900, 225). Locations whose source art
## is taller than the standard 500x125 should declare the matching scaled
## size here — e.g. Work uses 500x400 source, so frame_size = (800, 640).
##
## Main animates the SceneImage's custom_minimum_size to this value at the
## transition midpoint, and back to the default when leaving the location.
@export var frame_size: Vector2 = Vector2.ZERO

## Preferred width of the OUTER FRAME (FrameOuter) while this location is
## active. The outer frame normally has a hard minimum width set in
## Main.tscn that's wide enough for the standard 900px-wide picture plus
## padding; locations whose picture is narrower than that need to declare
## a smaller minimum here, or the outer frame won't shrink to match.
##
## Leave at 0 to use the default width from Main.tscn. Height of the
## outer frame is not customizable per location — its container-driven
## minimum will accommodate whatever frame_size.y you ask for.
@export var frame_outer_width: float = 0.0

## Optional: if true, visiting this location does NOT consume the phase.
## (Reserved for things like checking inventory; nothing uses it yet.)
@export var free_action: bool = false


func available_in_phase(phase: int) -> bool:
	return phase in allowed_phases
