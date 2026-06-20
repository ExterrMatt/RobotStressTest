extends LocationBase

const BLUE_SHIRT_UNCLE_TEXTURE_PATH := "res://assets/textures/characters/uncle/blue_shirt_uncle1.png"

@onready var dialogue_box: DialogueBox = %DialogueBox


func _ready() -> void:
	Dialogue.load_file("intro", "res://data/dialogue/intro.dlg")
	dialogue_box.finished.connect(_on_dialogue_finished)
	var key := GameState.intro_step
	if key.is_empty():
		key = "exposition"
	_apply_intro_portrait(key)
	dialogue_box.play_pages(Dialogue.get_pages("intro", key))


func _on_dialogue_finished() -> void:
	finish(0, 0, 0, {}, false)


func _apply_intro_portrait(key: String) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	if key == "exposition":
		var tex := load(BLUE_SHIRT_UNCLE_TEXTURE_PATH) as Texture2D
		if tex != null and main.has_method("show_teacher_portrait"):
			main.show_teacher_portrait(tex, "Uncle", "")
		return
	if main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()
