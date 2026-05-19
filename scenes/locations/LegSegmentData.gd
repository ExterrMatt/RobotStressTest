extends Resource
class_name LegSegmentData
## One segment of the assembled leg.
##
## Most segments are a single piece (e.g. `butt`, `side_thigh`). Some are a
## stack of pieces that all need to show at once at the same anchor
## (e.g. `ankle` = ankle_cap + ankle_axel; `foot` = heel + middle_foot +
## toes + toes_border + upper_foot).
##
## Each piece has its own texture, its own shadow texture, and a per-piece
## offset from the segment's anchor point (so the cap can sit above the
## axle, etc). All offsets are in source pixels (before any upscaling).
##
## When a player drags ANY piece of a segment onto the target hitbox, the
## whole segment "places" — every piece in `pieces` becomes visible at its
## offset, and any remaining draggable pieces of that segment disappear
## from the craft bin (they're consumed by the placement). This mirrors
## Work's "fill the slot" feel but supports multi-image segments.

## Stable id matched against DropSlot.accepts_item_id on the assembly side.
## Examples: "ankle", "foot", "knee", "calf", "mid_thigh".
@export var id: StringName = &""

## Friendly name for tooltips / debug.
@export var display_name: String = ""

## Where on the assembly diagram this segment lands, in SOURCE PIXELS
## measured from the top-left of the assembly area (right half of the
## 500x400 picture). The minigame multiplies by its display scale at
## runtime so we author once and it scales cleanly.
@export var anchor_in_assembly: Vector2 = Vector2.ZERO

## Pieces that make up this segment. Order matters: pieces drawn later
## sit on top of earlier ones. So put the "underneath" piece first.
##
## Each entry is a Dictionary with these keys:
##   "id":        StringName  -- unique within this segment, used as a
##                                draggable id when the piece is in the bin
##   "texture":   Texture2D   -- the main sprite
##   "shadow":    Texture2D   -- shadow sprite (optional; may be null)
##   "offset":    Vector2     -- pixel offset from `anchor_in_assembly`
##                                (and the same offset used in the bin so
##                                the piece group reads as a unit there
##                                too, though we'll center the group)
##   "shadow_offset": Vector2 -- extra offset applied to the shadow on top
##                                of `offset`. Defaults to (0, 0).
##
## Plain Array (not Array[Dictionary]) for .tres compatibility — the same
## reason StoreItemData / StubLocation use plain Arrays.
@export var pieces: Array = []
