extends RefCounted
## The debug menu's "Skip to..." story points: one ordered table of every point in
## the story a skip can land on, and the code that rebuilds GameState / DayCycle
## for a point.
##
## Landing on a point is a fresh game plus the effects of every earlier point,
## applied in order, so the state matches a natural playthrough that just reached
## it: nothing after the target is marked done, nothing before it is left undone.
## Each point has two halves:
##   - arrive: what is already true the moment the point's scene starts (its day,
##     phase and intro step, plus anything the run leading into it carried in,
##     e.g. the shift that ends on the park call).
##   - pass:   what playing the point through leaves behind (rewards, seen flags).
## Skipping to point N runs arrive + pass for every point before N, then arrive
## for N. Main then opens N's scene (see Main._debug_skip_to_story_point).
##
## Story choices along the way take the canonical branch: the intro and the
## class-disruption question are answered correctly, the chest is pocketed but not
## put on her yet, the night is spent asleep, and the drone finds nothing. Stats
## (money, suspicion) only carry the scripted beats' own rewards; free days in
## between are not simulated.
##
## The intro part of the table is built from Main.INTRO_STEPS, so a new intro step
## shows up here automatically (label it in INTRO_LABELS; give it a case in
## _pass_intro_step if finishing it changes state).

const WORK_SCRIPT := preload("res://scenes/locations/Work.gd")
const SCHOOL_SCRIPT := preload("res://scenes/locations/School.gd")

## Menu labels for the intro steps (Main.INTRO_STEPS ids).
const INTRO_LABELS: Dictionary = {
	"exposition": "Exposition (name prompt)",
	"school_first": "First school (history lesson)",
	"evening_room": "Uncle's errand (bedroom)",
	"store": "Ed's store pickup",
	"store_outro": "Home with the uncle (store outro)",
	"bedroom_night": "Bedroom at night",
	"sleep": "First sleep",
	"work": "First shift (finds the head)",
	"pre_workshop": "Before the workshop",
	"workshop": "Workshop: build the head",
	"pre_stress_test": "Shed before the stress test",
	"pre_stress_test_bedroom": "Bedroom before the stress test",
	"stress_test": "First stress test (tutorial)",
	"robot_first_talk": "Robot's first talk (drone reveal)",
	"free_reign": "Free reign speech",
}

## The story after the intro, in the order a canonical playthrough meets it. Each
## entry: id, label, the free day/phase its scene plays in (free day 1 = the day the
## intro ends on; points() shifts these to real day numbers), and `open` - what Main opens
## to land on it. An `alt_of` entry is another branch of the named point: reachable
## as a target (in that point's place), but never applied as an earlier step of a
## later point.
##   Day 1 morning: school, the robot calls in class.
##   Day 2 morning: work, the upper-arm shift ends on her chest-steal call.
##   Day 3 morning: the first Maintenance visit plays the factory break-in.
##   Day 4 morning: a work shift where the player steals scrap; she calls in the park.
##   Day 5 morning: a work shift, then the first patrol-drone stop on the way home.
##   Day 5 evening: the uncle pulls the player in for drinks on the way into night.
const STORY_POINTS: Array[Dictionary] = [
	{"id": "intro_done", "label": "Intro done: free days begin", "day": 1, "phase": 0, "open": "selection"},
	{"id": "class_disruption", "label": "Class disruption call (school)", "day": 1, "phase": 0, "open": "school"},
	{"id": "work_disruption", "label": "Chest-steal call (work)", "day": 2, "phase": 0, "open": "work"},
	{"id": "maintenance_intro", "label": "Maintenance intro (factory break-in)", "day": 3, "phase": 0, "open": "maintenance"},
	{"id": "park_call", "label": "Park call (after stealing scrap)", "day": 4, "phase": 0, "open": "park_call"},
	{"id": "drone_encounter", "label": "First drone stop (clean)", "day": 5, "phase": 0, "open": "drone_encounter"},
	{"id": "drone_encounter_caught", "label": "First drone stop (caught with scrap)", "day": 5, "phase": 0, "open": "drone_encounter", "alt_of": "drone_encounter"},
	{"id": "uncle_hangout", "label": "Uncle hang-out (drinks)", "day": 5, "phase": 1, "open": "uncle_hangout"},
]

## The shift that leads into a park call or drone stop: where it was, and what the
## player pocketed (Main's pending drone / park arguments).
const SHIFT_PLACE: String = "work"
const STOLEN_SCRAP_CONTRABAND: String = "scrap metal"


## Every story point in order: the intro steps first (from `intro_steps`, Main's
## INTRO_STEPS), then STORY_POINTS. Each is a Dictionary with at least id, label,
## day, phase and open ("intro" for intro steps).
static func points(intro_steps: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var day := 1
	var phase := 0
	for step_def in intro_steps:
		var step := String(step_def.get("step", ""))
		var step_phase := int(step_def.get("phase", phase))
		# Same rule as Main._set_phase_for_intro_step: wrapping back to Morning is a new day.
		if step_phase == 0 and phase > 0:
			day += 1
		phase = step_phase
		out.append({
			"id": step,
			"label": String(INTRO_LABELS.get(step, step.capitalize())),
			"day": day,
			"phase": phase,
			"open": "intro",
			"intro_step": step,
		})
	# STORY_POINTS count free days from 1; free days start on the day the intro ends.
	var free_day_offset := day - 1
	for point in STORY_POINTS:
		var shifted := point.duplicate()
		shifted["day"] = int(point.get("day", 1)) + free_day_offset
		out.append(shifted)
	return out


static func index_of(all_points: Array[Dictionary], id: String) -> int:
	for i in all_points.size():
		if String(all_points[i].get("id", "")) == id:
			return i
	return -1


## Rebuilds GameState and DayCycle for landing on `all_points[target]`: a fresh game,
## then arrive + pass for each earlier point on the main line, then arrive for the
## target. The player's name is kept (cleared only when landing on the name prompt
## itself). Returns the landing details Main needs to open the scene: the point
## plus "place" / "contraband" for the park call and drone stop.
static func prepare(all_points: Array[Dictionary], target: int) -> Dictionary:
	var kept_name := GameState.player_name
	GameState.reset_for_new_game()
	DayCycle.reset_for_new_game()
	var target_point: Dictionary = all_points[target]
	if String(target_point.get("id", "")) != "exposition":
		GameState.set_player_name(kept_name if not kept_name.strip_edges().is_empty() else GameState.DEFAULT_PLAYER_NAME)

	# An alt target replaces the main-line point it branches from.
	var replaced := String(target_point.get("alt_of", ""))
	for i in target:
		var point: Dictionary = all_points[i]
		if point.has("alt_of") or String(point.get("id", "")) == replaced:
			continue
		_arrive(point)
		_pass(point)
	return _arrive(target_point)


## The state at the moment `point`'s scene starts. Returns its landing details.
static func _arrive(point: Dictionary) -> Dictionary:
	var landing := point.duplicate()
	var id := String(point.get("id", ""))
	if String(point.get("open", "")) == "intro":
		GameState.intro_completed = false
		GameState.set_intro_step(String(point.get("intro_step", id)))
		GameState.day = int(point.get("day", 1))
		GameState.phase = int(point.get("phase", 0))
		return landing

	_advance_to(int(point.get("day", 1)), int(point.get("phase", 0)))
	match id:
		"intro_done":
			# Main._complete_intro_sequence: day 1 morning, nightly state and the store
			# ledger wiped.
			GameState.complete_intro()
			GameState.phase = DayCycle.Phase.MORNING
			DayCycle.nightly_wakes = 0
			DayCycle.nightly_stress_test_completed = false
			GameState.reset_daily_purchases()
		"class_disruption":
			# The call is a 50/50 on the first class and certain on the next
			# (GameState.roll_story_beat): land as if the first roll missed.
			GameState.class_disruption_attempts = maxi(GameState.class_disruption_attempts, 1)
		"work_disruption":
			# Same for the upper-arm shift that leads into the call.
			GameState.work_disruption_attempts = maxi(GameState.work_disruption_attempts, 1)
		"park_call":
			# The call rings on the walk home from a shift where the player stole scrap:
			# that shift's result is in before the call starts.
			_apply_shift_result(true)
			landing["place"] = SHIFT_PLACE
			landing["contraband"] = STOLEN_SCRAP_CONTRABAND
		"drone_encounter":
			_apply_shift_result(false)
			landing["place"] = SHIFT_PLACE
			landing["contraband"] = ""
		"drone_encounter_caught":
			_apply_shift_result(true)
			landing["place"] = SHIFT_PLACE
			landing["contraband"] = STOLEN_SCRAP_CONTRABAND
	return landing


## What playing `point` through leaves behind.
static func _pass(point: Dictionary) -> void:
	var id := String(point.get("id", ""))
	if String(point.get("open", "")) == "intro":
		_pass_intro_step(String(point.get("intro_step", id)))
		return
	match id:
		"class_disruption":
			# School: the call starts the lesson (rolling the beat), then a correct answer.
			GameState.robot_class_disruption_seen = true
			GameState.class_disruption_attempts += 1
			_apply_reward(SCHOOL_SCRIPT.REWARD_CORRECT)
		"work_disruption":
			# Work: the call starts after the arm shift (rolling the beat); the chest is
			# pocketed, and bringing it home opens Maintenance.
			GameState.work_disruption_attempts += 1
			GameState.robot_work_disruption_seen = true
			GameState.robot_work_disruption_day = GameState.day
			var reward: Dictionary = WORK_SCRIPT.REWARD_COMPLETE.duplicate(true)
			reward["suspicion"] = int(reward.get("suspicion", 0)) + int(WORK_SCRIPT.REWARD_STEAL.get("suspicion", 0))
			var ingredients: Dictionary = reward.get("ingredients", {})
			ingredients["chest"] = int(ingredients.get("chest", 0)) + 1
			reward["ingredients"] = ingredients
			GameState.maintenance_unlocked = true
			_apply_reward(reward)
		"maintenance_intro":
			GameState.maintenance_intro_seen = true
		"park_call":
			GameState.robot_park_call_seen = true
		"drone_encounter":
			GameState.drone_encounter_seen = true
			GameState.drone_caught_last_inspection = false
		"drone_encounter_caught":
			GameState.drone_encounter_seen = true
			GameState.drone_ever_caught = true
			GameState.drone_caught_last_inspection = true
			GameState.add_suspicion(15, 5)
		"uncle_hangout":
			GameState.uncle_hangout_seen = true
			DayCycle.uncle_out_for_the_night = true


## Finishing an intro step. Only the first shift and the workshop change state; the
## other steps are dialogue or a no-reward intro variant of their location.
static func _pass_intro_step(step: String) -> void:
	match step:
		"work":
			# Work._finish_intro_work: the base wage and the head segments from the trash box.
			_apply_reward({"money": int(WORK_SCRIPT.REWARD_COMPLETE.get("money", 0)), "ingredients": {"head_segments": 1}})
		"workshop":
			# The guided build uses up the head recipe and hands over the head, which goes
			# straight on her (GameState._keep_head_on).
			var recipe: Dictionary = WorkshopMinigame.CRAFTABLE_PARTS.get("head", {}).get("recipe", {})
			var ingredients: Dictionary = {"head": 1}
			for id in recipe:
				ingredients[String(id)] = -int(recipe[id])
			_apply_reward({"ingredients": ingredients})


## The result of one regular work shift: the completion pay, plus the scrap steal.
static func _apply_shift_result(stole: bool) -> void:
	var reward: Dictionary = WORK_SCRIPT.REWARD_COMPLETE.duplicate(true)
	if stole:
		reward["money"] = int(reward.get("money", 0)) + int(WORK_SCRIPT.REWARD_STEAL.get("money", 0))
		reward["suspicion"] = int(reward.get("suspicion", 0)) + int(WORK_SCRIPT.REWARD_STEAL.get("suspicion", 0))
		var ingredients: Dictionary = reward.get("ingredients", {})
		var steal_ingredients: Dictionary = WORK_SCRIPT.REWARD_STEAL.get("ingredients", {})
		for id in steal_ingredients:
			ingredients[id] = int(ingredients.get(id, 0)) + int(steal_ingredients[id])
		reward["ingredients"] = ingredients
	_apply_reward(reward)


## Same bookkeeping as Main._apply_result: robot part ids go to the robot parts,
## everything else to the ingredients.
static func _apply_reward(reward: Dictionary) -> void:
	var money := int(reward.get("money", 0))
	var suspicion := int(reward.get("suspicion", 0))
	if money != 0:
		GameState.add_money(money)
	if suspicion != 0:
		GameState.add_suspicion(suspicion)
	var ingredients: Dictionary = reward.get("ingredients", {})
	for id in ingredients:
		var item_id := String(id)
		if GameState.is_robot_part_id(item_id):
			GameState.add_robot_part(item_id, int(ingredients[id]))
		else:
			GameState.add_ingredient(item_id, int(ingredients[id]))


## Walks the clock forward to `day` / `phase` the way the game does, through
## DayCycle.advance_phase (which runs end_day at night). Never goes backwards.
static func _advance_to(day: int, phase: int) -> void:
	var guard := 64
	while guard > 0 and (GameState.day < day or (GameState.day == day and GameState.phase < phase)):
		DayCycle.advance_phase()
		guard -= 1
