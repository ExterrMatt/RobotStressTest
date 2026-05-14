extends Control
class_name LocationBase
## Base class for all location scenes.
##
## Each location scene extends this and calls finish(result) when the
## player completes the activity. Main listens for the finished signal
## and advances the day-cycle phase.
##
## Result dict convention (all keys optional):
##   money_delta: int       - added to GameState.money
##   suspicion_delta: int   - added to GameState.suspicion
##   anger_delta: int       - added to GameState.anger
##   ingredients: Dictionary[String, int]  - added to GameState.ingredients
##   skip_advance: bool     - if true, don't advance the phase (free action)
##
## Locations should NOT mutate GameState directly. They report a result and
## Main applies it. This keeps the audit trail centralized and makes it easy
## to add modifiers (e.g. suspicion-reduces-money) in one place later.

signal finished(result: Dictionary)


## Convenience: build a result dict and emit. Subclasses call this when done.
func finish(
	money_delta: int = 0,
	suspicion_delta: int = 0,
	anger_delta: int = 0,
	ingredients: Dictionary = {},
	skip_advance: bool = false,
) -> void:
	finished.emit({
		"money_delta": money_delta,
		"suspicion_delta": suspicion_delta,
		"anger_delta": anger_delta,
		"ingredients": ingredients,
		"skip_advance": skip_advance,
	})
