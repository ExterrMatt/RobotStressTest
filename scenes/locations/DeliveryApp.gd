extends Control
class_name DeliveryApp
## Laptop desktop app: a legal online store ("delivery"). It sells only mundane,
## above-board goods - curtains, balloons, tools, oil, cosmetics. Anything black-market
## (robot parts, nanobots, weapons, stealth gear, raw robotics materials) is NOT here; the
## player still gets those from Ed's shop.
##
## Buying deducts GameState.money and grants the item the same way the Store does
## (unlock_tool / add_cosmetic_item / add_ingredient). One-time items read as OWNED once held.
##
## NIGHT STORE: opened from the stress test's laptop, the store wears its after-hours skin
## (indigo instead of green), every price carries the same-night shipping markup
## (NIGHT_PRICE_MULTIPLIER), and it adds a few raw parts (NIGHT_ITEMS) the player can buy
## one of each per night. That limit is tracked on the stress test itself
## (night_store_bought_count / record_night_store_purchase), so a retried night resets it.
## Night orders aren't handed over on the spot: they ride the delivery drone
## (StressTest.queue_night_delivery), which the player guides home on the PATROL app.

## The catalogue. kind: "tool" | "cosmetic" | "ingredient".
##   max: for tools, the cap you may own (screwdrivers stack to 2).
##   amount: units granted per order (ingredients).
const ITEMS: Array = [
	{"id": "curtains", "name": "Blackout Curtains", "cost": 40, "kind": "tool", "icon": "curtains"},
	{"id": "flashlight", "name": "Flashlight", "cost": 30, "kind": "tool", "icon": "flashlight"},
	{"id": "balloons", "name": "Party Balloons", "cost": 10, "kind": "cosmetic", "icon": "balloons"},
	{"id": "screwdriver", "name": "Screwdriver", "cost": 25, "kind": "tool", "max": 2, "icon": "screwdriver"},
	{"id": "welding_gun", "name": "Welding Gun", "cost": 60, "kind": "tool", "icon": "welding_gun"},
	{"id": "oil", "name": "Bottle of Oil", "cost": 15, "kind": "ingredient", "amount": 1, "icon": "oil"},
	{"id": "battery", "name": "Power Cell", "cost": 25, "kind": "ingredient", "amount": 1, "icon": "battery"},
]

## Same-night shipping: night prices are this multiple of the day price (rounded up).
const NIGHT_PRICE_MULTIPLIER: float = 1.2
## Night-only raw parts, one of each per night. cost is the day price per unit (Ed's
## bundle price split per piece); the shipping markup is added on top like everything else.
const NIGHT_ITEMS: Array = [
	{"id": "scrap_metal", "name": "Scrap Metal", "cost": 14, "kind": "ingredient", "amount": 1,
			"icon": "scrap_metal", "night_limit": 1},
	{"id": "nuts_bolts", "name": "Nuts & Bolts", "cost": 5, "kind": "ingredient", "amount": 1,
			"icon": "nuts_bolts", "night_limit": 1},
	{"id": "electronics", "name": "Electronics", "cost": 14, "kind": "ingredient", "amount": 1,
			"icon": "electronics", "night_limit": 1},
]

## Night skin palette.
const NIGHT_BG := Color(0.03, 0.03, 0.09, 1.0)
const NIGHT_TEXT := Color(0.72, 0.74, 1.0)
const NIGHT_DIM := Color(0.5, 0.5, 0.78)
const NIGHT_ACCENT := Color(1.0, 0.85, 0.45)
const NIGHT_BORDER := Color(0.45, 0.42, 0.95, 0.8)
const NIGHT_FILL := Color(0.04, 0.03, 0.12, 0.7)

var _money_label: Label = null
var _list: VBoxContainer = null
## The live stress test while the store is opened mid-night (null by day).
var _night_scene: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var st := get_tree().get_first_node_in_group("stress_test_scene")
	if st != null and is_instance_valid(st) and st.has_method("night_store_bought_count"):
		_night_scene = st

	if _is_night():
		var bg := ColorRect.new()
		bg.color = NIGHT_BG
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	var margin := LaptopUI.screen_margin(self)
	margin.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(_label("// AFTER-HOURS DELIVERY" if _is_night() else "// DELIVERY", 14, _text_col()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	_money_label = _label("", 12, NIGHT_ACCENT if _is_night() else LaptopUI.OK)
	head.add_child(_money_label)
	if _is_night():
		col.add_child(_label("SAME-NIGHT SHIPPING +%d%%  |  PARTS: 1 EACH PER NIGHT"
				% roundi((NIGHT_PRICE_MULTIPLIER - 1.0) * 100.0), 10, NIGHT_DIM))

	# Scrollable list so the catalogue never clips past the bottom of the screen.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := _box()
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
	if _is_night():
		_list.add_child(_label("TONIGHT ONLY", 10, NIGHT_ACCENT))
		for item in NIGHT_ITEMS:
			_list.add_child(_make_row(item))
		_list.add_child(_label("EVERYTHING ELSE", 10, NIGHT_ACCENT))
	for item in ITEMS:
		_list.add_child(_make_row(item))


func _make_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon := TextureRect.new()
	icon.texture = FlashlightIcon.texture(GameState.flashlight_on) if String(item.get("id", "")) == "flashlight" \
			else LaptopUI.icon_tex(String(item.get("icon", "")))
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_label := _label(String(item.get("name", "?")), 11, _text_col())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	row.add_child(_label("$%d" % _price(item), 11, _dim_col()))

	if _sold_out_tonight(item):
		row.add_child(_label("SOLD OUT", 11, NIGHT_DIM))
	elif _en_route(item):
		row.add_child(_label("EN ROUTE", 11, NIGHT_ACCENT))
	elif _is_owned(item):
		row.add_child(_label("OWNED", 11, NIGHT_ACCENT if _is_night() else LaptopUI.OK))
	else:
		var btn := _button("BUY", 11)
		btn.disabled = int(GameState.money) < _price(item)
		btn.pressed.connect(_buy.bind(item))
		row.add_child(btn)
	return row


func _is_night() -> bool:
	return _night_scene != null and is_instance_valid(_night_scene)


## What the item costs right now: the day price, plus same-night shipping at night.
func _price(item: Dictionary) -> int:
	var cost := int(item.get("cost", 0))
	return ceili(cost * NIGHT_PRICE_MULTIPLIER) if _is_night() else cost


## A once-per-night item already bought tonight.
func _sold_out_tonight(item: Dictionary) -> bool:
	if not item.has("night_limit") or not _is_night():
		return false
	return int(_night_scene.call("night_store_bought_count", String(item["id"]))) >= int(item["night_limit"])


# --- skin ---------------------------------------------------------------------

func _text_col() -> Color:
	return NIGHT_TEXT if _is_night() else LaptopUI.GREEN


func _dim_col() -> Color:
	return NIGHT_DIM if _is_night() else LaptopUI.DIM


func _label(text: String, font_size: int, color: Color) -> Label:
	return LaptopUI.label(text, font_size, color)


func _night_panel(border: Color) -> StyleBoxFlat:
	var sb := LaptopUI.panel_style(border)
	sb.bg_color = NIGHT_FILL
	return sb


func _box() -> PanelContainer:
	var box := LaptopUI.box()
	if _is_night():
		box.add_theme_stylebox_override("panel", _night_panel(NIGHT_BORDER))
	return box


func _button(text: String, font_size: int) -> Button:
	var btn := LaptopUI.button(text, font_size)
	if _is_night():
		btn.add_theme_color_override("font_color", NIGHT_TEXT)
		btn.add_theme_color_override("font_hover_color", NIGHT_ACCENT)
		btn.add_theme_color_override("font_disabled_color", NIGHT_DIM)
		btn.add_theme_stylebox_override("normal", _night_panel(NIGHT_BORDER))
		btn.add_theme_stylebox_override("hover", _night_panel(NIGHT_ACCENT))
		btn.add_theme_stylebox_override("pressed", _night_panel(NIGHT_ACCENT))
		btn.add_theme_stylebox_override("disabled", _night_panel(Color(NIGHT_DIM, 0.4)))
	return btn


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
	var cost := _price(item)
	if int(GameState.money) < cost or _is_owned(item) or _sold_out_tonight(item) or _en_route(item):
		return
	GameState.money -= cost
	if _is_night():
		if item.has("night_limit"):
			_night_scene.call("record_night_store_purchase", String(item["id"]))
		# Same-night shipping: the order rides the delivery drone and only lands once it
		# reaches home (StressTest delivery, guided on the PATROL app).
		_night_scene.call("queue_night_delivery", item)
	else:
		grant_item(item)
	_refresh()


## Hands the player a bought item, the same way the Store does.
static func grant_item(item: Dictionary) -> void:
	match String(item.get("kind", "")):
		"tool":
			GameState.unlock_tool(String(item["id"]))
		"cosmetic":
			GameState.add_cosmetic_item(String(item["id"]), 1)
		"ingredient":
			GameState.add_ingredient(String(item["id"]), int(item.get("amount", 1)))


## A one-time item (tool / cosmetic) already ordered tonight and still on the drone.
func _en_route(item: Dictionary) -> bool:
	if not _is_night() or String(item.get("kind", "")) == "ingredient":
		return false
	return bool(_night_scene.call("night_delivery_pending", String(item["id"])))
