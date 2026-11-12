extends Control
class_name DeliveryApp
## Laptop desktop app: a legal online store ("delivery"). It sells only mundane,
## above-board goods - curtains, balloons, tools, oil, cosmetics. Anything black-market
## (robot parts, nanobots, weapons, stealth gear) is NOT here; the player still gets those
## from Ed's shop.
##
## LAYOUT: the same shape as the SETTINGS app - a header (back, title, balance), category
## tabs down the left, the chosen category's items in a scrolling list on the right, and a
## hint line that describes the item under the mouse. A category only gets a tab while it
## has something listed, so the catalogue can grow without the screen filling up.
##
## ADDING AN ITEM: add an entry to ITEMS (and a category to CATEGORIES if it needs a new
## one). That is all - the tabs, list and counts build themselves from the catalogue.
##
## AVAILABILITY: not everything is for sale all the time. Per item (see ITEMS):
##   listed     - whether it appears at all: from_day / until_day, night_only / day_only.
##   in stock   - "rotating" items share ROTATING_IN_STOCK slots that are re-drawn every
##                day; the ones that miss out stay listed but read OUT OF STOCK.
## On top of that an item can be OWNED (held at its cap), and at night EN ROUTE or SOLD OUT.
##
## Buying deducts GameState.money and grants the item the same way the Store does
## (unlock_tool / add_cosmetic_item / add_ingredient).
##
## NIGHT STORE: opened from the stress test's laptop, the store wears its after-hours skin
## (indigo instead of green), every price carries the same-night shipping markup
## (NIGHT_PRICE_MULTIPLIER), and the night_only raw parts are listed, one of each per night
## (night_limit). That limit is tracked on the stress test itself (night_store_bought_count
## / record_night_store_purchase), so a retried night resets it. Night orders aren't handed
## over on the spot: they ride the delivery drone (StressTest.queue_night_delivery), which
## the player guides home on the PATROL app.

## The header's back button: the desktop goes home.
signal back_requested

## The category tabs, in order. "all" is every listed item; the rest show the items whose
## "category" matches, and only get a tab while at least one such item is listed.
const CATEGORIES: Array = [
	{"id": "all", "name": "ALL", "desc": "everything on the shelves today."},
	{"id": "parts", "name": "PARTS", "desc": "raw parts, flown in tonight. one of each per night."},
	{"id": "tools", "name": "TOOLS", "desc": "things you keep and use."},
	{"id": "supplies", "name": "SUPPLIES", "desc": "things that get used up."},
]

## The catalogue.
##   id, name, cost, icon   - what it is (cost is the day price).
##   kind                   - "tool" | "cosmetic" | "ingredient": how it is granted.
##   category               - which tab it sits under (a CATEGORIES id).
##   desc                   - the hint line while it is under the mouse.
##   max                    - tools: the cap you may own (default 1).
##   amount                 - ingredients: units per order (default 1).
## Availability (all optional - leave them out for "always for sale"):
##   from_day / until_day   - only listed from / up to this day (inclusive).
##   night_only / day_only  - only listed in the night store / the daytime store.
##   night_limit            - how many can be ordered per night.
##   rotating               - shares the daily rotating stock (see ROTATING_IN_STOCK).
const ITEMS: Array = [
	{"id": "curtains", "name": "Blackout Curtains", "cost": 40, "kind": "tool", "icon": "curtains",
			"category": "tools", "desc": "heavy curtains for the window."},
	{"id": "flashlight", "name": "Flashlight", "cost": 30, "kind": "tool", "icon": "flashlight",
			"category": "tools", "desc": "a pocket light for the dark."},
	# Click it in the inventory to start / stop recording (Main.set_camera_recording).
	{"id": "camera", "name": "Camera", "cost": 40, "kind": "tool", "icon": "camera",
			"category": "tools", "desc": "click it in your inventory to start or stop recording."},
	{"id": "screwdriver", "name": "Screwdriver", "cost": 25, "kind": "tool", "max": 2, "icon": "screwdriver",
			"category": "tools", "desc": "you can carry two."},
	{"id": "welding_gun", "name": "Welding Gun", "cost": 60, "kind": "tool", "icon": "welding_gun",
			"category": "tools", "desc": "for joining metal."},
	{"id": "oil", "name": "Bottle of Oil", "cost": 15, "kind": "ingredient", "amount": 1, "icon": "oil",
			"category": "supplies", "desc": "one bottle of machine oil."},
	{"id": "battery", "name": "Power Cell", "cost": 25, "kind": "ingredient", "amount": 1, "icon": "battery",
			"category": "supplies", "desc": "a spare power cell. you can only hold one."},
	# No category of its own: it is only listed under ALL.
	{"id": "balloons", "name": "Party Balloons", "cost": 10, "kind": "cosmetic", "icon": "balloons",
			"category": "", "desc": "party balloons."},
	# Night-only raw parts, one of each per night. cost is the day price per unit (Ed's
	# bundle price split per piece); the shipping markup is added on top like everything else.
	{"id": "scrap_metal", "name": "Scrap Metal", "cost": 14, "kind": "ingredient", "amount": 1,
			"icon": "scrap_metal", "category": "parts", "night_only": true, "night_limit": 1,
			"desc": "one piece of scrap metal."},
	{"id": "nuts_bolts", "name": "Nuts & Bolts", "cost": 5, "kind": "ingredient", "amount": 1,
			"icon": "nuts_bolts", "category": "parts", "night_only": true, "night_limit": 1,
			"desc": "one set of nuts and bolts."},
	{"id": "electronics", "name": "Electronics", "cost": 14, "kind": "ingredient", "amount": 1,
			"icon": "electronics", "category": "parts", "night_only": true, "night_limit": 1,
			"desc": "one electronics board."},
]

## How many "rotating" items are in stock on any one day (the rest read OUT OF STOCK).
const ROTATING_IN_STOCK: int = 2
## An item with a from_day wears a NEW tag for this many days after it arrives.
const NEW_FOR_DAYS: int = 2
## Same-night shipping: night prices are this multiple of the day price (rounded up).
const NIGHT_PRICE_MULTIPLIER: float = 1.2

## Night skin palette.
const NIGHT_BG := Color(0.03, 0.03, 0.09, 1.0)
const NIGHT_TEXT := Color(0.72, 0.74, 1.0)
const NIGHT_DIM := Color(0.5, 0.5, 0.78)
const NIGHT_ACCENT := Color(1.0, 0.85, 0.45)
const NIGHT_BORDER := Color(0.45, 0.42, 0.95, 0.8)
const NIGHT_FILL := Color(0.04, 0.03, 0.12, 0.7)

const TAB_WIDTH: float = 80.0
const ROW_HEIGHT: float = 55.0
const ICON_SIZE: float = 45.0
## The BUY button / status column, so prices line up down the list.
const ACTION_WIDTH: float = 60.0
## Text sizes on an item's row. The laptop screen is only ~370 px wide, so the name has
## roughly 100 px to itself: it wraps onto a second line rather than being cut short.
const NAME_FONT_SIZE: int = 16
const PRICE_FONT_SIZE: int = 24
const BUY_FONT_SIZE: int = 20
const STATUS_FONT_SIZE: int = 10
## Padding above and below the BUY button's text (keeps it wider than it is tall).
const BUY_MARGIN_Y: int = 3

## What a row offers, from _state(). The first two can still be ordered (or could, with
## more money); the rest can't.
enum { BUY, CANT_AFFORD, OWNED, EN_ROUTE, SOLD_OUT, OUT_OF_STOCK }

## The category to open on (a CATEGORIES id). Set before this enters the tree.
var category: String = "all"

var _money_label: Label = null
var _tab_column: VBoxContainer = null
var _section_title: Label = null
var _section_count: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _hint: Label = null
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
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	LaptopUI.screen_margin(self, 6).add_child(col)
	col.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)

	_tab_column = VBoxContainer.new()
	_tab_column.custom_minimum_size = Vector2(TAB_WIDTH, 0)
	_tab_column.add_theme_constant_override("separation", 3)
	_tab_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_tab_column)

	var panel := _box()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(title_row)
	_section_title = _label("", 12, _text_col())
	_section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_section_title)
	_section_count = _label("", 9, _dim_col())
	_section_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_section_count)
	var rule := ColorRect.new()
	rule.color = _border_col()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(rule)

	# Scrolls, so a long category never clips past the bottom of the screen.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(_scroll.get_v_scroll_bar())
	inner.add_child(_scroll)
	_list = VBoxContainer.new()
	# No gap between rows: the mouse is always over one of them, so the hint line goes
	# straight from one item to the next instead of flashing the category's in between.
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list)

	_hint = _label("", 9, _dim_col())
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(_hint)

	GameState.money_changed.connect(_on_money_changed)
	_refresh()


## Deferred: a BUY button is usually still handling its press when the money moves.
func _on_money_changed(_value: int) -> void:
	_refresh.call_deferred()


## Back button, title, and what you have to spend.
func _build_header() -> Control:
	var box := _box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var back := _button("‹", 11)
	back.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(back)
	if _is_night():
		row.add_child(LaptopUI.glow_title("AFTER-HOURS STORE", 16, NIGHT_TEXT, Color(0.45, 0.4, 1.0, 1.0)))
	else:
		row.add_child(LaptopUI.glow_title("ONLINE STORE"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var caption := _label("BALANCE", 9, _dim_col())
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	_money_label = _label("", 13, _accent_col())
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_money_label)
	return box


# =============================================================================
# AVAILABILITY
# =============================================================================

## Whether `item` appears in the catalogue at all on `day`, in the night store or the day one.
static func is_listed(item: Dictionary, day: int, night: bool) -> bool:
	if not _in_season(item, day):
		return false
	if bool(item.get("night_only", false)) and not night:
		return false
	if bool(item.get("day_only", false)) and night:
		return false
	return true


## Whether a listed item can actually be ordered on `day`. Always true unless it is a
## "rotating" item that missed out on today's stock.
static func in_stock(item: Dictionary, day: int) -> bool:
	if not bool(item.get("rotating", false)):
		return true
	return String(item.get("id", "")) in rotating_stock(day)


## The ids of the rotating items in stock on `day`: ROTATING_IN_STOCK of them, drawn afresh
## each day (the same draw every time that day is asked about).
static func rotating_stock(day: int) -> Array[String]:
	var pool: Array[String] = []
	for item in ITEMS:
		if bool(item.get("rotating", false)) and _in_season(item, day):
			pool.append(String(item["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("delivery_stock_%d" % day)
	var stock: Array[String] = []
	while not pool.is_empty() and stock.size() < ROTATING_IN_STOCK:
		stock.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return stock


## Inside the item's from_day .. until_day window.
static func _in_season(item: Dictionary, day: int) -> bool:
	if item.has("from_day") and day < int(item["from_day"]):
		return false
	if item.has("until_day") and day > int(item["until_day"]):
		return false
	return true


## Recently arrived (see NEW_FOR_DAYS).
func _is_new(item: Dictionary) -> bool:
	return item.has("from_day") and _day() - int(item["from_day"]) < NEW_FOR_DAYS


func _day() -> int:
	return int(GameState.day)


## What the item's row offers right now.
func _state(item: Dictionary) -> int:
	if _sold_out_tonight(item):
		return SOLD_OUT
	if _en_route(item):
		return EN_ROUTE
	if _is_owned(item):
		return OWNED
	if not in_stock(item, _day()):
		return OUT_OF_STOCK
	if int(GameState.money) < _price(item):
		return CANT_AFFORD
	return BUY


## The listed items under `cat`, in the order they are shown: what can still be ordered
## first (tonight's limited parts ahead of the rest), what can't sunk to the bottom.
func _items_in(cat: String) -> Array:
	var limited: Array = []
	var open: Array = []
	var closed: Array = []
	for item in ITEMS:
		if not is_listed(item, _day(), _is_night()):
			continue
		if cat != "all" and String(item.get("category", "")) != cat:
			continue
		if _state(item) > CANT_AFFORD:
			closed.append(item)
		elif item.has("night_limit"):
			limited.append(item)
		else:
			open.append(item)
	return limited + open + closed


# =============================================================================
# TABS / LIST
# =============================================================================

func _refresh() -> void:
	_money_label.text = "$%d" % int(GameState.money)
	_build_tabs()
	_show_category(category)


## One tab per category that has something listed (ALL is always there).
func _build_tabs() -> void:
	for child in _tab_column.get_children():
		_tab_column.remove_child(child)
		child.queue_free()
	var shown: Array[String] = []
	for cat in CATEGORIES:
		var id := String(cat["id"])
		if id != "all" and _items_in(id).is_empty():
			continue
		shown.append(id)
	if not category in shown:
		category = "all"
	for id in shown:
		var on: bool = id == category
		var tab := Button.new()
		tab.text = ("> " if on else "  ") + String(_category_info(id).get("name", ""))
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.focus_mode = Control.FOCUS_NONE
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_font_size_override("font_size", 11)
		_style_tab(tab, on)
		tab.pressed.connect(_on_tab_pressed.bind(id))
		_tab_column.add_child(tab)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_column.add_child(spacer)
	if _is_night():
		_tab_column.add_child(_label("SAME-NIGHT +%d%%" % roundi((NIGHT_PRICE_MULTIPLIER - 1.0) * 100.0), 8, NIGHT_ACCENT))
		_tab_column.add_child(_label("ARRIVES BY DRONE", 8, Color(NIGHT_DIM, 0.8)))
	else:
		# Only claims a changing stock while something in the catalogue actually rotates.
		var rotates: bool = ITEMS.any(func(item: Dictionary) -> bool: return bool(item.get("rotating", false)))
		_tab_column.add_child(_label("STOCK CHANGES DAILY" if rotates else "ROBO-OS v0.2", 8, Color(LaptopUI.DIM, 0.7)))


func _on_tab_pressed(id: String) -> void:
	if id == category:
		return
	category = id
	_scroll.scroll_vertical = 0
	# Deferred: this rebuilds the tabs, and one of them is still handling this press.
	_refresh.call_deferred()


func _show_category(id: String) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var items := _items_in(id)
	var orderable := 0
	for item in items:
		_list.add_child(_make_row(item))
		if _state(item) <= CANT_AFFORD:
			orderable += 1
	if items.is_empty():
		_list.add_child(_label("nothing listed right now. check back another day.", 10, _dim_col()))
	_section_title.text = "// " + String(_category_info(id).get("name", ""))
	_section_count.text = "%d OF %d AVAILABLE" % [orderable, items.size()]
	_set_hint("")


func _category_info(id: String) -> Dictionary:
	for cat in CATEGORIES:
		if String(cat["id"]) == id:
			return cat
	return {}


func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = "> " + (text if text != "" else String(_category_info(category).get("desc", "")))


## An item's line: icon, name, then either its price and BUY or why it can't be ordered.
## Hovering it describes the item on the hint line.
func _make_row(item: Dictionary) -> Control:
	var state := _state(item)
	var orderable: bool = state <= CANT_AFFORD
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_entered.connect(_set_hint.bind(_row_hint(item, state)))
	row.mouse_exited.connect(_set_hint.bind(""))
	var dots := Color(_dim_col(), 0.35)
	row.draw.connect(func() -> void:
		var x := 0.0
		while x < row.size.x:
			row.draw_rect(Rect2(x, row.size.y - 1.0, 1.0, 1.0), dots)
			x += 3.0)

	var icon := TextureRect.new()
	if String(item.get("id", "")) == "flashlight":
		icon.texture = FlashlightIcon.texture(GameState.flashlight_on)
	else:
		icon.texture = LaptopUI.icon_tex(String(item.get("icon", "")))
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not orderable:
		icon.modulate = Color(1, 1, 1, 0.4)
	row.add_child(icon)

	var name_label := _label(String(item.get("name", "?")), NAME_FONT_SIZE,_text_col() if orderable else Color(_dim_col(), 0.75))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.custom_minimum_size = Vector2(40, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	row.add_child(name_label)

	if orderable and _is_new(item):
		row.add_child(_tag("NEW", _accent_col()))
	if orderable and item.has("night_limit"):
		row.add_child(_tag("%d LEFT" % _left_tonight(item), _accent_col()))

	if orderable:
		var price := _label("$%d" % _price(item), PRICE_FONT_SIZE,LaptopUI.ERR if state == CANT_AFFORD else _accent_col())
		price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(price)
		var btn := _button("BUY", BUY_FONT_SIZE)
		for style in ["normal", "hover", "pressed", "disabled"]:
			var sb := btn.get_theme_stylebox(style) as StyleBoxFlat
			sb.content_margin_top = BUY_MARGIN_Y
			sb.content_margin_bottom = BUY_MARGIN_Y
		btn.custom_minimum_size = Vector2(ACTION_WIDTH, 0)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Lets the mouse wheel scroll the list from on top of the button.
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.disabled = state == CANT_AFFORD
		btn.pressed.connect(_buy.bind(item))
		row.add_child(btn)
	else:
		var status := _label(_status_text(state), STATUS_FONT_SIZE,_accent_col() if state in [OWNED, EN_ROUTE] else _dim_col())
		status.custom_minimum_size = Vector2(ACTION_WIDTH, 0)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(status)
	return row


func _status_text(state: int) -> String:
	match state:
		OWNED: return "OWNED"
		EN_ROUTE: return "EN ROUTE"
		SOLD_OUT: return "SOLD OUT"
		OUT_OF_STOCK: return "NO STOCK"
	return ""


## The hint line for a row: what the item is, or why it can't be ordered.
func _row_hint(item: Dictionary, state: int) -> String:
	match state:
		CANT_AFFORD: return "you need $%d more for this." % (_price(item) - int(GameState.money))
		OWNED: return "you already have this."
		EN_ROUTE: return "on the delivery drone. guide it home on the PATROL app."
		SOLD_OUT: return "sold out for tonight."
		OUT_OF_STOCK: return "out of stock today. check back another day."
	return String(item.get("desc", ""))


## A small boxed word on a row (NEW, 1 LEFT).
func _tag(text: String, color: Color) -> Control:
	var tag := _label(text, 8, color)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.12)
	sb.border_color = Color(color, 0.7)
	sb.set_border_width_all(1)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	tag.add_theme_stylebox_override("normal", sb)
	return tag


func _is_night() -> bool:
	return _night_scene != null and is_instance_valid(_night_scene)


## What the item costs right now: the day price, plus same-night shipping at night.
func _price(item: Dictionary) -> int:
	var cost := int(item.get("cost", 0))
	return ceili(cost * NIGHT_PRICE_MULTIPLIER) if _is_night() else cost


## How many more of a once-per-night item can be ordered tonight.
func _left_tonight(item: Dictionary) -> int:
	if not item.has("night_limit") or not _is_night():
		return 0
	return maxi(0, int(item["night_limit"]) - int(_night_scene.call("night_store_bought_count", String(item["id"]))))


## A once-per-night item already bought tonight.
func _sold_out_tonight(item: Dictionary) -> bool:
	return item.has("night_limit") and _is_night() and _left_tonight(item) <= 0


# --- skin ---------------------------------------------------------------------

func _text_col() -> Color:
	return NIGHT_TEXT if _is_night() else LaptopUI.GREEN


func _dim_col() -> Color:
	return NIGHT_DIM if _is_night() else LaptopUI.DIM


func _accent_col() -> Color:
	return NIGHT_ACCENT if _is_night() else LaptopUI.OK


func _border_col() -> Color:
	return NIGHT_BORDER if _is_night() else LaptopUI.BORDER


## The bright border of whatever is hovered or selected.
func _hot_col() -> Color:
	return NIGHT_ACCENT if _is_night() else Color(0.35, 1.0, 0.5, 0.95)


func _label(text: String, font_size: int, color: Color) -> Label:
	return LaptopUI.label(text, font_size, color)


func _panel(border: Color) -> StyleBoxFlat:
	var sb := LaptopUI.panel_style(border)
	if _is_night():
		sb.bg_color = NIGHT_FILL
	return sb


func _box() -> PanelContainer:
	var box := LaptopUI.box()
	box.add_theme_stylebox_override("panel", _panel(_border_col()))
	return box


func _button(text: String, font_size: int) -> Button:
	var btn := LaptopUI.button(text, font_size)
	if _is_night():
		btn.add_theme_color_override("font_color", NIGHT_TEXT)
		btn.add_theme_color_override("font_hover_color", NIGHT_ACCENT)
		btn.add_theme_color_override("font_disabled_color", NIGHT_DIM)
		btn.add_theme_stylebox_override("normal", _panel(NIGHT_BORDER))
		btn.add_theme_stylebox_override("hover", _panel(NIGHT_ACCENT))
		btn.add_theme_stylebox_override("pressed", _panel(NIGHT_ACCENT))
		btn.add_theme_stylebox_override("disabled", _panel(Color(NIGHT_DIM, 0.4)))
	return btn


## A category tab: filled and bright while it is the open one.
func _style_tab(tab: Button, on: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := _panel(_hot_col() if on or state == "hover" or state == "pressed" else _border_col())
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		sb.content_margin_left = 4
		if on:
			sb.bg_color = Color(0.1, 0.08, 0.26, 0.9) if _is_night() else Color(0.03, 0.2, 0.09, 0.9)
		elif state == "hover":
			sb.bg_color = Color(0.07, 0.06, 0.18, 0.8) if _is_night() else Color(0.02, 0.12, 0.06, 0.8)
		tab.add_theme_stylebox_override(state, sb)
	tab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tab.add_theme_color_override("font_color", _accent_col() if on else _dim_col())
	tab.add_theme_color_override("font_hover_color", _accent_col())
	tab.add_theme_color_override("font_pressed_color", _accent_col())


## A thin bar in the skin's colours instead of the default grey one.
func _style_scrollbar(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(_dim_col(), 0.15)
	track.content_margin_left = 1.5
	track.content_margin_right = 1.5
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grab := StyleBoxFlat.new()
		grab.bg_color = _dim_col() if state == "grabber" else _accent_col()
		bar.add_theme_stylebox_override(state, grab)


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
	if _state(item) != BUY:
		return
	# Spending refreshes the screen (money_changed); refreshed again once the order is placed.
	GameState.money -= _price(item)
	if _is_night():
		if item.has("night_limit"):
			_night_scene.call("record_night_store_purchase", String(item["id"]))
		# Same-night shipping: the order rides the delivery drone and only lands once it
		# reaches home (StressTest delivery, guided on the PATROL app).
		_night_scene.call("queue_night_delivery", item)
	else:
		grant_item(item)
	_refresh.call_deferred()


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
