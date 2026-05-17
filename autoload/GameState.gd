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
## Emitted when the set of items bought today changes. The overlay listens
## to this so the per-day-purchase markers stay in sync without polling.
signal purchased_today_changed(purchased_ids: Array)

const MAX_ANGER: int = 100
const MAX_SUSPICION: int = 100
const ARREST_THRESHOLD: int = 100  # tweak later; suspicion at/above this triggers arrest event

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

var _suspicion: int = 0
var _anger: int = 0

# --- robot config (stubbed until construction system exists) ---
## Number of equipped limbs. Feeds into stress-test difficulty and the anger
## tick formula ("2 units per limb per second at max ma").
var equipped_limbs: int = 0

# --- inventory (stubbed - list of ingredient string IDs for now) ---
var ingredients: Dictionary = {
	"scrap_metal": 0,
	"synth_skin": 0,
	"nuts_bolts": 0,
	"electronics": 0,
	"nanobots": 0,
	"oil": 0,
	"sneaky_shoes": 0,
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
	purchased_today_changed.emit(purchased_today)


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


# --- skills ---

func has_skill(skill_id: String) -> bool:
	return skill_id in skills


func unlock_skill(skill_id: String) -> void:
	if skill_id not in skills:
		skills.append(skill_id)


# --- tools ---

func has_tool(tool_id: String) -> bool:
	return tool_id in owned_tools


func unlock_tool(tool_id: String) -> void:
	if tool_id not in owned_tools:
		owned_tools.append(tool_id)


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
		"ingredients": ingredients.duplicate(),
		"skills": skills.duplicate(),
		"owned_tools": owned_tools.duplicate(),
		"purchased_today": purchased_today.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	_day = data.get("day", 1)
	_phase = data.get("phase", 0)  # 0 = MORNING
	_money = data.get("money", 0)
	_suspicion = data.get("suspicion", 0)
	_anger = data.get("anger", 0)
	equipped_limbs = data.get("equipped_limbs", 0)
	ingredients = data.get("ingredients", {}).duplicate()
	skills.assign(data.get("skills", []))
	owned_tools.assign(data.get("owned_tools", ["mouth", "hand"]))
	purchased_today.assign(data.get("purchased_today", []))
	_emit_initial_state()
