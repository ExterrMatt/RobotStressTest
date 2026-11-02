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
signal fatigue_changed(new_value: int)
signal day_changed(new_day: int)
signal phase_changed(new_phase: int)
signal arrested()
signal brightness_changed(new_value: float)
signal volume_changed(new_value: float)
signal music_volume_changed(new_value: float)
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
## Emitted when the set of limbs the player has prepared (via the laptop build app)
## changes. Carries a duplicate of prepared_limbs.
signal prepared_limbs_changed(limbs: Array)
signal intro_changed(active: bool, step: String)
## Emitted when the flashlight's beam turns on or off (see flashlight_on).
signal flashlight_on_changed(on: bool)

## Display/window fit options, exposed in the settings menu. Persisted as an
## int. Defaults to WINDOWED to match the project's authored window size.
enum WindowMode { WINDOWED = 0, WINDOWED_FULLSCREEN = 1, FULLSCREEN = 2 }

const MAX_ANGER: int = 100
const MAX_SUSPICION: int = 100
const MAX_FATIGUE: int = 100
const ARREST_THRESHOLD: int = 100  # tweak later; suspicion at/above this triggers arrest event
const DEFAULT_PLAYER_NAME: String = "Noah"
## Names offered as the pre-filled suggestion when the player is asked to name
## themselves. One is picked at random each time the name prompt appears, instead
## of always suggesting the same name.
const DEFAULT_PLAYER_NAMES: Array[String] = [
	"Adam", "Ben", "Clyde", "Derek", "Evan", "Fabian", "George", "Harry",
	"Isiah", "Josh", "Kenny", "Lamar", "Mark", "Noah", "Oscar", "Patrick",
	"Quincy", "Ramon", "Stanley", "Thomas", "Ulrich", "Vernon", "Walrus",
	"Xylophone", "Zuko",
]
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
		# Moving on a day: how the stats stood when today began becomes yesterday's, and the
		# new day starts from where they are now (night penalties included). Going back (a
		# restart) starts over from zero.
		yesterday_stats = today_start_stats.duplicate() if value > _day else _zero_stats()
		today_start_stats = _current_stats()
		_day = value
		day_changed.emit(_day)

## Suspicion, anger and fatigue as they stood at the start of yesterday (all 0 on day 1), for
## the HUD's "yesterday" hover - which compares them with the stats now.
var yesterday_stats: Dictionary = {"suspicion": 0, "anger": 0, "fatigue": 0}
## The same, as they stood at the start of today.
var today_start_stats: Dictionary = {"suspicion": 0, "anger": 0, "fatigue": 0}


func _current_stats() -> Dictionary:
	return {"suspicion": _total_suspicion(), "anger": _anger, "fatigue": _fatigue}


func _zero_stats() -> Dictionary:
	return {"suspicion": 0, "anger": 0, "fatigue": 0}

## Current day phase. Values match DayCycle.Phase enum (MORNING=0, EVENING=1,
## NIGHT=2). Stored as int rather than DayCycle.Phase.MORNING to avoid an
## autoload-init-order dependency at class-parse time.
var _phase: int = 0
var _money: int = 0
var _brightness_value: float = 50.0
## Default master volume (0-100). The game starts at 50% (half amplitude on the
## master bus) rather than full blast; a player who wants the old full-volume mix
## can raise the slider to 100.
const DEFAULT_VOLUME_VALUE: float = 50.0
var _volume_value: float = DEFAULT_VOLUME_VALUE
## Music has its own 0-100 slider, on top of the master volume. It starts at 50%.
const DEFAULT_MUSIC_VOLUME_VALUE: float = 50.0
## Global ceiling for music: even at a 100% music slider the music plays at this
## fraction of full amplitude, so the mix sits well under the sound effects.
const MUSIC_GLOBAL_SCALE: float = 0.33
var _music_volume_value: float = DEFAULT_MUSIC_VOLUME_VALUE
var _scanlines_enabled: bool = true

## Default playback level for any sound effect that does NOT set its own volume.
## Individually-tuned sounds keep their own scale (e.g. the generator loops, clock,
## bell, screw sounds); every other/new sound plays at this fraction of full. To
## re-balance all untuned sounds at once, change this one value. To tune a specific
## sound, give its AudioStreamPlayer its own volume_db instead of this default.
const DEFAULT_SFX_VOLUME_SCALE: float = 0.5
var _debug_mode_enabled: bool = false
var _easy_workshop_enabled: bool = false

## Camera-feel settings, toggled from the pause/settings menu and polled by the stress
## test each frame. Persisted with the other settings; both default on.
## The camera roll (tilt) during the curved table/window <-> generator pans.
var camera_roll_enabled: bool = true
## The subtle mouse-follow "sway" that drifts the camera toward the cursor.
var camera_mouse_follow_enabled: bool = true

# --- Laptop debug cheats ---
## Set from the hidden bedroom laptop menu (debug only) and read by the next
## stress test as it starts. They persist until changed again from the laptop.
## Extra seconds added to the stress test's night clock (the laptop's "+30s"
## button adds 30 each press).
var stress_test_bonus_time_seconds: float = 0.0
## Multiplier applied to the stress test's awareness fail threshold (the laptop's
## "double threshold" button doubles this each press). 1.0 leaves it at default.
var stress_test_awareness_threshold_multiplier: float = 1.0
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
## True once the scripted work-disruption call has played. The robot phones the
## first time the player finishes the upper-arm assembly minigame after the intro
## and talks them into pocketing the chest; that shift skips the usual scrap steal.
var robot_work_disruption_seen: bool = false
## The day the work-disruption call played (0 = never). The park call waits for a
## later day than this.
var robot_work_disruption_day: int = 0
## True once the robot's park phone call has played (the first walk home from school
## or work on a day after the work-disruption call). The patrol-drone encounter
## can't happen until it has.
var robot_park_call_seen: bool = false
## True once the player has brought home the robot chest pocketed during the
## work-disruption shift. Maintenance stays locked on the location screen (outside
## debug mode) until then, and its first-visit cutscene waits for it too.
var maintenance_unlocked: bool = false
## True once the one-time cutscene before the first Maintenance visit (sneaking into
## the uncle's factory) has played.
var maintenance_intro_seen: bool = false
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

## Music volume as a 0-100 percentage, independent of the master volume slider.
## Music players read music_player_volume_db() for their level and listen to
## music_volume_changed to update live as the slider moves.
var music_volume_value: float:
	get: return _music_volume_value
	set(value):
		var clamped: float = clampf(value, 0.0, 100.0)
		if is_equal_approx(clamped, _music_volume_value):
			return
		_music_volume_value = clamped
		music_volume_changed.emit(_music_volume_value)

## The volume_db a music player should use: the music slider scaled by the global
## music ceiling. Returns a deep-silent level at 0 so tracks fully fade out.
func music_player_volume_db() -> float:
	if _music_volume_value <= 0.0:
		return -80.0
	return linear_to_db((_music_volume_value / 100.0) * MUSIC_GLOBAL_SCALE)

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
var _fatigue: int = 0

# --- robot config ---
const ROBOT_PART_IDS: Array[String] = ["leg", "arm", "stomach", "chest", "head", "hand"]

## Kept for older scene logic that only understood legs: how many legs are on the robot.
var equipped_limbs: int = 0

## Robot parts in the inventory - loose, not on her. What she's wearing is equipped_parts;
## a part moves between the two (taken off: into here; put on: used up from here), so one
## is never in both.
var robot_parts: Dictionary = {
	"leg": 0,
	"arm": 0,
	"stomach": 0,
	"chest": 0,
	"head": 0,
	"hand": 0,
}
## What the robot is wearing: slot -> the part id in it. A slot is limb_key(part, side) -
## "head", "chest", "stomach", "arm_left", "arm_right", "hand_left", "hand_right",
## "leg_left", "leg_right" (see part_slots). A free slot isn't in here. Everything that
## draws her reads this, never the inventory.
var equipped_parts: Dictionary = {}
## Parts worn as a pair, one slot per side.
const PAIRED_PART_IDS: Array[String] = ["arm", "leg", "hand"]
const PART_SIDES: Array[String] = ["left", "right"]
## How many of each part the robot wears at once (only read now to convert old saves).
const ROBOT_PART_SLOTS: Dictionary = {"leg": 2, "arm": 2, "hand": 2, "head": 1, "chest": 1, "stomach": 1}
## Parts put on body first, so a leg has a stomach to hang from and a hand its arm.
const EQUIP_ORDER: Array[String] = ["head", "chest", "stomach", "arm", "hand", "leg"]

## What each limb the player built in the workshop went together from: part id -> one list
## of component item ids per limb, oldest build first (a stomach's might be
## ["pelvis", "tank", "tank", "pump", "outer_plating"]). Disassembling a limb hands back
## exactly what's on its list, so the optional pieces (the stomach's tanks, pump, battery,
## external) only come back if they really went in. Parts are counted, not tracked one by
## one, so a list belongs to "one of the player's limbs of that kind", not a particular one.
var limb_builds: Dictionary = {}

# --- cosmetic chest items ---
## Optional chest overlays the robot can wear. Unlike robot_parts these are
## purely cosmetic: they gate the matching chest-region sprites (static and in
## the leg/vegetable animation) but never affect part counts. NOTHING is owned by
## default: the big coconuts and big chest cover are granted together the moment a
## chest (torso) is first acquired (see _grant_torso_cosmetics), so a fresh game -
## debug or not, endless or not - starts with a bare chest. Small coconuts and
## balloons are alternative fills that stay unowned until obtained.
const COSMETIC_ITEM_IDS: Array[String] = ["big_coconuts", "small_coconuts", "balloons", "big_chest_cover"]
const COSMETIC_ITEM_DEFAULTS: Dictionary = {
	"big_coconuts": 0,
	"small_coconuts": 0,
	"balloons": 0,
	"big_chest_cover": 0,
}

var cosmetic_items: Dictionary = COSMETIC_ITEM_DEFAULTS.duplicate()

## Hair-front style the robot last wore in the stress test, so other scenes (the
## maintenance robot) can match it. Index into the stress test's hair options:
## 0 = normal, 1 = swing, 2 = bangs. Defaults to swing.
var robot_hair_style: int = 1

# --- inventory (stubbed - list of ingredient string IDs for now) ---
var ingredients: Dictionary = {
	"scrap_metal": 0,
	"synth_skin": 0,
	"nuts_bolts": 0,
	"electronics": 0,
	"nanobots": 0,
	"head_segments": 0,
	"oil": 0,
	# Pre-made limb sub-assemblies — intermediate items crafted in the workshop. Each can be
	# crafted on its own from raw ingredients, and limbs are crafted from these
	# (see WorkshopMinigame.CRAFTABLE_PARTS). The upper arm is the template for the rest.
	"upper_arm": 0,
	"forearm": 0,
	"thigh": 0,
	"shin": 0,
	"foot": 0,
	"ribcage": 0,
	"upper_plating": 0,
	"lower_plating": 0,
	# Stomach sub-assemblies: the pelvis (metal shell) and outer plating are required, the
	# internals optional.
	"pelvis": 0,
	"outer_plating": 0,
	"tank": 0,
	"pump": 0,
	"huge_battery": 0,
	"external": 0,
	# Spare battery used in maintenance (dragged onto the robot).
	"battery": 0,
	# Shoulder pads taken off her in bed (dragged off in the Sleep scene); clicking an
	# empty shoulder there puts one back on.
	"shoulder_pad": 0,
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

## Whether the flashlight's beam is on right now (the stress test turns it on in the dark).
## Not saved - it's only ever on while that scene runs. Icons show it lit while true.
var flashlight_on: bool = false

# --- daily purchase tracking (resets at day rollover) ---
## Item IDs the player has bought from the Store today. Used to enforce
## "one of each item per day". Cleared by DayCycle.end_day().
var purchased_today: Array[String] = []

# --- laptop: limbs prepared for assembly ---
## Limb ids the player has "unlocked for preparation" from the laptop build app's
## success screen (e.g. "arm", "leg", "torso", "head"). The maintenance laptop's
## assembly screen reads this to list what is ready to slot onto the robot.
var prepared_limbs: Array[String] = []

# --- laptop assembly locks (simplified first pass) ---
## Whether the prepared arm's lock is open. Both this and torso_socket_lock_open
## must be open before the arm can be connected to the torso socket.
var arm_lock_open: bool = false
## Whether the torso socket's lock is open.
var torso_socket_lock_open: bool = false
## Whether the arm has been slotted into the torso (both locks were open).
var arm_connected: bool = false

# --- stress-test history (for the laptop's history app) ---
## One entry per completed stress-test night, oldest first. Each entry:
##   {day:int, success:bool, reason:String, electricity:int, screws:int}
## Recorded by StressTest via record_stress_test_result().
var stress_test_history: Array = []
## Keep the log from growing without bound.
const STRESS_TEST_HISTORY_MAX: int = 60

# --- save file ---
const SAVE_PATH: String = "user://savegame.json"


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
	fatigue_changed.emit(_fatigue)
	day_changed.emit(_day)
	phase_changed.emit(_phase)
	brightness_changed.emit(_brightness_value)
	volume_changed.emit(_volume_value)
	music_volume_changed.emit(_music_volume_value)
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
	yesterday_stats = _zero_stats()
	today_start_stats = _zero_stats()
	_phase = 0
	_money = 0
	_suspicion_permanent = 0
	_suspicion_temp = 0
	_anger = 0
	_fatigue = 0
	player_name = ""
	equipped_limbs = 0

	for id in robot_parts.keys():
		robot_parts[id] = 0
	equipped_parts.clear()
	limb_segments.clear()
	limb_builds.clear()
	cosmetic_items = COSMETIC_ITEM_DEFAULTS.duplicate()
	for id in ingredients.keys():
		ingredients[id] = 0
	skills.clear()
	owned_tools = ["mouth", "hand"]
	tool_counts.clear()
	purchased_today.clear()
	prepared_limbs.clear()
	unlocked_segments.clear()
	arm_lock_open = false
	torso_socket_lock_open = false
	arm_connected = false
	stress_test_history.clear()

	intro_active = true
	intro_completed = false
	intro_step = "exposition"

	uncle_hangout_seen = false
	drone_encounter_seen = false
	robot_class_disruption_seen = false
	robot_work_disruption_seen = false
	robot_work_disruption_day = 0
	robot_park_call_seen = false
	maintenance_unlocked = false
	maintenance_intro_seen = false
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


# --- fatigue ---
# Rises each night the player doesn't sleep (see Main's night-result handling)
# and resets to 0 when they do.

var fatigue: int:
	get: return _fatigue
	set(value):
		var clamped: int = clampi(value, 0, MAX_FATIGUE)
		if clamped == _fatigue:
			return
		_fatigue = clamped
		fatigue_changed.emit(_fatigue)


func add_fatigue(delta: int) -> void:
	fatigue = _fatigue + delta


# --- ingredients ---

## Ingredients that cap at a maximum the player can ever hold at once. The spare
## battery used in maintenance is single-use and capped at one - buying or being
## granted more never stocks past one.
const INGREDIENT_MAX := {"battery": 1, "shoulder_pad": 2}


func add_ingredient(id: String, amount: int = 1) -> void:
	if not ingredients.has(id):
		push_warning("Unknown ingredient id: %s" % id)
		return
	var new_value: int = max(0, int(ingredients[id]) + amount)
	if INGREDIENT_MAX.has(id):
		new_value = min(new_value, int(INGREDIENT_MAX[id]))
	ingredients[id] = new_value


# --- robot parts ---

func is_robot_part_id(id: String) -> bool:
	return id in ROBOT_PART_IDS


## Adds (or, negative, uses up) `id` parts in the inventory. Never touches what she's wearing.
func add_robot_part(id: String, amount: int = 1) -> void:
	if not is_robot_part_id(id):
		push_warning("Unknown robot part id: %s" % id)
		return
	var had_chest := get_owned_part_count("chest") >= 1
	robot_parts[id] = max(0, int(robot_parts.get(id, 0)) + amount)
	# Crafting a chest (the torso) is what grants the coconuts + chest cover.
	if id == "chest" and not had_chest and get_owned_part_count("chest") >= 1:
		_grant_torso_cosmetics()
	_robot_parts_updated()


## Sets how many `id` parts are in the inventory. Never touches what she's wearing.
func set_robot_part_count(id: String, amount: int) -> void:
	if not is_robot_part_id(id):
		push_warning("Unknown robot part id: %s" % id)
		return
	var had_chest := get_owned_part_count("chest") >= 1
	robot_parts[id] = max(0, amount)
	if id == "chest" and not had_chest and get_owned_part_count("chest") >= 1:
		_grant_torso_cosmetics()
	_robot_parts_updated()


## Notes what a limb just built in the workshop went together from (see limb_builds).
func record_limb_build(id: String, components: Array[String]) -> void:
	var builds: Array = limb_builds.get(id, [])
	builds.append(components.duplicate())
	limb_builds[id] = builds


## Takes one `id` limb's build list off limb_builds for disassembly (the newest), or an
## empty list when none of the player's limbs of that kind has one (bought, rewarded, or
## built before builds were kept). Lists left over from limbs no longer owned - lost on her,
## debug-removed - are dropped first, oldest first, so they can't come back later. Call it
## before the limb is taken out of the inventory.
func take_limb_build(id: String) -> Array[String]:
	var components: Array[String] = []
	var builds: Array = limb_builds.get(id, [])
	while builds.size() > get_owned_part_count(id):
		builds.pop_front()
	if not builds.is_empty():
		components.assign(builds.pop_back())
	if builds.is_empty():
		limb_builds.erase(id)
	else:
		limb_builds[id] = builds
	return components


## Seconds every part on the robot (legs, arms, hands, torso, head...) adds to a night.
const NIGHT_TIME_PER_ROBOT_PART_SECONDS: float = 10.0


## How long a night lasts in the night scenes (the stress test and sleep). Both use
## this, so a night is the same length wherever it's played: `base_seconds`, plus any
## banked bonus time (the laptop's "+30s"), plus NIGHT_TIME_PER_ROBOT_PART_SECONDS for
## each part on the robot.
func night_duration_seconds(base_seconds: float) -> float:
	var parts := 0
	for id in ROBOT_PART_IDS:
		parts += get_attached_part_count(id)
	return base_seconds + maxf(0.0, stress_test_bonus_time_seconds) \
			+ NIGHT_TIME_PER_ROBOT_PART_SECONDS * float(parts)


## How many `id` parts are in the inventory (loose - not on her).
func get_robot_part_count(id: String) -> int:
	if not is_robot_part_id(id):
		return 0
	return int(robot_parts.get(id, 0))


## How many `id` parts are on the robot (see equipped_parts). The robot is drawn with these.
func get_attached_part_count(id: String) -> int:
	var count := 0
	for slot in part_slots(id):
		if equipped_parts.has(slot):
			count += 1
	return count


## Every `id` part the player has: in the inventory plus on her.
func get_owned_part_count(id: String) -> int:
	return get_robot_part_count(id) + get_attached_part_count(id)


## The slots part `id` goes in (equipped_parts keys): one per side for a paired part.
func part_slots(id: String) -> Array[String]:
	var slots: Array[String] = []
	if not is_robot_part_id(id):
		return slots
	if is_paired_part(id):
		for side in PART_SIDES:
			slots.append(limb_key(id, side))
	else:
		slots.append(id)
	return slots


func is_paired_part(id: String) -> bool:
	return id in PAIRED_PART_IDS


## Whether the robot is wearing part `id` on `side` ("left" / "right"; "" for an unpaired part).
func is_part_attached_on(id: String, side: String) -> bool:
	return equipped_parts.has(limb_key(id, side)) and part_slots(id).has(limb_key(id, side))


## Whether a part `id` could go on `side` now (whether or not one is in the inventory): the
## slot is free and not holding a part-built limb, and what it anchors to is on her - a leg
## hangs from the stomach, a hand from its arm, the stomach and the arms from the chest.
func can_equip_part(id: String, side: String = "") -> bool:
	var slot := limb_key(id, side)
	if not part_slots(id).has(slot) or equipped_parts.has(slot):
		return false
	if LIMB_SEGMENTS.has(id) and not get_limb_segments(id, side).is_empty():
		return false
	return has_anchor(id, side)


## Whether what part `id` (on `side`) hangs from is on her: the stomach for a leg, the arm
## for a hand, the chest for the stomach or an arm. Anything else needs nothing.
func has_anchor(id: String, side: String = "") -> bool:
	match id:
		"leg":
			return get_attached_part_count("stomach") > 0
		"hand":
			return is_part_attached_on("arm", side)
		"stomach", "arm":
			return get_attached_part_count("chest") > 0
	return true


## Puts one `id` part from the inventory on `side` (using it up), and locks that slot again
## if the laptop had it unlocked. Only that part goes on - the stomach is its own piece, so
## the legs go back on one by one. Returns what went on, {part id: count} (empty if nothing
## could).
func equip_part(id: String, side: String = "") -> Dictionary:
	var added := {}
	if get_robot_part_count(id) < 1 or not can_equip_part(id, side):
		return added
	robot_parts[id] = get_robot_part_count(id) - 1
	equipped_parts[limb_key(id, side)] = id
	unprepare_limb(limb_key(id, side))
	_clear_segment_unlocks(limb_key(id, side))
	added[id] = 1
	_robot_parts_updated()
	return added


## Fills every free slot `id` can go in from the inventory (all parts when `id` is ""), body
## before limbs so legs have a stomach and hands an arm. Slots unlocked on the laptop are
## left free for the part the player chose to put there. Returns what went on.
func equip_free_slots(id: String = "") -> Dictionary:
	var added := {}
	for part in EQUIP_ORDER:
		if id != "" and part != id:
			continue
		for slot in part_slots(part):
			if is_limb_prepared(slot):
				continue
			var side := slot.trim_prefix(part + "_") if is_paired_part(part) else ""
			var got := equip_part(part, side)
			for key in got:
				added[key] = int(added.get(key, 0)) + int(got[key])
	return added


## Debug: puts a full robot on her the proper way - every free slot filled from the inventory
## (a part-built limb's pieces go back in the inventory first), whether or not the laptop has
## it unlocked.
func equip_all_robot_parts() -> void:
	for part in EQUIP_ORDER:
		for slot in part_slots(part):
			var side := slot.trim_prefix(part + "_") if is_paired_part(part) else ""
			if LIMB_SEGMENTS.has(part):
				drop_limb_segments(part, side)
			equip_part(part, side)


## Takes everything off her into the inventory, except the slots in `keep` (and her head,
## which never comes off).
func unequip_all_robot_parts(keep: Array = []) -> void:
	for slot in equipped_parts.keys():
		if keep.has(slot) or slot == "head":
			continue
		var id := String(equipped_parts[slot])
		equipped_parts.erase(slot)
		robot_parts[id] = get_robot_part_count(id) + 1
	_robot_parts_updated()


func has_robot_part(id: String, amount: int = 1) -> bool:
	return get_robot_part_count(id) >= amount


## "Torso" is not an item of its own — it is shorthand for the mid-body as a
## whole, i.e. having both the chest and the stomach. Kept so any logic that used
## to treat the old single "torso" part as one thing still has a concept to ask
## for; most callers should check "chest" or "stomach" specifically instead.
func has_torso() -> bool:
	return get_owned_part_count("chest") >= 1 and get_owned_part_count("stomach") >= 1


## Sets the inventory count of every robot part (what she's wearing is left as it is).
func set_all_robot_parts(amount: int) -> void:
	var had_chest := get_owned_part_count("chest") >= 1
	for id in ROBOT_PART_IDS:
		robot_parts[id] = max(0, amount)
	if not had_chest and get_owned_part_count("chest") >= 1:
		_grant_torso_cosmetics()
	_robot_parts_updated()


## After any change to the inventory parts or what she's wearing.
func _robot_parts_updated() -> void:
	_keep_head_on()
	_sync_legacy_limb_count()
	robot_parts_changed.emit(robot_parts.duplicate())


## Her head is always on: whenever the player has one and her head slot is empty, one goes
## on from the inventory (used up, like any part put on). It never comes off again.
func _keep_head_on() -> void:
	if not equipped_parts.has("head") and get_robot_part_count("head") > 0:
		robot_parts["head"] = get_robot_part_count("head") - 1
		equipped_parts["head"] = "head"
		unprepare_limb("head")


func _sync_legacy_limb_count() -> void:
	equipped_limbs = get_attached_part_count("leg")


## The big coconuts and big chest cover come with the torso: they are granted
## together the first time a chest is acquired (crafted), rather than being owned
## from the start. Only fills empties, so it never fights a debug removal made
## while a chest is already owned.
func _grant_torso_cosmetics() -> void:
	if get_owned_part_count("chest") < 1:
		return
	var changed := false
	for id in ["big_coconuts", "big_chest_cover"]:
		if int(cosmetic_items.get(id, 0)) < 1:
			cosmetic_items[id] = 1
			changed = true
	if changed:
		cosmetic_items_changed.emit(cosmetic_items.duplicate())


# --- cosmetic chest items ---

func is_cosmetic_item_id(id: String) -> bool:
	return id in COSMETIC_ITEM_IDS


func get_cosmetic_item_count(id: String) -> int:
	if not is_cosmetic_item_id(id):
		return 0
	return int(cosmetic_items.get(id, 0))


func has_cosmetic_item(id: String) -> bool:
	return get_cosmetic_item_count(id) >= 1


# --- laptop: prepared limbs ---

## Takes the `id` part off the robot (off `side`, for a paired part) and puts it in the
## inventory as that part - the laptop does this when a fresh one is unlocked to take its
## place. Whatever hangs from it comes off too, each as its own part: the legs hang from the
## stomach's pelvis, so they come off with it; a hand comes off with its arm; the stomach and
## both arms come off with the chest. A part-built limb's
## pieces go back in the inventory. Her head never comes off (see _keep_head_on). Returns
## what came off, {part id: count} (empty if none did).
func detach_robot_part(id: String, side: String = "") -> Dictionary:
	var removed := {}
	if id == "head" or not is_part_attached_on(id, side):
		return removed
	_take_off(limb_key(id, side))
	removed[id] = 1
	match id:
		"stomach":
			for leg_side in PART_SIDES:
				if is_part_attached_on("leg", leg_side):
					_take_off(limb_key("leg", leg_side))
					_add_part_counts(removed, {"leg": 1})
			_return_part_built_legs()
		"arm":
			if is_part_attached_on("hand", side):
				_take_off(limb_key("hand", side))
				removed["hand"] = 1
		"chest":
			_add_part_counts(removed, detach_robot_part("stomach"))
			for arm_side in PART_SIDES:
				_add_part_counts(removed, detach_robot_part("arm", arm_side))
				drop_limb_segments("arm", arm_side)
				if is_part_attached_on("hand", arm_side):
					_take_off(limb_key("hand", arm_side))
					_add_part_counts(removed, {"hand": 1})
	_robot_parts_updated()
	return removed


## Adds `more`'s {part id: count} into `into`.
func _add_part_counts(into: Dictionary, more: Dictionary) -> void:
	for part_id in more:
		into[part_id] = int(into.get(part_id, 0)) + int(more[part_id])


## Empties one equipped slot into the inventory.
func _take_off(slot: String) -> void:
	var id := String(equipped_parts.get(slot, ""))
	equipped_parts.erase(slot)
	if id != "":
		robot_parts[id] = get_robot_part_count(id) + 1


## The prepared_limbs id for a limb: a paired part's carries its side ("arm_left"), anything
## else is just the part id ("chest"). Also the limb's slot in equipped_parts.
func limb_key(id: String, side: String = "") -> String:
	return "%s_%s" % [id, side] if is_paired_part(id) and side != "" else id


## Mark a limb as prepared (unlocked for assembly) via the laptop build app. Safe
## to call repeatedly; only the first call for a given limb emits the change.
func prepare_limb(limb_id: String) -> void:
	if limb_id == "" or prepared_limbs.has(limb_id):
		return
	# The whole limb unlocked covers its segments too.
	_clear_segment_unlocks(limb_id)
	prepared_limbs.append(limb_id)
	prepared_limbs_changed.emit(prepared_limbs.duplicate())


func is_limb_prepared(limb_id: String) -> bool:
	return prepared_limbs.has(limb_id)


## Undoes prepare_limb (the laptop locking a limb again).
func unprepare_limb(limb_id: String) -> void:
	if not prepared_limbs.has(limb_id):
		return
	prepared_limbs.erase(limb_id)
	prepared_limbs_changed.emit(prepared_limbs.duplicate())


## Locks a limb the laptop unlocked: it's no longer prepared, and if its slot is free one
## from the inventory goes on (see equip_part - the stomach bringing back its legs). A paired
## part is locked per `side`. Returns what went on, {part id: count}.
func lock_limb(id: String, side: String = "") -> Dictionary:
	unprepare_limb(limb_key(id, side))
	return equip_part(id, side)


## Whether unlocking `side`'s `id` limb (or only its `segment` and those below it) would bring
## more off her than one end piece - something still hangs from it: an arm's forearm (and its
## hand) from its upper arm, a leg's shin and foot from its thigh, the legs from the stomach,
## the stomach and arms from the chest. Her head never comes off, so it doesn't count.
func limb_has_attachments(id: String, side: String = "", segment: String = "") -> bool:
	if not has_detachable(id, side, segment):
		return false
	match id:
		"arm", "leg":
			var from := 0 if segment == "" else (LIMB_SEGMENTS[id] as Array).find(segment)
			return _segments_on(id, side) - from > 1 or (id == "arm" and is_part_attached_on("hand", side))
		"stomach":
			return _limb_on_either_side("leg")
		"chest":
			return get_attached_part_count("stomach") > 0 or _limb_on_either_side("arm")
	return false


## Whether anything of `side`'s `id` limb (or of only its `segment` and those below it) is on
## her for the laptop to detach. Her head never comes off.
func has_detachable(id: String, side: String = "", segment: String = "") -> bool:
	if id == "head":
		return false
	if not LIMB_SEGMENTS.has(id):
		return segment == "" and is_part_attached_on(id, side)
	var from := 0 if segment == "" else (LIMB_SEGMENTS[id] as Array).find(segment)
	return from >= 0 and from < _segments_on(id, side)


## How many of `side`'s `id` limb's segments are on her: all of them for a whole limb.
func _segments_on(id: String, side: String) -> int:
	if is_part_attached_on(id, side):
		return (LIMB_SEGMENTS[id] as Array).size()
	return get_limb_segments(id, side).size()


## Whether any of limb `id` is on her on either side, whole or part-built.
func _limb_on_either_side(id: String) -> bool:
	for side in PART_SIDES:
		if is_part_attached_on(id, side) or not get_limb_segments(id, side).is_empty():
			return true
	return false


# --- limbs built on the robot piece by piece (maintenance) ---

## The segments a limb is built from on the robot, in the order they go on: a leg from the
## hip down, an arm from the shoulder down. Each is a workshop-crafted ingredient.
const LIMB_SEGMENTS: Dictionary = {"leg": ["thigh", "shin", "foot"], "arm": ["upper_arm", "forearm"]}
## Limbs part-built on the robot in maintenance: limb key ("leg_left") -> the segments on so
## far, in order. Once the last one goes on, the limb is whole (worn in its slot) and leaves here.
var limb_segments: Dictionary = {}


## The segments on `side`'s `id` limb so far (part-built), in order.
func get_limb_segments(id: String, side: String) -> Array[String]:
	var out: Array[String] = []
	for segment in limb_segments.get(limb_key(id, side), []):
		out.append(String(segment))
	return out


## The limb `segment` belongs to ("leg" / "arm"), or "" if it isn't a limb segment.
func limb_for_segment(segment: String) -> String:
	for id in LIMB_SEGMENTS:
		if segment in LIMB_SEGMENTS[id]:
			return String(id)
	return ""


## The segment that goes on `side`'s `id` limb next, or "" when none can: a whole limb is in
## that slot already, or what it hangs from isn't on her (see has_anchor).
func next_limb_segment(id: String, side: String) -> String:
	if not LIMB_SEGMENTS.has(id) or not part_slots(id).has(limb_key(id, side)) \
			or is_part_attached_on(id, side):
		return ""
	if not has_anchor(id, side):
		return ""
	var done := get_limb_segments(id, side)
	var all: Array = LIMB_SEGMENTS[id]
	return String(all[done.size()]) if done.size() < all.size() else ""


## Puts `segment` on `side`'s `id` limb, using one up from the ingredients. The last one makes
## the limb whole: it's worn in that slot (and the slot locked again). Returns whether it went on.
func add_limb_segment(id: String, side: String, segment: String) -> bool:
	if next_limb_segment(id, side) != segment or int(ingredients.get(segment, 0)) < 1:
		return false
	add_ingredient(segment, -1)
	var key := limb_key(id, side)
	unlocked_segments.erase(segment_key(id, side, segment))
	var done := get_limb_segments(id, side)
	done.append(segment)
	if done.size() < (LIMB_SEGMENTS[id] as Array).size():
		limb_segments[key] = done
	else:
		limb_segments.erase(key)
		equipped_parts[key] = id
		unprepare_limb(key)
		_clear_segment_unlocks(key)
	_robot_parts_updated()
	return true


# --- limb segments unlocked on the laptop ---

## Limb segments the laptop has unlocked on her, as segment_key()s ("arm_left:forearm").
## Unlocking one takes it and every segment below it off; it locks again once that segment
## goes back on (or the whole limb does).
var unlocked_segments: Array[String] = []


func segment_key(id: String, side: String, segment: String) -> String:
	return "%s:%s" % [limb_key(id, side), segment]


func is_segment_unlocked(id: String, side: String, segment: String) -> bool:
	return unlocked_segments.has(segment_key(id, side, segment))


## Unlocks `segment` of `side`'s `id` limb: it and every segment after it come off her into
## the inventory as those segments - an arm's hand with them, as it hangs off the forearm -
## and the ones above it stay on. A whole limb becomes part-built (its pieces are what's left
## of it). Returns {"segments": the segments that came off, in order, "hand": 1 if the hand
## did} - empty when nothing was on to come off.
func unlock_limb_segment(id: String, side: String, segment: String) -> Dictionary:
	var all: Array = LIMB_SEGMENTS.get(id, [])
	var at := all.find(segment)
	if at < 0:
		return {}
	var key := limb_key(id, side)
	if not unlocked_segments.has(segment_key(id, side, segment)):
		unlocked_segments.append(segment_key(id, side, segment))
	var whole := is_part_attached_on(id, side)
	var on: Array[String] = []
	if whole:
		for s in all:
			on.append(String(s))
	else:
		on = get_limb_segments(id, side)
	if on.size() <= at:
		return {}
	var dropped: Array[String] = on.slice(at)
	var kept: Array[String] = on.slice(0, at)
	for s in dropped:
		add_ingredient(s, 1)
	if whole:
		equipped_parts.erase(key)
	if kept.is_empty():
		limb_segments.erase(key)
	else:
		limb_segments[key] = kept
	var removed := {"segments": dropped}
	if id == "arm" and is_part_attached_on("hand", side):
		_take_off(limb_key("hand", side))
		removed["hand"] = 1
	_robot_parts_updated()
	return removed


## Locks a segment the laptop unlocked; if it's the next one her limb takes and one is in the
## inventory, it goes back on (see add_limb_segment). Returns whether it went on.
func lock_limb_segment(id: String, side: String, segment: String) -> bool:
	unlocked_segments.erase(segment_key(id, side, segment))
	if next_limb_segment(id, side) == segment and int(ingredients.get(segment, 0)) > 0:
		return add_limb_segment(id, side, segment)
	return false


## Locks every unlocked segment of the limb in slot `key` ("arm_left").
func _clear_segment_unlocks(key: String) -> void:
	for seg_key in unlocked_segments.duplicate():
		if seg_key.begins_with(key + ":"):
			unlocked_segments.erase(seg_key)


## Unlocking `side`'s `id` limb takes a part-built one off: its segments fall off and go back
## in the inventory. Returns them, in the order they went on (empty if none were on).
func drop_limb_segments(id: String, side: String) -> Array[String]:
	var dropped := get_limb_segments(id, side)
	if dropped.is_empty():
		return dropped
	for segment in dropped:
		add_ingredient(segment, 1)
	limb_segments.erase(limb_key(id, side))
	robot_parts_changed.emit(robot_parts.duplicate())
	return dropped


## Part-built legs come off with the stomach they hang from: their segments go back in the
## inventory.
func _return_part_built_legs() -> void:
	for side in PART_SIDES:
		var key := limb_key("leg", side)
		for segment in get_limb_segments("leg", side):
			add_ingredient(segment, 1)
		limb_segments.erase(key)


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

func set_flashlight_on(on: bool) -> void:
	if flashlight_on == on:
		return
	flashlight_on = on
	flashlight_on_changed.emit(on)


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


## Spends one `tool_id` (a single-use tool used up - e.g. the taser fired at the robot):
## one fewer in the ledger, and no longer owned once none are left.
func use_up_tool(tool_id: String) -> void:
	tool_id = _normalized_tool_id(tool_id)
	var left := get_tool_count(tool_id) - 1
	if left > 0:
		tool_counts[tool_id] = left
	else:
		tool_counts.erase(tool_id)
		owned_tools.erase(tool_id)


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


## A random name from DEFAULT_PLAYER_NAMES, used as the suggested default in the
## name prompt. Falls back to DEFAULT_PLAYER_NAME if the list is somehow empty.
func random_default_player_name() -> String:
	if DEFAULT_PLAYER_NAMES.is_empty():
		return DEFAULT_PLAYER_NAME
	return DEFAULT_PLAYER_NAMES.pick_random()


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


# --- stress-test history ---

## Appends one night's result to the history log (oldest first), trimming to the cap.
## Called by StressTest when a real night concludes.
func record_stress_test_result(entry: Dictionary) -> void:
	var record := {
		"day": int(entry.get("day", _day)),
		"success": bool(entry.get("success", false)),
		"reason": String(entry.get("reason", "")),
		"electricity": int(round(float(entry.get("electricity", 0.0)))),
		"screws": int(round(float(entry.get("screws", 0.0)))),
	}
	stress_test_history.append(record)
	while stress_test_history.size() > STRESS_TEST_HISTORY_MAX:
		stress_test_history.remove_at(0)


# --- save / load (JSON snapshot on disk) ---

## Writes the full to_dict() snapshot to SAVE_PATH as JSON. Returns true on success.
func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save_game: could not open %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return true


## True if a save file exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Loads and applies the saved snapshot. Returns true on success.
func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("load_game: save file is not valid JSON")
		return false
	from_dict(parsed)
	return true


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
		"fatigue": _fatigue,
		"yesterday_stats": yesterday_stats.duplicate(),
		"today_start_stats": today_start_stats.duplicate(),
		"equipped_limbs": equipped_limbs,
		"robot_parts": robot_parts.duplicate(),
		"equipped_parts": equipped_parts.duplicate(),
		"limb_segments": limb_segments.duplicate(true),
		"limb_builds": limb_builds.duplicate(true),
		"cosmetic_items": cosmetic_items.duplicate(),
		"robot_hair_style": robot_hair_style,
		"ingredients": ingredients.duplicate(),
		"skills": skills.duplicate(),
		"owned_tools": owned_tools.duplicate(),
		"tool_counts": tool_counts.duplicate(),
		"purchased_today": purchased_today.duplicate(),
		"prepared_limbs": prepared_limbs.duplicate(),
		"unlocked_segments": unlocked_segments.duplicate(),
		"arm_lock_open": arm_lock_open,
		"torso_socket_lock_open": torso_socket_lock_open,
		"arm_connected": arm_connected,
		"stress_test_history": stress_test_history.duplicate(true),
		"player_name": player_name,
		"intro_active": intro_active,
		"intro_completed": intro_completed,
		"intro_step": intro_step,
		"uncle_hangout_seen": uncle_hangout_seen,
		"drone_encounter_seen": drone_encounter_seen,
		"robot_class_disruption_seen": robot_class_disruption_seen,
		"robot_work_disruption_seen": robot_work_disruption_seen,
		"robot_work_disruption_day": robot_work_disruption_day,
		"robot_park_call_seen": robot_park_call_seen,
		"maintenance_unlocked": maintenance_unlocked,
		"maintenance_intro_seen": maintenance_intro_seen,
		"drone_ever_caught": drone_ever_caught,
		"drone_caught_last_inspection": drone_caught_last_inspection,
		"debug_mode_enabled": _debug_mode_enabled,
		"window_mode": _window_mode,
		"volume_value": _volume_value,
		"music_volume_value": _music_volume_value,
		"easy_workshop_enabled": _easy_workshop_enabled,
		"camera_roll_enabled": camera_roll_enabled,
		"camera_mouse_follow_enabled": camera_mouse_follow_enabled,
	}


## Saves from before equipped_parts counted every owned part (on her or not) in robot_parts,
## less `detached` {part: count} taken off (paired ones off the `detached_sides` {part: sides},
## the right side first otherwise). She wore as many as she has slots for, a pair's first on
## the left. Those go in her slots; the rest stay in the inventory.
func _convert_legacy_parts(detached: Dictionary, detached_sides: Dictionary) -> void:
	for id in ROBOT_PART_IDS:
		var owned := get_robot_part_count(id)
		var worn := mini(owned, int(ROBOT_PART_SLOTS.get(id, 1)))
		var off := clampi(int(detached.get(id, 0)), 0, worn)
		var on_slots: Array[String] = []
		if is_paired_part(id):
			var worn_sides: Array[String] = PART_SIDES.slice(0, worn)
			var off_sides: Array[String] = []
			for side in detached_sides.get(id, []):
				if off_sides.size() < off and worn_sides.has(String(side)) and not off_sides.has(String(side)):
					off_sides.append(String(side))
			for i in range(worn_sides.size() - 1, -1, -1):
				if off_sides.size() < off and not off_sides.has(worn_sides[i]):
					off_sides.append(worn_sides[i])
			for side in worn_sides:
				if not off_sides.has(side):
					on_slots.append(limb_key(id, side))
		elif worn - off > 0:
			on_slots.append(id)
		for slot in on_slots:
			equipped_parts[slot] = id
		robot_parts[id] = owned - on_slots.size()


func from_dict(data: Dictionary) -> void:
	_day = data.get("day", 1)
	_phase = data.get("phase", 0)  # 0 = MORNING
	_money = data.get("money", 0)
	# Newer saves store the split; older saves only had a single "suspicion"
	# total, which is treated as entirely temporary (no permanent floor).
	_suspicion_permanent = clampi(int(data.get("suspicion_permanent", 0)), 0, MAX_SUSPICION)
	_suspicion_temp = maxi(0, int(data.get("suspicion_temp", data.get("suspicion", 0))))
	_anger = data.get("anger", 0)
	_fatigue = clampi(int(data.get("fatigue", 0)), 0, MAX_FATIGUE)
	# Saves from before these were kept: yesterday reads 0, today starts from the loaded stats.
	yesterday_stats = _zero_stats()
	yesterday_stats.merge(data.get("yesterday_stats", {}), true)
	today_start_stats = {"suspicion": int(data.get("suspicion", 0)), "anger": _anger, "fatigue": _fatigue}
	today_start_stats.merge(data.get("today_start_stats", {}), true)
	equipped_limbs = data.get("equipped_limbs", 0)
	var loaded_parts: Dictionary = data.get("robot_parts", {}).duplicate()
	for id in ROBOT_PART_IDS:
		robot_parts[id] = max(0, int(loaded_parts.get(id, 0)))
	limb_builds.clear()
	var loaded_builds: Dictionary = data.get("limb_builds", {})
	for id in loaded_builds:
		var builds: Array = []
		for build in loaded_builds[id]:
			var components: Array[String] = []
			components.assign((build as Array).map(func(c): return String(c)))
			builds.append(components)
		limb_builds[String(id)] = builds
	# Older saves kept one list of internals for "the" stomach: it becomes that stomach's
	# build, alongside the shell and plating every stomach has.
	var legacy_internals: Array = data.get("stomach_internals", [])
	if not legacy_internals.is_empty() and not limb_builds.has("stomach"):
		var components: Array[String] = ["pelvis", "outer_plating"]
		components.assign(components + legacy_internals.map(func(c): return String(c)))
		limb_builds["stomach"] = [components]
	# Legacy saves stored a single "torso" part; it is now split into chest and
	# stomach, so seed both from the old value when they weren't saved separately.
	var legacy_torso: int = int(loaded_parts.get("torso", 0))
	if legacy_torso > 0:
		if int(robot_parts.get("chest", 0)) == 0:
			robot_parts["chest"] = legacy_torso
		if int(robot_parts.get("stomach", 0)) == 0:
			robot_parts["stomach"] = legacy_torso
	equipped_parts.clear()
	if data.has("equipped_parts"):
		var loaded_equipped: Dictionary = data.get("equipped_parts", {})
		for id in ROBOT_PART_IDS:
			for slot in part_slots(id):
				if String(loaded_equipped.get(slot, "")) == id:
					equipped_parts[slot] = id
	else:
		if get_robot_part_count("leg") == 0 and equipped_limbs > 0:
			robot_parts["leg"] = equipped_limbs
		_convert_legacy_parts(data.get("detached_parts", {}), data.get("detached_sides", {}))
	_keep_head_on()
	_sync_legacy_limb_count()
	limb_segments.clear()
	var loaded_segments: Dictionary = data.get("limb_segments", {})
	for key in loaded_segments:
		if loaded_segments[key] is Array and not (loaded_segments[key] as Array).is_empty():
			var segments: Array[String] = []
			for segment in loaded_segments[key]:
				segments.append(String(segment))
			limb_segments[String(key)] = segments
	# Cosmetic chest items: seed from defaults, then apply saved values so older
	# saves (which lack the key) keep the default look.
	var loaded_cosmetics: Dictionary = data.get("cosmetic_items", {})
	cosmetic_items = COSMETIC_ITEM_DEFAULTS.duplicate()
	for id in COSMETIC_ITEM_IDS:
		if loaded_cosmetics.has(id):
			cosmetic_items[id] = max(0, int(loaded_cosmetics[id]))
	robot_hair_style = int(data.get("robot_hair_style", 1))
	ingredients = data.get("ingredients", {}).duplicate()
	for id in ["scrap_metal", "synth_skin", "nuts_bolts", "electronics", "nanobots", "head_segments", "oil", "battery", "shoulder_pad"]:
		ingredients[id] = max(0, int(ingredients.get(id, 0)))
		if INGREDIENT_MAX.has(id):
			ingredients[id] = min(int(ingredients[id]), int(INGREDIENT_MAX[id]))
	var had_legacy_sneaky_shoes: bool = int(ingredients.get("sneaky_shoes", 0)) > 0
	ingredients.erase("sneaky_shoes")
	skills.assign(data.get("skills", []))
	owned_tools.assign(data.get("owned_tools", ["mouth", "hand"]))
	_normalize_owned_tools()
	tool_counts = _normalized_tool_counts(data.get("tool_counts", {}))
	if had_legacy_sneaky_shoes:
		unlock_tool("sneaky_shoes")
	purchased_today.assign(data.get("purchased_today", []))
	prepared_limbs.clear()
	for limb in data.get("prepared_limbs", []):
		# Older saves kept a paired limb without its side; back then unlocking one always
		# took the right one off, so that's the side it was.
		var key := limb_key(String(limb), "right") if is_paired_part(String(limb)) else String(limb)
		if not prepared_limbs.has(key):
			prepared_limbs.append(key)
	unlocked_segments.clear()
	for seg_key in data.get("unlocked_segments", []):
		if not unlocked_segments.has(String(seg_key)):
			unlocked_segments.append(String(seg_key))
	arm_lock_open = bool(data.get("arm_lock_open", false))
	torso_socket_lock_open = bool(data.get("torso_socket_lock_open", false))
	arm_connected = bool(data.get("arm_connected", false))
	stress_test_history = (data.get("stress_test_history", []) as Array).duplicate(true)
	set_player_name(String(data.get("player_name", DEFAULT_PLAYER_NAME)))
	intro_completed = bool(data.get("intro_completed", false))
	intro_active = bool(data.get("intro_active", not intro_completed))
	intro_step = String(data.get("intro_step", "" if intro_completed else "exposition"))
	uncle_hangout_seen = bool(data.get("uncle_hangout_seen", false))
	drone_encounter_seen = bool(data.get("drone_encounter_seen", false))
	robot_class_disruption_seen = bool(data.get("robot_class_disruption_seen", false))
	robot_work_disruption_seen = bool(data.get("robot_work_disruption_seen", false))
	robot_work_disruption_day = int(data.get("robot_work_disruption_day", 0))
	robot_park_call_seen = bool(data.get("robot_park_call_seen", false))
	# Saves from before this flag existed: the chest came home with the
	# work-disruption shift, so having seen it means the chest was collected.
	maintenance_unlocked = bool(data.get("maintenance_unlocked", robot_work_disruption_seen))
	maintenance_intro_seen = bool(data.get("maintenance_intro_seen", false))
	drone_ever_caught = bool(data.get("drone_ever_caught", false))
	drone_caught_last_inspection = bool(data.get("drone_caught_last_inspection", false))
	_debug_mode_enabled = bool(data.get("debug_mode_enabled", false))
	_window_mode = clampi(int(data.get("window_mode", WindowMode.WINDOWED)), WindowMode.WINDOWED, WindowMode.FULLSCREEN)
	_volume_value = clampf(float(data.get("volume_value", DEFAULT_VOLUME_VALUE)), 0.0, 100.0)
	_apply_volume()
	_music_volume_value = clampf(float(data.get("music_volume_value", DEFAULT_MUSIC_VOLUME_VALUE)), 0.0, 100.0)
	music_volume_changed.emit(_music_volume_value)
	_easy_workshop_enabled = bool(data.get("easy_workshop_enabled", false))
	camera_roll_enabled = bool(data.get("camera_roll_enabled", true))
	camera_mouse_follow_enabled = bool(data.get("camera_mouse_follow_enabled", true))
	_emit_initial_state()
