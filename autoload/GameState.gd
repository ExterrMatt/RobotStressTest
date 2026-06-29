extends Node
## Persistent game state singleton.
##
## Holds all values that survive between scenes, phases, and days.
## Emits signals on change so UI can react without polling.
##
## Anger and suspicion are clamped to [0, 100]. Money has no cap.
## Carryover anger is applied by DayCycle at day-rollover, not here.

signal money_changed(new_value: int)
signal suspicion_changed(new_value: int)
signal anger_changed(new_value: int)
signal day_changed(new_day: int)
signal phase_changed(new_phase: int)
signal arrested()
signal brightness_changed(new_value: float)
signal scanlines_enabled_changed(enabled: bool)
signal debug_mode_changed(enabled: bool)
## Emitted when the display/window mode setting changes. WindowManager listens
## and applies the change via DisplayServer. Value is a WindowMode entry.
signal window_mode_changed(mode: int)
## Emitted when the set of items bought today changes. The overlay listens
## to this so the per-day-purchase markers stay in sync without polling.
signal purchased_today_changed(purchased_ids: Array)
signal robot_parts_changed(parts: Dictionary)
signal intro_changed(active: bool, step: String)

## Display/window fit options, exposed in the settings menu. Persisted as an
## int. Defaults to WINDOWED to match the project's authored window size.
enum WindowMode { WINDOWED = 0, WINDOWED_FULLSCREEN = 1, FULLSCREEN = 2 }

const MAX_ANGER: int = 100
const MAX_SUSPICION: int = 100
const ARREST_THRESHOLD: int = 100  # tweak later; suspicion at/above this triggers arrest event
const DEFAULT_PLAYER_NAME: String = "Noah"
const LEGACY_TOOL_ID_MAP: Dictionary = {
	"electric_prod": "taser",
}

# --- core scalars ---
var _day: int = 1
## Current day number, starting at 1.
var day: int:
	get: return _day
	set(value):
		if value == _day:
			return
		_day = value
		day_changed.emit(_day)

## Current day phase. Values match DayCycle.Phase enum (MORNING=0, EVENING=1,
## NIGHT=2). Stored as int rather than DayCycle.Phase.MORNING to avoid an
## autoload-init-order dependency at class-parse time.
var _phase: int = 0
var _money: int = 0
var _brightness_value: float = 50.0
var _scanlines_enabled: bool = true
var _debug_mode_enabled: bool = false
var _window_mode: int = WindowMode.WINDOWED
var player_name: String = ""
var intro_active: bool = true
var intro_completed: bool = false
var intro_step: String = "exposition"

var money: int:
	get: return _money
	set(value):
		var new_value: int = max(0, value)
		if new_value == _money:
			return
		_money = new_value
		money_changed.emit(_money)

var phase: int:
	get: return _phase
	set(value):
		if value == _phase:
			return
		_phase = value
		phase_changed.emit(_phase)

var brightness_value: float:
	get: return _brightness_value
	set(value):
		var clamped: float = clampf(value, 0.0, 100.0)
		if is_equal_approx(clamped, _brightness_value):
			return
		_brightness_value = clamped
		brightness_changed.emit(_brightness_value)

var scanlines_enabled: bool:
	get: return _scanlines_enabled
	set(value):
		if value == _scanlines_enabled:
			return
		_scanlines_enabled = value
		scanlines_enabled_changed.emit(_scanlines_enabled)

var debug_mode_enabled: bool:
	get: return _debug_mode_enabled
	set(value):
		if value == _debug_mode_enabled:
			return
		_debug_mode_enabled = value
		debug_mode_changed.emit(_debug_mode_enabled)

var window_mode: int:
	get: return _window_mode
	set(value):
		var clamped: int = clampi(value, WindowMode.WINDOWED, WindowMode.FULLSCREEN)
		if clamped == _window_mode:
			return
		_window_mode = clamped
		window_mode_changed.emit(_window_mode)

var _suspicion: int = 0
var _anger: int = 0

# --- robot config ---
const ROBOT_PART_IDS: Array[String] = ["leg", "arm", "torso", "head", "hand"]

## Kept for older scene logic that only understood legs. Mirrors
## robot_parts["leg"].
var equipped_limbs: int = 0

var robot_parts: Dictionary = {
	"leg": 0,
	"arm": 0,
	"torso": 0,
	"head": 0,
	"hand": 0,
}

# --- inventory (stubbed - list of ingredient string IDs for now) ---
var ingredients: Dictionary = {
	"scrap_metal": 0,
	"synth_skin": 0,
	"nuts_bolts": 0,
	"electronics": 0,
	"nanobots": 0,
	"head_segments": 0,
	"oil": 0,
}

# --- unlocked skills (string IDs from design doc) ---
var skills: Array[String] = []

# --- tools owned (default tools: mouth + hand are always available) ---
var owned_tools: Array[String] = ["mouth", "hand"]

# --- daily purchase tracking (resets at day rollover) ---
## Item IDs the player has bought from the Store today. Used to enforce
## "one of each item per day". Cleared by DayCycle.end_day().
var purchased_today: Array[String] = []


func _ready() -> void:
	# Emit initial values so any listeners attached at startup get a value.
	# Deferred so listeners in other autoloads / Main have time to connect.
	call_deferred("_emit_initial_state")


func _emit_initial_state() -> void:
	money_changed.emit(_money)
	suspicion_changed.emit(_suspicion)
	anger_changed.emit(_anger)
	day_changed.emit(_day)
	phase_changed.emit(_phase)
	brightness_changed.emit(_brightness_value)
	scanlines_enabled_changed.emit(_scanlines_enabled)
	debug_mode_changed.emit(_debug_mode_enabled)
	window_mode_changed.emit(_window_mode)
	purchased_today_changed.emit(purchased_today)
	robot_parts_changed.emit(robot_parts.duplicate())
	intro_changed.emit(intro_active, intro_step)


func reset_for_new_game() -> void:
	_day = 1
	_phase = 0
	_money = 0
	_suspicion = 0
	_anger = 0
	player_name = ""
	equipped_limbs = 0

	for id in robot_parts.keys():
		robot_parts[id] = 0
	for id in ingredients.keys():
		ingredients[id] = 0
	skills.clear()
	owned_tools = ["mouth", "hand"]
	purchased_today.clear()

	intro_active = true
	intro_completed = false
	intro_step = "exposition"

	_emit_initial_state()


# --- money ---

func add_money(amount: int) -> void:
	money = _money + amount


func can_afford(cost: int) -> bool:
	return _money >= cost


func spend_money(cost: int) -> bool:
	if not can_afford(cost):
		return false
	money = _money - cost
	return true


# --- suspicion ---

var suspicion: int:
	get: return _suspicion
	set(value):
		var clamped: int = clampi(value, 0, MAX_SUSPICION)
		if clamped == _suspicion:
			return
		_suspicion = clamped
		suspicion_changed.emit(_suspicion)
		if _suspicion >= ARREST_THRESHOLD:
			arrested.emit()


func add_suspicion(delta: int) -> void:
	suspicion = _suspicion + delta


# --- anger ---

var anger: int:
	get: return _anger
	set(value):
		var clamped: int = clampi(value, 0, MAX_ANGER)
		if clamped == _anger:
			return
		_anger = clamped
		anger_changed.emit(_anger)


func add_anger(delta: int) -> void:
	anger = _anger + delta


# --- ingredients ---

func add_ingredient(id: String, amount: int = 1) -> void:
	if not ingredients.has(id):
		push_warning("Unknown ingredient id: %s" % id)
		return
	ingredients[id] = max(0, ingredients[id] + amount)


# --- robot parts ---

func is_robot_part_id(id: String) -> bool:
	return id in ROBOT_PART_IDS


func add_robot_part(id: String, amount: int = 1) -> void:
	if not is_robot_part_id(id):
		push_warning("Unknown robot part id: %s" % id)
		return
	robot_parts[id] = max(0, int(robot_parts.get(id, 0)) + amount)
	_sync_legacy_limb_count()
	robot_parts_changed.emit(robot_parts.duplicate())


func set_robot_part_count(id: String, amount: int) -> void:
	if not is_robot_part_id(id):
		push_warning("Unknown robot part id: %s" % id)
		return
	robot_parts[id] = max(0, amount)
	_sync_legacy_limb_count()
	robot_parts_changed.emit(robot_parts.duplicate())


func get_robot_part_count(id: String) -> int:
	if not is_robot_part_id(id):
		return 0
	return int(robot_parts.get(id, 0))


func has_robot_part(id: String, amount: int = 1) -> bool:
	return get_robot_part_count(id) >= amount


func set_all_robot_parts(amount: int) -> void:
	for id in ROBOT_PART_IDS:
		robot_parts[id] = max(0, amount)
	_sync_legacy_limb_count()
	robot_parts_changed.emit(robot_parts.duplicate())


func _sync_legacy_limb_count() -> void:
	equipped_limbs = get_robot_part_count("leg")


# --- skills ---

func has_skill(skill_id: String) -> bool:
	return skill_id in skills


func unlock_skill(skill_id: String) -> void:
	if skill_id not in skills:
		skills.append(skill_id)


# --- tools ---

func has_tool(tool_id: String) -> bool:
	tool_id = _normalized_tool_id(tool_id)
	return tool_id in owned_tools


func unlock_tool(tool_id: String) -> void:
	tool_id = _normalized_tool_id(tool_id)
	if tool_id not in owned_tools:
		owned_tools.append(tool_id)


func _normalized_tool_id(tool_id: String) -> String:
	return String(LEGACY_TOOL_ID_MAP.get(tool_id, tool_id))


func _normalize_owned_tools() -> void:
	var normalized: Array[String] = []
	for tool_id in owned_tools:
		var normalized_id := _normalized_tool_id(tool_id)
		if normalized_id not in normalized:
			normalized.append(normalized_id)
	owned_tools = normalized


# --- daily purchases ---
## Has the player already bought this item today? Used by the Store to
## gate buying any given item to once per day.

func has_purchased_today(item_id: String) -> bool:
	return item_id in purchased_today


func mark_purchased_today(item_id: String) -> void:
	if item_id in purchased_today:
		return
	purchased_today.append(item_id)
	purchased_today_changed.emit(purchased_today)


## Called by DayCycle at end_day() to wipe the per-day purchase ledger.
func reset_daily_purchases() -> void:
	if purchased_today.is_empty():
		return
	purchased_today.clear()
	purchased_today_changed.emit(purchased_today)


# --- intro sequence ---

func set_intro_step(step: String) -> void:
	intro_active = not intro_completed
	intro_step = step
	intro_changed.emit(intro_active, intro_step)


func is_intro_step(step: String) -> bool:
	return intro_active and not intro_completed and intro_step == step


func complete_intro() -> void:
	intro_completed = true
	intro_active = false
	intro_step = ""
	intro_changed.emit(intro_active, intro_step)


func set_player_name(value: String) -> void:
	var normalized := normalize_player_name(value)
	player_name = DEFAULT_PLAYER_NAME if normalized.is_empty() else normalized


func get_player_name() -> String:
	return DEFAULT_PLAYER_NAME if player_name.strip_edges().is_empty() else player_name


func normalize_player_name(value: String) -> String:
	var cleaned := ""
	var previous_was_separator := false
	var raw := String(value).strip_edges()
	for i in raw.length():
		var c := raw.substr(i, 1)
		var lower := c.to_lower()
		var is_letter := lower >= "a" and lower <= "z"
		var is_separator := c == "-" or c == "'"
		if is_letter:
			cleaned += lower
			previous_was_separator = false
		elif is_separator and not cleaned.is_empty() and not previous_was_separator:
			cleaned += c
			previous_was_separator = true
	while cleaned.ends_with("-") or cleaned.ends_with("'"):
		cleaned = cleaned.substr(0, cleaned.length() - 1)
	if cleaned.is_empty():
		return ""
	return cleaned.substr(0, 1).to_upper() + cleaned.substr(1)


# --- serialization stubs for future save system ---
## Returns a dictionary snapshot of all persistent state. Future save system
## can write this to disk; from_dict() reverses the operation.

func to_dict() -> Dictionary:
	return {
		"day": _day,
		"phase": _phase,
		"money": _money,
		"suspicion": _suspicion,
		"anger": _anger,
		"equipped_limbs": equipped_limbs,
		"robot_parts": robot_parts.duplicate(),
		"ingredients": ingredients.duplicate(),
		"skills": skills.duplicate(),
		"owned_tools": owned_tools.duplicate(),
		"purchased_today": purchased_today.duplicate(),
		"player_name": player_name,
		"intro_active": intro_active,
		"intro_completed": intro_completed,
		"intro_step": intro_step,
		"debug_mode_enabled": _debug_mode_enabled,
		"window_mode": _window_mode,
	}


func from_dict(data: Dictionary) -> void:
	_day = data.get("day", 1)
	_phase = data.get("phase", 0)  # 0 = MORNING
	_money = data.get("money", 0)
	_suspicion = data.get("suspicion", 0)
	_anger = data.get("anger", 0)
	equipped_limbs = data.get("equipped_limbs", 0)
	var loaded_parts: Dictionary = data.get("robot_parts", {}).duplicate()
	for id in ROBOT_PART_IDS:
		robot_parts[id] = max(0, int(loaded_parts.get(id, 0)))
	if get_robot_part_count("leg") == 0 and equipped_limbs > 0:
		robot_parts["leg"] = equipped_limbs
	_sync_legacy_limb_count()
	ingredients = data.get("ingredients", {}).duplicate()
	for id in ["scrap_metal", "synth_skin", "nuts_bolts", "electronics", "nanobots", "head_segments", "oil"]:
		ingredients[id] = max(0, int(ingredients.get(id, 0)))
	var had_legacy_sneaky_shoes: bool = int(ingredients.get("sneaky_shoes", 0)) > 0
	ingredients.erase("sneaky_shoes")
	skills.assign(data.get("skills", []))
	owned_tools.assign(data.get("owned_tools", ["mouth", "hand"]))
	_normalize_owned_tools()
	if had_legacy_sneaky_shoes:
		unlock_tool("sneaky_shoes")
	purchased_today.assign(data.get("purchased_today", []))
	set_player_name(String(data.get("player_name", DEFAULT_PLAYER_NAME)))
	intro_completed = bool(data.get("intro_completed", false))
	intro_active = bool(data.get("intro_active", not intro_completed))
	intro_step = String(data.get("intro_step", "" if intro_completed else "exposition"))
	_debug_mode_enabled = bool(data.get("debug_mode_enabled", false))
	_window_mode = clampi(int(data.get("window_mode", WindowMode.WINDOWED)), WindowMode.WINDOWED, WindowMode.FULLSCREEN)
	_emit_initial_state()
