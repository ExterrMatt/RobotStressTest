extends LocationBase
## Stub for the stress-test minigame.
##
## Real version will be the rich timed minigame from the design doc. For now,
## this asks the player which outcome they want to simulate, applies the
## design-doc-spec'd consequences, and reports to DayCycle so day-rollover
## carryover/fail-penalty logic can be exercised.

@onready var info_label: Label = %InfoLabel


func _ready() -> void:
	_refresh_info()


func _refresh_info() -> void:
	info_label.text = "Equipped limbs: %d    |    Current anger: %d    |    Tonight's wakes so far: %d" % [
		GameState.equipped_limbs,
		GameState.anger,
		DayCycle.nightly_wakes,
	]


func _on_good_pressed() -> void:
	# Good stress-test - reduces tomorrow's anger meaningfully.
	# (Real version computes this from time-in-optimal-electricity, tool
	# quality, and stress curve.)
	DayCycle.register_stress_test_completed()
	finish(0, 0, -20, {}, false)


func _on_bad_pressed() -> void:
	# Bad stress-test - barely helps; multiple neglected tasks.
	DayCycle.register_stress_test_completed()
	finish(0, 0, -5, {}, false)


func _on_recorded_pressed() -> void:
	# Recording: extra money, more suspicion, harder night (more anger gain).
	DayCycle.register_stress_test_completed()
	finish(40, 6, -10, {}, false)


func _on_wake_pressed() -> void:
	# Robot woke up. Register with DayCycle for fail-penalty at day-end.
	# Player stays on the night phase to retry (skip_advance).
	DayCycle.register_stress_test_wake()
	_refresh_info()
	# No phase advance, no anger reduction from this attempt.
	# We don't call finish() because the player should be able to retry.
	# Instead just refresh and let them pick again.


func _on_give_up_pressed() -> void:
	# Player decides to stop trying tonight without a successful test.
	finish(0, 0, 0, {}, false)
