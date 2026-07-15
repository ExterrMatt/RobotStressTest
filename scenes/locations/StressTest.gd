extends LocationBase

const ZOOM_LEVEL_OUT: int = 0
const ZOOM_LEVEL_FIRST: int = 1
const ZOOM_LEVEL_SECOND: int = 2
const MAX_ZOOM_LEVEL: int = ZOOM_LEVEL_SECOND
const FIRST_ZOOM_SCALE: Vector2 = Vector2(2.0, 2.0)
const SECOND_ZOOM_SCALE: Vector2 = Vector2(3.0, 3.0)
const ZOOMED_OUT_SCALE: Vector2 = Vector2.ONE
const BASE_SCENE_SIZE: Vector2 = Vector2(800.0, 600.0)
## How much the debug speedrun accelerates the night.
const DEBUG_SPEEDRUN_TIME_SCALE: float = 10.0
const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const ZOOM_DURATION: float = 0.35
const MOUSE_TOOLTIP_SCRIPT: GDScript = preload("res://scenes/ui/MouseFollowTooltip.gd")
const RIP_CORD_FULL_EXTEND_SOUND_PATH := "res://assets/sounds/rip_cord/ripcord.mp3"
const GENERATOR_HUM_SOUND_PATH := "res://assets/sounds/generator/generator_hum.mp3"
const GENERATOR_CHUG_SOUND_PATH := "res://assets/sounds/generator/generator_chug.mp3"
const GENERATOR_SHUTTING_OFF_SOUND_PATH := "res://assets/sounds/generator/generator_shutting_off.mp3"
const GENERATOR_NO_POWER_SOUND_PATH := "res://assets/sounds/generator/generator_no_power.mp3"
const EMERGENCY_POWER_BUTTON_SOUND_PATH := "res://assets/sounds/emergency_button/emergency_power_button.mp3"
const NIGHT_AMBIENT_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/night_sounds/1_min_night_sounds.mp3",
	"res://assets/sounds/night_sounds/loud_crickets.mp3",
	"res://assets/sounds/night_sounds/loud_night_sounds.mp3",
]
const NIGHT_AMBIENT_LOUD_VOLUME_SCALE: float = 0.5
const HEAD_ONLY_DISABLED_ZOOM_REGIONS: Array[StringName] = [
	&"Zoom1_R1_C1",
	&"Zoom1_R3_C1",
	&"Zoom2_R2_C1",
	&"Zoom2_R4_C1",
]
const BODY_DISABLED_ZOOM_REGIONS: Array[StringName] = [
	&"Zoom1_R1_C1",
	&"Zoom1_R3_C1",
	&"Zoom2_R3_C1",
]
const HEAD_ONLY_ENABLED_ZOOM_REGIONS: Array[StringName] = [
	&"Zoom2_R3_C1",
]
const BODY_ENABLED_ZOOM_REGIONS: Array[StringName] = [
	&"Zoom2_R2_C1",
	&"Zoom2_R4_C1",
]
const HEAD_ONLY_GENERATOR_ZOOM_REGION: StringName = &"Zoom1_R1_C3"
const HEAD_ONLY_TABLE_ZOOM_REGION: StringName = &"Zoom2_R3_C1"
const BODY_INITIAL_ZOOM_REGION: StringName = &"Zoom1_R1_C1"
const HEAD_ONLY_INITIAL_ZOOM_REGION: StringName = &"Zoom2_R2_C1"
const SCREW_REPAIR_SAFE_ZOOM_REGIONS: Array[StringName] = [
	&"Zoom1_R1_C1",
	&"Zoom1_R3_C1",
	&"Zoom2_R2_C1",
	&"Zoom2_R3_C1",
	&"Zoom2_R4_C1",
]
const TORSO_SCREW_INDEX_LEFT_WAIST: int = 2
const TORSO_SCREW_INDEX_RIGHT_WAIST: int = 3
const LEG_SCREW_INDEX_INNER_KNEE: int = 2
@export var robot_lights_on_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var robot_lights_off_modulate: Color = Color(0.3, 0.3, 0.3, 1.0)

@export_group("Night Timer")
@export var night_duration_seconds: float = 60.0
@export var intro_tutorial_duration_seconds: float = 30.0
@export var intro_head_interaction_unlock_remaining_seconds: float = 5.0
@export var timer_label_text: String = "Time"

@export_group("Electricity Meter")
@export var electricity_label_text: String = "Electricity"
@export var electricity_start_percent: float = 100.0
@export var electricity_ripcord_gain_percent: float = 20.0
@export var electricity_decay_percent_per_second: float = 6.0
@export var electricity_lights_off_decay_multiplier: float = 2.0
@export var electricity_wake_threshold_percent: float = 130.0
@export var electricity_meter_visual_max_percent: float = 105.0
@export var electricity_low_end_score_threshold: float = 25.0

@export_group("Darkness Effects")
@export var screw_repair_lights_off_duration_multiplier: float = 2.0

@export_group("Gas Meter")
@export var gas_label_text: String = "Gas"
@export var gas_start_percent: float = 50.0
@export var gas_optimal_start_percent: float = 50.0
@export var gas_optimal_min_percent: float = 25.0
@export var gas_optimal_max_percent: float = 75.0
@export_range(0, 20, 1) var gas_optimal_event_count_min: int = 5
@export_range(0, 20, 1) var gas_optimal_event_count_max: int = 10
@export_range(0, 40, 1) var gas_drift_event_count_min: int = 10
@export_range(0, 40, 1) var gas_drift_event_count_max: int = 20
@export var gas_drift_change_percent: float = 5.0
@export var gas_valve_wheel_step_percent: float = 5.0
@export var gas_valve_drag_percent_per_pixel: float = 0.15
@export var gas_low_failure_percent: float = 0.0
@export var gas_high_failure_percent: float = 100.0

@export_group("Emergency Power Shutoff")
@export var emergency_power_gas_target_percent: float = 50.0
@export var emergency_power_gas_equalize_units_per_second: float = 2.0
@export var emergency_power_electricity_decay_per_second: float = 50.0
@export var emergency_power_electricity_consequence_pause_seconds: float = 6.0

@export_group("Window Alert")
@export_range(0, 3, 1) var window_alert_event_count_min: int = 0
@export_range(0, 3, 1) var window_alert_event_count_max: int = 3
@export var window_alert_initial_delay_seconds: float = 10.0
@export var window_alert_return_delay_seconds: float = 15.0
@export var window_alert_light_seconds_min: float = 5.0
@export var window_alert_light_seconds_max: float = 10.0
@export var window_alert_indicator_lead_seconds: float = 3.0
@export var window_alert_spotted_light_remaining_seconds: float = 3.0
@export var window_alert_safe_silhouette_seconds: float = 3.0
@export var window_alert_late_safe_silhouette_seconds: float = 6.0
@export var window_alert_seen_failure_seconds: float = 3.0
@export var window_alert_indicator_flash_seconds: float = 0.35

## A patrol drone that appears at the window at random moments through the
## night, the same way the uncle does. Position and scale the Drone node in the
## scene to place it; these control the timing of the encounter.
@export_group("Patrol Drone")
## Average seconds between drone appearances. Actual gaps vary randomly around
## this, so the drone shows up roughly once per this many seconds.
@export var drone_average_interval_seconds: float = 60.0
## Appearances are never scheduled within this many seconds of the night's
## start or end.
@export var drone_edge_exclusion_seconds: float = 5.0
## Seconds the drone simply sits there before it readies its guns.
@export var drone_idle_seconds: float = 5.0
## Seconds the drone aims (guns texture) before it fires.
@export var drone_guns_seconds: float = 3.0
## Seconds the shot texture shows before the night is failed.
@export var drone_shot_seconds: float = 0.1
## Seconds the drone shows the electrocution placeholder (id texture) after the
## emergency button drives it off, before it disappears. Halved so the zap plays
## twice as fast and lasts half as long.
@export var drone_zap_seconds: float = 0.15
@export var drone_failure_text: String = "You were caught by a patrol drone. Hit the emergency button to fend it off."

@export_group("Failure Messages")
@export var gas_high_failure_text: String = "She woke up because you let the gas pressure rise too high."
@export var gas_low_failure_text: String = "She woke up because you let the gas pressure fall too low."
@export var electricity_failure_text: String = "She woke up because you over supplied her with electricity."
@export var uncle_failure_text: String = "Your uncle caught you. Click the lights and shut off the generator."
@export var electricity_low_end_failure_text: String = "You did not supply enough electricity to the robot during the stress test. Pull on the generator's pull cord to generate electricity."
@export var timeout_failure_text: String = "You ran out of time."
@export var wake_button_failure_text: String = "She woke up."

@export_group("End Summary")
@export var summary_title_text: String = "STRESS TEST SUMMARY"
@export var summary_success_text: String = "Stress test completed."
@export var electricity_target_min_percent: float = 70.0
@export var electricity_target_max_percent: float = 110.0
@export_range(0.0, 1.0, 0.01) var electricity_five_star_required_ratio: float = 0.8
@export var screw_spawn_start_buffer_seconds: float = 5.0
@export var screw_spawn_end_buffer_seconds: float = 5.0
@export var screw_batch_interval_min_seconds: float = 10.0
@export var screw_batch_interval_max_seconds: float = 15.0
@export_range(0, 8, 1) var screw_batch_max_per_limb: int = 2
@export_range(0.0, 1.0, 0.01) var screw_electrical_pull_chance: float = 0.25
@export var screw_response_grace_seconds: float = 7.0
@export var screw_late_penalty_percent: float = 5.0
@export var screw_unrepaired_penalty_percent: float = 20.0
@export_range(0.0, 1.0, 0.01) var screw_completion_target_ratio: float = 0.8
@export var screw_completion_penalty_step_percent: float = 10.0

@export_group("Manual Screwing")
## Foundational nudge for the bare-hand screwing animation, in base scene
## pixels, authored against the left side. Applied on top of the automatic
## centering for every screw on every limb, so a constant misalignment can be
## corrected once here. Positive x moves it right, positive y moves it down.
## The right side's animation is mirrored, so its horizontal component is
## negated automatically to stay aligned.
@export var hand_screw_animation_offset: Vector2 = Vector2.ZERO

@export_group("Robot Position")
@export var head_only_drop_px: float = 57.0

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var first_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel1
@onready var second_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel2
@onready var light_placeholder: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder
@onready var dark_placeholder: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/DarkPlaceholder
@onready var window_light_on: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/WindowLightOn
@onready var uncle_window: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/UncleWindow
@onready var patrol_drone: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/PatrolDrone
@onready var patrol_drone_accessory: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/PatrolDrone/Accessory
@onready var patrol_drone_lights_off: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/DroneLightsOff
@onready var patrol_drone_guns_dark: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/DroneGuns
@onready var patrol_drone_glow: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/DroneGlow
@onready var patrol_drone_darks: Array[TextureRect] = [
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/DroneDark1,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/DroneDark2,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/DroneDark3,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/DroneDark4,
]
@onready var shed_light: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/Light
@onready var shed_bulb: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/Bulb
@onready var bulb_over_window: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/BulbOverWindow
@onready var pull_cord: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/PullCord
@onready var electrical_cord: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ElectricalCord
@onready var stress_test_robot_shadow: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobotShadow
@onready var stress_test_robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot
@onready var left_arm_screw_repair: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot/LeftArmScrewRepair
@onready var right_arm_screw_repair: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot/RightArmScrewRepair
@onready var torso_screw_repair: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot/TorsoScrewRepair
@onready var left_leg_screw_repair: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot/LeftLegScrewRepair
@onready var right_leg_screw_repair: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot/RightLegScrewRepair
@onready var gas_valve: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/GasValve
@onready var emergency_power_button: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/EmergencyPowerButton
@onready var window_alert_rect: ColorRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/WindowAlertRect
@onready var window_alert_indicator: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/WindowAlertIndicator
@onready var timer_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/TimerLabel
@onready var electricity_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/ElectricityLabel
@onready var gas_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/GasLabel
@onready var uncle_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/UncleLabel
@onready var electricity_meter_groups: VBoxContainer = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/ElectricityMeter/ElectricityMeterGroups
@onready var failure_overlay: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay
@onready var failure_title_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/FailureTitleLabel
@onready var failure_reason_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/FailureReasonLabel
@onready var failure_continue_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/FailureContinueButton
@onready var end_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/EndButton

var _zoom_level: int = ZOOM_LEVEL_FIRST
var _current_zoom_region: Control = null
var _pan_tween: Tween = null
var _zoom_tween: Tween = null
var _canvas_base_scale: float = 1.0
var _stress_test_dark: bool = false
var _night_elapsed: float = 0.0
var _night_finished: bool = false
var _electricity_percent: float = 0.0
var _gas_flow_percent: float = 50.0
var _gas_optimal_percent: float = 50.0
var _gas_last_change_percent: float = 0.0
var _emergency_power_shutoff_pressed: bool = false
var _gas_optimal_event_times: Array[float] = []
var _gas_drift_event_times: Array[float] = []
var _window_alert_event_times: Array[float] = []
var _gas_optimal_event_index: int = 0
var _gas_drift_event_index: int = 0
var _window_alert_event_index: int = 0
var _window_alert_state: int = WINDOW_ALERT_NONE
var _window_alert_elapsed: float = 0.0
var _window_alert_total_elapsed: float = 0.0
var _window_alert_light_duration: float = 5.0
var _window_alert_silhouette_leave_seconds: float = 3.0
var _window_alert_safe_elapsed: float = 0.0
var _window_alert_seen_elapsed: float = 0.0
var _window_alert_next_allowed_time: float = 0.0
var _dragging_gas_valve: bool = false
var _pending_failure_registers_wake: bool = false
var _failure_result_emitted: bool = false
var _failure_transition_playing: bool = false
var _intro_failure_restart_pending: bool = false
var _intro_head_interaction_unlocked: bool = true
var _summary_result: Dictionary = {}
var _summary_registers_completion: bool = false
var _summary_success: bool = false
var _summary_reason: String = ""
var _electricity_target_elapsed: float = 0.0
var _electricity_consequence_pause_until: float = 0.0
var _consequence_pause_intervals: Array[Vector2] = []
var _next_screw_batch_elapsed: float = 0.0
var _screw_started_count: int = 0
var _screw_repaired_count: int = 0
var _screw_late_count: int = 0
var _screw_late_penalty_total: float = 0.0
var _screw_active_events: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _robot_base_position: Vector2
var _robot_shadow_base_position: Vector2
var _tooltip_layer: CanvasLayer = null
var _mouse_tooltip: MouseFollowTooltip = null
var _rip_cord_full_extend_sound: AudioStream = null
var _rip_cord_audio_player: AudioStreamPlayer = null
var _generator_hum_sound: AudioStream = null
var _generator_chug_sound: AudioStream = null
var _generator_shutting_off_sound: AudioStream = null
var _generator_no_power_sound: AudioStream = null
var _emergency_power_button_sound: AudioStream = null
var _generator_hum_audio_player: AudioStreamPlayer = null
var _generator_chug_audio_player: AudioStreamPlayer = null
var _generator_shutdown_audio_player: AudioStreamPlayer = null
var _generator_no_power_audio_player: AudioStreamPlayer = null
var _emergency_power_button_audio_player: AudioStreamPlayer = null
var _night_ambient_sounds: Array[AudioStream] = []
var _night_ambient_paths: Array[String] = []
var _night_ambient_audio_player: AudioStreamPlayer = null
var _generator_had_power: bool = false

const WINDOW_ALERT_NONE: int = 0
const WINDOW_ALERT_YELLOW: int = 1
const WINDOW_ALERT_RED: int = 2

const DRONE_NONE: int = 0
const DRONE_IDLE: int = 1
const DRONE_GUNS: int = 2
const DRONE_SHOT: int = 3
const DRONE_ZAP: int = 4
## Base drone body. Some textures fully replace it (guns_shot); others are
## accessories layered on top of the body (guns, id) so the drone stays visible
## underneath.
const DRONE_IDLE_TEXTURE: Texture2D = preload("res://assets/textures/characters/drone/drone.png")
const DRONE_SHOT_TEXTURE: Texture2D = preload("res://assets/textures/characters/drone/guns_shot.png")
const DRONE_GUNS_TEXTURE: Texture2D = preload("res://assets/textures/characters/drone/guns.png")
## Placeholder for the eventual electrocution animation shown when the player
## drives the drone off with the emergency button.
const DRONE_ID_TEXTURE: Texture2D = preload("res://assets/textures/characters/drone/id.png")
## Electrocution animation played over the drone while it is being zapped: the
## three frames each show for a third of drone_zap_seconds, in order 1 -> 2 -> 3.
const DRONE_ZAP_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/characters/drone/zap_1.png"),
	preload("res://assets/textures/characters/drone/zap_2.png"),
	preload("res://assets/textures/characters/drone/zap_3.png"),
]

## Lights-off drone art (assigned to the scene's dark overlay nodes). When the
## lights are off the lit body is swapped for the darkened silhouette plus the
## red lens glow instead of being dimmed with a modulate, and the guns get their
## own dark variant. The four dark_drone frames are static overlays layered on
## top of the drone whenever it is present.

## Patrol-drone window encounter. Appearances are scheduled at random times up
## front (like the uncle); once a drone appears it runs its own timeline and the
## emergency button clears it.
var _drone_state: int = DRONE_NONE
var _drone_elapsed: float = 0.0
var _drone_event_times: Array[float] = []
var _drone_event_index: int = 0


func _ready() -> void:
	if _is_intro_tutorial_stress_test():
		night_duration_seconds = intro_tutorial_duration_seconds
	_create_mouse_tooltip()
	_initialize_audio_players()
	_initialize_robot_position_state()
	_initialize_pull_cord()
	_initialize_stress_systems()
	_initialize_emergency_power_button()
	call_deferred("_initialize_zoom")


func _process(delta: float) -> void:
	if _night_finished:
		_hide_mouse_tooltip()
		return

	# Debug speedrun (held Enter). Two flavours:
	# - Enter alone: real time acceleration. Every delta-driven system runs at
	#   the sped-up rate, so the whole simulation - electricity, gas, uncle and
	#   drone events - plays out faster but at its normal in-game pacing.
	# - Shift+Enter: the original "skip" mode. Only the night clock is wound
	#   forward; electricity is frozen and the uncle/drone are suppressed, so the
	#   player can ride the night out without managing anything.
	var enter_held := debug_enter_held()
	var timer_only_speedrun := enter_held and _debug_shift_held()
	var real_speedrun := enter_held and not timer_only_speedrun
	var time_scale := DEBUG_SPEEDRUN_TIME_SCALE if enter_held else 1.0
	# Delta handed to the general simulation: accelerated only in real speedrun.
	var sim_delta := delta * (DEBUG_SPEEDRUN_TIME_SCALE if real_speedrun else 1.0)

	var previous_elapsed := _night_elapsed
	_night_elapsed += delta * time_scale
	_update_intro_head_interaction_gate()
	if not timer_only_speedrun:
		_electricity_percent = maxf(0.0, _electricity_percent - _current_electricity_decay_per_second() * sim_delta)
	if _electricity_percent <= 0.0 and _emergency_power_shutoff_pressed:
		_set_emergency_power_shutoff_pressed(false)
	_update_electricity_summary_time(_night_elapsed - previous_elapsed)
	_update_screw_batches()
	_apply_scheduled_meter_events()
	_update_emergency_power_gas_equalization(sim_delta)
	_update_generator_power_sound()
	if timer_only_speedrun:
		_suppress_uncle_appearance()
		_suppress_patrol_drone()
	else:
		_update_window_alert(sim_delta)
		_update_patrol_drone(sim_delta)
	_refresh_stress_hud()
	_update_hover_box_tooltip()

	if _gas_flow_percent >= gas_high_failure_percent:
		_fail_stress_test(gas_high_failure_text, true)
		return
	if _gas_flow_percent <= gas_low_failure_percent:
		_fail_stress_test(gas_low_failure_text, true)
		return
	if _electricity_percent > electricity_wake_threshold_percent and not _is_electricity_consequence_paused():
		_fail_stress_test(electricity_failure_text, true)
		return
	if _night_elapsed >= night_duration_seconds:
		_handle_night_timer_finished()
		return


func _unhandled_input(event: InputEvent) -> void:
	if _night_finished:
		return

	if _handle_gas_valve_input(event):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_level(_zoom_level - 1, _global_to_scene_source(mouse_event.global_position))
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_level(_zoom_level + 1, _global_to_scene_source(mouse_event.global_position))
			get_viewport().set_input_as_handled()
			return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	if key_event.keycode == KEY_Z:
		_set_zoom_level((_zoom_level + 1) % (MAX_ZOOM_LEVEL + 1), _global_to_scene_source(get_viewport().get_mouse_position()))
		get_viewport().set_input_as_handled()
		return

	var direction := Vector2i.ZERO
	match key_event.keycode:
		KEY_W:
			direction.y = -1
		KEY_A:
			direction.x = -1
		KEY_S:
			direction.y = 1
		KEY_D:
			direction.x = 1
		_:
			return

	_move_zoom_region(direction)
	get_viewport().set_input_as_handled()


func _initialize_zoom() -> void:
	if camera_window == null or scene_canvas == null:
		return

	if camera_window.size == Vector2.ZERO:
		await get_tree().process_frame

	if not camera_window.resized.is_connected(_on_camera_window_resized):
		camera_window.resized.connect(_on_camera_window_resized)

	_apply_default_canvas_transform()
	scene_canvas.pivot_offset = Vector2.ZERO
	_current_zoom_region = _initial_zoom_region()
	if _current_zoom_region == null:
		_current_zoom_region = _find_region_for_focus(_zoom_level, BASE_SCENE_SIZE * 0.5)
	if _current_zoom_region != null:
		_zoom_level = _zoom_level_for_region(_current_zoom_region)
	scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
	_apply_zoom_region(false)


func _move_zoom_region(direction: Vector2i) -> void:
	if not _is_zoomed_in():
		return

	var next_region := _neighbor_region(_current_zoom_region, direction)
	if next_region == null or next_region == _current_zoom_region:
		return

	_zoom_level = _zoom_level_for_region(next_region)
	_current_zoom_region = next_region
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_apply_zoom_region(true)
	_interrupt_screw_repairs_if_current_view_requires_it()


func _set_zoom_level(value: int, focus_position: Vector2) -> void:
	var next_zoom_level := clampi(value, ZOOM_LEVEL_OUT, MAX_ZOOM_LEVEL)
	if _zoom_level == next_zoom_level:
		return

	var next_region: Control = null
	if next_zoom_level > ZOOM_LEVEL_OUT:
		next_region = _find_region_for_focus(next_zoom_level, focus_position)
		if next_region == null:
			return

	_zoom_level = next_zoom_level
	_current_zoom_region = next_region

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var target_scale := _current_zoom_scale()
	var target_position := _zoom_position_for_region(_current_zoom_region, target_scale) if _is_zoomed_in() else _default_canvas_position()

	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", target_scale * _canvas_base_scale, ZOOM_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", target_position, ZOOM_DURATION)
	_interrupt_screw_repairs_if_current_view_requires_it()


func _apply_zoom_region(animated: bool) -> void:
	var logical_scale := _current_zoom_scale()
	var target_position := _zoom_position_for_region(_current_zoom_region, logical_scale) if _is_zoomed_in() else _default_canvas_position()
	var target_scale := logical_scale * _canvas_base_scale

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()

	if not animated:
		scene_canvas.scale = target_scale
		scene_canvas.position = target_position
		return

	_pan_tween = create_tween()
	_pan_tween.set_parallel(true)
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_property(scene_canvas, "scale", target_scale, PAN_DURATION)
	_pan_tween.tween_property(scene_canvas, "position", target_position, PAN_DURATION)


func _zoom_position_for_region(region: Control, scale_value: Vector2) -> Vector2:
	if region == null:
		return _default_canvas_position()

	var display_scale := scale_value * _canvas_base_scale
	var region_center := _region_center(region)
	return camera_window.size * 0.5 - region_center * display_scale


func _on_camera_window_resized() -> void:
	_apply_default_canvas_transform()
	if _is_zoomed_in():
		scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
		_apply_zoom_region(false)
	else:
		scene_canvas.scale = ZOOMED_OUT_SCALE * _canvas_base_scale
		scene_canvas.position = _default_canvas_position()


func _apply_default_canvas_transform() -> void:
	if camera_window == null or scene_canvas == null or camera_window.size == Vector2.ZERO:
		return
	_canvas_base_scale = minf(
		camera_window.size.x / BASE_SCENE_SIZE.x,
		camera_window.size.y / BASE_SCENE_SIZE.y
	)
	scene_canvas.size = BASE_SCENE_SIZE


func _default_canvas_position() -> Vector2:
	var display_size := BASE_SCENE_SIZE * _canvas_base_scale
	return (camera_window.size - display_size) * 0.5


func _current_zoom_scale() -> Vector2:
	if _is_zoomed_in() and _current_zoom_region != null:
		return _zoom_scale_for_region(_current_zoom_region)

	return _base_zoom_scale_for_level(_zoom_level)


func _base_zoom_scale_for_level(zoom_level: int) -> Vector2:
	match zoom_level:
		ZOOM_LEVEL_SECOND:
			return SECOND_ZOOM_SCALE
		ZOOM_LEVEL_FIRST:
			return FIRST_ZOOM_SCALE
		_:
			return ZOOMED_OUT_SCALE


func _zoom_scale_for_region(region: Control) -> Vector2:
	var region_size := _region_rect(region).size
	if region_size.x <= 0.001 or region_size.y <= 0.001:
		return _base_zoom_scale_for_level(_zoom_level)

	return Vector2(
		BASE_SCENE_SIZE.x / region_size.x,
		BASE_SCENE_SIZE.y / region_size.y
	)


func _is_zoomed_in() -> bool:
	return _zoom_level > ZOOM_LEVEL_OUT


func _find_region_for_focus(zoom_level: int, focus_position: Vector2) -> Control:
	var active_regions := _active_regions_for_level(zoom_level)
	if active_regions.is_empty():
		return null

	var nearest_region: Control = null
	var nearest_distance := INF
	for region in active_regions:
		if not _region_rect(region).has_point(focus_position):
			continue

		var distance := _region_center(region).distance_squared_to(focus_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_region = region
	if nearest_region != null:
		return nearest_region

	nearest_distance = INF
	for region in active_regions:
		var distance := _region_center(region).distance_squared_to(focus_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_region = region
	return nearest_region


func _neighbor_region(region: Control, direction: Vector2i) -> Control:
	if region == null:
		return _find_navigation_region_for_focus(_visible_source_center())

	var override_region := _navigation_override_region(region, direction)
	if override_region != null:
		return override_region

	var active_regions := _navigation_regions()
	if active_regions.is_empty():
		return null

	var direction_vector := Vector2(direction)
	if direction_vector.length_squared() <= 0.0:
		return null

	var current_rect := _region_rect(region)
	var current_center := current_rect.get_center()
	var nearest_region: Control = null
	var nearest_score := INF
	for candidate in active_regions:
		if candidate == region:
			continue

		var candidate_rect := _region_rect(candidate)
		var candidate_center := candidate_rect.get_center()
		var center_delta := candidate_center - current_center
		var primary_distance := center_delta.dot(direction_vector)
		if primary_distance <= 0.001:
			continue

		var lane_gap := _region_perpendicular_gap(current_rect, candidate_rect, direction)
		var perpendicular_distance := absf(center_delta.cross(direction_vector))
		var score := lane_gap * 1000000.0 + perpendicular_distance * 1000.0 + primary_distance
		if score < nearest_score:
			nearest_score = score
			nearest_region = candidate

	return nearest_region


func _navigation_override_region(region: Control, direction: Vector2i) -> Control:
	if not _is_head_only_robot():
		return null

	var region_name := StringName(String(region.name))
	if region_name == HEAD_ONLY_GENERATOR_ZOOM_REGION and direction == Vector2i.LEFT:
		return _zoom_region_by_name(ZOOM_LEVEL_SECOND, HEAD_ONLY_TABLE_ZOOM_REGION)
	if region_name == HEAD_ONLY_TABLE_ZOOM_REGION and direction == Vector2i.RIGHT:
		return _zoom_region_by_name(ZOOM_LEVEL_FIRST, HEAD_ONLY_GENERATOR_ZOOM_REGION)

	return null


func _initial_zoom_region() -> Control:
	if _is_head_only_robot():
		return _zoom_region_by_name(ZOOM_LEVEL_SECOND, HEAD_ONLY_INITIAL_ZOOM_REGION)
	return _zoom_region_by_name(ZOOM_LEVEL_FIRST, BODY_INITIAL_ZOOM_REGION)


func _find_navigation_region_for_focus(focus_position: Vector2) -> Control:
	var active_regions := _navigation_regions()
	if active_regions.is_empty():
		return null

	var nearest_region: Control = null
	var nearest_distance := INF
	for region in active_regions:
		if not _region_rect(region).has_point(focus_position):
			continue

		var distance := _region_center(region).distance_squared_to(focus_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_region = region
	if nearest_region != null:
		return nearest_region

	nearest_distance = INF
	for region in active_regions:
		var distance := _region_center(region).distance_squared_to(focus_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_region = region
	return nearest_region


func _region_perpendicular_gap(current_rect: Rect2, candidate_rect: Rect2, direction: Vector2i) -> float:
	if direction.x != 0:
		return _span_gap(
			current_rect.position.y,
			current_rect.position.y + current_rect.size.y,
			candidate_rect.position.y,
			candidate_rect.position.y + candidate_rect.size.y
		)

	return _span_gap(
		current_rect.position.x,
		current_rect.position.x + current_rect.size.x,
		candidate_rect.position.x,
		candidate_rect.position.x + candidate_rect.size.x
	)


func _span_gap(first_min: float, first_max: float, second_min: float, second_max: float) -> float:
	if second_min > first_max:
		return second_min - first_max
	if first_min > second_max:
		return first_min - second_max
	return 0.0


func _active_regions_for_level(zoom_level: int) -> Array[Control]:
	var container := _region_container_for_level(zoom_level)
	var regions: Array[Control] = []
	if container == null:
		return regions

	for child in container.get_children():
		var region := child as Control
		if region == null:
			continue
		if _is_zoom_region_active(region):
			regions.append(region)
	return regions


func _navigation_regions() -> Array[Control]:
	var regions := _active_regions_for_level(ZOOM_LEVEL_FIRST)
	var replacement_region_names := BODY_ENABLED_ZOOM_REGIONS
	if _is_head_only_robot():
		replacement_region_names = HEAD_ONLY_ENABLED_ZOOM_REGIONS

	for region_name in replacement_region_names:
		var region := _zoom_region_by_name(ZOOM_LEVEL_SECOND, region_name)
		if region != null and _is_zoom_region_active(region):
			regions.append(region)
	return regions


func _is_zoom_region_active(region: Control) -> bool:
	var region_name := StringName(String(region.name))
	var head_only := _is_head_only_robot()

	if head_only:
		if region_name in HEAD_ONLY_DISABLED_ZOOM_REGIONS:
			return false
		if region_name in HEAD_ONLY_ENABLED_ZOOM_REGIONS:
			return true
	else:
		if region_name in BODY_DISABLED_ZOOM_REGIONS:
			return false
		if region_name in BODY_ENABLED_ZOOM_REGIONS:
			return true

	return bool(region.get("active"))


func _apply_robot_zoom_profile() -> void:
	if not _is_zoomed_in():
		return
	if _current_zoom_region == null:
		return
	if _is_zoom_region_active(_current_zoom_region):
		return

	_current_zoom_region = _find_navigation_region_for_focus(_visible_source_center())
	if _current_zoom_region != null:
		_zoom_level = _zoom_level_for_region(_current_zoom_region)
		_apply_zoom_region(false)


func _zoom_region_by_name(zoom_level: int, region_name: StringName) -> Control:
	var container := _region_container_for_level(zoom_level)
	if container == null:
		return null

	var node := container.get_node_or_null(NodePath(String(region_name)))
	return node as Control


func _regions_by_cell_for_level(zoom_level: int) -> Dictionary:
	var container := _region_container_for_level(zoom_level)
	var regions_by_cell := {}
	if container == null:
		return regions_by_cell

	for child in container.get_children():
		var region := child as Control
		if region == null:
			continue

		var cell := _cell_for_region(region)
		if cell.x >= 0 and cell.y >= 0:
			regions_by_cell[cell] = region
	return regions_by_cell


func _region_container_for_level(zoom_level: int) -> Control:
	match zoom_level:
		ZOOM_LEVEL_FIRST:
			return first_zoom_regions
		ZOOM_LEVEL_SECOND:
			return second_zoom_regions
		_:
			return null


func _region_rect(region: Control) -> Rect2:
	var region_transform := region.get_transform()
	var top_left := region_transform * Vector2.ZERO
	var top_right := region_transform * Vector2(region.size.x, 0.0)
	var bottom_left := region_transform * Vector2(0.0, region.size.y)
	var bottom_right := region_transform * region.size

	var min_position := Vector2(
		minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x)),
		minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	)
	var max_position := Vector2(
		maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x)),
		maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	)
	return Rect2(min_position, max_position - min_position)


func _region_center(region: Control) -> Vector2:
	return _region_rect(region).get_center()


func _cell_for_region(region: Control) -> Vector2i:
	var region_name := String(region.name)
	var regex := RegEx.new()
	if regex.compile("_R([0-9]+)_C([0-9]+)$") != OK:
		return Vector2i(-1, -1)

	var result := regex.search(region_name)
	if result == null:
		return Vector2i(-1, -1)
	return Vector2i(int(result.get_string(2)), int(result.get_string(1)))


func _zoom_level_for_region(region: Control) -> int:
	if region == null:
		return _zoom_level

	var region_name := String(region.name)
	if region_name.begins_with("Zoom2_"):
		return ZOOM_LEVEL_SECOND
	if region_name.begins_with("Zoom1_"):
		return ZOOM_LEVEL_FIRST
	return _zoom_level


func _visible_source_center() -> Vector2:
	if scene_canvas == null:
		return BASE_SCENE_SIZE * 0.5
	return _global_to_scene_source(camera_window.get_global_rect().get_center())


func _global_to_scene_source(global_position: Vector2) -> Vector2:
	if scene_canvas == null:
		return BASE_SCENE_SIZE * 0.5
	return scene_canvas.get_global_transform_with_canvas().affine_inverse() * global_position


func _initialize_pull_cord() -> void:
	if pull_cord == null:
		return
	if pull_cord.has_signal("max_pull_reached"):
		var max_pull_callable := Callable(self, "_on_pull_cord_max_pull_reached")
		if not pull_cord.is_connected("max_pull_reached", max_pull_callable):
			pull_cord.connect("max_pull_reached", max_pull_callable)
	if electrical_cord != null and electrical_cord.has_signal("max_pull_reached"):
		var max_pull_callable := Callable(self, "_on_electrical_cord_max_pull_reached")
		if not electrical_cord.is_connected("max_pull_reached", max_pull_callable):
			electrical_cord.connect("max_pull_reached", max_pull_callable)
	_set_stress_test_dark(false)


func _on_pull_cord_max_pull_reached() -> void:
	_set_stress_test_dark(not _stress_test_dark)


func _set_stress_test_dark(value: bool) -> void:
	var was_dark := _stress_test_dark
	_stress_test_dark = value
	_apply_background_light_state()
	_apply_lights_off_modulate()
	_apply_patrol_drone_visual()
	if stress_test_robot != null and _stress_test_dark and not was_dark and stress_test_robot.has_method("reset_interactions_to_default"):
		stress_test_robot.call("reset_interactions_to_default")
	_apply_screw_repair_light_state()


func _apply_lights_off_modulate() -> void:
	var lights_modulate := robot_lights_off_modulate if _stress_test_dark else robot_lights_on_modulate
	if stress_test_robot != null:
		stress_test_robot.modulate = lights_modulate
	if pull_cord != null:
		pull_cord.modulate = lights_modulate
	if electrical_cord != null:
		electrical_cord.modulate = lights_modulate
	if emergency_power_button != null:
		emergency_power_button.modulate = lights_modulate
	# The drone is not dimmed by modulate: it swaps to dedicated lights-off art
	# (silhouette + lens glow) instead, handled in _apply_patrol_drone_visual.


func _apply_background_light_state() -> void:
	if light_placeholder != null:
		light_placeholder.visible = true
	if dark_placeholder != null:
		dark_placeholder.visible = _stress_test_dark
	if shed_light != null:
		shed_light.visible = not _stress_test_dark
	if shed_bulb != null:
		shed_bulb.visible = not _stress_test_dark
	if bulb_over_window != null:
		bulb_over_window.visible = not _stress_test_dark


func _create_mouse_tooltip() -> void:
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "TooltipLayer"
	_tooltip_layer.layer = 200
	add_child(_tooltip_layer)

	_mouse_tooltip = MOUSE_TOOLTIP_SCRIPT.new() as MouseFollowTooltip
	_mouse_tooltip.show_delay_seconds = 0.0
	_tooltip_layer.add_child(_mouse_tooltip)


func _update_hover_box_tooltip() -> void:
	if stress_test_robot == null or not stress_test_robot.has_method("hovered_hover_box_description"):
		_hide_mouse_tooltip()
		return

	var description := String(stress_test_robot.call("hovered_hover_box_description"))
	if description.strip_edges().is_empty():
		_hide_mouse_tooltip()
		return

	_show_mouse_tooltip(description)


func _show_mouse_tooltip(text: String) -> void:
	if _mouse_tooltip != null:
		_mouse_tooltip.show_text(text)


func _hide_mouse_tooltip() -> void:
	if _mouse_tooltip != null:
		_mouse_tooltip.hide_tooltip()


func _initialize_robot_position_state() -> void:
	if stress_test_robot != null:
		_robot_base_position = stress_test_robot.position
	if stress_test_robot_shadow != null:
		_robot_shadow_base_position = stress_test_robot_shadow.position

	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_signal("robot_parts_changed"):
		var changed_callable := Callable(self, "_on_robot_parts_changed")
		if not state.is_connected("robot_parts_changed", changed_callable):
			state.connect("robot_parts_changed", changed_callable)

	_apply_robot_head_only_position()
	_apply_robot_zoom_profile()


func _on_robot_parts_changed(_parts: Dictionary) -> void:
	_apply_robot_head_only_position()
	_apply_robot_zoom_profile()


func _apply_robot_head_only_position() -> void:
	var head_only := _is_head_only_robot()
	var offset := Vector2(0.0, head_only_drop_px if head_only else 0.0)
	if stress_test_robot != null:
		stress_test_robot.position = _robot_base_position + offset
	if stress_test_robot_shadow != null:
		if stress_test_robot_shadow.has_method("set_head_only_shadow_enabled"):
			stress_test_robot_shadow.call("set_head_only_shadow_enabled", head_only)
		var shadow_profile_offset := Vector2.ZERO
		if stress_test_robot_shadow.has_method("get_shadow_position_offset"):
			shadow_profile_offset = stress_test_robot_shadow.call("get_shadow_position_offset")
		stress_test_robot_shadow.position = _robot_shadow_base_position + offset + shadow_profile_offset


func _is_head_only_robot() -> bool:
	return _robot_part_count("chest") <= 0 \
			and _robot_part_count("stomach") <= 0 \
			and _robot_part_count("arm") <= 0 \
			and _robot_part_count("hand") <= 0 \
			and _robot_part_count("leg") <= 0


func _robot_part_count(id: String) -> int:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return 0
	if state.has_method("get_robot_part_count"):
		return int(state.call("get_robot_part_count", id))
	if id == "leg":
		return int(state.get("equipped_limbs"))
	return 0


func _initialize_audio_players() -> void:
	_rip_cord_full_extend_sound = load(RIP_CORD_FULL_EXTEND_SOUND_PATH) as AudioStream
	if _rip_cord_full_extend_sound != null:
		_rip_cord_audio_player = AudioStreamPlayer.new()
		_rip_cord_audio_player.name = "RipCordAudioPlayer"
		add_child(_rip_cord_audio_player)

	_generator_hum_sound = load(GENERATOR_HUM_SOUND_PATH) as AudioStream
	_generator_chug_sound = load(GENERATOR_CHUG_SOUND_PATH) as AudioStream
	_generator_shutting_off_sound = load(GENERATOR_SHUTTING_OFF_SOUND_PATH) as AudioStream
	_generator_no_power_sound = load(GENERATOR_NO_POWER_SOUND_PATH) as AudioStream
	_emergency_power_button_sound = load(EMERGENCY_POWER_BUTTON_SOUND_PATH) as AudioStream
	_set_audio_stream_loop(_generator_hum_sound, true)
	_set_audio_stream_loop(_generator_chug_sound, true)

	if _generator_hum_sound != null:
		_generator_hum_audio_player = AudioStreamPlayer.new()
		_generator_hum_audio_player.name = "GeneratorHumAudioPlayer"
		_generator_hum_audio_player.stream = _generator_hum_sound
		add_child(_generator_hum_audio_player)
		_generator_hum_audio_player.finished.connect(_on_generator_hum_finished)
	if _generator_chug_sound != null:
		_generator_chug_audio_player = AudioStreamPlayer.new()
		_generator_chug_audio_player.name = "GeneratorChugAudioPlayer"
		_generator_chug_audio_player.stream = _generator_chug_sound
		add_child(_generator_chug_audio_player)
		_generator_chug_audio_player.finished.connect(_on_generator_chug_finished)
	if _generator_shutting_off_sound != null:
		_generator_shutdown_audio_player = AudioStreamPlayer.new()
		_generator_shutdown_audio_player.name = "GeneratorShutdownAudioPlayer"
		add_child(_generator_shutdown_audio_player)
	if _generator_no_power_sound != null:
		_generator_no_power_audio_player = AudioStreamPlayer.new()
		_generator_no_power_audio_player.name = "GeneratorNoPowerAudioPlayer"
		add_child(_generator_no_power_audio_player)
	if _emergency_power_button_sound != null:
		_emergency_power_button_audio_player = AudioStreamPlayer.new()
		_emergency_power_button_audio_player.name = "EmergencyPowerButtonAudioPlayer"
		add_child(_emergency_power_button_audio_player)

	_night_ambient_sounds.clear()
	_night_ambient_paths.clear()
	for path in NIGHT_AMBIENT_SOUND_PATHS:
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		_night_ambient_sounds.append(stream)
		_night_ambient_paths.append(path)
	if not _night_ambient_sounds.is_empty():
		_night_ambient_audio_player = AudioStreamPlayer.new()
		_night_ambient_audio_player.name = "NightAmbientAudioPlayer"
		add_child(_night_ambient_audio_player)


func _play_rip_cord_full_extend_sound() -> void:
	if _rip_cord_audio_player == null or _rip_cord_full_extend_sound == null:
		return
	_rip_cord_audio_player.stream = _rip_cord_full_extend_sound
	_rip_cord_audio_player.pitch_scale = 1.0
	_rip_cord_audio_player.volume_db = 0.0
	_rip_cord_audio_player.play()


func _update_generator_power_sound() -> void:
	var has_power := _electricity_percent > 0.001
	if _generator_had_power and not has_power and not _night_finished:
		_play_generator_no_power_sound()
	_generator_had_power = has_power

	if _night_finished or _emergency_power_shutoff_pressed:
		_apply_generator_loop_volume(_generator_hum_audio_player, 0.0)
		_apply_generator_loop_volume(_generator_chug_audio_player, 0.0)
		return

	_apply_generator_loop_volume(_generator_hum_audio_player, _generator_hum_volume())
	_apply_generator_loop_volume(_generator_chug_audio_player, _generator_chug_volume())


func _generator_hum_volume() -> float:
	return clampf((_electricity_percent - 20.0) / 30.0, 0.0, 1.0)


func _generator_chug_volume() -> float:
	if _electricity_percent <= 0.0:
		return 0.0
	if _electricity_percent < 20.0:
		return 0.5 + 0.5 * clampf(_electricity_percent / 20.0, 0.0, 1.0)
	return clampf((50.0 - _electricity_percent) / 30.0, 0.0, 1.0)


func _apply_generator_loop_volume(player: AudioStreamPlayer, volume: float) -> void:
	if player == null:
		return
	var clamped_volume := clampf(volume, 0.0, 1.0)
	if clamped_volume <= 0.001:
		if player.playing:
			player.stop()
		return
	player.volume_db = linear_to_db(clamped_volume)
	player.pitch_scale = 1.0
	if not player.playing:
		player.play()


func _stop_generator_power_sound() -> void:
	if _generator_hum_audio_player != null:
		_generator_hum_audio_player.stop()
	if _generator_chug_audio_player != null:
		_generator_chug_audio_player.stop()


func _on_generator_hum_finished() -> void:
	if _generator_hum_audio_player == null or _generator_hum_volume() <= 0.001:
		return
	_generator_hum_audio_player.play()


func _on_generator_chug_finished() -> void:
	if _generator_chug_audio_player == null or _generator_chug_volume() <= 0.001:
		return
	_generator_chug_audio_player.play()


func _play_generator_shutting_off_sound() -> void:
	if _generator_shutdown_audio_player == null or _generator_shutting_off_sound == null:
		return
	_generator_shutdown_audio_player.stream = _generator_shutting_off_sound
	_generator_shutdown_audio_player.pitch_scale = 1.0
	_generator_shutdown_audio_player.volume_db = 0.0
	_generator_shutdown_audio_player.play()


func _play_generator_no_power_sound() -> void:
	if _generator_no_power_audio_player == null or _generator_no_power_sound == null:
		return
	_generator_no_power_audio_player.stream = _generator_no_power_sound
	_generator_no_power_audio_player.pitch_scale = 1.0
	_generator_no_power_audio_player.volume_db = 0.0
	_generator_no_power_audio_player.play()


func _play_emergency_power_button_sound() -> void:
	if _emergency_power_button_audio_player == null or _emergency_power_button_sound == null:
		return
	_emergency_power_button_audio_player.stream = _emergency_power_button_sound
	_emergency_power_button_audio_player.pitch_scale = 1.0
	_emergency_power_button_audio_player.volume_db = 0.0
	_emergency_power_button_audio_player.play()


func _set_audio_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", enabled)
			return


func _play_random_night_ambient() -> void:
	if _night_ambient_audio_player == null or _night_ambient_sounds.is_empty():
		return
	var index := _rng.randi_range(0, _night_ambient_sounds.size() - 1)
	var path := _night_ambient_paths[index]
	_night_ambient_audio_player.stream = _night_ambient_sounds[index]
	_night_ambient_audio_player.pitch_scale = 1.0
	_night_ambient_audio_player.volume_db = linear_to_db(NIGHT_AMBIENT_LOUD_VOLUME_SCALE) if _is_loud_night_ambient(path) else 0.0
	_night_ambient_audio_player.play()


func _stop_night_ambient() -> void:
	if _night_ambient_audio_player != null:
		_night_ambient_audio_player.stop()


func _is_loud_night_ambient(path: String) -> bool:
	return path.get_file().begins_with("loud_")


func _initialize_stress_systems() -> void:
	_rng.randomize()
	if end_button != null:
		var show_end_button := not _is_intro_tutorial_stress_test()
		end_button.visible = show_end_button
		end_button.disabled = not show_end_button
	_night_elapsed = 0.0
	_night_finished = false
	_play_random_night_ambient()
	_electricity_percent = electricity_start_percent
	_gas_flow_percent = gas_start_percent
	_gas_optimal_percent = gas_optimal_start_percent
	_gas_last_change_percent = 0.0
	_set_emergency_power_shutoff_pressed(false)
	_gas_optimal_event_index = 0
	_gas_drift_event_index = 0
	_window_alert_event_index = 0
	_window_alert_state = WINDOW_ALERT_NONE
	_window_alert_elapsed = 0.0
	_window_alert_total_elapsed = 0.0
	_window_alert_light_duration = window_alert_light_seconds_min
	_window_alert_silhouette_leave_seconds = window_alert_safe_silhouette_seconds
	_window_alert_safe_elapsed = 0.0
	_window_alert_seen_elapsed = 0.0
	_window_alert_next_allowed_time = maxf(0.0, window_alert_initial_delay_seconds)
	_dragging_gas_valve = false
	_pending_failure_registers_wake = false
	_failure_result_emitted = false
	_failure_transition_playing = false
	_intro_failure_restart_pending = false
	_intro_head_interaction_unlocked = not _is_intro_tutorial_stress_test()
	_summary_result = {}
	_summary_registers_completion = false
	_electricity_target_elapsed = 0.0
	_electricity_consequence_pause_until = 0.0
	_consequence_pause_intervals.clear()
	_generator_had_power = false
	_screw_started_count = 0
	_screw_repaired_count = 0
	_screw_late_count = 0
	_screw_late_penalty_total = 0.0
	_screw_active_events.clear()
	_next_screw_batch_elapsed = maxf(
		maxf(0.0, screw_spawn_start_buffer_seconds),
		_random_screw_batch_interval()
	)
	_apply_body_part_screw_availability()
	_connect_screw_summary_tracking()

	var optimal_count := _random_event_count(gas_optimal_event_count_min, gas_optimal_event_count_max)
	var drift_count := _random_event_count(gas_drift_event_count_min, gas_drift_event_count_max)
	var alert_count := _random_event_count(window_alert_event_count_min, window_alert_event_count_max)
	_gas_optimal_event_times = _evenly_spaced_times(optimal_count, night_duration_seconds)
	_gas_drift_event_times = _evenly_spaced_times(drift_count, night_duration_seconds)
	_window_alert_event_times = _random_window_alert_times(alert_count)
	_drone_state = DRONE_NONE
	_drone_elapsed = 0.0
	_drone_event_index = 0
	# Space the drone appearances around the uncle's so the two never overlap.
	_drone_event_times = _deconflict_drone_schedule(_random_drone_event_times(), _window_alert_event_times)
	_apply_patrol_drone_visual()

	if window_alert_rect != null:
		window_alert_rect.visible = false
	if window_alert_indicator != null:
		window_alert_indicator.visible = false
	_apply_window_alert_visual_state()
	if failure_overlay != null:
		failure_overlay.visible = false
		failure_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if failure_title_label != null:
		failure_title_label.text = summary_title_text
	if failure_continue_button != null:
		failure_continue_button.disabled = false
		failure_continue_button.text = "CONTINUE"

	_set_stress_test_interaction_enabled(true)
	_update_intro_head_interaction_gate()
	_update_generator_power_sound()
	set_process(true)
	_refresh_stress_hud()


func _random_event_count(min_count: int, max_count: int) -> int:
	var low := maxi(0, mini(min_count, max_count))
	var high := maxi(0, max_count)
	if high < low:
		high = low
	return _rng.randi_range(low, high)


func _evenly_spaced_times(count: int, duration: float) -> Array[float]:
	var times: Array[float] = []
	if count <= 0 or duration <= 0.0:
		return times
	for i in range(count):
		times.append((float(i) + 1.0) * duration / (float(count) + 1.0))
	return times


func _random_window_alert_times(count: int) -> Array[float]:
	var times: Array[float] = []
	if count <= 0:
		return times
	var alert_duration := _window_alert_schedule_duration()
	var latest_start := maxf(0.0, night_duration_seconds - alert_duration - 0.5)
	var earliest_start := maxf(0.0, window_alert_initial_delay_seconds)
	if latest_start < earliest_start:
		return times
	for _i in range(count):
		times.append(_rng.randf_range(earliest_start, latest_start))
	times.sort()
	return times


func _apply_scheduled_meter_events() -> void:
	while _gas_optimal_event_index < _gas_optimal_event_times.size() and _night_elapsed >= _gas_optimal_event_times[_gas_optimal_event_index]:
		_gas_optimal_event_index += 1
		_gas_optimal_percent = _rng.randf_range(gas_optimal_min_percent, gas_optimal_max_percent)

	while _gas_drift_event_index < _gas_drift_event_times.size() and _night_elapsed >= _gas_drift_event_times[_gas_drift_event_index]:
		_gas_drift_event_index += 1
		var direction := _rng.randi_range(-1, 1)
		var amount := _rng.randf_range(0.0, gas_drift_change_percent)
		_apply_gas_flow_change(float(direction) * amount)


func _update_window_alert(delta: float) -> void:
	if _window_alert_state == WINDOW_ALERT_NONE:
		if _window_alert_event_index < _window_alert_event_times.size() \
				and _night_elapsed >= _window_alert_event_times[_window_alert_event_index] \
				and _night_elapsed >= _window_alert_next_allowed_time:
			# Never overlap the drone: if it is on screen, hold the uncle back
			# until it clears rather than have both events run at once.
			if _drone_state != DRONE_NONE:
				return
			_window_alert_event_index += 1
			_start_window_alert()
		return

	_window_alert_elapsed += delta
	_window_alert_total_elapsed += delta
	if _window_alert_state == WINDOW_ALERT_YELLOW:
		_shorten_window_alert_light_if_spotted()
	if _window_alert_state == WINDOW_ALERT_YELLOW and _window_alert_elapsed >= _window_alert_light_duration:
		_window_alert_state = WINDOW_ALERT_RED
		_window_alert_elapsed = 0.0
		_window_alert_safe_elapsed = 0.0
		_window_alert_seen_elapsed = 0.0
		_window_alert_silhouette_leave_seconds = window_alert_late_safe_silhouette_seconds
		if not _is_uncle_exposure_active():
			_window_alert_silhouette_leave_seconds = window_alert_safe_silhouette_seconds
		_apply_window_alert_visual_state()
	if _window_alert_state == WINDOW_ALERT_RED:
		if _is_uncle_exposure_active():
			_window_alert_silhouette_leave_seconds = window_alert_late_safe_silhouette_seconds
			_window_alert_seen_elapsed += delta
			_window_alert_safe_elapsed = 0.0
			if _window_alert_seen_elapsed >= window_alert_seen_failure_seconds:
				_fail_stress_test(uncle_failure_text, false)
				if window_alert_indicator != null:
					window_alert_indicator.visible = false
				return
		else:
			_window_alert_safe_elapsed += delta
			if _window_alert_safe_elapsed >= _window_alert_silhouette_leave_seconds:
				_clear_window_alert()
				return
	_update_window_alert_indicator()


func _start_window_alert() -> void:
	_window_alert_state = WINDOW_ALERT_YELLOW
	_window_alert_elapsed = 0.0
	_window_alert_total_elapsed = 0.0
	_window_alert_safe_elapsed = 0.0
	_window_alert_seen_elapsed = 0.0
	_window_alert_light_duration = _random_window_alert_light_duration()
	_window_alert_silhouette_leave_seconds = window_alert_safe_silhouette_seconds
	if window_alert_rect != null:
		window_alert_rect.visible = false
	_apply_window_alert_visual_state()
	_update_window_alert_indicator()


func _clear_window_alert() -> void:
	_window_alert_state = WINDOW_ALERT_NONE
	_window_alert_elapsed = 0.0
	_window_alert_total_elapsed = 0.0
	_window_alert_safe_elapsed = 0.0
	_window_alert_seen_elapsed = 0.0
	if not _night_finished:
		_window_alert_next_allowed_time = _night_elapsed + maxf(0.0, window_alert_return_delay_seconds)
	_skip_elapsed_window_alert_events()
	if window_alert_rect != null:
		window_alert_rect.visible = false
	if window_alert_indicator != null:
		window_alert_indicator.visible = false
	_apply_window_alert_visual_state()


func _apply_window_alert_visual_state() -> void:
	if window_light_on != null:
		window_light_on.visible = _window_alert_state != WINDOW_ALERT_NONE
	if uncle_window != null:
		uncle_window.visible = _window_alert_state == WINDOW_ALERT_RED


func _skip_elapsed_window_alert_events() -> void:
	while _window_alert_event_index < _window_alert_event_times.size() \
			and _night_elapsed >= _window_alert_event_times[_window_alert_event_index]:
		_window_alert_event_index += 1


func _update_window_alert_indicator() -> void:
	if window_alert_indicator == null:
		return
	var should_show := _window_alert_state != WINDOW_ALERT_NONE \
			and _window_alert_total_elapsed >= _window_alert_indicator_start_time() \
			and not _is_window_alert_in_camera_view()
	var flash_duration := maxf(0.05, window_alert_indicator_flash_seconds)
	var flash_on := fmod(_window_alert_total_elapsed, flash_duration * 2.0) < flash_duration
	window_alert_indicator.visible = should_show and flash_on
	window_alert_indicator.modulate.a = 1.0


func _window_alert_indicator_start_time() -> float:
	return maxf(0.0, _window_alert_light_duration - window_alert_indicator_lead_seconds)


func _shorten_window_alert_light_if_spotted() -> void:
	if not _is_window_alert_in_camera_view():
		return
	var spotted_remaining := maxf(0.0, window_alert_spotted_light_remaining_seconds)
	var remaining := _window_alert_light_duration - _window_alert_elapsed
	if remaining > spotted_remaining:
		_window_alert_light_duration = _window_alert_elapsed + spotted_remaining


func _is_window_alert_in_camera_view() -> bool:
	if camera_window == null or window_alert_rect == null:
		return false
	return camera_window.get_global_rect().intersects(window_alert_rect.get_global_rect())


func _is_window_alert_in_target_view() -> bool:
	if window_alert_rect == null:
		return false
	if not _is_zoomed_in():
		return true
	if _current_zoom_region == null:
		return false
	return _region_rect(_current_zoom_region).intersects(_region_rect(window_alert_rect))


func _interrupt_screw_repairs_if_window_in_target_view() -> void:
	if not _is_window_alert_in_target_view():
		return
	_interrupt_screw_repairs()


func _interrupt_screw_repairs_if_current_view_requires_it() -> void:
	if _is_window_alert_in_target_view() or not _is_current_screw_repair_view_safe():
		_interrupt_screw_repairs()


func _is_current_screw_repair_view_safe() -> bool:
	if not _is_zoomed_in() or _current_zoom_region == null:
		return false
	return StringName(String(_current_zoom_region.name)) in SCREW_REPAIR_SAFE_ZOOM_REGIONS


func _interrupt_screw_repairs() -> void:
	for repair in _screw_repair_controllers():
		if repair.has_method("interrupt_repair"):
			repair.call("interrupt_repair")


func _is_uncle_exposure_active() -> bool:
	return not _stress_test_dark or (_electricity_percent > 0.0 and not _emergency_power_shutoff_pressed)


## Advances the patrol-drone encounter. While no drone is present it waits for
## the next scheduled appearance time; once present the drone runs its
## idle -> guns -> shot -> fail timeline on its own clock (the player can only
## stop it with the emergency button).
func _update_patrol_drone(delta: float) -> void:
	if _drone_state == DRONE_NONE:
		if _drone_event_index < _drone_event_times.size() \
				and _night_elapsed >= _drone_event_times[_drone_event_index]:
			# Never overlap the uncle: if he is on screen, hold the drone back
			# until he clears, but drop this appearance rather than let the wait
			# push it into the night's end-exclusion window.
			if _window_alert_state != WINDOW_ALERT_NONE:
				if _night_elapsed > _latest_drone_start_time():
					_drone_event_index += 1
				return
			_drone_event_index += 1
			_start_patrol_drone()
		return

	_drone_elapsed += delta
	match _drone_state:
		DRONE_IDLE:
			if _drone_elapsed >= maxf(0.0, drone_idle_seconds):
				_set_drone_state(DRONE_GUNS)
		DRONE_GUNS:
			if _drone_elapsed >= maxf(0.0, drone_guns_seconds):
				_set_drone_state(DRONE_SHOT)
		DRONE_SHOT:
			if _drone_elapsed >= maxf(0.0, drone_shot_seconds):
				_fail_stress_test(drone_failure_text, false)
		DRONE_ZAP:
			if _drone_elapsed >= maxf(0.0, drone_zap_seconds):
				_clear_patrol_drone()
			else:
				# Advance the arc animation (frame 1 -> 2 -> 3) as time passes.
				_show_accessory(_current_zap_texture())


func _start_patrol_drone() -> void:
	_set_drone_state(DRONE_IDLE)


## Emergency-button response: if a drone is present (and not already being
## driven off), show the electrocution placeholder for a moment before it
## vanishes instead of clearing it instantly.
func _zap_patrol_drone_if_active() -> void:
	if _drone_state == DRONE_NONE or _drone_state == DRONE_ZAP:
		return
	_set_drone_state(DRONE_ZAP)


## Removes the drone and resets its timeline. Safe to call when no drone is
## present, so the emergency button and night-end path can call it freely.
func _clear_patrol_drone() -> void:
	if _drone_state == DRONE_NONE:
		_apply_patrol_drone_visual()
		return
	_drone_state = DRONE_NONE
	_drone_elapsed = 0.0
	_skip_elapsed_drone_events()
	_apply_patrol_drone_visual()


## Debug speedrun: keep the drone from appearing and drop any appearances whose
## scheduled time has already slipped past, so none fire in a burst afterwards.
func _suppress_patrol_drone() -> void:
	if _drone_state != DRONE_NONE:
		_clear_patrol_drone()
	else:
		_skip_elapsed_drone_events()


func _skip_elapsed_drone_events() -> void:
	while _drone_event_index < _drone_event_times.size() \
			and _night_elapsed >= _drone_event_times[_drone_event_index]:
		_drone_event_index += 1


## Builds the random appearance schedule for the night, the same way the uncle
## does: pick a count so appearances average one per interval across the usable
## window (the night minus the start/end exclusions), then drop that many at
## uniformly random times in that window. The fractional part of the expected
## count is honoured probabilistically so the long-run average stays on target.
func _random_drone_event_times() -> Array[float]:
	var times: Array[float] = []
	var edge := maxf(0.0, drone_edge_exclusion_seconds)
	var start := edge
	var end := night_duration_seconds - edge
	var average := maxf(1.0, drone_average_interval_seconds)
	if end <= start:
		return times
	var expected := (end - start) / average
	var count := int(floor(expected))
	if _rng.randf() < expected - floor(expected):
		count += 1
	for _i in range(count):
		times.append(_rng.randf_range(start, end))
	times.sort()
	return times


## Worst-case on-screen duration of one drone encounter, used to reserve room
## so appearances neither collide with the uncle nor run off the night's end.
func _drone_reserved_seconds() -> float:
	return maxf(0.0, drone_idle_seconds) \
			+ maxf(0.0, drone_guns_seconds) \
			+ maxf(0.0, drone_shot_seconds) \
			+ maxf(0.0, drone_zap_seconds)


## Latest moment a drone may still appear and finish before the end exclusion.
func _latest_drone_start_time() -> float:
	return night_duration_seconds - maxf(0.0, drone_edge_exclusion_seconds) - _drone_reserved_seconds()


## Shifts drone appearances so their on-screen windows never overlap an uncle
## window (or each other), dropping any that no longer fit before the end
## exclusion. The uncle schedule is treated as fixed, so the drone is the one
## that yields — and it is only dropped when there is genuinely no room, never
## pushed into the final seconds of the night.
func _deconflict_drone_schedule(drone_times: Array[float], uncle_times: Array[float]) -> Array[float]:
	var result: Array[float] = []
	var latest_start := _latest_drone_start_time()
	if latest_start < maxf(0.0, drone_edge_exclusion_seconds):
		return result
	var gap := 1.0
	var drone_dur := _drone_reserved_seconds()
	var uncle_dur := _window_alert_schedule_duration()
	for original in drone_times:
		var t := original
		var settled := false
		var guard := 0
		while not settled and guard < 128:
			guard += 1
			settled = true
			for u in uncle_times:
				if t < u + uncle_dur + gap and t + drone_dur + gap > u:
					t = u + uncle_dur + gap
					settled = false
					break
			if not settled:
				continue
			for placed in result:
				if t < placed + drone_dur + gap and t + drone_dur + gap > placed:
					t = placed + drone_dur + gap
					settled = false
					break
		if settled and t <= latest_start:
			result.append(t)
	result.sort()
	return result


func _set_drone_state(state: int) -> void:
	_drone_state = state
	_drone_elapsed = 0.0
	_apply_patrol_drone_visual()


## Resolves every drone layer for the current state and light level. The drone
## body (drone.png, or the firing pose during the shot) is always present; the
## four dark overlays sit on top of it whenever it is on-screen. With the lights
## off the lights-off tint and the red lens glow are layered on as well, and the
## guns use their dark variant. During the shot the firing pose draws under the
## dark overlays and only the dark guns turn off.
func _apply_patrol_drone_visual() -> void:
	if patrol_drone == null:
		return
	var present := _drone_state != DRONE_NONE
	var zapping := _drone_state == DRONE_ZAP
	# Hide the per-state layers first; the dark overlays follow "present".
	patrol_drone.visible = false
	patrol_drone.texture = DRONE_IDLE_TEXTURE
	_hide_node(patrol_drone_accessory)
	_hide_node(patrol_drone_lights_off)
	_hide_node(patrol_drone_guns_dark)
	_hide_node(patrol_drone_glow)
	# While zapping, the drone is lit only by the arc: use dark_drone 1, 2 and 4
	# (no lights-off tint or glow), whatever the light level was before.
	if zapping:
		_apply_zap_dark_overlays()
	else:
		_set_dark_overlays_visible(present)
	if not present:
		return

	# The drone body is always drawn; lights-off just adds the tint and glow.
	patrol_drone.visible = true
	var dark := _stress_test_dark
	if dark and not zapping:
		_show_node(patrol_drone_lights_off)
		_show_node(patrol_drone_glow)

	match _drone_state:
		DRONE_SHOT:
			# Firing pose sits under the dark overlays; the dark guns turn off
			# but every other dark layer stays on.
			patrol_drone.texture = DRONE_SHOT_TEXTURE
		DRONE_GUNS:
			if dark:
				_show_node(patrol_drone_guns_dark)
			else:
				_show_accessory(DRONE_GUNS_TEXTURE)
		DRONE_ZAP:
			_show_accessory(_current_zap_texture())
		_:  # DRONE_IDLE
			pass


## During a zap, dark_drone 1, 2 and 4 stay lit (indices 0, 1 and last); only
## dark_drone 3 turns off, along with the lights-off tint and glow.
func _apply_zap_dark_overlays() -> void:
	var last := patrol_drone_darks.size() - 1
	for i in patrol_drone_darks.size():
		var node := patrol_drone_darks[i]
		if node != null:
			node.visible = i == 0 or i == 1 or i == last


## The zap frame for the current elapsed time: three frames, each shown for a
## third of drone_zap_seconds, in order 1 -> 2 -> 3.
func _current_zap_texture() -> Texture2D:
	if DRONE_ZAP_TEXTURES.is_empty():
		return DRONE_ID_TEXTURE
	var total := maxf(0.0001, drone_zap_seconds)
	var fraction := clampf(_drone_elapsed / total, 0.0, 0.99999)
	var index := clampi(int(fraction * DRONE_ZAP_TEXTURES.size()), 0, DRONE_ZAP_TEXTURES.size() - 1)
	return DRONE_ZAP_TEXTURES[index]


func _set_dark_overlays_visible(value: bool) -> void:
	for node in patrol_drone_darks:
		if node != null:
			node.visible = value


func _show_accessory(texture: Texture2D) -> void:
	if patrol_drone_accessory == null:
		return
	patrol_drone_accessory.texture = texture
	patrol_drone_accessory.visible = true


func _hide_node(node: CanvasItem) -> void:
	if node != null:
		node.visible = false


func _show_node(node: CanvasItem) -> void:
	if node != null:
		node.visible = true


func _random_window_alert_light_duration() -> float:
	var low := maxf(0.0, minf(window_alert_light_seconds_min, window_alert_light_seconds_max))
	var high := maxf(low, window_alert_light_seconds_max)
	return _rng.randf_range(low, high)


func _window_alert_schedule_duration() -> float:
	return maxf(0.0, window_alert_light_seconds_max) \
			+ maxf(0.0, window_alert_late_safe_silhouette_seconds) \
			+ maxf(0.0, window_alert_seen_failure_seconds)


func _on_electrical_cord_max_pull_reached() -> void:
	if _night_finished:
		return
	_play_rip_cord_full_extend_sound()
	_electricity_percent += electricity_ripcord_gain_percent
	_refresh_stress_hud()
	if _rng.randf() < clampf(screw_electrical_pull_chance, 0.0, 1.0):
		_trigger_random_screw()


func _trigger_random_screw() -> bool:
	var controllers := _screw_repair_controllers()
	controllers.shuffle()
	for repair in controllers:
		if repair.has_method("loosen_screws") and int(repair.call("loosen_screws", 1)) > 0:
			return true
	return false


func _handle_gas_valve_input(event: InputEvent) -> bool:
	if gas_valve == null:
		return false

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed and _is_over_gas_valve(mouse_event.global_position):
				_dragging_gas_valve = true
				return true
			if not mouse_event.pressed and _dragging_gas_valve:
				_dragging_gas_valve = false
				return true

		if mouse_event.pressed and _is_over_gas_valve(mouse_event.global_position):
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_gas_flow_change(gas_valve_wheel_step_percent)
				return true
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_gas_flow_change(-gas_valve_wheel_step_percent)
				return true

	if event is InputEventMouseMotion and _dragging_gas_valve:
		var motion_event := event as InputEventMouseMotion
		_apply_gas_flow_change(-motion_event.relative.y * gas_valve_drag_percent_per_pixel)
		return true

	return false


func _is_over_gas_valve(global_position: Vector2) -> bool:
	return gas_valve != null and gas_valve.get_global_rect().has_point(global_position)


func _apply_gas_flow_change(delta_percent: float) -> void:
	_gas_last_change_percent = delta_percent
	_gas_flow_percent = clampf(_gas_flow_percent + delta_percent, gas_low_failure_percent, gas_high_failure_percent)
	_refresh_stress_hud()


func _initialize_emergency_power_button() -> void:
	if emergency_power_button == null or not emergency_power_button.has_signal("pressed"):
		return
	var pressed_callable := Callable(self, "_on_emergency_power_button_pressed")
	if not emergency_power_button.is_connected("pressed", pressed_callable):
		emergency_power_button.connect("pressed", pressed_callable)


func _on_emergency_power_button_pressed() -> void:
	if _night_finished:
		return
	# Hitting the emergency button drives off a patrol drone at the window,
	# flashing the electrocution placeholder before it vanishes.
	_zap_patrol_drone_if_active()
	_play_emergency_power_button_sound()
	if _electricity_percent > 0.001:
		_play_generator_shutting_off_sound()
	if _can_start_emergency_consequence_pause():
		_start_emergency_consequence_pause()
	_set_emergency_power_shutoff_pressed(true)
	_update_generator_power_sound()
	_refresh_stress_hud()


func _set_emergency_power_shutoff_pressed(value: bool) -> void:
	_emergency_power_shutoff_pressed = value
	if emergency_power_button != null:
		emergency_power_button.set("is_pressed", value)


func _update_emergency_power_gas_equalization(delta: float) -> void:
	if not _emergency_power_shutoff_pressed:
		return
	var target := clampf(emergency_power_gas_target_percent, gas_low_failure_percent, gas_high_failure_percent)
	var previous := _gas_flow_percent
	_gas_flow_percent = move_toward(
		_gas_flow_percent,
		target,
		maxf(0.0, emergency_power_gas_equalize_units_per_second) * delta
	)
	_gas_last_change_percent = _gas_flow_percent - previous


func _debug_mode_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and bool(state.debug_mode_enabled)


## Whether a Shift key is held, used to pick the timer-only debug speedrun.
func _debug_shift_held() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


## Debug speedrun: keep the uncle from ever appearing while Enter is held.
## Any live window alert is cleared, and alerts whose scheduled time has passed
## (including those the 10x clock races through) are skipped so none queue up to
## fire the instant Enter is released.
func _suppress_uncle_appearance() -> void:
	if _window_alert_state != WINDOW_ALERT_NONE:
		_clear_window_alert()
	else:
		_skip_elapsed_window_alert_events()


func _refresh_stress_hud() -> void:
	var debug_mode := _debug_mode_enabled()
	if timer_value_label != null:
		timer_value_label.text = "%s: %s" % [timer_label_text, _format_remaining_time()]
	if electricity_value_label != null:
		if debug_mode:
			electricity_value_label.text = "%s: %.0f%% (%+.1f%%/s)" % [
				electricity_label_text,
				_electricity_percent,
				-_current_electricity_decay_per_second(),
			]
		else:
			electricity_value_label.text = "%s: %.0f%%" % [
				electricity_label_text,
				_electricity_percent,
			]
	if gas_value_label != null:
		gas_value_label.text = "%s: %.0f%% / %.0f%% (%+.1f%%)" % [
			gas_label_text,
			_gas_flow_percent,
			_gas_optimal_percent,
			_gas_last_change_percent,
		]
	if uncle_value_label != null:
		uncle_value_label.text = _format_uncle_meter_text()
	_refresh_electricity_meter()


func _format_uncle_meter_text() -> String:
	var light_text := "--"
	if _window_alert_state == WINDOW_ALERT_YELLOW:
		var light_remaining := maxf(0.0, _window_alert_light_duration - _window_alert_elapsed)
		light_text = "%.1fs" % light_remaining
	if not _debug_mode_enabled():
		return "Light: %s" % light_text
	var seen_limit := maxf(0.0, window_alert_seen_failure_seconds)
	var leave_text := "--"
	if _window_alert_state == WINDOW_ALERT_RED and not _is_uncle_exposure_active():
		var leave_remaining := maxf(0.0, _window_alert_silhouette_leave_seconds - _window_alert_safe_elapsed)
		leave_text = "%.1fs" % leave_remaining
	return "Light: %s | Seen: %.1f/%.1fs | Leaves: %s" % [
		light_text,
		_window_alert_seen_elapsed,
		seen_limit,
		leave_text,
	]


func _refresh_electricity_meter() -> void:
	var segments := _electricity_meter_segments()
	var visual_max := maxf(1.0, electricity_meter_visual_max_percent)
	var visible_segment_count := clampi(
		int(ceil((_electricity_percent / visual_max) * float(segments.size()))),
		0,
		segments.size()
	)
	var color := Color(0.1, 0.95, 0.18, 1.0)
	var completed_bar_count := int(floor(_electricity_percent / 20.0))
	if completed_bar_count >= 6:
		color = Color(1.0, 0.08, 0.04, 1.0)
	elif completed_bar_count >= 5:
		color = Color(1.0, 0.88, 0.08, 1.0)

	for i in range(segments.size()):
		var segment := segments[i]
		segment.visible = true
		segment.color = color if i < visible_segment_count else Color(0.0, 0.0, 0.0, 0.0)


func _electricity_meter_segments() -> Array[ColorRect]:
	var segments: Array[ColorRect] = []
	if electricity_meter_groups == null:
		return segments
	var groups := electricity_meter_groups.get_children()
	for group_index in range(groups.size() - 1, -1, -1):
		var group := groups[group_index]
		var group_segments := group.get_children()
		for segment_index in range(group_segments.size() - 1, -1, -1):
			var segment := group_segments[segment_index] as ColorRect
			if segment != null:
				segments.append(segment)
	return segments


func _format_remaining_time() -> String:
	var remaining := maxf(0.0, night_duration_seconds - _night_elapsed)
	var total_seconds := int(floor(remaining))
	var minutes := int(total_seconds / 60)
	var seconds := int(total_seconds % 60)
	var centiseconds := int(floor((remaining - float(total_seconds)) * 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]


func _current_electricity_decay_per_second() -> float:
	if _emergency_power_shutoff_pressed:
		return emergency_power_electricity_decay_per_second
	var multiplier := electricity_lights_off_decay_multiplier if _stress_test_dark else 1.0
	return electricity_decay_percent_per_second * multiplier


## Debug (number-4 give-items): re-derive which limbs expose screws now that new
## parts may have been granted, and refresh the screwdriver/manual repair mode.
## The robot's limb visuals already update live via robot_parts_changed; the
## screw wiring is intentionally only recomputed on this explicit trigger, never
## polled, so there is no per-frame cost.
func debug_recalibrate() -> void:
	_apply_body_part_screw_availability()
	_connect_screw_summary_tracking()


func _apply_body_part_screw_availability() -> void:
	var arm_count := _robot_part_count("arm")
	_set_screw_repair_available(left_arm_screw_repair, arm_count >= 1)
	_set_screw_repair_available(right_arm_screw_repair, arm_count >= 2)
	# The torso screw plate spans both mid-body parts, so it is reachable if
	# either the chest or the stomach is attached. The two waist screws sit on the
	# stomach, so they additionally require it (and stay hidden under an arm).
	var chest_count := _robot_part_count("chest")
	var stomach_count := _robot_part_count("stomach")
	_set_screw_repair_available(torso_screw_repair, chest_count >= 1 or stomach_count >= 1)
	if torso_screw_repair != null and torso_screw_repair.has_method("set_screw_available"):
		torso_screw_repair.call("set_screw_available", TORSO_SCREW_INDEX_LEFT_WAIST, stomach_count >= 1 and arm_count < 1)
		torso_screw_repair.call("set_screw_available", TORSO_SCREW_INDEX_RIGHT_WAIST, stomach_count >= 1 and arm_count < 2)
	var leg_count := _robot_part_count("leg")
	_set_screw_repair_available(left_leg_screw_repair, leg_count >= 1)
	_set_screw_repair_available(right_leg_screw_repair, leg_count >= 2)
	# The inner knee is hidden between the legs, so it is only exposed once a
	# leg is missing. Keep it unavailable while both legs are still attached.
	for leg_repair in [left_leg_screw_repair, right_leg_screw_repair]:
		if leg_repair != null and leg_repair.has_method("set_screw_available"):
			leg_repair.call("set_screw_available", LEG_SCREW_INDEX_INNER_KNEE, leg_count < 2)


func _set_screw_repair_available(repair: Node, available: bool) -> void:
	if repair == null:
		return
	repair.set("enabled", available)


func _apply_screw_repair_light_state() -> void:
	var multiplier := screw_repair_lights_off_duration_multiplier if _stress_test_dark else 1.0
	for repair in _screw_repair_controllers():
		if repair.has_method("set_repair_animation_duration_multiplier"):
			repair.call("set_repair_animation_duration_multiplier", multiplier)


func _screw_repair_controllers() -> Array[Node]:
	var controllers: Array[Node] = []
	if stress_test_robot != null:
		_collect_screw_repair_controllers(stress_test_robot, controllers)
	return controllers


func _collect_screw_repair_controllers(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child.has_method("set_repair_animation_duration_multiplier") or child.has_method("interrupt_repair"):
			out.append(child)
		_collect_screw_repair_controllers(child, out)


func _connect_screw_summary_tracking() -> void:
	var manual_screwing := _screwdriver_count() <= 0
	for repair in _screw_repair_controllers():
		if repair.has_method("set_repair_gate"):
			repair.call("set_repair_gate", Callable(self, "_can_begin_screw_repair"))
		if repair.has_method("set_manual_screwing"):
			repair.call("set_manual_screwing", manual_screwing)
		if repair.has_method("set_hand_screw_offset"):
			repair.call("set_hand_screw_offset", hand_screw_animation_offset)
		_connect_screw_signal(repair, "screw_loosened", "_on_screw_loosened")
		_connect_screw_signal(repair, "repair_started", "_on_screw_repair_started")
		_connect_screw_signal(repair, "repair_interrupted", "_on_screw_repair_interrupted")
		_connect_screw_signal(repair, "screw_repaired", "_on_screw_repaired")


## Permission gate handed to each screw repair controller. Two hands are free
## when the player either owns two or more screwdrivers or owns none at all and
## screws bare-handed, so one left-side and one right-side repair may run at
## once (but never two on the same side). With exactly one screwdriver a single
## hand is occupied holding it, so only one screw may be driven at a time.
func _can_begin_screw_repair(side: String) -> bool:
	var screwdriver_count := _screwdriver_count()
	if screwdriver_count >= 2 or screwdriver_count <= 0:
		return not _is_side_screw_repair_active(side)
	return not _is_screw_repair_animation_active()


func _is_side_screw_repair_active(side: String) -> bool:
	for repair in _screw_repair_controllers():
		if repair.has_method("is_side_repairing") and bool(repair.call("is_side_repairing", side)):
			return true
	return false


func _screwdriver_count() -> int:
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("get_tool_count"):
		return int(state.call("get_tool_count", "screwdriver"))
	return 1


func _connect_screw_signal(repair: Node, signal_name: StringName, method_name: StringName) -> void:
	if repair == null or not repair.has_signal(signal_name):
		return
	var callable := Callable(self, String(method_name)).bind(repair)
	if not repair.is_connected(signal_name, callable):
		repair.connect(signal_name, callable)


func _screw_event_key(repair: Node, index: int) -> String:
	return "%s:%d" % [str(repair.get_instance_id()), index]


func _on_screw_loosened(index: int, repair: Node) -> void:
	var key := _screw_event_key(repair, index)
	if _screw_active_events.has(key):
		return
	_screw_started_count += 1
	_screw_active_events[key] = {
		"loosened_elapsed": _night_elapsed,
		"repair_started_elapsed": -1.0,
	}


func _on_screw_repair_started(index: int, repair: Node) -> void:
	# The player pulls the matching hand off the robot to hold the screwdriver,
	# so hide that hand for the duration of the screwdriver animation.
	_set_repair_hand_hidden_for_screw(repair, index, true)
	var key := _screw_event_key(repair, index)
	if not _screw_active_events.has(key):
		return
	var event: Dictionary = _screw_active_events[key]
	event["repair_started_elapsed"] = _night_elapsed
	_screw_active_events[key] = event


func _on_screw_repair_interrupted(index: int, repair: Node) -> void:
	_set_repair_hand_hidden_for_screw(repair, index, false)
	var key := _screw_event_key(repair, index)
	if not _screw_active_events.has(key):
		return
	var event: Dictionary = _screw_active_events[key]
	event["repair_started_elapsed"] = -1.0
	_screw_active_events[key] = event


func _on_screw_repaired(index: int, repair: Node) -> void:
	# Animation is over: the hand can return to its resting pose.
	_set_repair_hand_hidden_for_screw(repair, index, false)
	var key := _screw_event_key(repair, index)
	if not _screw_active_events.has(key):
		return
	var event: Dictionary = _screw_active_events[key]
	var response_elapsed := float(event.get("repair_started_elapsed", -1.0))
	if response_elapsed < 0.0:
		response_elapsed = _night_elapsed
	var loosened_elapsed := float(event.get("loosened_elapsed", response_elapsed))
	var paused_seconds := _consequence_pause_overlap_seconds(loosened_elapsed, response_elapsed)
	var response_seconds := maxf(0.0, response_elapsed - loosened_elapsed - paused_seconds)
	if response_seconds > maxf(0.0, screw_response_grace_seconds):
		_screw_late_count += 1
		_screw_late_penalty_total += maxf(0.0, screw_late_penalty_percent)
	_screw_repaired_count += 1
	_screw_active_events.erase(key)


func _set_repair_hand_hidden_for_screw(repair: Node, index: int, hidden: bool) -> void:
	if stress_test_robot == null or not stress_test_robot.has_method("set_repair_hand_hidden"):
		return
	if repair == null:
		return
	# Hide the hand that actually drives the screw. For flipped limb screws that
	# is the opposite hand, so prefer the hand-side query when the controller
	# exposes it, falling back to the plain body side otherwise.
	var side := ""
	if repair.has_method("hand_side_for_screw"):
		side = String(repair.call("hand_side_for_screw", index))
	elif repair.has_method("side_for_screw"):
		side = String(repair.call("side_for_screw", index))
	if side.is_empty():
		return
	stress_test_robot.call("set_repair_hand_hidden", side, hidden)


func _update_screw_batches() -> void:
	if _night_elapsed < maxf(0.0, screw_spawn_start_buffer_seconds):
		return
	if _night_elapsed > night_duration_seconds - maxf(0.0, screw_spawn_end_buffer_seconds):
		return
	if _night_elapsed < _next_screw_batch_elapsed:
		return

	_next_screw_batch_elapsed = _night_elapsed + _random_screw_batch_interval()
	for repair in _screw_repair_controllers():
		if not repair.has_method("loosen_screws"):
			continue
		var count := _rng.randi_range(0, maxi(0, screw_batch_max_per_limb))
		if count > 0:
			repair.call("loosen_screws", count)


func _random_screw_batch_interval() -> float:
	var low := maxf(0.1, minf(screw_batch_interval_min_seconds, screw_batch_interval_max_seconds))
	var high := maxf(low, screw_batch_interval_max_seconds)
	return _rng.randf_range(low, high)


func _update_electricity_summary_time(delta: float) -> void:
	if delta <= 0.0:
		return
	var low := minf(electricity_target_min_percent, electricity_target_max_percent)
	var high := maxf(electricity_target_min_percent, electricity_target_max_percent)
	if _is_electricity_consequence_paused() or (_electricity_percent >= low and _electricity_percent <= high):
		_electricity_target_elapsed += delta


func _is_electricity_consequence_paused() -> bool:
	return _night_elapsed < _electricity_consequence_pause_until


func _can_start_emergency_consequence_pause() -> bool:
	return _window_alert_state != WINDOW_ALERT_NONE


func _start_emergency_consequence_pause() -> void:
	var duration := maxf(0.0, emergency_power_electricity_consequence_pause_seconds)
	if duration <= 0.0:
		return
	var pause_start := _night_elapsed
	var pause_end := pause_start + duration
	_electricity_consequence_pause_until = maxf(_electricity_consequence_pause_until, pause_end)
	if not _consequence_pause_intervals.is_empty():
		var last_index := _consequence_pause_intervals.size() - 1
		var last_interval := _consequence_pause_intervals[last_index]
		if pause_start <= last_interval.y:
			last_interval.y = maxf(last_interval.y, pause_end)
			_consequence_pause_intervals[last_index] = last_interval
			return
	_consequence_pause_intervals.append(Vector2(pause_start, pause_end))


func _consequence_pause_overlap_seconds(start_elapsed: float, end_elapsed: float) -> float:
	var window_start := minf(start_elapsed, end_elapsed)
	var window_end := maxf(start_elapsed, end_elapsed)
	if window_end <= window_start:
		return 0.0
	var total := 0.0
	for interval in _consequence_pause_intervals:
		var overlap_start := maxf(window_start, interval.x)
		var overlap_end := minf(window_end, interval.y)
		if overlap_end > overlap_start:
			total += overlap_end - overlap_start
	return total


func _complete_stress_test_success() -> void:
	if _night_finished:
		return
	if _is_intro_tutorial_stress_test():
		_finish_intro_tutorial_stress_test()
		return
	_begin_stress_test_summary(
		true,
		"",
		{
			"money_delta": 0,
			"suspicion_delta": 0,
			"anger_delta": -10,
			"ingredients": {},
			"skip_advance": false,
		},
		false,
		true
	)


func _handle_night_timer_finished() -> void:
	if _is_intro_tutorial_stress_test():
		_finish_intro_tutorial_stress_test()
		return
	var electricity := _electricity_summary()
	if float(electricity.get("score", 0.0)) < electricity_low_end_score_threshold:
		_fail_stress_test(electricity_low_end_failure_text, false)
		return
	_complete_stress_test_success()


func _is_screw_repair_animation_active() -> bool:
	for repair in _screw_repair_controllers():
		if repair.has_method("is_repairing") and bool(repair.call("is_repairing")):
			return true
	return false


func _fail_robot_wake() -> void:
	_fail_stress_test(wake_button_failure_text, true)


func _fail_stress_test(reason: String, registers_wake: bool) -> void:
	if _night_finished:
		return
	if _is_intro_tutorial_stress_test():
		_begin_intro_tutorial_failure(reason)
		return
	_begin_stress_test_summary(
		false,
		reason,
		{
			"money_delta": 0,
			"suspicion_delta": 0,
			"anger_delta": 0,
			"ingredients": {},
			"skip_advance": false,
		},
		registers_wake,
		false
	)


func _begin_intro_tutorial_failure(reason: String) -> void:
	_intro_failure_restart_pending = true
	_begin_stress_test_summary(
		false,
		reason,
		{
			"money_delta": 0,
			"suspicion_delta": 0,
			"anger_delta": 0,
			"ingredients": {},
			"skip_advance": true,
		},
		false,
		false
	)


func _is_intro_tutorial_stress_test() -> bool:
	return GameState.is_intro_step("stress_test")


func _finish_intro_tutorial_stress_test() -> void:
	if _night_finished:
		return
	_night_finished = true
	_stop_generator_power_sound()
	_stop_night_ambient()
	_hide_mouse_tooltip()
	_set_stress_test_interaction_enabled(false)
	finish(0, 0, 0, {}, false)


func _begin_stress_test_summary(
		success: bool,
		reason: String,
		result: Dictionary,
		registers_wake: bool,
		registers_completion: bool
) -> void:
	_night_finished = true
	_clear_patrol_drone()
	_stop_generator_power_sound()
	_stop_night_ambient()
	_hide_mouse_tooltip()
	_set_stress_test_interaction_enabled(false)
	_summary_success = success
	_summary_reason = reason
	_summary_result = result
	_summary_registers_completion = registers_completion
	_pending_failure_registers_wake = registers_wake
	_dragging_gas_valve = false
	_update_summary_text()

	if failure_overlay == null:
		_finish_stress_test_summary()
		return

	var main := _main_controller()
	if main != null and main.has_method("play_current_fullscreen_transition"):
		_failure_transition_playing = true
		var played := bool(main.call(
			"play_current_fullscreen_transition",
			Callable(self, "_show_failure_overlay"),
			Callable(self, "_on_failure_transition_finished")
		))
		if played:
			return

	_show_failure_overlay()
	_on_failure_transition_finished()


func _update_summary_text() -> void:
	if failure_title_label != null:
		failure_title_label.text = "You failed" if _intro_failure_restart_pending else summary_title_text
	if failure_reason_label != null:
		failure_reason_label.text = _build_summary_text()
	if failure_continue_button != null:
		failure_continue_button.text = "RETRY" if _intro_failure_restart_pending else "CONTINUE"


func _build_summary_text() -> String:
	if _intro_failure_restart_pending:
		return _summary_reason if not _summary_reason.is_empty() else "The stress test has to be repeated."

	var lines: Array[String] = []
	if _summary_success:
		lines.append("Result: %s" % summary_success_text)
	else:
		lines.append("Result: Failed")
		if not _summary_reason.is_empty():
			lines.append("Reason: %s" % _summary_reason)

	var electricity := _electricity_summary()
	lines.append("Electricity Flow: %s  %.0f%% in range" % [
		_stars_for_score(float(electricity["score"])),
		float(electricity["target_ratio"]) * 100.0,
	])

	var screws := _screw_summary()
	lines.append("Screws: %s  %.0f%% score" % [
		_stars_for_score(float(screws["score"])),
		float(screws["score"]),
	])
	return "\n".join(lines)


func _electricity_summary() -> Dictionary:
	var duration := maxf(0.001, minf(_night_elapsed, night_duration_seconds))
	var target_ratio := clampf(_electricity_target_elapsed / duration, 0.0, 1.0)
	var required_ratio := maxf(0.001, electricity_five_star_required_ratio)
	var score := clampf((target_ratio / required_ratio) * 100.0, 0.0, 100.0)
	return {
		"target_ratio": target_ratio,
		"score": score,
	}


func _screw_summary() -> Dictionary:
	var expected_count := maxi(0, _screw_started_count)
	var unrepaired_count := _screw_active_events.size()
	var score := 100.0
	score -= _screw_late_penalty_total
	score -= float(unrepaired_count) * maxf(0.0, screw_unrepaired_penalty_percent)

	if expected_count > 0:
		var completion_ratio := clampf(float(_screw_repaired_count) / float(expected_count), 0.0, 1.0)
		var target_ratio := clampf(screw_completion_target_ratio, 0.0, 1.0)
		if completion_ratio < target_ratio:
			var step := maxf(0.1, screw_completion_penalty_step_percent)
			var deficit_percent := (target_ratio - completion_ratio) * 100.0
			score -= ceil(deficit_percent / step) * step

	return {
		"score": clampf(score, 0.0, 100.0),
		"expected_count": expected_count,
		"repaired_count": _screw_repaired_count,
		"late_count": _screw_late_count,
		"unrepaired_count": unrepaired_count,
	}


func _stars_for_score(score: float) -> String:
	var full_count := clampi(int(floor(clampf(score, 0.0, 100.0) / 20.0)), 0, 5)
	var stars := ""
	for i in range(5):
		stars += "★" if i < full_count else "☆"
	return stars


func _show_failure_overlay() -> void:
	if failure_overlay == null:
		return
	_update_summary_text()
	failure_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	failure_overlay.visible = true
	if failure_continue_button != null:
		failure_continue_button.disabled = true


func _on_failure_transition_finished() -> void:
	_failure_transition_playing = false
	if failure_continue_button != null:
		failure_continue_button.disabled = false
	get_tree().paused = true


func _main_controller() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("play_current_fullscreen_transition"):
			return node
		node = node.get_parent()
	return null


func _finish_stress_test_summary() -> void:
	if _failure_result_emitted:
		return
	_failure_result_emitted = true
	get_tree().paused = false
	if _summary_registers_completion:
		DayCycle.register_stress_test_completed()
		_summary_registers_completion = false
	if _pending_failure_registers_wake:
		DayCycle.register_stress_test_wake()
		_pending_failure_registers_wake = false
	finish(
		int(_summary_result.get("money_delta", 0)),
		int(_summary_result.get("suspicion_delta", 0)),
		int(_summary_result.get("anger_delta", 0)),
		_summary_result.get("ingredients", {}),
		bool(_summary_result.get("skip_advance", false))
	)


func _on_end_button_pressed() -> void:
	if _is_intro_tutorial_stress_test():
		return
	_complete_stress_test_success()


func _on_wake_button_pressed() -> void:
	_fail_robot_wake()


func _on_give_up_button_pressed() -> void:
	if _night_finished:
		return
	_night_finished = true
	_stop_generator_power_sound()
	_stop_night_ambient()
	_set_stress_test_interaction_enabled(false)
	finish(0, 0, 0, {}, false)


func _on_failure_continue_button_pressed() -> void:
	if _failure_transition_playing:
		return
	if _intro_failure_restart_pending:
		_restart_intro_tutorial_stress_test()
		return
	_finish_stress_test_summary()


func _restart_intro_tutorial_stress_test() -> void:
	_intro_failure_restart_pending = false
	get_tree().paused = false
	var main := _main_controller()
	if main != null and main.has_method("restart_intro_current_step"):
		main.call("restart_intro_current_step")
	else:
		get_tree().reload_current_scene()


func _update_intro_head_interaction_gate() -> void:
	if not _is_intro_tutorial_stress_test():
		return
	if _intro_head_interaction_unlocked:
		return
	var remaining := maxf(0.0, night_duration_seconds - _night_elapsed)
	if remaining > maxf(0.0, intro_head_interaction_unlock_remaining_seconds):
		return
	_intro_head_interaction_unlocked = true
	_set_robot_interaction_enabled(true)


func _set_robot_interaction_enabled(value: bool) -> void:
	if stress_test_robot != null and stress_test_robot.has_method("set_interaction_enabled"):
		var enabled := value
		if _is_intro_tutorial_stress_test():
			enabled = enabled and _intro_head_interaction_unlocked
		stress_test_robot.call("set_interaction_enabled", enabled)


func _set_stress_test_interaction_enabled(value: bool) -> void:
	_set_robot_interaction_enabled(value)
	for repair in _screw_repair_controllers():
		if repair.has_method("set_completion_enabled"):
			repair.call("set_completion_enabled", value)
	if pull_cord != null:
		pull_cord.set_process_input(value)
	if electrical_cord != null:
		electrical_cord.set_process_input(value)
	if not value and gas_valve != null:
		gas_valve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not value and emergency_power_button != null:
		emergency_power_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
