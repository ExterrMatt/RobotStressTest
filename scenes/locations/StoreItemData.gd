extends Resource
class_name StoreItemData
## One purchasable item in the Store.
##
## Each item in Store.tscn's `items` array is a StoreItemData. The fields
## here mirror the old hand-rolled dictionary entries — see Store.gd's
## class docstring for the design rationale. Edit per-item in the Inspector
## by selecting the Store node and expanding its `items` array.
##
## Inline-only: these are saved as SubResource blocks inside Store.tscn,
## not as separate .tres files. If you want to reuse an item elsewhere,
## right-click the SubResource in the Inspector and "Save As..." to a
## .tres file, then assign that file in other scenes.

## Identifier matching either an ingredients key on GameState (for ingredient
## items) or a tool id (when is_tool = true). Used by GameState's
## has_purchased_today / mark_purchased_today machinery.
@export var id: StringName = &""

## Shown in the tooltip when the player hovers the item.
@export var display_name: String = ""

## Deducted from GameState.money on purchase.
@export var cost: int = 0

## How many ingredient units the player gets per purchase. Ignored when
## is_tool is true (tools are a one-time unlock, not a stacking quantity).
@export var amount: int = 1

## If true, treated as a tool unlock (added to GameState.owned_tools) instead
## of stacking into ingredients.
@export var is_tool: bool = false

## Maximum number of this tool the player may own. Most tools are one-time
## unlocks (1). Stackable tools such as the screwdriver set this higher so the
## Store keeps offering it until the player owns the cap. Ignored when
## is_tool is false. Values below 1 are treated as 1.
@export var max_quantity: int = 1

## The item sprite shown on the table. The shadow path defaults to
## "<basename>_shadow.<ext>" alongside this texture, unless shadow_texture
## or shadow_path_override is set below.
@export var texture: Texture2D


@export_group("Shadow")

## Explicit shadow texture. If set, this is used directly and the
## auto-derived "_shadow" path is ignored. Leave empty to use the
## auto-derived path.
@export var shadow_texture: Texture2D

## Nudge the shadow's position in source pixels, relative to the sprite's
## centered position. Positive y = shadow sits LOWER on screen.
@export var shadow_offset: Vector2 = Vector2.ZERO

## Size multiplier on SLOT_SIZE for the shadow rect. E.g. Vector2(1.2, 1.0)
## makes a wider, same-height shadow. Vector2.ONE = same size as the slot.
@export var shadow_scale: Vector2 = Vector2.ONE

## Color/alpha applied to the shadow at normal brightness. Use alpha < 1
## to soften, RGB to tint, or full transparency (alpha = 0) to hide the
## shadow on this item entirely. The affordability dim multiplies on top
## of this — a soft shadow stays soft when dimmed, just darker.
@export var shadow_modulate: Color = Color(1, 1, 1, 1)
