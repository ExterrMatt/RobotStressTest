extends Node
## Day-cycle state machine.
##
## Each in-game day is broken into three phases. The player chooses one
## activity per phase, then advances. After Night, the day rolls over:
## anger carryover is applied, ephemeral nightly state resets.
##
## This script does NOT know about specific locations. It just tracks which
## phase we're in and exposes advance_phase() / end_day(). Location scenes
## ask DayCycle whether they're available in the current phase.

signal advanced_to_phase(phase: int)
signal day_ended(new_day: int)

enum Phase {
	MORNING,
	EVENING,
	NIGHT,
}

## Carryover formula from design doc: if previous day's anger > 25,
## apply (prev_anger / 25) as a penalty to the next day's starting anger.
const CARRYOVER_THRESHOLD: int = 25
const CARRYOVER_DIVISOR: int = 25

## Penalty applied to next-day starting anger if the player failed
## stress-tests (waking the robot). Compounds per failure, capped.
const FAIL_PENALTY_PER_WAKE: int = 10
const FAIL_PENALTY_CAP: int = 50

## Nightly state - resets every day. Tracked here rather than on GameState
## because it's conceptually about the current night's stress-test result,
## not about persistent character state.
var nightly_wakes: int = 0
var nightly_stress_test_completed: bool = false


func _ready() -> void:
	# Phase is initialized on GameState; we just listen for advancement requests.
	pass


## Returns the human-readable name of a phase enum value.
func phase_name(p: int) -> String:
	match p:
		Phase.MORNING: return "Morning"
		Phase.EVENING: return "Evening"
		Phase.NIGHT:   return "Night"
		_: return "Unknown"


## Advance to the next phase. If we're at Night, this ends the day instead.
func advance_phase() -> void:
	if GameState.phase == Phase.NIGHT:
		end_day()
		return

	# Setter on GameState.phase emits phase_changed automatically.
	GameState.phase = GameState.phase + 1
	advanced_to_phase.emit(GameState.phase)


## End the current day. Applies anger carryover, increments day counter,
## resets nightly state, returns to Morning.
func end_day() -> void:
	_apply_carryover()
	_apply_fail_penalty()

	nightly_wakes = 0
	nightly_stress_test_completed = false
	# Wipe the per-day store-purchase ledger so the player can buy each
	# item again tomorrow.
	GameState.reset_daily_purchases()

	GameState.day += 1
	GameState.phase = Phase.MORNING

	day_ended.emit(GameState.day)


## Apply anger carryover from the design doc:
## "Previous Day's anger / 25 is applied to current day's anger as a penalty
##  if > 25 anger."
##
## Interpretation: the carryover is *added* to the new day's starting anger.
## We do NOT zero anger between days - it carries forward AND takes a hit.
## (If you want anger to fully reset and only the penalty remain, change the
## three lines below to set anger to the penalty directly.)
func _apply_carryover() -> void:
	if GameState.anger > CARRYOVER_THRESHOLD:
		var penalty: int = GameState.anger / CARRYOVER_DIVISOR
		GameState.add_anger(penalty)


## If the player woke the robot during stress-tests tonight, they took
## +10 anger per wake (compounding, capped at 50).
## This is applied when the day ends, on top of whatever anger they accrued.
func _apply_fail_penalty() -> void:
	if nightly_wakes <= 0:
		return
	var penalty: int = min(FAIL_PENALTY_PER_WAKE * nightly_wakes, FAIL_PENALTY_CAP)
	GameState.add_anger(penalty)


## Called by the stress-test scene when the robot wakes up.
## Stress-test scene handles retry UI itself; this just tracks the count.
func register_stress_test_wake() -> void:
	nightly_wakes += 1


func register_stress_test_completed() -> void:
	nightly_stress_test_completed = true
