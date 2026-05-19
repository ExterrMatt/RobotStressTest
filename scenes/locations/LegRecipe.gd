extends Resource
class_name LegRecipe
## The cost in ingredients to produce one leg's worth of segment pieces.
##
## The Workshop minigame reads this when the player presses CRAFT. The
## bin must contain AT LEAST `inputs[id]` of every key in `inputs` —
## extras are allowed but only the listed amounts are consumed.
##
## Inputs match GameState.ingredients keys exactly:
##   "scrap_metal", "nuts_bolts", "nanobots", "electronics", "synth_skin",
##   "oil", "sneaky_shoes"

@export var inputs: Dictionary = {
	"nanobots": 1,
	"scrap_metal": 1,
	"nuts_bolts": 1,
}
