extends Control
class_name DeliveryApp
## Laptop desktop app: a legal online store ("delivery"). It sells only mundane,
## above-board goods - curtains, balloons, tools, oil, cosmetics. Anything black-market
## (robot parts, nanobots, weapons, stealth gear, raw robotics materials) is NOT here; the
## player still gets those from Ed's shop.
##
## Buying deducts GameState.money and grants the item the same way the Store does
## (unlock_tool / add_cosmetic_item / add_ingredient). One-time items read as OWNED once held.

## The catalogue. kind: "tool" | "cosmetic" | "ingredient".
##   max: for tools, the cap you may own (screwdrivers stack to 2).
##   amount: units granted per order (ingredients).
const ITEMS: Array = [
	{"id": "curtains", "name": "Blackout Curtains", "cost": 40, "kind": "tool", "icon": "curtains"},
	{"id": "balloons", "name": "Party Balloons", "cost": 10, "kind": "cosmetic", "icon": "balloons"},
	{"id": "screwdriver", "name": "Screwdriver", "cost": 25, "kind": "tool", "max": 2, "icon": "screwdriver"},
	{"id": "welding_gun", "name": "Welding Gun", "cost": 60, "kind": "tool", "icon": "welding_gun"},
	{"id": "oil", "name": "Bottle of Oil", "cost": 15, "kind": "ingredient", "amount": 1, "icon": "oil"},
	{"id": "battery", "name": "Power Cell", "cost": 25, "kind": "ingredient", "amount": 1, "icon": "battery"},
]

var _money_label: Label = null
var _list: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	var margin := LaptopUI.screen_margin(self)
	margin.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(LaptopUI.label("// DELIVERY", 14, LaptopUI.GREEN))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	_money_label = LaptopUI.label("", 12, LaptopUI.OK)
	head.add_child(_money_label)

	# Scrollable list so the catalogue never clips past the bottom of the screen.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := LaptopUI.box()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list)

	_refresh()


func _refresh() -> void:
	_money_label.text = "$%d" % int(GameState.money)
	for child in _list.get_children():
		child.queue_free()
	for item in ITEMS:
		_list.add_child(_make_row(item))


func _make_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon := TextureRect.new()
	icon.texture = LaptopUI.icon_tex(String(item.get("icon", "")))
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_label := LaptopUI.label(String(item.get("name", "?")), 11, LaptopUI.GREEN)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	row.add_child(LaptopUI.label("$%d" % int(item.get("cost", 0)), 11, LaptopUI.DIM))

	var owned := _is_owned(item)
	if owned:
		row.add_child(LaptopUI.label("OWNED", 11, LaptopUI.OK))
	else:
		var btn := LaptopUI.button("BUY", 11)
		btn.disabled = int(GameState.money) < int(item.get("cost", 0))
		btn.pressed.connect(_buy.bind(item))
		row.add_child(btn)
	return row


## One-time items (tools at their cap, single-owned cosmetics) read as OWNED. Stackable
## tools (screwdriver) and ingredients can always be re-ordered.
func _is_owned(item: Dictionary) -> bool:
	match String(item.get("kind", "")):
		"tool":
			var cap: int = maxi(1, int(item.get("max", 1)))
			return GameState.get_tool_count(String(item["id"])) >= cap
		"cosmetic":
			return GameState.has_cosmetic_item(String(item["id"]))
		"ingredient":
			# A capped ingredient (e.g. the single battery) reads as OWNED once at its cap so
			# it can't be re-bought for nothing; uncapped ingredients (oil) always re-order.
			var id := String(item["id"])
			if GameState.INGREDIENT_MAX.has(id):
				return int(GameState.ingredients.get(id, 0)) >= int(GameState.INGREDIENT_MAX[id])
			return false
		_:
			return false


func _buy(item: Dictionary) -> void:
	var cost: int = int(item.get("cost", 0))
	if int(GameState.money) < cost or _is_owned(item):
		return
	GameState.money -= cost
	match String(item.get("kind", "")):
		"tool":
			GameState.unlock_tool(String(item["id"]))
		"cosmetic":
			GameState.add_cosmetic_item(String(item["id"]), 1)
		"ingredient":
			GameState.add_ingredient(String(item["id"]), int(item.get("amount", 1)))
	_refresh()
