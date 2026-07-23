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
signal volume_changed(new_value: float)
signal scanlines_enabled_changed(enabled: bool)
signal debug_mode_changed(enabled: bool)
signal easy_workshop_changed(enabled: bool)
## Emitted when the display/window mode setting changes. WindowManager listens
## and applies the change via DisplayServer. Value is a WindowMode entry.
signal window_mode_changed(mode: int)
## Emitted when the set of items bought today changes. The overlay listens
## to this so the per-day-purchase markers stay in sync without polling.
signal purchased_today_changed(purchased_ids: Array)
signal robot_parts_changed(parts: Dictionary)
## Emitted when the set of owned cosmetic chest items changes, so the robot
## visuals re-resolve without polling.
signal cosmetic_items_changed(items: Dictionary)
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
var _volume_value: float = 100.0
var _scanlines_enabled: bool = true
var _debug_mode_enabled: bool = false
var _easy_workshop_enabled: bool = false
var _window_mode: int = WindowMode.WINDOWED
var player_name: String = ""
var intro_active: bool = true
var intro_completed: bool = false
var intro_step: String = "exposition"

# --- patrol drone encounter tracking ---
## True once the player has sat down for the uncle's hang-out (drinking) event at
## least once. The first hang-out is meant to play a longer, lore-heavy version;
## every one after that plays the short version. Only the short version exists
## today, so nothing branches on this yet — see UncleHangout.gd's _start().
var uncle_hangout_seen: bool = false
## True once the player has been stopped by the patrol drone at least once
## (used to play the closing "that was stressful" thought only the first time).
var drone_encounter_seen: bool = false
## True once the scripted class-disruption science lesson has played. That lesson
## (the robot phones during class) is shown the first time the player goes to
## class after the intro ends; every class after that is a normal random lesson.
var robot_class_disruption_seen: bool = false
## True once the player has ever been caught with contraband by the drone.
var drone_ever_caught: bool = false
## Whether the most recent drone inspection caught the player with contraband.
var drone_caught_last_inspection: bool = false

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

## Master audio volume as a 0-100 percentage. Applied to the master audio bus
## immediately on change (and on startup) so the setting takes effect everywhere.
var volume_value: float:
	get: return _volume_value
	set(value):
		var clamped: float = clampf(value, 0.0, 100.0)
		if is_equal_approx(clamped, _volume_value):
			return
		_volume_value = clamped
		_apply_volume()
		volume_changed.emit(_volume_value)

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

## Easy Workshop Mode: when on, the workshop flashes a hint showing where each
## piece belongs. Off by default; the player can turn it on in Settings, or via
## the button the workshop offers once they have been struggling for a while.
var easy_workshop_enabled: bool:
	get: return _easy_workshop_enabled
	set(value):
		if value == _easy_workshop_enabled:
			return
		_easy_workshop_enabled = value
		easy_workshop_changed.emit(_easy_workshop_enabled)

var window_mode: int:
	get: return _window_mode
	set(value):
		var clamped: int = clampi(value, WindowMode.WINDOWED, WindowMode.FULLSCREEN)
		if clamped == _window_mode:
			return
		_window_mode = clamped
		window_mode_changed.emit(_window_mode)

# Suspicion is tracked in two pools whose sum is the value shown to the player.
#   * permanent — a floor the total can never drop below. Only special events
#     raise it (e.g. the patrol drone flagging you as a criminal); it is never
#     lost.
#   * temporary — the ordinary, losable part. add_suspicion() adds here by
#     default, and reductions only ever eat into this pool.
var _suspicion_permanent: int = 0
var _suspicion_temp: int = 0
var _anger: int = 0

# --- robot config ---
const ROBOT_PART_IDS: Array[String] = ["leg", "arm", "stomach", "chest", "head", "hand"]

## Kept for older scene logic that only understood legs. Mirrors
## robot_parts["leg"].
var equipped_limbs: int = 0

var robot_parts: Dictionary = {
	"leg": 0,
	"arm": 0,
	"stomach": 0,
	"chest": 0,
	"head": 0,
	"hand": 0,
}

# --- cosmetic chest items ---
## Optional chest overlays the robot can wear. Unlike robot_parts these are
## purely cosmetic: they gate the matching chest-region sprites (static and in
## the leg/vegetable animation) but never affect part counts. Owning big
## coconuts and the big chest cover is the default look; small coconuts is an
## alternative that starts unowned. The big chest cover is contoured for big
## coconuts specifically (a separate small chest cover is planned for the small
## coconuts). Balloons are a third mutually-exclusive chest fill (like the
## coconut variants) and also start unowned.
const COSMETIC_ITEM_IDS: Array[String] = ["big_coconuts", "small_coconuts", "balloons", "big_chest_cover"]
const COSMETIC_ITEM_DEFAULTS: Dictionary = {
	"big_coconuts": 1,
	"small_coconuts": 0,
	"balloons": 0,
	"big_chest_cover": 1,
}

var cosmetic_items: Dictionary = COSMETIC_ITEM_DEFAULTS.duplicate()

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

# --- stackable tool quantities ---
## How many of each tool the player owns. Most tools are one-time unlocks and
## never appear here (has_tool covers them). Stackable tools such as the
## screwdriver track a count so the stress test can allow one per hand once the
## player owns two or more.
var tool_counts: Dictionary = {}

# --- daily purchase tracking (resets at day rollover) ---
## Item IDs the player has bought from the Store today. Used to enforce
## "one of each item per day". Cleared by DayCycle.end_day().
var purchased_today: Array[String] = []


func _ready() -> void:
	# Apply the persisted audio volume up front so startup sounds honour it.
	_apply_volume()
	# Emit initial values so any listeners attached at startup get a value.
	# Deferred so listeners in other autoloads / Main have time to connect.
	call_deferred("_emit_initial_state")


## Push the current volume onto the master audio bus. 0% fully mutes the bus;
## anything above maps linearly (0-1) to decibels.
func _apply_volume() -> void:
	var master_bus: int = 0
	if _volume_value <= 0.0:
		AudioServer.set_bus_mute(master_bus, true)
		return
	AudioServer.set_bus_mute(master_bus, false)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(_volume_value / 100.0))


func _emit_initial_state() -> void:
	money_changed.emit(_money)
	suspicion_changed.emit(_total_suspicion())
	anger_changed.emit(_anger)
	day_changed.emit(_day)
	phase_changed.emit(_phase)
	brightness_changed.emit(_brightness_value)
	volume_changed.emit(_volume_value)
	scanlines_enabled_changed.emit(_scanlines_enabled)
	debug_mode_changed.emit(_debug_mode_enabled)
	easy_workshop_changed.emit(_easy_workshop_enabled)
	window_mode_changed.emit(_window_mode)
	purchased_today_changed.emit(purchased_today)
	robot_parts_changed.emit(robot_parts.duplicate())
	cosmetic_items_changed.emit(cosmetic_items.duplicate())
	intro_changed.emit(intro_active, intro_step)


func reset_for_new_game() -> void:
	_day = 1
	_phase = 0
	_money = 0
	_suspicion_permanent = 0
	_suspicion_temp = 0
	_anger = 0
	player_name = ""
	equipped_limbs = 0

	for id in robot_parts.keys():
		robot_parts[id] = 0
	cosmetic_items = COSMETIC_ITEM_DEFAULTS.duplicate()
	for id in ingredients.keys():
		ingredients[id] = 0
	skills.clear()
	owned_tools = ["mouth", "hand"]
	tool_counts.clear()
	purchased_today.clear()

	intro_active = true
	intro_completed = false
	intro_step = "exposition"

	uncle_hangout_seen = false
	drone_encounter_seen = false
	robot_class_disruption_seen = false
	drone_ever_caught = false
	drone_caught_last_inspection = false

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

## Total suspicion shown to the player: permanent floor plus temporary, clamped.
var suspicion: int:
	get: return _total_suspicion()
	# Setting the total directly adjusts the temporary pool, leaving the
	# permanent floor untouched. Used by debug helpers.
	set(value):
		var old_total: int = _total_suspicion()
		var target: int = clampi(value, 0, MAX_SUSPICION)
		_suspicion_temp = maxi(0, target - _suspicion_permanent)
		_notify_suspicion_changed(old_total)

## The permanent (unlosable) portion of suspicion.
var suspicion_permanent: int:
	get: return _suspicion_permanent


func _total_suspicion() -> int:
	return clampi(_suspicion_permanent + _suspicion_temp, 0, MAX_SUSPICION)


func _notify_suspicion_changed(old_total: int) -> void:
	var new_total: int = _total_suspicion()
	if new_total == old_total:
		return
	suspicion_changed.emit(new_total)
	if new_total >= ARREST_THRESHOLD:
		arrested.emit()


## Raise (or lower) suspicion. `amount` goes to the temporary pool by default —
## it can be negative to lose temporary suspicion, but never drops the total
## below the permanent floor. Pass a non-zero `permanent` for special occasions
## that also raise the permanent floor, which can never be lost again.
func add_suspicion(amount: int, permanent: int = 0) -> void:
	var old_total: int = _total_suspicion()
	if permanent != 0:
		_suspicion_permanent = clampi(_suspicion_permanent + permanent, 0, MAX_SUSPICION)
	# Keep the temp pool from hiding slack past the display cap, so reductions
	# take effect immediately instead of burning through invisible headroom.
	_suspicion_temp = clampi(_suspicion_temp + amount, 0, MAX_SUSPICION - _suspicion_permanent)
	_notify_suspicion_changed(old_total)


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


## "Torso" is not an item of its own — it is shorthand for the mid-body as a
## whole, i.e. having both the chest and the stomach. Kept so any logic that used
## to treat the old single "torso" part as one thing still has a concept to ask
## for; most callers should check "chest" or "stomach" specifically instead.
func has_torso() -> bool:
	return has_robot_part("chest") and has_robot_part("stomach")


func set_all_robot_parts(amount: int) -> void:
	for id in ROBOT_PART_IDS:
		robot_parts[id] = max(0, amount)
	_sync_legacy_limb_count()
	robot_parts_changed.emit(robot_parts.duplicate())


func _sync_legacy_limb_count() -> void:
	equipped_limbs = get_robot_part_count("leg")


# --- cosmetic chest items ---

func is_cosmetic_item_id(id: String) -> bool:
	return id in COSMETIC_ITEM_IDS


func get_cosmetic_item_count(id: String) -> int:
	if not is_cosmetic_item_id(id):
		return 0
	return int(cosmetic_items.get(id, 0))


func has_cosmetic_item(id: String) -> bool:
	return get_cosmetic_item_count(id) >= 1


func set_cosmetic_item(id: String, amount: int) -> void:
	if not is_cosmetic_item_id(id):
		push_warning("Unknown cosmetic item id: %s" % id)
		return
	var clamped: int = max(0, amount)
	if int(cosmetic_items.get(id, 0)) == clamped:
		return
	cosmetic_items[id] = clamped
	cosmetic_items_changed.emit(cosmetic_items.duplicate())


func add_cosmetic_item(id: String, amount: int = 1) -> void:
	set_cosmetic_item(id, get_cosmetic_item_count(id) + amount)


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


func unlock_tool(tool_id: String, amount: int = 1) -> void:
	tool_id = _normalized_tool_id(tool_id)
	if tool_id not in owned_tools:
		owned_tools.append(tool_id)
	tool_counts[tool_id] = int(tool_counts.get(tool_id, 0)) + maxi(1, amount)


## How many of the given tool the player owns. Falls back to 1 for tools that
## are owned but predate the count ledger (e.g. loaded from an older save).
func get_tool_count(tool_id: String) -> int:
	tool_id = _normalized_tool_id(tool_id)
	if tool_counts.has(tool_id):
		return maxi(0, int(tool_counts[tool_id]))
	return 1 if tool_id in owned_tools else 0


func _normalized_tool_id(tool_id: String) -> String:
	return String(LEGACY_TOOL_ID_MAP.get(tool_id, tool_id))


func _normalize_owned_tools() -> void:
	var normalized: Array[String] = []
	for tool_id in owned_tools:
		var normalized_id := _normalized_tool_id(tool_id)
		if normalized_id not in normalized:
			normalized.append(normalized_id)
	owned_tools = normalized


## Rebuilds the tool-count ledger from a loaded dictionary, applying the same
## legacy id remapping used for owned_tools so counts survive renames.
func _normalized_tool_counts(loaded: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for tool_id in loaded:
		var normalized_id := _normalized_tool_id(String(tool_id))
		var count := maxi(0, int(loaded[tool_id]))
		if count <= 0:
			continue
		normalized[normalized_id] = int(normalized.get(normalized_id, 0)) + count
	return normalized


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
		"suspicion": _total_suspicion(),
		"suspicion_permanent": _suspicion_permanent,
		"suspicion_temp": _suspicion_temp,
		"anger": _anger,
		"equipped_limbs": equipped_limbs,
		"robot_parts": robot_parts.duplicate(),
		"cosmetic_items": cosmetic_items.duplicate(),
		"ingredients": ingredients.duplicate(),
		"skills": skills.duplicate(),
		"owned_tools": owned_tools.duplicate(),
		"tool_counts": tool_counts.duplicate(),
		"purchased_today": purchased_today.duplicate(),
		"player_name": player_name,
		"intro_active": intro_active,
		"intro_completed": intro_completed,
		"intro_step": intro_step,
		"uncle_hangout_seen": uncle_hangout_seen,
		"drone_encounter_seen": drone_encounter_seen,
		"robot_class_disruption_seen": robot_class_disruption_seen,
		"drone_ever_caught": drone_ever_caught,
		"drone_caught_last_inspection": drone_caught_last_inspection,
		"debug_mode_enabled": _debug_mode_enabled,
		"window_mode": _window_mode,
		"volume_value": _volume_value,
		"easy_workshop_enabled": _easy_workshop_enabled,
	}


func from_dict(data: Dictionary) -> void:
	_day = data.get("day", 1)
	_phase = data.get("phase", 0)  # 0 = MORNING
	_money = data.get("money", 0)
	# Newer saves store the split; older saves only had a single "suspicion"
	# total, which is treated as entirely temporary (no permanent floor).
	_suspicion_permanent = clampi(int(data.get("suspicion_permanent", 0)), 0, MAX_SUSPICION)
	_suspicion_temp = maxi(0, int(data.get("suspicion_temp", data.get("suspicion", 0))))
	_anger = data.get("anger", 0)
	equipped_limbs = data.get("equipped_limbs", 0)
	var loaded_parts: Dictionary = data.get("robot_parts", {}).duplicate()
	for id in ROBOT_PART_IDS:
		robot_parts[id] = max(0, int(loaded_parts.get(id, 0)))
	# Legacy saves stored a single "torso" part; it is now split into chest and
	# stomach, so seed both from the old value when they weren't saved separately.
	var legacy_torso: int = int(loaded_parts.get("torso", 0))
	if legacy_torso > 0:
		if int(robot_parts.get("chest", 0)) == 0:
			robot_parts["chest"] = legacy_torso
		if int(robot_parts.get("stomach", 0)) == 0:
			robot_parts["stomach"] = legacy_torso
	if get_robot_part_count("leg") == 0 and equipped_limbs > 0:
		robot_parts["leg"] = equipped_limbs
	_sync_legacy_limb_count()
	# Cosmetic chest items: seed from defaults, then apply saved values so older
	# saves (which lack the key) keep the default look.
	var loaded_cosmetics: Dictionary = data.get("cosmetic_items", {})
	cosmetic_items = COSMETIC_ITEM_DEFAULTS.duplicate()
	for id in COSMETIC_ITEM_IDS:
		if loaded_cosmetics.has(id):
			cosmetic_items[id] = max(0, int(loaded_cosmetics[id]))
	ingredients = data.get("ingredients", {}).duplicate()
	for id in ["scrap_metal", "synth_skin", "nuts_bolts", "electronics", "nanobots", "head_segments", "oil"]:
		ingredients[id] = max(0, int(ingredients.get(id, 0)))
	var had_legacy_sneaky_shoes: bool = int(ingredients.get("sneaky_shoes", 0)) > 0
	ingredients.erase("sneaky_shoes")
	skills.assign(data.get("skills", []))
	owned_tools.assign(data.get("owned_tools", ["mouth", "hand"]))
	_normalize_owned_tools()
	tool_counts = _normalized_tool_counts(data.get("tool_counts", {}))
	if had_legacy_sneaky_shoes:
		unlock_tool("sneaky_shoes")
	purchased_today.assign(data.get("purchased_today", []))
	set_player_name(String(data.get("player_name", DEFAULT_PLAYER_NAME)))
	intro_completed = bool(data.get("intro_completed", false))
	intro_active = bool(data.get("intro_active", not intro_completed))
	intro_step = String(data.get("intro_step", "" if intro_completed else "exposition"))
	uncle_hangout_seen = bool(data.get("uncle_hangout_seen", false))
	drone_encounter_seen = bool(data.get("drone_encounter_seen", false))
	robot_class_disruption_seen = bool(data.get("robot_class_disruption_seen", false))
	drone_ever_caught = bool(data.get("drone_ever_caught", false))
	drone_caught_last_inspection = bool(data.get("drone_caught_last_inspection", false))
	_debug_mode_enabled = bool(data.get("debug_mode_enabled", false))
	_window_mode = clampi(int(data.get("window_mode", WindowMode.WINDOWED)), WindowMode.WINDOWED, WindowMode.FULLSCREEN)
	_volume_value = clampf(float(data.get("volume_value", 100.0)), 0.0, 100.0)
	_apply_volume()
	_easy_workshop_enabled = bool(data.get("easy_workshop_enabled", false))
	_emit_initial_state()
