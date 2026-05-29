extends LocationBase

@onready var blanket: TextureRect = %Blanket
@onready var blanket_bump: TextureRect = %BlanketBump
@onready var bot_placeholder: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/SceneCanvas/Bed/BotPlaceholder
@onready var bot_shadow_light: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/SceneCanvas/Bed/BotShadowLight
@onready var bot_shadow_heavy: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/SceneCanvas/Bed/BotShadowHeavy
@onready var mattress_texture: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/SceneCanvas/Bed/MattressTexture
@onready var mattress_texture_indent: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/SceneCanvas/Bed/MattressTextureIndent
@onready var pillow: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/SceneCanvas/Bed/Pillow
@onready var pillow_indented: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/SceneCanvas/Bed/PillowIndented

var _blanket_removed := false


func _ready() -> void:
	if GameState.equipped_limbs <= 0:
		return

	bot_placeholder.visible = true
	bot_shadow_light.visible = true
	bot_shadow_heavy.visible = true
	mattress_texture_indent.visible = true
	pillow_indented.visible = true
	blanket_bump.visible = true

	mattress_texture.visible = false
	pillow.visible = false
	blanket.visible = false


func _on_bed_click_area_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	get_viewport().set_input_as_handled()
	if not _blanket_removed:
		_blanket_removed = true
		blanket.visible = false
		blanket_bump.visible = false
		return

	finish()
