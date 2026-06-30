@tool
extends Resource
class_name DialogueBundle
## Baked copy of the dialogue .dlg source files, keyed by file id (the .dlg
## file's basename, e.g. "intro" for intro.dlg).
##
## Why this exists: the .dlg files are plain text, NOT Godot resources, so they
## are easily dropped from an exported build - they only ship if
## export_presets.cfg lists them under include_filter, which is fragile. This
## .tres IS a real resource, so it is always packed by the "all_resources"
## export filter. The Dialogue autoload falls back to it whenever the raw .dlg
## files are not present in the running build (i.e. in most exports).
##
## Kept in sync automatically: when the game runs from the editor, Dialogue
## refreshes the matching entry here each time it loads a .dlg (see
## Dialogue._read_source / _sync_bundle_entry). You normally never edit this by
## hand - edit the .dlg files and playtest once, and the bundle updates itself.
@export var sources: Dictionary = {}
