class_name UncleWardrobe
## Central registry of the uncle's outfits, so every scene that shows him reads
## the art paths from one place. Each outfit has two interchangeable variants;
## call random_texture() to pick one at random.
##
## If the uncle art is renamed again, update the paths here only. (The blue-shirt
## and tank-top art use the "_1/_2" suffix; the older Hawaiian art uses "1/2".)

const BLUE_SHIRT: Array[String] = [
	"res://assets/textures/characters/uncle/blue_shirt_uncle_1.png",
	"res://assets/textures/characters/uncle/blue_shirt_uncle_2.png",
]
const HAWAIIAN: Array[String] = [
	"res://assets/textures/characters/uncle/hawaiian_uncle1.png",
	"res://assets/textures/characters/uncle/hawaiian_uncle2.png",
]
const BLUE_TANKTOP: Array[String] = [
	"res://assets/textures/characters/uncle/blue_tanktop_uncle_1.png",
	"res://assets/textures/characters/uncle/blue_tanktop_uncle_2.png",
]


## Pick a random variant path from one of the outfit arrays above.
static func random_texture(outfit: Array) -> String:
	if outfit.is_empty():
		return ""
	return String(outfit[randi() % outfit.size()])
