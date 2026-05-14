extends Control
## Root scene script.
##
## Responsibilities:
## - Display persistent HUD (day, phase, money, suspicion, anger)
## - Show location-selection screen filtered by current phase
## - Instantiate the chosen location scene and listen for its `finished` signal
## - Apply the location's result to GameState
## - Advance the day cycle (unless skip_advance was set)
## - Toggle the debug event-log overlay with Tab.
##
## Locations themselves are dumb - they emit a result dict and Main applies it.

const LOCATION_RESOURCE_PATHS: Array[String] = [
	"res://resources/locations/school.tres",
	"res://resources/locations/work.tres",
	"res://resources/locations/maintenance.tres",
	"res://resources/locations/store.tres",
	"res://resources/locations/workshop.tres",
	"res://resources/locations/stress_test.tres",
	"res://resources/locations/sleep.tres",
	"res://resources/locations/personality_training.tres",
]

## Background shown on the selection screen for each phase.
## Keyed by DayCycle.Phase int values (0=Morning, 1=Evening, 2=Night).
## Missing entries fall back to the default placeholder.
const PHASE_BACKGROUNDS: Dictionary = {
	0: preload("res://assets/textures/backgrounds/bedroom_morning.png"),
	1: preload("res://assets/textures/backgrounds/bedroom_evening.png"),
	2: preload("res://assets/textures/backgrounds/bedroom_night.png"),
}

# HUD labels
@onready var day_label: Label = %DayLabel
@onready var phase_label: Label = %PhaseLabel
@onready var money_label: Label = %MoneyLabel
@onready var suspicion_label: Label = %SuspicionLabel
@onready var anger_label: Label = %AngerLabel
@onready var scene_image: TextureRect = %SceneImage

# Selection screen / location host
@onready var selection_screen: VBoxContainer = %SelectionScreen
@onready var location_grid: GridContainer = %LocationGrid
@onready var location_host: Control = %LocationHost

# Log overlay
@onready var log_overlay: PanelContainer = %LogOverlay
@onready var event_log: RichTextLabel = %EventLog

var _locations: Array[LocationData] = []
var _current_location_node: Node = null
var _default_scene_image: Texture2D


func _ready() -> void:
	# Cache the placeholder texture BEFORE anything else can swap it.
	_default_scene_image = scene_image.texture
	
	_load_locations()

	GameState.money_changed.connect(_on_money_changed)
	GameState.suspicion_changed.connect(_on_suspicion_changed)
	GameState.anger_changed.connect(_on_anger_changed)
	GameState.day_changed.connect(_on_day_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.arrested.connect(_on_arrested)
	DayCycle.day_ended.connect(_on_day_ended)

	_refresh_hud()
	_show_selection_screen()
	_default_scene_image = scene_image.texture


func _unhandled_input(event: InputEvent) -> void:
	# Tab toggles the debug event log overlay.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			log_overlay.visible = not log_overlay.visible
			get_viewport().set_input_as_handled()


func _load_locations() -> void:
	for path in LOCATION_RESOURCE_PATHS:
		var res: LocationData = load(path)
		if res:
			_locations.append(res)
		else:
			push_warning("Failed to load location resource: %s" % path)


# --- HUD ---

func _refresh_hud() -> void:
	day_label.text = str(GameState.day)
	phase_label.text = DayCycle.phase_name(GameState.phase).to_upper()
	money_label.text = "$%d" % GameState.money
	suspicion_label.text = str(GameState.suspicion)
	anger_label.text = str(GameState.anger)


func _on_money_changed(_v: int) -> void:    _refresh_hud()
func _on_suspicion_changed(_v: int) -> void: _refresh_hud()
func _on_anger_changed(_v: int) -> void:     _refresh_hud()
func _on_day_changed(_v: int) -> void:       _refresh_hud()
func _on_phase_changed(_v: int) -> void:
	_refresh_hud()
	_show_selection_screen()


# --- selection screen ---

func _show_selection_screen() -> void:
	# Phase-specific background, or the diagonal placeholder if none.
	scene_image.texture = PHASE_BACKGROUNDS.get(GameState.phase, _default_scene_image)
	# Tear down any existing location.
	if _current_location_node and is_instance_valid(_current_location_node):
		_current_location_node.queue_free()
		_current_location_node = null

	selection_screen.visible = true
	location_host.visible = false

	# Rebuild button list filtered by current phase.
	for child in location_grid.get_children():
		child.queue_free()

	for loc in _locations:
		if not loc.available_in_phase(GameState.phase):
			continue
		var btn := _build_location_button(loc)
		location_grid.add_child(btn)


func _build_location_button(loc: LocationData) -> Button:
	var btn := Button.new()
	btn.text = loc.display_name.to_upper()
	btn.tooltip_text = loc.description
	btn.custom_minimum_size = Vector2(0, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 58)
	if loc.icon:
		btn.icon = loc.icon
		btn.expand_icon = true
	btn.pressed.connect(_on_location_picked.bind(loc))
	return btn


func _on_location_picked(loc: LocationData) -> void:
	var packed: PackedScene = load(loc.scene_path)
	if packed == null:
		_log("ERROR: could not load %s" % loc.scene_path)
		return

	_current_location_node = packed.instantiate()
	if loc.preview_texture:
		scene_image.texture = loc.preview_texture
	location_host.add_child(_current_location_node)

	if _current_location_node.has_signal("finished"):
		_current_location_node.finished.connect(_on_location_finished)
	else:
		push_warning("Location %s did not expose a `finished` signal." % loc.display_name)

	selection_screen.visible = false
	location_host.visible = true
	_log("[b]→ %s[/b]" % loc.display_name)


# --- result handling ---

func _on_location_finished(result: Dictionary) -> void:
	_apply_result(result)

	if result.get("skip_advance", false):
		_show_selection_screen()
	else:
		DayCycle.advance_phase()


func _apply_result(result: Dictionary) -> void:
	var money_delta: int = result.get("money_delta", 0)
	var suspicion_delta: int = result.get("suspicion_delta", 0)
	var anger_delta: int = result.get("anger_delta", 0)
	var ingredients: Dictionary = result.get("ingredients", {})

	if money_delta != 0:    GameState.add_money(money_delta)
	if suspicion_delta != 0: GameState.add_suspicion(suspicion_delta)
	if anger_delta != 0:     GameState.add_anger(anger_delta)

	for ing_id in ingredients:
		var amt: int = ingredients[ing_id]
		GameState.add_ingredient(ing_id, amt)

	_log_result(money_delta, suspicion_delta, anger_delta, ingredients)


func _log_result(money: int, suspicion: int, anger: int, ingredients: Dictionary) -> void:
	var parts: Array[String] = []
	if money != 0:     parts.append("$%+d" % money)
	if suspicion != 0: parts.append("susp %+d" % suspicion)
	if anger != 0:     parts.append("anger %+d" % anger)
	for ing_id in ingredients:
		var amt: int = ingredients[ing_id]
		if amt != 0:
			parts.append("%s %+d" % [ing_id, amt])

	if parts.is_empty():
		_log("   (no effect)")
	else:
		_log("   " + "  ".join(parts))


# --- day rollover ---

func _on_day_ended(new_day: int) -> void:
	_log("[color=#88aaff]── Day %d begins ──[/color]" % new_day)


func _on_arrested() -> void:
	_log("[color=#ff7777][b]ARRESTED.[/b] Suspicion maxed out. (Punishment screen TBD.)[/color]")
	GameState.suspicion = 50
	GameState.add_money(-GameState.money / 2)


# --- event log ---

func _log(text: String) -> void:
	event_log.append_text(text + "\n")
