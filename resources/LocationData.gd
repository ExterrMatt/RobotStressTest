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

## Optional: if true, visiting this location does NOT consume the phase.
## (Reserved for things like checking inventory; nothing uses it yet.)
@export var free_action: bool = false


func available_in_phase(phase: int) -> bool:
	return phase in allowed_phases
