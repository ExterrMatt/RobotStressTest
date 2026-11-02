extends LocationBase

## Furthest out: the whole shed fitted on screen (_full_scene_rect).
const ZOOM_LEVEL_FULL: int = -1
## Zoomed out at the scene's base scale; WASD slides the camera around (free pan).
const ZOOM_LEVEL_OUT: int = 0
const ZOOM_LEVEL_FIRST: int = 1
const ZOOM_LEVEL_SECOND: int = 2
const MAX_ZOOM_LEVEL: int = ZOOM_LEVEL_SECOND
# Fallback zoom scales for a level when no specific region is active. Scaled to the
# square 800-tall base so they match the old 4:3 framing (800/300 and 800/200); the
# named region cameras compute their own scale in _zoom_scale_for_region.
const FIRST_ZOOM_SCALE: Vector2 = Vector2(2.6667, 2.6667)
const SECOND_ZOOM_SCALE: Vector2 = Vector2(4.0, 4.0)
const ZOOMED_OUT_SCALE: Vector2 = Vector2.ONE
const BASE_SCENE_SIZE: Vector2 = Vector2(1200.0, 800.0)
## The whole shed in scene coordinates once it is pulled apart: the sideways left wall
## (out past x -1650) to the right wall's edge, the lifted roof (y -600) down to the
## floor. The upside-down bottom section below the black gap is left out. ZOOM_LEVEL_FULL
## fits this on screen, and the ZOOM_LEVEL_OUT free pan stops at its edges.
const FULL_SCENE_RECT: Rect2 = Rect2(-1700.0, -600.0, 3300.0, 1400.0)
## The shed art is one Aseprite canvas (1800 wide) with three walls side by side: the
## left wall (Aseprite x 0-550), the front (550-1250) and the right wall (1250-1800).
## At load the side walls are pulled apart from the front by SIDE_WALL_GAP pixels each
## way, leaving a black "bridge" between the walls (see _split_shed). In scene
## coordinates (Aseprite x - 600) the cuts sit at these x positions.
const SIDE_WALL_LEFT_CUT_X: float = -50.0
const SIDE_WALL_RIGHT_CUT_X: float = 650.0
const SIDE_WALL_GAP: float = 400.0
## The roof and the front wall above FRONT_FLOOR_Y (the window, curtains, gas tank and
## its mechanicals) are also lifted this far off the table and floor, leaving black
## between them (see _split_shed).
const FRONT_LIFT: float = 200.0
## Scene y where the front wall ends and the table / floor begin: just under the gas
## tank's mechanicals and the front darkness, just above the table top.
const FRONT_FLOOR_Y: float = 415.0
## Thinnest piece (scene px) a layer is cut into when the shed is pulled apart; a cut
## closer than this to a layer's edge is skipped (see _shed_pieces).
const SHED_MIN_PIECE_PX: float = 4.0
## Roof layers never go sideways with a wall: the roof runs over all three walls, so it
## lifts with the front.
const SHED_ROOF_LAYERS: Array[StringName] = [&"Roof", &"LightsOffRoof", &"DarkTop"]
## Table layers never go right with the right wall: the side table by the robot's table,
## and the table darkness over it, poke past that wall's seam but belong to the table.
## (Any part over the left wall still goes with it: the table darkness reaches under it.)
const SHED_TABLE_LAYERS: Array[StringName] = [&"SideTable", &"SideTable2", &"LightsOffTable", &"DarkTable"]
## The pulled-out left wall is also laid on its side, turned 90 degrees counterclockwise
## about the left area view's centre, so the camera turns a quarter clockwise to look at
## it upright (like the upside-down bottom section, but a quarter turn).
const LEFT_WALL_TURN: float = -PI / 2.0
## The left wall is pulled this much further out than the right one, so the black between
## it and the front is wider than a whole view: the window<->left slide turns the camera
## there while nothing at all is on screen (see _black_slide_pan_to).
const LEFT_WALL_EXTRA_GAP: float = 700.0
## Extra black (scene px) kept between the edge of the screen and the left wall when the
## slide snaps its turn.
const LEFT_SLIDE_BLACK_MARGIN: float = 24.0
## Free pan at ZOOM_LEVEL_OUT: top speed (scene px per second) and how quickly the
## camera gets up to speed / slides to a stop.
const FREE_PAN_SPEED: float = 700.0
const FREE_PAN_RESPONSE: float = 8.0

## Engine lever (lever_sheet.png): a vertical strip of 96x96 frames, one per stage.
signal lever_stage_changed(stage: int)
const LEVER_FRAME_SIZE: float = 96.0
## Handle centre (y, in frame pixels) for each stage. Dragging snaps to the stage
## whose handle is nearest the cursor, so the lever tracks the mouse precisely.
const LEVER_HANDLE_Y: Array[float] = [20.5, 26.5, 31.5, 38.5, 45.5, 56.5, 63.5, 68.5, 76.5]
const LEVER_STAGE_COUNT: int = 9
## The clickable lever box inside each frame (the art's bounds).
const LEVER_BOX: Rect2 = Rect2(22.0, 13.0, 51.0, 69.0)
## How much the debug speedrun accelerates the night.
const DEBUG_SPEEDRUN_TIME_SCALE: float = 10.0
const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
## The camera views that look at the robot on the table (head, body, torso, legs),
## across both zoom levels (the vertical navigation between them mixes levels).
const TABLE_VIEW_ZOOM_REGIONS: Array[StringName] = [
	&"Zoom1_R1_C1",
	&"Zoom1_R3_C1",
	&"Zoom2_R2_C1",
	&"Zoom2_R3_C1",
	&"Zoom2_R4_C1",
]
## The engine (generator) camera, over on the right. Panning between it and any of
## the table views swings along a curved path (see _curved_pan_to_region) that bows
## down toward the scene's bottom-right corner instead of tracking a straight diagonal.
const ENGINE_ZOOM_REGION: StringName = &"Zoom1_R1_C3"
## The window camera (top-left). Panning between it and the engine also curves, but
## bows the opposite way - up toward the top-right corner - so it hugs the top.
const WINDOW_ZOOM_REGION: StringName = &"Zoom1_R0_C1"
## Placeholder side views of the shed's newer areas: the left section and the
## bottom section. They sit outside the WASD grid (see _side_area_neighbor): A from
## any table view (or the window) looks left and D comes back; S from the lowest table view looks
## down and S again comes back (the view is upside down, so "down" leads out). The bottom section (the art's bottom third) is laid out
## upside down below a black gap, so the camera pans down into the black, flips
## 180 degrees there unseen, then carries on into it (see _black_gap_pan_to).
const LEFT_AREA_ZOOM_REGION: StringName = &"Zoom1_LeftArea"
const BOTTOM_AREA_ZOOM_REGION: StringName = &"Zoom1_BottomArea"
const SIDE_AREA_ZOOM_REGIONS: Array[StringName] = [
	LEFT_AREA_ZOOM_REGION,
	BOTTOM_AREA_ZOOM_REGION,
]
## Which curved-pan hop a transition is (see _curved_pan_hop): each kind picks its own
## corner to bow toward and its own pair of roll angles.
const CURVED_PAN_NONE: int = 0
const CURVED_PAN_TABLE_GENERATOR: int = 1
const CURVED_PAN_WINDOW_GENERATOR: int = 2
## The table<->left-area hop: the table<->generator swing mirrored to the left, turning
## onto the sideways left wall and eased like the window<->left slide (see
## _turning_swing_pan_to).
const CURVED_PAN_TABLE_LEFT: int = 3
## The window<->left-area hop. Not curved: a straight sideways slide that turns the
## camera in the black between the walls (see _black_slide_pan_to).
const CURVED_PAN_WINDOW_LEFT: int = 4
## Peak of pow(p, 6) * (1 - p) (at p = 6/7), used to normalise the arrival overshoot
## bump so curved_pan_bounce reads as roughly the fraction of overshoot past the target.
const OVERSHOOT_BUMP_PEAK: float = 0.0566578
const ZOOM_DURATION: float = 0.35
const MOUSE_TOOLTIP_SCRIPT: GDScript = preload("res://scenes/ui/MouseFollowTooltip.gd")
const RIP_CORD_FULL_EXTEND_SOUND_PATH := "res://assets/sounds/rip_cord/ripcord.mp3"
const GENERATOR_HUM_SOUND_PATH := "res://assets/sounds/generator/generator_hum.mp3"
const GENERATOR_CHUG_SOUND_PATH := "res://assets/sounds/generator/generator_chug.mp3"
const GENERATOR_SHUTTING_OFF_SOUND_PATH := "res://assets/sounds/generator/generator_shutting_off.mp3"
const GENERATOR_NO_POWER_SOUND_PATH := "res://assets/sounds/generator/generator_no_power.mp3"
const EMERGENCY_POWER_BUTTON_SOUND_PATH := "res://assets/sounds/emergency_button/emergency_power_button.mp3"
## Zap played when the emergency button drives off a patrol drone at the window.
const ZAP_SOUND_PATH := "res://assets/sounds/zap/zap_3.mp3"
const ZAP_VOLUME_SCALE: float = 0.25
## Jump-scare sting played when the patrol drone catches a player who was not
## looking at the window, as the camera is forced over to the drone.
const JUMPSCARE_SOUND_PATH := "res://assets/sounds/bass/jumpscare.mp3"
const JUMPSCARE_VOLUME_SCALE: float = 0.798
## Gunshot played the instant the patrol drone actually fires.
const GUNSHOT_SOUND_PATH := "res://assets/sounds/drone/gun_shot.mp3"
## Awareness / endurance meters and the stress-indicator eyes, shared with the
## Sleep scene (see RobotAwareness.gd).
const RobotAwareness := preload("res://scenes/locations/RobotAwareness.gd")
const GUNSHOT_VOLUME_SCALE: float = 0.665
## When the night ends and the results screen wipes in, every night sound fades to
## silence over this many seconds (starting from whatever was playing) and is then
## hard-stopped - so nothing bleeds through the wipe or resumes for a sliver when
## the player continues to the bedroom. Kept under the results wipe's cover time.
const SUMMARY_AUDIO_FADE_SECONDS: float = 0.4
## Target volume for the fade: low enough to be inaudible before the hard stop.
const SUMMARY_AUDIO_SILENCE_DB: float = -60.0
## The forced camera yank onto the drone pans at this multiple of the normal
## camera speed (2x = half the usual pan time).
const FORCED_LOOK_PAN_SPEED_MULTIPLIER: float = 2.0
## The running generator hum/chug loops (and the out-of-battery chug) play at 20%.
const GENERATOR_VOLUME_SCALE: float = 0.2
## The manual emergency-button powering-off sound, at 17.5% (half of its old 35%).
const GENERATOR_SHUTTING_OFF_VOLUME_SCALE: float = 0.175
## The rip-cord pull plays at a quarter volume.
const RIP_CORD_VOLUME_SCALE: float = 0.25
const NIGHT_AMBIENT_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/night_sounds/3_min_night_sounds.mp3",
]
const NIGHT_AMBIENT_LOUD_VOLUME_SCALE: float = 0.5

# One-off night flyovers/sirens layered over the ambient bed. Each night we roll,
# once per in-game minute, whether these play; a hit is scheduled at a random
# moment inside that minute (never exactly on the minute boundary).
const PLANE_SOUND_PATH: String = "res://assets/sounds/night_sounds/plane_fly_by.mp3"
## The plane fly-by plays at 25% volume.
const PLANE_VOLUME_SCALE: float = 0.25
## The police sirens play at 15% volume.
const POLICE_SIREN_VOLUME_SCALE: float = 0.15
## Police sirens: two distinct clips, each of which may play at most once a night.
const POLICE_SIREN_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/night_sounds/police_sirens_1.mp3",
	"res://assets/sounds/night_sounds/police_sirens_2.mp3",
]
## Length of one "minute" of night for the per-minute probability rolls.
const NIGHT_SPECIAL_MINUTE_SECONDS: float = 60.0
## Per-minute odds: the plane has a 1-in-30 chance, each siren roll a 1-in-5.
const PLANE_CHANCE_ONE_IN: int = 30
const POLICE_CHANCE_ONE_IN: int = 5
## Old-house wood creaking, rolled like the sirens but a touch more likely
## (1-in-4 per minute vs the sirens' 1-in-5). Plays quietly and can recur through
## the night, but never overlaps itself.
const WOOD_CREAK_SOUND_PATH: String = "res://assets/sounds/wood/random_creaking.mp3"
const WOOD_CREAK_VOLUME_SCALE: float = 0.06
const WOOD_CREAK_CHANCE_ONE_IN: int = 4
## A scheduled hit fires at a random point within its minute, kept clear of the
## minute's very start and end so it never lands right on a boundary.
const NIGHT_SPECIAL_MIN_OFFSET: float = 1.0
const NIGHT_SPECIAL_MAX_OFFSET: float = 59.0
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
## Awareness fail threshold added for each in-game day that has already passed
## (Day 1 gets +0, Day 2 +10, and so on). Real nights only.
const AWARENESS_THRESHOLD_PER_DAY: float = 10.0
const TORSO_SCREW_INDEX_LEFT_WAIST: int = 2
const TORSO_SCREW_INDEX_RIGHT_WAIST: int = 3
const LEG_SCREW_INDEX_INNER_KNEE: int = 2
@export_group("Night Timer")
@export var night_duration_seconds: float = 60.0
@export var intro_tutorial_duration_seconds: float = 30.0
@export var intro_head_interaction_unlock_remaining_seconds: float = 5.0

@export_group("Electricity & Generator")
## Electricity supplied at each engine-lever stage, from stage 0 (handle fully up)
## to the last stage (fully down). While the generator runs, the meter sits exactly
## at the lever's value - there is no drain.
@export var lever_stage_electricity_percents: Array[float] = [120.0, 105.0, 90.0, 75.0, 60.0, 45.0, 30.0, 15.0, 0.0]
## Lever stage each night starts on (8 = handle fully down, 0% electricity).
@export_range(0, 8) var lever_start_stage: int = 8
## Chance that one full rip-cord pull restarts a stopped generator.
@export_range(0.0, 1.0, 0.01) var generator_ripcord_start_chance: float = 0.25
## Pity timer: this many rip cord pulls on a stopped generator always restarts it,
## however unlucky the rolls before it were.
@export var generator_ripcord_guaranteed_pull: int = 5
## How fast the electricity meter eases toward the lever's level (percent per
## second), instead of snapping straight to it.
@export var electricity_change_percent_per_second: float = 40.0
@export var electricity_wake_threshold_percent: float = 130.0
@export var electricity_meter_visual_max_percent: float = 105.0
@export var electricity_low_end_score_threshold: float = 25.0
## Electricity produced over the night (scored at the end, see End Summary): it starts
## at 0 and adds this many units per second with the meter at 100%, scaling down to
## nothing at 0%...
@export var electricity_produced_per_second_at_full: float = 20.0
## ...and this many per second at ELECTRICITY_OVERLOAD_PERCENT (120%), rising in a
## straight line from the 100% rate; past it the rate holds there.
@export var electricity_produced_per_second_at_overload: float = 40.0
const ELECTRICITY_OVERLOAD_PERCENT: float = 120.0

@export_group("Gas")
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
@export var emergency_power_electricity_decay_per_second: float = 200.0
@export var emergency_power_electricity_consequence_pause_seconds: float = 6.0

@export_group("Awareness")
## The robot's awareness of being tampered with. It climbs as the player moves
## her parts and decays while she is left alone; if it reaches the (doublable)
## fail threshold the night ends because you woke her up.
@export var awareness_fail_threshold: float = 100.0
## Awareness added the moment the emergency power-off button is pressed.
@export var awareness_emergency_button_gain: float = 15.0
## Power below the power-gain start percent (50%) lowers awareness while she is
## left undisturbed: 0/s at that percent, scaling up to this rate at 0% power.
@export var awareness_decay_max_per_second: float = 15.0
## Power above the start percent steadily raises awareness: 0/s at the start
## percent, scaling up to the full rate at 100% power, then on up to the overload
## rate at the overload percent (and held there past it).
@export var awareness_power_gain_start_percent: float = 50.0
@export var awareness_power_gain_full_per_second: float = 5.0
@export var awareness_power_gain_overload_percent: float = 120.0
@export var awareness_power_gain_overload_per_second: float = 10.0
## Awareness added per second for every screw currently loose on the robot
## (from when it loosens until it is repaired).
@export var awareness_per_loose_screw_per_second: float = 1.5

@export_group("Loose Screws")
## Screws only loosen while the power is at or above this percent, one at a time.
## The gap between screws scales from the min-power interval at this percent down
## to the full-power interval at 100%, and is the overload interval above 100%.
## Every gap also gets a random bonus of a few seconds on top.
@export var screw_spawn_min_power_percent: float = 51.0
@export var screw_interval_at_min_power_seconds: float = 10.0
@export var screw_interval_at_full_power_seconds: float = 5.0
@export var screw_interval_overload_seconds: float = 3.0
@export var screw_interval_bonus_min_seconds: float = 1.0
@export var screw_interval_bonus_max_seconds: float = 3.0
@export_range(0.0, 1.0, 0.01) var screw_electrical_pull_chance: float = 0.25
@export var screw_response_grace_seconds: float = 7.0
@export var screw_late_penalty_percent: float = 5.0
## How many times longer a screw repair takes while the lights are off.
@export var screw_repair_lights_off_duration_multiplier: float = 2.0
## Foundational nudge for the bare-hand screwing animation, in base scene
## pixels, authored against the left side. Applied on top of the automatic
## centering for every screw on every limb, so a constant misalignment can be
## corrected once here. Positive x moves it right, positive y moves it down.
## The right side's animation is mirrored, so its horizontal component is
## negated automatically to stay aligned.
@export var hand_screw_animation_offset: Vector2 = Vector2.ZERO

@export_group("Electrical Shorts")
## Electrical shorts (RobotZaps): zap bolts that pop up on her body every so often, each
## adding awareness until fixed with the raw part it needs (ZapFixMinigame). Ordering
## that part from the night store eases the zap to the reduced rate for a while. Debug
## mode only for now: outside it no zaps spawn.
@export var zap_spawn_interval_range: Vector2 = Vector2(35.0, 70.0)
@export var zap_max_active: int = 3
@export var zap_awareness_per_second: float = 2.0
@export var zap_reduced_awareness_per_second: float = 1.0
@export var zap_reduced_seconds: float = 30.0

@export_group("Robot")
## Every robot limb move first plays a random repair minigame; the limb only moves if
## the minigame is won (see StressTestRobot.limb_move_minigames_enabled).
@export var limb_move_minigames_enabled: bool = true
## How far (scene px) a bare-head robot sits lower on the table.
@export var head_only_drop_px: float = 57.0

@export_group("Uncle (Window Alert)")
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
## Without the curtains upgrade, lights off alone keeps the player safe, but the
## uncle lingers this many times longer before leaving.
@export var window_alert_no_curtains_leave_multiplier: float = 2.0
@export var window_alert_seen_failure_seconds: float = 3.0
@export var window_alert_indicator_flash_seconds: float = 0.35

## A patrol drone that appears at the window at random moments through the
## night, the same way the uncle does. Position and scale the Drone node in the
## scene to place it; these control the timing of the encounter.
@export_group("Patrol Drone")
@export_subgroup("At The Window")
## Average seconds between drone appearances. Actual gaps vary randomly around
## this, so the drone shows up roughly once per this many seconds.
@export var drone_average_interval_seconds: float = 60.0
## Appearances are never scheduled within this many seconds of the night's
## start or end.
@export var drone_edge_exclusion_seconds: float = 5.0
## No drone may attack within this many seconds of the night's start.
@export var drone_opening_grace_seconds: float = 15.0
## After a drone leaves (zapped, curtained off, ...), the next one can't arrive for a
## random number of seconds in this range (x = min, y = max).
@export var drone_cooldown_seconds_range: Vector2 = Vector2(15.0, 30.0)
## Seconds the drone simply sits there before it readies its guns.
@export var drone_idle_seconds: float = 5.0
## Seconds the drone aims (guns texture) before it fires.
@export var drone_guns_seconds: float = 3.0
## Once the drone is locked on and about to fire (aim finished, and the forced
## camera look-up done if it was needed), it holds this long before the gunshot.
@export var drone_pre_shot_delay_seconds: float = 0.15
## Seconds the shot texture shows before the night is failed.
@export var drone_shot_seconds: float = 0.1
## Seconds the drone shows the electrocution placeholder (id texture) after the
## emergency button drives it off, before it disappears. Halved so the zap plays
## twice as fast and lasts half as long.
@export var drone_zap_seconds: float = 0.15
## Chance that shutting the curtains on a drone at the window drives it off (rolled once
## per drone) - a desperate last resort that rarely pays off.
@export_range(0.0, 1.0) var drone_curtain_escape_chance: float = 0.2
@export_subgroup("Laptop Route & Hacks")
## The drone's approach on the laptop's PATROL monitor (see DroneRoute): a random route
## across a grid this many nodes wide, flown this many seconds per edge, with a few
## checkpoints it pauses at.
@export var drone_route_grid_size: int = 5
@export var drone_route_seconds_per_edge: float = 2.0
@export var drone_checkpoint_count_min: int = 2
@export var drone_checkpoint_count_max: int = 3
@export var drone_checkpoint_pause_seconds: float = 3.0
## Chance that each checkpoint is a hack attempt (never the last checkpoint before home,
## and at most drone_hack_max_per_route per route). The drone sits there for
## drone_hack_buffer_seconds setting it up - clicking it on the PATROL monitor in that
## window foils the hack and stuns it (delaying its arrival) for a random
## drone_stun_seconds_range seconds. Otherwise the hack goes live - shown ONLY on the
## laptop, as a takeover warning screen - and the player has drone_hack_block_seconds
## to win a repair minigame on the laptop screen before it lands and cuts the power.
@export_range(0.0, 1.0) var drone_hack_chance: float = 0.1
@export var drone_hack_max_per_route: int = 2
@export var drone_hack_buffer_seconds: float = 4.0
@export var drone_hack_block_seconds: float = 15.0
@export var drone_stun_seconds_range: Vector2 = Vector2(1.0, 5.0)
@export_subgroup("Death Sequence")
## PROTOTYPE death sequence after the drone's shot: instead of failing at once, the
## camera pans upward (past the top of the background into black), then a red gradient
## sweeps down the screen, and only then does the night fail.
@export var drone_death_sequence_enabled: bool = true
## Seconds the camera takes to pan upward after the shot.
@export var drone_death_pan_seconds: float = 1.5
## How far the camera pans up, in visible screen heights (0.5 = the top half of the
## screen ends up black, above the background art).
@export var drone_death_pan_screens: float = 0.5
## Seconds the red gradient takes to sweep from the top to the bottom of the screen.
@export var drone_death_red_fade_seconds: float = 3.0
## Height of the soft leading edge of the red sweep, as a fraction of the screen.
@export var drone_death_red_softness: float = 0.35
@export var drone_death_red_color: Color = Color(0.7, 0.0, 0.0, 1.0)
## When on, the red sweep starts together with the pan instead of after it. The night
## fails once whichever of the two is longer has finished.
@export var drone_death_pan_and_red_together: bool = false
## Camera zoom applied during the pan (same duration and easing, centred on the screen).
## 1.0 = no zoom; above 1 zooms in (e.g. 1.3), below 1 zooms out (e.g. 0.8).
@export var drone_death_zoom: float = 1.0

@export_group("Lighting")
## Tint on the robot with the lights on / off.
@export var robot_lights_on_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var robot_lights_off_modulate: Color = Color(0.3, 0.3, 0.3, 1.0)
## Darkening applied to the whole curtain group when the lights are off. The curtains
## render above the lights-off layers (so a closed curtain covers the window instead
## of showing through its hole), so they are dimmed here to sink into the dark room
## rather than staying lit. Kept darker than the robot so the fabric reads as shadow.
@export var curtain_lights_off_modulate: Color = Color(0.12, 0.12, 0.14, 1.0)
## Darkening applied to the drone's deployed guns whenever they are out. The lit gun
## art reads clearly as guns but pops over the drone's shading at full bright, while
## the dedicated dark art is too dull to read - so the lit guns are dimmed to this
## level (in both light states, since the drone is shaded whenever present) to stay
## legible while sitting within the shadows.
@export var drone_guns_dim_modulate: Color = Color(0.5, 0.5, 0.52, 1.0)
## The flashlight (a tool from the laptop store): while it's owned and the lights are
## off, a circle that follows the mouse shines through every darkness layer in the shed.
## Inside flashlight_core_radius the darkness is cut away (by flashlight_core_strength,
## with a hard edge); past it the light drops straight to flashlight_edge_strength and
## fades out to nothing at flashlight_falloff_radius. Radii are in screen pixels
## (1280x720 space), so the beam stays the same size whatever the camera zoom.
@export_subgroup("Flashlight")
@export var flashlight_core_radius: float = 110.0
@export var flashlight_falloff_radius: float = 240.0
@export_range(0.0, 1.0) var flashlight_core_strength: float = 1.0
@export_range(0.0, 1.0) var flashlight_edge_strength: float = 0.5

@export_group("Camera")
@export_subgroup("Robot Framing")
## Vertical camera shift for the "new" head-camera framing: the panned-back
## "robot on the table" view (the Zoom2_R3_C1 region). Applied only when the
## robot has grown past a bare head into the chest / upper-arm stage but has not
## yet reached the full-body camera (no stomach/legs/forearm/hand) — see
## _robot_uses_new_head_camera(). Added to the framed view's screen-space Y:
## negative pushes the camera view down, positive up. A bare head and the
## full-body robot are both unaffected.
@export var head_only_camera_drop_px: float = -100.0
@export_subgroup("Mouse Follow")
## A subtle sway: while the camera rests on a view it drifts toward the mouse. These set
## how far (pixels) it drifts at full pull for each kind of view. 0 disables it for that
## view. The whole effect is also gated by the CAMERA SWAY setting.
@export var mouse_follow_strength_table: float = 24.0
## Drift while looking at the generator.
@export var mouse_follow_strength_generator: float = 24.0
## Drift while looking at the window.
@export var mouse_follow_strength_window: float = 24.0
## Universal multiplier on the horizontal (left-right) sway only, applied on top of every
## view's strength above. 1 = same as vertical; below 1 damps side-to-side drift; 0 makes
## the sway vertical-only; above 1 exaggerates it. Applies to all camera views.
@export_range(0.0, 3.0, 0.05) var mouse_follow_horizontal_strength: float = 1.0
## Edge softness: higher makes the pull toward the mouse saturate sooner, so it tapers
## off (exponentially) as the cursor approaches the screen edge - a natural smoothing so
## the camera never lurches when the mouse reaches the border.
@export_range(0.5, 8.0, 0.1) var mouse_follow_edge_falloff: float = 2.5
## How quickly the camera eases toward the mouse-follow target, per second. Higher is
## snappier, lower is floatier.
@export_range(1.0, 30.0, 0.5) var mouse_follow_smoothing: float = 8.0
@export_subgroup("Table-Window Pan")
## How long the look between the table and the window takes, in seconds. Lower = faster.
@export_range(0.05, 2.0, 0.01) var table_window_pan_duration: float = 0.35
## How much the pan speeds up through its midpoint (a smooth ease-in-out power): 1 = a
## straight, constant-speed move; 2 = quadratic (slow ends, fast middle); higher makes
## the ends slower and the midpoint punch through faster still.
@export_range(1.0, 6.0, 0.1) var table_window_mid_speedup: float = 2.5
@export_subgroup("Generator Pans")
## How far the curved table<->generator and window<->generator pans bow toward their
## corner (bottom-right for the table hop, top-right for the window hop). 0 = a straight
## line; 1.0 puts the route's midpoint halfway to that corner; higher bows it further.
## (The table<->left pan has its own: table_left_bow_1 / table_left_bow_2.)
@export var curved_pan_bow_strength: float = 1.0
## Table<->generator roll: degrees the view tilts to at the first keyframe.
@export var table_to_generator_rotation_1: float = 30.0
## Table<->generator roll: degrees the view tilts to at the second keyframe (then eases
## back to 0 by the end of the pan).
@export var table_to_generator_rotation_2: float = -30.0
## Table<->generator: progress (0-1) of the first roll keyframe - the roll reaches
## rotation_1 here (default a third of the way through the pan).
@export_range(0.0, 1.0, 0.01) var table_to_generator_keyframe_1: float = 0.33
## Table<->generator: progress (0-1) of the second roll keyframe - reaches rotation_2
## here, then eases to 0 (default two thirds through). Keep it above keyframe_1.
@export_range(0.0, 1.0, 0.01) var table_to_generator_keyframe_2: float = 0.66
## Window<->generator roll: degrees the view tilts to at the first keyframe.
@export var window_to_generator_rotation_1: float = 30.0
## Window<->generator roll: degrees the view tilts to at the second keyframe.
@export var window_to_generator_rotation_2: float = -30.0
## Window<->generator: progress (0-1) of the first roll keyframe.
@export_range(0.0, 1.0, 0.01) var window_to_generator_keyframe_1: float = 0.33
## Window<->generator: progress (0-1) of the second roll keyframe. Keep above keyframe_1.
@export_range(0.0, 1.0, 0.01) var window_to_generator_keyframe_2: float = 0.66
## When the roll finishes relative to the camera's arrival (both hops). 1.0 = the roll
## returns to level exactly as the camera settles; below 1 finishes it early (then holds
## level); above 1 delays it, letting the roll keep settling for a moment after the
## camera has arrived (the pan runs proportionally longer to make room).
@export_range(0.25, 2.0, 0.01) var rotation_settle: float = 1.0
## Arrival bounce (both hops). 0 = the camera eases cleanly into place; higher makes it
## sail a little past the target along its route and spring back, so it never snaps dead.
@export_range(0.0, 0.6, 0.01) var curved_pan_bounce: float = 0.0
@export_subgroup("Side View Pans")
## How much longer the window<->generator (right view), window<->left view and
## table<->left view hops take than the other curved hops. 1.0 = the same; 1.5 = half
## again as long.
@export_range(0.25, 4.0, 0.05) var window_side_pan_duration_scale: float = 1.5
## Seconds for each half of the move into or out of the bottom view: panning into
## the black gap, then (after the unseen flip) on to the destination.
@export var bottom_view_pan_seconds: float = 0.45
## The table<->left pan, split at its midpoint. The first half is the table end (the
## start of table -> left, the finish of left -> table); the second half is the left
## view's end. Left -> table plays the same pan backwards.
@export_subgroup("Table-Left First Half")
## How wide the route swings leaving the table: it heads out toward the bottom-left
## corner, and this sets how far. 0 = straight toward the left view; higher bends it further.
@export var table_left_bow_1: float = 0.8
## The camera's turn, first half (0 -> 45 degrees): how fast it runs. 1 = it takes half
## the pan; 2 = a quarter; and so on. It starts that long before table_left_turn_1_end
## (never before the pan starts).
@export_range(1.0, 6.0, 0.05) var table_left_turn_1_speed: float = 1.45
## The camera's turn, first half: where in the pan (0-1, from the table) it reaches 45
## degrees.
@export_range(0.05, 0.95, 0.01) var table_left_turn_1_end: float = 0.35
@export_subgroup("Table-Left Second Half")
## How wide the route swings coming into the left view. 0 = straight in; higher bends it
## further, out in the direction table_left_arrival_direction picks.
@export var table_left_bow_2: float = 0.8
## Which way the route comes into the left view, in quarter turns round it:
## 0 = up from below (the route runs low across the shed, then turns up into it);
## 1 = in from the right (it rises across the middle, then comes straight across);
## 2 = down from above; 3 and -1 = in from the left (looping round past the wall).
## In-between values come in diagonally (0.5 = from the lower right).
@export_range(-1.0, 3.0, 0.01) var table_left_arrival_direction: float = 0.0
## The camera's turn, second half (45 -> 90 degrees): how fast it runs, as for the first
## half. It never starts before the first half has finished, so a speed too slow to fit
## simply fills the time between the two end points.
@export_range(1.0, 6.0, 0.05) var table_left_turn_2_speed: float = 2.0
## The camera's turn, second half: where in the pan (0-1, from the table) the camera is
## fully turned onto the sideways left wall. Keep it after table_left_turn_1_end.
@export_range(0.1, 1.0, 0.01) var table_left_turn_2_end: float = 0.9

@export_group("HUD Text")
@export var timer_label_text: String = "Time"
@export var electricity_label_text: String = "Electricity"
@export var gas_label_text: String = "Gas"
@export var awareness_label_text: String = "Awareness"
## The endurance tuning lives on the RobotAwareness node.
@export var endurance_label_text: String = "Endurance"
@export var robot_endurance_label_text: String = "Robot Endurance"

@export_group("Failure Messages")
@export var awareness_failure_text: String = "You woke her up."
@export var gas_high_failure_text: String = "She woke up because you let the gas pressure rise too high."
@export var gas_low_failure_text: String = "She woke up because you let the gas pressure fall too low."
@export var electricity_failure_text: String = "She woke up because you over supplied her with electricity."
@export var electricity_low_end_failure_text: String = "You did not supply enough electricity to the robot during the stress test. Raise the generator lever to supply more, and pull the rip cord to restart the generator if it shuts off."
## The uncle caught you: with curtains to shut, and without.
@export var uncle_failure_text: String = "Your uncle caught you. Shut the curtains and turn off the lights to hide from him."
@export var uncle_failure_no_curtains_text: String = "Your uncle caught you. Turn off the lights to hide from him."
@export var drone_failure_text: String = "You were caught by a patrol drone. Hit the emergency button to fend it off."
@export var timeout_failure_text: String = "You ran out of time."
@export var wake_button_failure_text: String = "She woke up."

@export_group("End Summary")
@export var summary_title_text: String = "STRESS TEST SUMMARY"
@export var summary_success_text: String = "Stress test completed."
## A completed night's result on the results screen ("Result: Completed").
@export var summary_success_result_text: String = "Completed"
## Electricity scoring, against the night's full length in seconds (T): producing
## T x this is the break-even point - no change in anger. Less adds anger, up to
## electricity_anger_max_gain at 0 produced.
@export var electricity_break_even_per_second: float = 10.0
## Producing T x this removes the most anger (electricity_anger_max_removal), rising in
## a straight line from break-even. It counts as 100% on the results screen.
@export var electricity_top_score_per_second: float = 20.0
@export var electricity_anger_max_gain: int = 10
@export var electricity_anger_max_removal: int = 10
## Producing more than the top score also takes this off fatigue...
@export var electricity_bonus_fatigue_delta: int = -10
## ...and this off temporary suspicion.
@export var electricity_bonus_suspicion_delta: int = -5
@export_group("")

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
## The upside-down bottom section, sitting below the black gap (see _black_gap_center_y).
@onready var bottom_third: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/BottomThird
## Awareness, endurance and the stress-indicator eyes (shared with the Sleep scene).
@onready var awareness_meter: RobotAwareness = $RobotAwareness
@onready var first_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel1
@onready var second_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel2
@onready var light_placeholder: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder
## The lights-off layers (Aseprite lights_off_*), shown only while the lights are off.
## Each sits at its own depth in the shed art, matching the Aseprite stack.
@onready var lights_off_layers: Array[CanvasItem] = [
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/LightsOffFront,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/LightsOffTable,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/LightsOffRoof,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/LightsOffEngine,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/LightsOffLeft,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/BottomThird/LightsOffBottom,
	$FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/BottomThird/LightsOffEye,
]
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
# The bulb/lighting group renders above the curtains and the darkness overlays, so
# the lit bulb hangs in front of a closed curtain and the deactivated bulb is not
# hidden by the lights-off layers.
@onready var shed_light: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Light
@onready var bulb_on: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/BulbOn
@onready var bulb_off: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/BulbOff
## Curtain layers live above the lights-off layers so the closed
## curtain covers the window instead of showing through its transparent hole. The
## whole group is dimmed as one when the lights go out.
@onready var curtains_root: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Curtains
@onready var curtain_opened: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Curtains/CurtainOpened
@onready var curtain_closed: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Curtains/CurtainClosed
@onready var curtain_toggle: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/CurtainToggle
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
@onready var engine_lever: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Lever
@onready var emergency_power_button: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/EmergencyPowerButton
@onready var window_alert_rect: ColorRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/WindowAlertRect
@onready var window_alert_indicator: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/WindowAlertIndicator
@onready var timer_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/TimerLabel
@onready var electricity_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/ElectricityLabel
@onready var gas_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/GasLabel
@onready var uncle_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/UncleLabel
@onready var awareness_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/AwarenessLabel
@onready var endurance_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/EnduranceLabel
@onready var robot_endurance_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/RobotEnduranceLabel
@onready var electricity_meter_groups: VBoxContainer = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/ElectricityMeter/ElectricityMeterGroups
@onready var failure_overlay: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay
@onready var failure_title_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/FailureTitleLabel
@onready var failure_reason_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/FailureReasonLabel
@onready var anger_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/AngerValueLabel
@onready var failure_continue_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/FailureContinueButton
@onready var end_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/EndButton

## The laptop opened from the laptop bar, which shows only while looking at the left
## area. Loaded at runtime (not preloaded) to keep the stress test free of a load cycle.
const LAPTOP_SCENE_PATH: String = "res://scenes/locations/Laptop.tscn"
var _laptop_bar: LaptopDragBar = null
## Invisible stand-in laid out in the camera window where the bar belongs.
var _laptop_bar_anchor: Control = null
## The bar draws just above the laptop overlay (canvas layer 40).
const LAPTOP_BAR_CANVAS_LAYER: int = 41
## False after the bar opens the laptop, until the cursor leaves the bar.
var _laptop_bar_armed: bool = true
## The laptop overlay while it is open; null when closed. The night keeps running.
var _laptop_overlay: Node = null

var _zoom_level: int = ZOOM_LEVEL_FIRST
var _current_zoom_region: Control = null
## The table view the player was on when they looked into a side area, so D / W
## bring them back to the same view.
var _side_area_return_region: Control = null
var _pan_tween: Tween = null
## Where the black lies for the window<->left slide (set in _split_shed): the
## sideways left wall's bounds and the x of the middle of the gap between it and the room.
var _left_wall_bounds: Rect2 = Rect2()
var _left_gap_center_x: float = 0.0
## The whole shed as laid out (FULL_SCENE_RECT, widened at load if the left wall had to be
## pushed further out than it allows for; see _split_shed).
var _full_scene_rect: Rect2 = FULL_SCENE_RECT
## True while the prototype drone-shot death sequence plays (see _begin_drone_death_sequence).
var _drone_death_active: bool = false
var _zoom_tween: Tween = null
var _canvas_base_scale: float = 1.0
## ZOOM_LEVEL_OUT free pan: the scene point at the centre of the screen, and its
## current velocity (scene px per second).
var _out_focus: Vector2 = BASE_SCENE_SIZE * 0.5
var _free_pan_velocity: Vector2 = Vector2.ZERO
## Current smoothed mouse-follow (sway) offset added on top of the resting camera
## position; eased toward the mouse target each frame and back to zero during pans.
var _mouse_follow_offset: Vector2 = Vector2.ZERO
var _stress_test_dark: bool = false
## Whether the window curtain is drawn open (true) or pulled closed (false).
## Closing it hides the window.
var _curtain_open: bool = true
## Bumped whenever a light flicker starts or the player pulls the light cord, so
## a stale flicker sequence stops touching the lights.
var _lights_flicker_id: int = 0
## Position of the light's pull-cord switch. The bulb is only lit while the switch
## is on AND the generator is running (_stress_test_dark is the bulb's state).
var _light_switch_on: bool = false
## Set the first time tonight the generator puts out power (see _update_light_power).
var _first_power_on_done: bool = false
## Whether the generator was powering the lights last frame, to spot power
## cutting out or coming back (see _update_light_power).
var _lights_had_power: bool = true
var _night_elapsed: float = 0.0
var _night_finished: bool = false
var _electricity_percent: float = 0.0
## Debug-menu cheats for this night (see debug_toggle_cheat): awareness pinned
## at 0, no uncle or drone, and a frozen night clock so the night never ends.
var _debug_no_awareness: bool = false
var _debug_no_enemies: bool = false
var _debug_infinite_time: bool = false
## Debug-only running tally shown as "electricity generated" on the results screen.
var _electricity_generated: float = 0.0
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
var _dragging_lever: bool = false
## Current engine-lever stage: 0 = handle fully up ... LEVER_STAGE_COUNT - 1 = fully down.
var lever_stage: int = 0
## False once the emergency button shuts the generator down; the rip cord restarts it.
var _generator_running: bool = true
var _pending_failure_registers_wake: bool = false
var _failure_result_emitted: bool = false
## The results screen (StressTestResultsScreen), shown over the failure overlay in place
## of its summary panel at the end of the night.
var _results_screen: StressTestResultsScreen = null
## The night ended with the patrol drone shooting you (the results screen goes red).
var _summary_shot: bool = false
## The drone's death sweep has turned the whole view red: the results come straight in
## over it, on the same red, with no wipe between.
var _drone_death_red_done: bool = false
## How long the results screen's code takes to fade in, coming straight off the red.
const RESULTS_AFTER_RED_RAIN_FADE: float = 0.6
var _failure_transition_playing: bool = false
var _intro_failure_restart_pending: bool = false
var _intro_head_interaction_unlocked: bool = true
var _summary_result: Dictionary = {}
var _summary_registers_completion: bool = false
## True when the night was ended by the player pressing the end button rather
## than running out the clock. The results then measure against the full night
## that was supposed to elapse (predicted screws, full-night electricity target)
## instead of the short time actually played, so bailing out early can't buy a
## cheap perfect score.
var _ended_early: bool = false
var _summary_success: bool = false
var _summary_reason: String = ""
var _electricity_consequence_pause_until: float = 0.0
var _consequence_pause_intervals: Array[Vector2] = []
## Seconds the power has been high enough to loosen screws since the last one,
## and the random bonus seconds added to the current gap.
var _screw_spawn_timer: float = 0.0
var _screw_spawn_bonus: float = 0.0
## Rip cord pulls on the stopped generator that have failed to start it.
var _ripcord_failed_pulls: int = 0
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
var _zap_sound: AudioStream = null
var _zap_audio_player: AudioStreamPlayer = null
var _jumpscare_sound: AudioStream = null
var _jumpscare_audio_player: AudioStreamPlayer = null
var _gunshot_sound: AudioStream = null
var _gunshot_audio_player: AudioStreamPlayer = null
var _night_ambient_sounds: Array[AudioStream] = []
var _night_ambient_paths: Array[String] = []
var _night_ambient_audio_player: AudioStreamPlayer = null
var _generator_had_power: bool = false

# Plane/police one-off night sounds.
var _plane_sound: AudioStream = null
var _plane_audio_player: AudioStreamPlayer = null
var _police_siren_sounds: Array[AudioStream] = []
var _police_siren_audio_players: Array[AudioStreamPlayer] = []
## Last night-minute we rolled for (-1 = none rolled yet this night).
var _night_special_last_minute: int = -1
## The plane plays at most once a night; -1 time = nothing scheduled.
var _plane_played: bool = false
var _plane_scheduled_time: float = -1.0
## Siren indices not yet used this night, plus the currently-scheduled hit.
var _police_sirens_remaining: Array[int] = []
var _police_scheduled_time: float = -1.0
var _police_scheduled_index: int = -1

var _wood_creak_sound: AudioStream = null
var _wood_creak_audio_player: AudioStreamPlayer = null
var _wood_creak_scheduled_time: float = -1.0

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
## Night time before which no drone may arrive: the cooldown after the last one left.
var _drone_ready_time: float = 0.0
## True while the camera is being forced onto the drone (the player was not
## watching the window as it readied to fire); the shot is withheld until the
## forced look-up finishes.
var _drone_forced_look_active: bool = false
## Set the instant the drone finishes aiming: it is now locked on and can no
## longer be fended off with the emergency button, and it counts down the
## pre-shot hold (plus the forced look-up, if any) before firing.
var _drone_committed_to_fire: bool = false
## The zap layer on the robot (created in _ready) and the countdown to the next zap.
var _robot_zaps: RobotZaps = null
var _zap_spawn_timer: float = 0.0
## Night-store delivery drone, guided on PATROL from the depot (bottom-right) to home.
## It sits at _delivery_node, flies toward _delivery_next (_delivery_t of the way there),
## then follows _delivery_path. _delivery_cargo is handed over when it reaches home.
var _delivery_active: bool = false
var _delivery_cargo: Array[Dictionary] = []
var _delivery_node: Vector2i = Vector2i.ZERO
var _delivery_next: Vector2i = Vector2i.ZERO
var _delivery_t: float = 0.0
var _delivery_path: Array[Vector2i] = []
var _delivery_depot_node: Vector2i = Vector2i.ZERO
## Night-store (laptop STORE during the stress test) limited items bought tonight, by id.
## Lives on this scene instance, so a fresh or retried night starts empty.
var _night_store_purchases: Dictionary = {}
## One DroneRoute per _drone_event_times entry (same index): the approach the PATROL
## monitor shows, and where the checkpoint hacks happen.
var _drone_routes: Array[DroneRoute] = []
const HACK_NONE: int = 0
## The drone is setting up a hack at a checkpoint: clicking it on PATROL stuns it.
const HACK_BUFFER: int = 1
## The hack is running: win a minigame on the laptop before _hack_deadline or it lands.
const HACK_LIVE: int = 2
## Canvas layers for the zap-fix overlay minigame and the shed-wide banners.
const HACK_MINIGAME_LAYER: int = 50
const HACK_ALERT_LAYER: int = 45
var _hack_phase: int = HACK_NONE
var _hack_route: DroneRoute = null
var _hack_node: int = -1
var _hack_deadline: float = 0.0
## Night time until which the drone shows as stunned on PATROL.
var _drone_stun_until: float = -1.0
## The laptop's hack takeover screen while a live hack shows on an open laptop.
var _hack_screen: LaptopHackScreen = null
## A curtain escape was already rolled for the drone now at the window.
var _drone_curtain_rolled: bool = false
## Shared by every darkness layer the flashlight shines through (see _initialize_flashlight).
var _flashlight_material: ShaderMaterial = null
## Shared by the robot and the props dimmed alongside her (see _flashlight_brightened_roots).
var _flashlight_brighten_material: ShaderMaterial = null
## Brightening material for the curtain group, tuned to curtain_lights_off_modulate.
var _flashlight_curtain_material: ShaderMaterial = null
var _flashlight_on: bool = false
## The overlay minigame currently up (hack block or zap fix), and which.
var _hack_minigame: Minigame = null
var _overlay_minigame_kind: String = ""
## process_input of the nodes muted while the hack minigame is open, to restore after.
var _hack_muted_input: Dictionary = {}


func _ready() -> void:
	# So the laptop's drone-monitor app can find the live stress test to visualize it.
	add_to_group("stress_test_scene")
	_split_shed()
	_initialize_flashlight()
	_tuck_rip_cord_under_shading()
	if _is_intro_tutorial_stress_test():
		night_duration_seconds = intro_tutorial_duration_seconds
	else:
		# The night's length, shared with the Sleep scene: the base, plus banked bonus
		# time (the laptop's "+30s"), plus a fixed chunk per part on the robot (see
		# GameState.night_duration_seconds). The intro tutorial keeps its fixed length.
		night_duration_seconds = GameState.night_duration_seconds(night_duration_seconds)
	# The scene leaves the camera window unclipped so the whole shed (roof, left
	# side, floor) is visible in the editor; clip it to the window in game.
	var camera_window := get_node_or_null(^"FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow") as Control
	if camera_window != null:
		camera_window.clip_contents = true
	_create_mouse_tooltip()
	_create_laptop_bar()
	_initialize_robot_zaps()
	_initialize_audio_players()
	_initialize_robot_position_state()
	_initialize_pull_cord()
	_initialize_stress_systems()
	_initialize_emergency_power_button()
	_initialize_engine_lever()
	_initialize_curtain()
	_initialize_awareness_meter()
	call_deferred("_initialize_zoom")


func _process(delta: float) -> void:
	_update_laptop_bar()
	_update_flashlight()
	_update_interactable_cursor()
	if _night_finished or _drone_death_active:
		_hide_mouse_tooltip()
		return
	# She has woken up: everything is frozen while the eyes loop and the night
	# ends after the wake delay.
	if awareness_meter.is_waking():
		awareness_meter.update_waking(delta)
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

	if not _debug_infinite_time:
		_night_elapsed += delta * time_scale
	_update_intro_head_interaction_gate()
	if not timer_only_speedrun:
		_update_electricity(sim_delta)
		awareness_meter.update_awareness(sim_delta, _passive_awareness_gain_per_second(), _current_awareness_decay_per_second())
		awareness_meter.update_endurance(sim_delta)
		_accumulate_electricity_generated(sim_delta)
	if _electricity_percent <= 0.0 and _emergency_power_shutoff_pressed:
		_set_emergency_power_shutoff_pressed(false)
	_update_screw_spawns(sim_delta)
	_update_night_special_sounds()
	_apply_scheduled_meter_events()
	_update_emergency_power_gas_equalization(sim_delta)
	_update_generator_power_sound()
	_update_light_power()
	if timer_only_speedrun or _debug_no_enemies:
		_suppress_uncle_appearance()
		_suppress_patrol_drone()
	else:
		_update_window_alert(sim_delta)
		_update_patrol_drone(sim_delta)
		_update_drone_hacks()
		_update_delivery_drone(sim_delta)
	_update_zaps(sim_delta)
	_refresh_stress_hud()
	_update_hover_box_tooltip()
	_update_camera_mouse_follow(delta)
	_update_free_pan(delta)

	# Failures: the uncle catching you (window alert) and the drone shooting you
	# (both handled where they occur), plus the robot waking up once her awareness
	# stays maxed out through the stress eyes' buffer (see RobotAwareness).
	# Gas pressure and an electricity over-supply no longer end the night - they
	# only feed the electricity/screw scoring - so otherwise it runs the clock.
	awareness_meter.update_eyes(sim_delta)
	if awareness_meter.is_waking():
		return
	if _night_elapsed >= night_duration_seconds and not _debug_infinite_time:
		_handle_night_timer_finished()
		return


func _unhandled_input(event: InputEvent) -> void:
	if _night_finished or _drone_death_active or _laptop_open() or _hack_minigame_open():
		return

	# The forced-look camera yank cannot be resisted: swallow all camera/gas input
	# for the brief moment the drone holds the player's gaze before the night fails.
	if _drone_forced_look_active:
		return

	if _handle_gas_valve_input(event):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		# While the pointer is over the Shift+Tab debug menu, the wheel scrolls that
		# menu - don't also zoom the camera underneath it.
		if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP] \
				and _is_pointer_over_debug_menu():
			return
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


## True when the Shift+Tab debug menu panel is open and the mouse is over it, so
## the wheel should scroll that menu instead of zooming the camera. The panel adds
## itself to this group while open (see Main.DEBUG_POINTER_BLOCK_GROUP).
func _is_pointer_over_debug_menu() -> bool:
	for node in get_tree().get_nodes_in_group(&"debug_pointer_block"):
		var control := node as Control
		if control != null and control.is_visible_in_tree() \
				and control.get_global_rect().has_point(control.get_global_mouse_position()):
			return true
	return false


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

	var from_region := _current_zoom_region
	_zoom_level = _zoom_level_for_region(next_region)
	_current_zoom_region = next_region
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_apply_zoom_region(true, PAN_DURATION, from_region)
	_interrupt_screw_repairs_if_current_view_requires_it()


## The furthest-out zoom the player may reach. Only debug mode allows the zoomed-out
## views (ZOOM_LEVEL_OUT and the whole-shed ZOOM_LEVEL_FULL); in normal play the player
## stays zoomed into the scene (first level and closer).
func _min_zoom_level() -> int:
	return ZOOM_LEVEL_FULL if _debug_mode_enabled() else ZOOM_LEVEL_FIRST


func _set_zoom_level(value: int, focus_position: Vector2) -> void:
	var next_zoom_level := clampi(value, _min_zoom_level(), MAX_ZOOM_LEVEL)
	if _zoom_level == next_zoom_level:
		return

	var next_region: Control = null
	if next_zoom_level > ZOOM_LEVEL_OUT:
		next_region = _find_region_for_focus(next_zoom_level, focus_position)
		if next_region == null:
			return

	_zoom_level = next_zoom_level
	_current_zoom_region = next_region
	if next_zoom_level == ZOOM_LEVEL_OUT:
		# Free pan starts centred on where the player zoomed (the mouse), kept in bounds.
		_free_pan_velocity = Vector2.ZERO
		_out_focus = _clamp_out_focus(focus_position)

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var target_scale := _current_zoom_scale()
	var target_position := _zoom_position_for_region(_current_zoom_region, target_scale) if _is_zoomed_in() else _default_canvas_position()

	# Zooming onto or off a turned view (the bottom one) turns the camera with it.
	var target_rotation := _rest_rotation_for_region(_current_zoom_region) if _is_zoomed_in() else 0.0
	if target_rotation != 0.0 or not is_zero_approx(scene_canvas.rotation):
		_zoom_tween = _turning_pan_to(target_position, target_scale * _canvas_base_scale, target_rotation, ZOOM_DURATION)
		_interrupt_screw_repairs_if_current_view_requires_it()
		return

	# Driven through _step_linear_pan so the zoom rides the live sway offset and levels any
	# leftover roll, settling on centre + sway instead of centre then re-adjusting.
	var start_position := scene_canvas.position - _mouse_follow_offset
	var start_scale := scene_canvas.scale
	var start_rotation := scene_canvas.rotation
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_method(
		_step_linear_pan.bind(start_position, target_position, start_scale, target_scale * _canvas_base_scale, start_rotation),
		0.0, 1.0, ZOOM_DURATION)
	_interrupt_screw_repairs_if_current_view_requires_it()


func _apply_zoom_region(animated: bool, duration: float = PAN_DURATION, from_region: Control = null) -> void:
	if _current_zoom_region != null:
		print("[ZoomDebug] region=", _current_zoom_region.name, " level=", _zoom_level, " head_only=", _is_head_only_robot(), " new_head_cam=", _robot_uses_new_head_camera())
	var logical_scale := _current_zoom_scale()
	var target_position := _zoom_position_for_region(_current_zoom_region, logical_scale) if _is_zoomed_in() else _default_canvas_position()
	var target_scale := logical_scale * _canvas_base_scale

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()

	var target_rotation := _rest_rotation_for_region(_current_zoom_region) if _is_zoomed_in() else 0.0
	if not animated:
		scene_canvas.scale = target_scale
		scene_canvas.position = target_position + _mouse_follow_offset
		scene_canvas.rotation = target_rotation
		return

	# Into or out of the upside-down bottom view: pan into the black gap, flip there
	# while only black is on screen, then pan on to the destination.
	if _is_bottom_area(_current_zoom_region) or _is_bottom_area(from_region):
		_pan_tween = _black_gap_pan_to(target_position, target_scale, target_rotation)
		return

	# The engine<->table and engine<->window hops swing along a curved path instead of a
	# straight diagonal, each bowing toward its own corner with its own roll (see
	# _curved_pan_hop / _curved_pan_to_region).
	var hop := _curved_pan_hop(from_region, _current_zoom_region)
	# The window<->left look is a straight sideways slide that turns in the black.
	if hop == CURVED_PAN_WINDOW_LEFT:
		_pan_tween = _black_slide_pan_to(target_position, target_scale, target_rotation, duration * window_side_pan_duration_scale)
		return
	# The table<->left look swings over and turns onto the sideways left wall, eased the
	# same way as the window<->left slide.
	if hop == CURVED_PAN_TABLE_LEFT:
		_pan_tween = _turning_swing_pan_to(target_position, target_scale, target_rotation, duration * window_side_pan_duration_scale)
		return
	if from_region != null and hop != CURVED_PAN_NONE:
		if hop == CURVED_PAN_WINDOW_GENERATOR:
			duration *= window_side_pan_duration_scale
		_curved_pan_to_region(target_position, target_scale, duration, hop)
		return

	# Anything else onto or off a turned view (the drone yanking the camera off the left
	# area, say) turns the camera as it pans.
	if target_rotation != 0.0 or _rest_rotation_for_region(from_region) != 0.0 \
			or absf(scene_canvas.rotation) > PI / 4.0:
		_pan_tween = _turning_pan_to(target_position, target_scale, target_rotation, duration)
		return

	# Looking between the table and the window uses its own duration and a stronger
	# ease-in-out (slow at the ends, fastest through the midpoint).
	if from_region != null and _is_table_window_pan(from_region, _current_zoom_region):
		_eased_pan_to_region(target_position, target_scale)
		return

	# Plain straight pan, driven through _step_linear_pan so it too rides the live sway
	# offset (and eases any leftover roll from an interrupted curved pan back to level).
	var start_position := scene_canvas.position - _mouse_follow_offset
	var start_scale := scene_canvas.scale
	var start_rotation := scene_canvas.rotation
	_pan_tween = create_tween()
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_method(
		_step_linear_pan.bind(start_position, target_position, start_scale, target_scale, start_rotation),
		0.0, 1.0, duration)


## Which curved-pan hop this transition is (or CURVED_PAN_NONE for a straight line):
## the table<->generator hop, the window<->generator hop, or their mirror images to the
## left area (table<->left, window<->left), in either direction. Every other hop stays
## straight.
func _curved_pan_hop(from_region: Control, to_region: Control) -> int:
	if from_region == null or to_region == null:
		return CURVED_PAN_NONE
	var from_name := StringName(String(from_region.name))
	var to_name := StringName(String(to_region.name))
	var from_engine := from_name == ENGINE_ZOOM_REGION
	var to_engine := to_name == ENGINE_ZOOM_REGION
	var from_table := from_name in TABLE_VIEW_ZOOM_REGIONS
	var to_table := to_name in TABLE_VIEW_ZOOM_REGIONS
	if (from_table and to_engine) or (from_engine and to_table):
		return CURVED_PAN_TABLE_GENERATOR
	if (from_name == WINDOW_ZOOM_REGION and to_engine) or (from_engine and to_name == WINDOW_ZOOM_REGION):
		return CURVED_PAN_WINDOW_GENERATOR
	if (from_table and to_name == LEFT_AREA_ZOOM_REGION) or (from_name == LEFT_AREA_ZOOM_REGION and to_table):
		return CURVED_PAN_TABLE_LEFT
	if (from_name == WINDOW_ZOOM_REGION and to_name == LEFT_AREA_ZOOM_REGION) \
			or (from_name == LEFT_AREA_ZOOM_REGION and to_name == WINDOW_ZOOM_REGION):
		return CURVED_PAN_WINDOW_LEFT
	return CURVED_PAN_NONE


## Pan the canvas to target_position along a quadratic Bezier for the given curved-pan
## `hop`. The control point pulls the route's midpoint toward that hop's corner (the
## table hop bows to the bottom-right, the window hop to the top-right), so the camera
## swings out toward the corner and then in to the target instead of tracking a straight
## diagonal. Scale eases in parallel and the view rolls through the hop's two configured
## angles; the same TRANS/EASE drive the whole thing.
func _curved_pan_to_region(target_position: Vector2, target_scale: Vector2, duration: float, hop: int) -> void:
	var corner: Vector2
	var rotation_1: float
	var rotation_2: float
	var keyframe_1: float
	var keyframe_2: float
	if hop == CURVED_PAN_WINDOW_GENERATOR:
		corner = Vector2(BASE_SCENE_SIZE.x, 0.0)  # top-right
		rotation_1 = window_to_generator_rotation_1
		rotation_2 = window_to_generator_rotation_2
		keyframe_1 = window_to_generator_keyframe_1
		keyframe_2 = window_to_generator_keyframe_2
	else:
		corner = Vector2(BASE_SCENE_SIZE.x, BASE_SCENE_SIZE.y)  # bottom-right
		rotation_1 = table_to_generator_rotation_1
		rotation_2 = table_to_generator_rotation_2
		keyframe_1 = table_to_generator_keyframe_1
		keyframe_2 = table_to_generator_keyframe_2

	# Start from the resting base (strip the current sway offset); the step re-adds it, so
	# the pan interpolates centre-to-centre and the sway rides continuously on top.
	var start_position := scene_canvas.position - _mouse_follow_offset
	var start_scale := scene_canvas.scale
	var midpoint := (start_position + target_position) * 0.5
	# The canvas position that centers `corner` in the camera. Pulling the route's
	# midpoint toward it bows the path toward that corner; at strength 1.0 the midpoint
	# sits halfway between the straight route and the corner. Use the average of the
	# start and target scales (not just the target) so the corner - and the whole curve -
	# is identical whichever direction the pan runs, keeping the two routes symmetric.
	var average_scale := (start_scale + target_scale) * 0.5
	var corner_position := camera_window.size * 0.5 - corner * average_scale
	var control := midpoint + (corner_position - midpoint) * curved_pan_bow_strength

	# Driven by a LINEAR 0..1 progress; each channel (position + its bounce, scale, and the
	# roll with its own settle timing) applies its own easing inside _step_curved_pan. A
	# rotation_settle above 1 stretches the tween so the roll can keep settling after the
	# camera has already arrived and parked at the target.
	_pan_tween = create_tween()
	_pan_tween.tween_method(
		_step_curved_pan.bind(start_position, control, target_position, start_scale, target_scale, rotation_1, rotation_2, keyframe_1, keyframe_2),
		0.0, 1.0, duration * maxf(1.0, rotation_settle))


## One frame of the curved pan. `t` is linear 0..1 over the (possibly stretched) tween.
## The camera position/scale run over the first part and settle (with the arrival bounce)
## while the roll runs over its own share so it can finish early or on a delay; the roll
## pivots around the camera-window centre so the framed subject stays centred.
func _step_curved_pan(t: float, start_position: Vector2, control: Vector2, target_position: Vector2, start_scale: Vector2, target_scale: Vector2, rotation_1_deg: float, rotation_2_deg: float, keyframe_1: float, keyframe_2: float) -> void:
	var view_center := camera_window.size * 0.5
	var settle := clampf(rotation_settle, 0.25, 4.0)
	var settle_factor := maxf(1.0, settle)
	# The camera motion occupies the first 1/settle_factor of the tween; the roll occupies
	# settle/settle_factor. When settle == 1 both are the whole tween (finish together).
	var position_progress := clampf(t * settle_factor, 0.0, 1.0)
	var roll_progress := clampf(t * settle_factor / settle, 0.0, 1.0)
	var bezier_position := _quadratic_bezier(start_position, control, target_position, _bounce_progress(position_progress))
	# The camera tilt is an optional setting; when off the pan keeps the same curved path
	# and bounce but never rolls.
	var roll := _pan_roll_at(roll_progress, rotation_1_deg, rotation_2_deg, keyframe_1, keyframe_2) if _camera_roll_enabled() else 0.0
	scene_canvas.scale = start_scale.lerp(target_scale, smoothstep(0.0, 1.0, position_progress))
	scene_canvas.rotation = roll
	scene_canvas.position = view_center - (view_center - bezier_position).rotated(roll) + _mouse_follow_offset


## Eased progress along the camera route for a linear 0..1 `p`: a smooth ease-in-out,
## plus (when curved_pan_bounce > 0) an overshoot bump near the end that pushes the value
## briefly past 1 - so the Bezier sails past the target - before settling back to exactly
## 1 at the end. The bump is 0 at both ends, so the start and final frame are unaffected.
func _bounce_progress(p: float) -> float:
	var base := smoothstep(0.0, 1.0, p)
	if curved_pan_bounce <= 0.0:
		return base
	return base + curved_pan_bounce * (pow(p, 6.0) * (1.0 - p) / OVERSHOOT_BUMP_PEAK)


## Camera roll in radians at pan progress t: eased from 0 up to rotation_1_deg by
## keyframe_1, smoothly to rotation_2_deg by keyframe_2, then smoothly back to 0 by the
## end. keyframe_1/keyframe_2 are this hop's own slider positions.
func _pan_roll_at(t: float, rotation_1_deg: float, rotation_2_deg: float, keyframe_1: float, keyframe_2: float) -> float:
	# Clamp the keyframes into a valid, strictly increasing order so no segment has zero
	# length (which would divide by zero) however the sliders are set.
	var k1 := clampf(keyframe_1, 0.0001, 0.9998)
	var k2 := clampf(keyframe_2, k1 + 0.0001, 0.9999)
	if t <= k1:
		return deg_to_rad(lerpf(0.0, rotation_1_deg, smoothstep(0.0, 1.0, t / k1)))
	if t <= k2:
		return deg_to_rad(lerpf(rotation_1_deg, rotation_2_deg, smoothstep(0.0, 1.0, (t - k1) / (k2 - k1))))
	return deg_to_rad(lerpf(rotation_2_deg, 0.0, smoothstep(0.0, 1.0, (t - k2) / (1.0 - k2))))


func _quadratic_bezier(p0: Vector2, control: Vector2, p1: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * control + t * t * p1


## True for the straight look between a table/robot view and the window view (either
## direction), which gets the stronger, tunable ease-in-out.
func _is_table_window_pan(from_region: Control, to_region: Control) -> bool:
	if from_region == null or to_region == null:
		return false
	var from_name := StringName(String(from_region.name))
	var to_name := StringName(String(to_region.name))
	var from_table := from_name in TABLE_VIEW_ZOOM_REGIONS
	var to_table := to_name in TABLE_VIEW_ZOOM_REGIONS
	return (from_table and to_name == WINDOW_ZOOM_REGION) \
			or (from_name == WINDOW_ZOOM_REGION and to_table)


## Straight-line pan to the target using table_window_pan_duration and a power ease-in-out
## whose strength (table_window_mid_speedup) sets how much faster the midpoint is than the
## slow ends. Driven linearly with the ease applied inside so the speed-up is smooth.
func _eased_pan_to_region(target_position: Vector2, target_scale: Vector2) -> void:
	var start_position := scene_canvas.position - _mouse_follow_offset
	var start_scale := scene_canvas.scale
	var start_rotation := scene_canvas.rotation
	_pan_tween = create_tween()
	_pan_tween.tween_method(
		_step_eased_pan.bind(start_position, target_position, start_scale, target_scale, start_rotation),
		0.0, 1.0, table_window_pan_duration)


func _step_eased_pan(t: float, start_position: Vector2, target_position: Vector2, start_scale: Vector2, target_scale: Vector2, start_rotation: float) -> void:
	var eased := _power_ease_in_out(t, table_window_mid_speedup)
	scene_canvas.position = start_position.lerp(target_position, eased) + _mouse_follow_offset
	scene_canvas.scale = start_scale.lerp(target_scale, eased)
	# Level out any leftover roll from an interrupted curved pan over the same ease.
	scene_canvas.rotation = lerpf(start_rotation, 0.0, eased)


## Symmetric ease-in-out raised to `power`: power 1 is linear (constant speed); higher
## powers hold the ends slower and make the midpoint (t = 0.5, its fastest point) punch
## through faster. Continuous in value and speed, so the acceleration stays smooth.
func _power_ease_in_out(t: float, power: float) -> float:
	var p := maxf(1.0, power)
	if t < 0.5:
		return 0.5 * pow(2.0 * t, p)
	return 1.0 - 0.5 * pow(2.0 * (1.0 - t), p)


## One frame of a plain straight pan/zoom (position, scale, roll-to-level), driven from
## the tween's eased 0..1 value, with the live mouse-follow sway offset added so the move
## settles directly on centre + sway rather than snapping to centre first.
func _step_linear_pan(t: float, start_position: Vector2, target_position: Vector2, start_scale: Vector2, target_scale: Vector2, start_rotation: float) -> void:
	scene_canvas.position = start_position.lerp(target_position, t) + _mouse_follow_offset
	scene_canvas.scale = start_scale.lerp(target_scale, t)
	scene_canvas.rotation = lerpf(start_rotation, 0.0, t)


## Whether the CAMERA TILT setting (the roll during curved pans) is on. Defaults to on
## if GameState is somehow unavailable.
func _camera_roll_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state == null or bool(state.get("camera_roll_enabled"))


## Whether the CAMERA SWAY setting (mouse-follow drift) is on.
func _camera_mouse_follow_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state == null or bool(state.get("camera_mouse_follow_enabled"))


## True while a pan or zoom tween is animating the camera, so the mouse-follow sway
## should stand down and let the tween own the position.
func _camera_transition_active() -> bool:
	return (_pan_tween != null and _pan_tween.is_running()) \
			or (_zoom_tween != null and _zoom_tween.is_running())


## Called every frame: while the camera rests on a view, drift it toward the mouse by a
## small, edge-softened offset added on top of the resting position. During a pan (or
## when the setting is off) the offset eases back to zero so nothing fights the pan.
func _update_camera_mouse_follow(delta: float) -> void:
	if camera_window == null or scene_canvas == null:
		return
	var smoothing := 1.0 - exp(-mouse_follow_smoothing * maxf(0.0, delta))
	# Track the sway toward the current view's mouse target every frame - including during
	# a pan, where _current_zoom_region is already the destination. Pans add this offset in
	# their step, so the camera flows straight to (centre + sway) instead of snapping to
	# centre and then re-adjusting.
	var following := _camera_mouse_follow_enabled() and _is_zoomed_in() and _current_zoom_region != null
	var target := _mouse_follow_target() if following else Vector2.ZERO
	# The sway holds still while the inventory is open.
	if not InventoryOverlay.is_open(get_tree()):
		_mouse_follow_offset = _mouse_follow_offset.lerp(target, smoothing)
	# While a pan runs its step applies the offset; at rest we apply it here.
	if not _camera_transition_active() and _is_zoomed_in() and _current_zoom_region != null:
		_apply_resting_camera_position()


## Place the canvas at its resting position for the current view plus the current sway
## offset. (The offset is a plain screen-space translation, whatever the rest rotation.)
func _apply_resting_camera_position() -> void:
	var base := _zoom_position_for_region(_current_zoom_region, _current_zoom_scale())
	scene_canvas.position = base + _mouse_follow_offset


## The sway offset the current mouse position calls for. The pull toward the cursor grows
## from the view centre and tapers exponentially toward the edges (via _mouse_follow_falloff)
## so it never lurches; scaled by this view's configured strength.
func _mouse_follow_target() -> Vector2:
	var strength := _mouse_follow_strength_for_current_view()
	if strength == 0.0:
		return Vector2.ZERO
	var view_size := camera_window.size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2.ZERO
	var center := view_size * 0.5
	var mouse := camera_window.get_local_mouse_position()
	var normalized := Vector2((mouse.x - center.x) / center.x, (mouse.y - center.y) / center.y)
	var pull := Vector2(_mouse_follow_falloff(normalized.x), _mouse_follow_falloff(normalized.y))
	# Negative: shifting the canvas the opposite way moves the *view* toward the cursor,
	# so the camera drifts with the mouse. The universal horizontal multiplier scales only
	# the left-right drift on top of this view's strength.
	var offset := -pull * strength
	offset.x *= mouse_follow_horizontal_strength
	return offset


## Signed, saturating edge falloff for one axis: near the centre it grows ~linearly with
## the cursor's distance; toward the edge each extra bit of distance adds exponentially
## less, so the pull eases off smoothly (never snapping at the border).
func _mouse_follow_falloff(x: float) -> float:
	return signf(x) * (1.0 - exp(-absf(x) * mouse_follow_edge_falloff))


## The sway strength for the kind of view the camera is currently on (table/robot,
## generator, or window); other views do not sway.
func _mouse_follow_strength_for_current_view() -> float:
	if _current_zoom_region == null:
		return 0.0
	var region_name := StringName(String(_current_zoom_region.name))
	if region_name == WINDOW_ZOOM_REGION:
		return mouse_follow_strength_window
	if region_name == ENGINE_ZOOM_REGION:
		return mouse_follow_strength_generator
	if region_name in TABLE_VIEW_ZOOM_REGIONS or region_name in SIDE_AREA_ZOOM_REGIONS:
		return mouse_follow_strength_table
	return 0.0


func _zoom_position_for_region(region: Control, scale_value: Vector2) -> Vector2:
	if region == null:
		return _default_canvas_position()

	var display_scale := scale_value * _canvas_base_scale
	var region_center := _region_center(region)
	# The canvas turns about its origin, so rotate the centre's offset with it to keep
	# the region centred under a flipped camera too.
	var position := camera_window.size * 0.5 \
			- (region_center * display_scale).rotated(_rest_rotation_for_region(region))
	if _robot_uses_new_head_camera() and StringName(String(region.name)) == HEAD_ONLY_TABLE_ZOOM_REGION:
		position.y += head_only_camera_drop_px
	return position


## How the camera rests on a view: the bottom view looks at the upside-down bottom
## third, so it sits turned a full 180 degrees; the left view looks at the left wall
## laid on its side, so it sits turned a quarter the other way; every other view is level.
func _rest_rotation_for_region(region: Control) -> float:
	if region == null:
		return 0.0
	var region_name := StringName(String(region.name))
	if region_name == BOTTOM_AREA_ZOOM_REGION:
		return PI
	if region_name == LEFT_AREA_ZOOM_REGION:
		return -LEFT_WALL_TURN
	return 0.0


func _is_bottom_area(region: Control) -> bool:
	return region != null and StringName(String(region.name)) == BOTTOM_AREA_ZOOM_REGION


## The scene point at the centre of the screen for a canvas placement.
func _canvas_focus(canvas_position: Vector2, canvas_scale: Vector2, canvas_rotation: float) -> Vector2:
	var view_center := camera_window.size * 0.5
	return (view_center - canvas_position).rotated(-canvas_rotation) / canvas_scale


## Places the canvas so `focus` sits at the centre of the screen (plus the sway).
func _place_canvas_on_focus(focus: Vector2, canvas_scale: Vector2, canvas_rotation: float) -> void:
	scene_canvas.scale = canvas_scale
	scene_canvas.rotation = canvas_rotation
	scene_canvas.position = camera_window.size * 0.5 - (focus * canvas_scale).rotated(canvas_rotation) + _mouse_follow_offset


## Scene y of the middle of the black gap between the main room (which ends at
## BASE_SCENE_SIZE.y) and the upside-down bottom section below it.
func _black_gap_center_y() -> float:
	var gap_bottom := BASE_SCENE_SIZE.y
	if bottom_third != null:
		gap_bottom = bottom_third.position.y
	return (BASE_SCENE_SIZE.y + gap_bottom) * 0.5


## Into or out of the bottom view: pan straight down (on screen) into the black gap,
## snap the camera's 180-degree flip there - black to black, so it cannot be seen -
## then pan on to the target view.
func _black_gap_pan_to(target_position: Vector2, target_scale: Vector2, target_rotation: float) -> Tween:
	var start_rotation := scene_canvas.rotation
	var start_scale := scene_canvas.scale
	var start_focus := _canvas_focus(scene_canvas.position - _mouse_follow_offset, start_scale, start_rotation)
	var target_focus := _canvas_focus(target_position, target_scale, target_rotation)
	var black_focus := Vector2(start_focus.x, _black_gap_center_y())
	var leg_seconds := maxf(0.01, bottom_view_pan_seconds)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_place_canvas_on_focus(start_focus.lerp(black_focus, t), start_scale.lerp(target_scale, t), start_rotation)
	, 0.0, 1.0, leg_seconds).set_trans(PAN_TRANS).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_place_canvas_on_focus(black_focus, target_scale, target_rotation)
	)
	tween.tween_method(func(t: float) -> void:
		_place_canvas_on_focus(black_focus.lerp(target_focus, t), target_scale, target_rotation)
	, 0.0, 1.0, leg_seconds).set_trans(PAN_TRANS).set_ease(Tween.EASE_OUT)
	return tween


## Window <-> left area: a straight sideways slide, like any other look left or right.
## The left wall lies on its side, so the camera has to turn a quarter on the way. It
## does that in the black between the walls: the slide runs out into the black, snaps
## the turn there and hops to the black just off the side of the turned wall (nothing is
## on screen either side of the cut), then slides on in. One S curve covers the whole
## trip, so the speed carries straight through the cut.
func _black_slide_pan_to(target_position: Vector2, target_scale: Vector2, target_rotation: float, duration: float) -> Tween:
	var start_rotation := scene_canvas.rotation
	var start_scale := scene_canvas.scale
	var start_focus := _canvas_focus(scene_canvas.position - _mouse_follow_offset, start_scale, start_rotation)
	var target_focus := _canvas_focus(target_position, target_scale, target_rotation)
	var exit_black := _left_slide_black_focus(start_focus, start_rotation, start_scale)
	var entry_black := _left_slide_black_focus(target_focus, target_rotation, target_scale)
	# Already turned the target's way (cut back mid-slide): just slide straight there.
	if is_equal_approx(start_rotation, target_rotation):
		exit_black = start_focus
		entry_black = start_focus
	var exit_length := start_focus.distance_to(exit_black)
	var total := exit_length + entry_black.distance_to(target_focus)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var travelled := _bounce_progress(t) * total
		var canvas_scale := start_scale.lerp(target_scale, smoothstep(0.0, 1.0, t))
		if travelled < exit_length:
			_place_canvas_on_focus(start_focus.lerp(exit_black, travelled / exit_length), canvas_scale, start_rotation)
		else:
			var entry := (travelled - exit_length) / maxf(0.001, total - exit_length)
			_place_canvas_on_focus(entry_black.lerp(target_focus, entry), canvas_scale, target_rotation)
	, 0.0, 1.0, maxf(0.01, duration))
	return tween


## Where the window<->left slide crosses the black for a view at `focus`. Level: the
## middle of the gap between the walls, at the view's own height. Turned onto the left
## wall: straight off its side (screen-right of it, which is above it in the scene), just
## far enough that none of it is on screen.
func _left_slide_black_focus(focus: Vector2, canvas_rotation: float, canvas_scale: Vector2) -> Vector2:
	if absf(canvas_rotation) < PI / 4.0:
		return Vector2(_left_gap_center_x, focus.y)
	# Turned a quarter, the screen's width runs along the scene's y.
	var half_view_width := camera_window.size.x * 0.5 / canvas_scale.x
	return Vector2(focus.x, _left_wall_bounds.position.y - half_view_width - LEFT_SLIDE_BLACK_MARGIN)


## Table <-> left area: the camera swings over to the sideways left wall (or back),
## turning as it goes. Driven like the window<->left slide: the scene point at the centre
## of the screen travels the route (_table_left_route_point) on one S curve, with the
## zoom eased alongside, so the camera glides into place instead of snapping onto the
## end. The turn follows _table_left_turn_progress.
func _turning_swing_pan_to(target_position: Vector2, target_scale: Vector2, target_rotation: float, duration: float) -> Tween:
	var start_rotation := scene_canvas.rotation
	var start_scale := scene_canvas.scale
	var start_focus := _canvas_focus(scene_canvas.position - _mouse_follow_offset, start_scale, start_rotation)
	var target_focus := _canvas_focus(target_position, target_scale, target_rotation)
	var toward_left := not is_zero_approx(target_rotation)
	# The route is always laid out table -> left; left -> table runs it backwards.
	var table_focus := start_focus if toward_left else target_focus
	var left_focus := target_focus if toward_left else start_focus
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		# No arrival bounce here: over a route this long it sails visibly past the view
		# and snaps back.
		var route := smoothstep(0.0, 1.0, t)
		var turn := _table_left_turn_progress(t, toward_left)
		_place_canvas_on_focus(_table_left_route_point(table_focus, left_focus, route if toward_left else 1.0 - route),
				start_scale.lerp(target_scale, smoothstep(0.0, 1.0, t)), lerpf(start_rotation, target_rotation, turn))
	, 0.0, 1.0, maxf(0.01, duration))
	return tween


## The table<->left route at `u` (0 at the table, 1 at the left view): a cubic curve that
## leaves the table heading out toward the bottom-left corner (the table<->generator
## swing mirrored), never dipping away from the left view's height, and comes into the left view from the
## direction table_left_arrival_direction picks - up from below (0), in from the right
## (1), down from above (2), in from the left (3 / -1), or in between.
## table_left_bow_1 sets how wide it swings leaving the table, table_left_bow_2 coming in.
func _table_left_route_point(table_focus: Vector2, left_focus: Vector2, u: float) -> Vector2:
	# Leaving the table: the start of a curve bowed toward the bottom-left corner, which
	# eases away at an unhurried pace. Its dip down is dropped when the left view sits
	# higher: heading down first and then back up past the table reads as an overshoot.
	var midpoint := (table_focus + left_focus) * 0.5
	var swing := midpoint + (Vector2(0.0, BASE_SCENE_SIZE.y) - midpoint) * table_left_bow_1
	var leave := table_focus + (swing - table_focus) * (2.0 / 3.0)
	if signf(leave.y - table_focus.y) != signf(left_focus.y - table_focus.y):
		leave.y = table_focus.y
	var handle := table_focus.distance_to(left_focus) * 0.5 * table_left_bow_2
	var across := signf(left_focus.x - table_focus.x)
	# The arrival handle swings round the left view a quarter turn per unit: straight
	# below it at 0, out on the table's side at 1, above at 2, the far side at 3 / -1.
	var arrival_angle := clampf(table_left_arrival_direction, -1.0, 3.0) * PI * 0.5
	var arrive := left_focus + Vector2(-across * sin(arrival_angle), cos(arrival_angle)) * handle
	return table_focus.bezier_interpolate(leave, arrive, left_focus, u)


## How far through its turn the table<->left swing is at linear progress `t` (0 at the
## table). The turn runs in two halves, each with its own speed and end point: 0 -> 45
## degrees (table_left_turn_1_*) and 45 -> 90 degrees (table_left_turn_2_*); the second
## never starts before the first is done. When the halves meet, the second picks up at
## the first's speed, so the hand-off is seamless; with a pause between them each half
## eases to a stop. Left -> table is the mirror image.
func _table_left_turn_progress(t: float, toward_left: bool) -> float:
	if not toward_left:
		return 1.0 - _table_left_turn_progress(1.0 - t, true)
	var end_1 := clampf(table_left_turn_1_end, 0.05, 0.95)
	var start_1 := maxf(0.0, end_1 - 0.5 / maxf(0.01, table_left_turn_1_speed))
	var end_2 := clampf(table_left_turn_2_end, end_1 + 0.01, 1.0)
	var start_2 := clampf(end_2 - 0.5 / maxf(0.01, table_left_turn_2_speed), end_1, end_2 - 0.01)
	var length_1 := end_1 - start_1
	var length_2 := end_2 - start_2
	# Each half is a cubic ease; where they meet they share one speed. The first half
	# lands the way smoothstep's first half does (slope 1.5), and the second takes that
	# speed on - capped where a much slower second half would otherwise overshoot. A
	# pause between the halves fades that shared speed out (gone by a 0.05 gap), so the
	# turn eases to a stop at 45 degrees instead of jolting.
	var carry := clampf(1.0 - (start_2 - end_1) / 0.05, 0.0, 1.0)
	var slope_1 := 1.5 * carry
	var slope_2 := minf(1.5 * length_2 / length_1, 3.0) * carry
	if t <= end_1:
		return 0.5 * _hermite_ease(clampf((t - start_1) / length_1, 0.0, 1.0), 0.0, slope_1)
	if t <= start_2:
		return 0.5
	return 0.5 + 0.5 * _hermite_ease(clampf((t - start_2) / length_2, 0.0, 1.0), slope_2, 0.0)


## A cubic ease from 0 to 1 over `u` (0..1), leaving with start_slope and arriving with
## end_slope (0 = at rest).
func _hermite_ease(u: float, start_slope: float, end_slope: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return start_slope * (u3 - 2.0 * u2 + u) + (3.0 * u2 - 2.0 * u3) + end_slope * (u3 - u2)


## A plain straight pan/zoom that also turns the camera to the target rotation
## (zooming onto or off the bottom view with the mouse wheel).
func _turning_pan_to(target_position: Vector2, target_scale: Vector2, target_rotation: float, duration: float) -> Tween:
	var start_rotation := scene_canvas.rotation
	var start_scale := scene_canvas.scale
	var start_focus := _canvas_focus(scene_canvas.position - _mouse_follow_offset, start_scale, start_rotation)
	var target_focus := _canvas_focus(target_position, target_scale, target_rotation)
	var tween := create_tween()
	tween.set_trans(PAN_TRANS)
	tween.set_ease(PAN_EASE)
	tween.tween_method(func(t: float) -> void:
		_place_canvas_on_focus(start_focus.lerp(target_focus, t), start_scale.lerp(target_scale, t), lerpf(start_rotation, target_rotation, t))
	, 0.0, 1.0, maxf(0.01, duration))
	return tween


func _on_camera_window_resized() -> void:
	_apply_default_canvas_transform()
	if _is_zoomed_in():
		scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
		_apply_zoom_region(false)
	else:
		scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
		_out_focus = _clamp_out_focus(_out_focus)
		scene_canvas.position = _default_canvas_position()


func _apply_default_canvas_transform() -> void:
	if camera_window == null or scene_canvas == null or camera_window.size == Vector2.ZERO:
		return
	# Lock the base scale to the scene's height, not min(width, height). The world is
	# wider than the 4:3 camera (1200x800), so a min() would fit the full width and
	# shrink every framed camera when the scene grew sideways. Height-fit keeps all the
	# existing (left-side) cameras framed exactly as before; the extra width to the
	# right is simply panned into view by the zoom regions that live out there.
	_canvas_base_scale = camera_window.size.y / BASE_SCENE_SIZE.y
	scene_canvas.size = BASE_SCENE_SIZE


## Canvas position for the zoomed-out views: the whole shed centred (ZOOM_LEVEL_FULL),
## or centred on the free-pan focus (ZOOM_LEVEL_OUT).
func _default_canvas_position() -> Vector2:
	var display_scale := _base_zoom_scale_for_level(_zoom_level) * _canvas_base_scale
	var focus := _full_scene_rect.get_center() if _zoom_level == ZOOM_LEVEL_FULL else _out_focus
	return camera_window.size * 0.5 - focus * display_scale


## Logical scale that fits the whole shed (_full_scene_rect) on screen.
func _full_scene_zoom_scale() -> Vector2:
	if camera_window == null or camera_window.size.x <= 0.0 or _canvas_base_scale <= 0.0:
		return ZOOMED_OUT_SCALE
	var fit := minf(camera_window.size.x / _full_scene_rect.size.x, camera_window.size.y / _full_scene_rect.size.y)
	var s := fit / _canvas_base_scale
	return Vector2(s, s)


## Keeps the ZOOM_LEVEL_OUT view inside the shed: the screen's edges stop at
## _full_scene_rect's walls (centred on an axis the view is wider than the shed on).
func _clamp_out_focus(focus: Vector2) -> Vector2:
	if camera_window == null or _canvas_base_scale <= 0.0:
		return focus
	var half_view := camera_window.size / (ZOOMED_OUT_SCALE * _canvas_base_scale) * 0.5
	var r := _full_scene_rect
	var out := focus
	for axis in 2:
		var lo := r.position[axis] + half_view[axis]
		var hi := r.end[axis] - half_view[axis]
		out[axis] = (lo + hi) * 0.5 if lo > hi else clampf(focus[axis], lo, hi)
	return out


## ZOOM_LEVEL_OUT free pan: hold WASD to slide the camera; it eases up to speed, glides
## to a stop when released, and stops dead on any side that reaches a wall of the shed.
func _update_free_pan(delta: float) -> void:
	if _zoom_level != ZOOM_LEVEL_OUT or scene_canvas == null or _camera_transition_active() \
			or _laptop_open() or _overlay_minigame_open() or _limb_minigame_open() or _drone_forced_look_active \
			or InventoryOverlay.is_open(get_tree()):
		_free_pan_velocity = Vector2.ZERO
		return
	var dir := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var target := dir.normalized() * FREE_PAN_SPEED
	_free_pan_velocity = _free_pan_velocity.lerp(target, 1.0 - exp(-FREE_PAN_RESPONSE * delta))
	if _free_pan_velocity.length() < 1.0:
		_free_pan_velocity = Vector2.ZERO
		return
	var wanted := _out_focus + _free_pan_velocity * delta
	var clamped := _clamp_out_focus(wanted)
	# Hit a wall: stop moving on that axis.
	if not is_equal_approx(clamped.x, wanted.x):
		_free_pan_velocity.x = 0.0
	if not is_equal_approx(clamped.y, wanted.y):
		_free_pan_velocity.y = 0.0
	_out_focus = clamped
	scene_canvas.scale = ZOOMED_OUT_SCALE * _canvas_base_scale
	scene_canvas.rotation = 0.0
	scene_canvas.position = _default_canvas_position()


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
		ZOOM_LEVEL_FULL:
			return _full_scene_zoom_scale()
		_:
			return ZOOMED_OUT_SCALE


func _zoom_scale_for_region(region: Control) -> Vector2:
	var region_size := _region_rect(region).size
	if region_size.x <= 0.001 or region_size.y <= 0.001:
		return _base_zoom_scale_for_level(_zoom_level)

	# The scene world is square (800x800) but the camera window stays 4:3, so lock the
	# zoom to the region's height - the axis that fills the 4:3 view - and keep it
	# uniform so the scene is never stretched. A region's width only sets how much
	# horizontal context is centered around it (the 4:3 view shows more than the
	# region's own width). This keeps every framed camera at its authored zoom
	# regardless of BASE_SCENE_SIZE's height.
	var factor := BASE_SCENE_SIZE.y / region_size.y
	return Vector2(factor, factor)


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

	var side_area_region := _side_area_neighbor(region, direction)
	if side_area_region != null:
		return side_area_region
	# The side areas only lead back the way the player came.
	var region_name := StringName(String(region.name))
	if region_name in SIDE_AREA_ZOOM_REGIONS:
		return null
	# A from the window or a table view only ever looks at the left area (debug only, see
	# _side_area_neighbor); otherwise the camera stays put instead of drifting to
	# whichever view happens to lie further left.
	if direction == Vector2i.LEFT and (region_name == WINDOW_ZOOM_REGION or region_name in TABLE_VIEW_ZOOM_REGIONS):
		return null

	var override_region := _navigation_override_region(region, direction)
	if override_region != null:
		return override_region

	return _nearest_region_in_direction(region, direction)


## Side-area navigation: A from a table view or the window looks at the left
## area, S from the lowest table view (nothing more of the table below it) looks
## at the bottom area, and D / S from those areas return to the view the player
## left.
func _side_area_neighbor(region: Control, direction: Vector2i) -> Control:
	var region_name := StringName(String(region.name))
	# D from the left area always looks at the window.
	if region_name == LEFT_AREA_ZOOM_REGION and direction == Vector2i.RIGHT:
		var window := _zoom_region_by_name(ZOOM_LEVEL_FIRST, WINDOW_ZOOM_REGION)
		if window != null and _is_zoom_region_active(window):
			return window
	# S from the left area looks back down at the table: the table view the player came
	# from, or the robot's resting view.
	if region_name == LEFT_AREA_ZOOM_REGION and direction == Vector2i.DOWN:
		if _side_area_return_region != null and is_instance_valid(_side_area_return_region) \
				and _is_zoom_region_active(_side_area_return_region) \
				and StringName(String(_side_area_return_region.name)) in TABLE_VIEW_ZOOM_REGIONS:
			return _side_area_return_region
		return _initial_zoom_region()
	if (region_name == LEFT_AREA_ZOOM_REGION and direction == Vector2i.RIGHT) \
			or (region_name == BOTTOM_AREA_ZOOM_REGION and direction == Vector2i.DOWN):
		if _side_area_return_region != null and is_instance_valid(_side_area_return_region) \
				and _is_zoom_region_active(_side_area_return_region):
			return _side_area_return_region
		return _initial_zoom_region()

	# Looking left or behind into the side areas is debug-only; the ways back out
	# above stay open so turning debug off there never strands the camera.
	if not _debug_mode_enabled():
		return null

	# A from the window looks at the left area too (D brings the player back to it).
	if region_name == WINDOW_ZOOM_REGION and direction == Vector2i.LEFT:
		var left_area := _zoom_region_by_name(ZOOM_LEVEL_FIRST, LEFT_AREA_ZOOM_REGION)
		if left_area == null or not _is_zoom_region_active(left_area):
			return null
		_side_area_return_region = region
		return left_area

	if not region_name in TABLE_VIEW_ZOOM_REGIONS:
		return null
	var target: Control = null
	if direction == Vector2i.LEFT:
		target = _zoom_region_by_name(ZOOM_LEVEL_FIRST, LEFT_AREA_ZOOM_REGION)
	elif direction == Vector2i.DOWN:
		var below := _nearest_region_in_direction(region, direction)
		if below == null or not StringName(String(below.name)) in TABLE_VIEW_ZOOM_REGIONS:
			target = _zoom_region_by_name(ZOOM_LEVEL_FIRST, BOTTOM_AREA_ZOOM_REGION)
	if target == null or not _is_zoom_region_active(target):
		return null
	_side_area_return_region = region
	return target


## The closest navigable region from this one in the given direction, preferring
## regions in the same lane (overlapping on the perpendicular axis).
func _nearest_region_in_direction(region: Control, direction: Vector2i) -> Control:
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
	var regions: Array[Control] = []
	# The side areas are reached only through _side_area_neighbor.
	for region in _active_regions_for_level(ZOOM_LEVEL_FIRST):
		if not StringName(String(region.name)) in SIDE_AREA_ZOOM_REGIONS:
			regions.append(region)
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


## The rip cord hangs in the generator's corner, which the shed's Dark* shading darkens -
## but as one of the scene's props it was drawn over all that shading, standing out
## bright against its corner. It's moved in among the shed's own layers, just under the
## shading (over the generator art and the lights-off layers), so the corner shades it
## like everything else there - the flashlight too, whose beam cuts the shading away.
func _tuck_rip_cord_under_shading() -> void:
	if electrical_cord == null or light_placeholder == null:
		return
	for layer in light_placeholder.get_children():
		if String(layer.name).begins_with("Dark"):
			electrical_cord.reparent(light_placeholder, true)
			light_placeholder.move_child(electrical_cord, layer.get_index())
			return


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
	# The night starts with the bulb switched off; the pull cord turns it on.
	_light_switch_on = false
	_lights_had_power = true
	_set_stress_test_dark(true)


## The pull cord flips the light switch. With no power the bulb stays dark either
## way, but the switch decides whether it comes back on with the power.
func _on_pull_cord_max_pull_reached() -> void:
	# Before the generator has ever put out power tonight there's nothing to light the
	# bulb with: pulling the cord does nothing (and doesn't flip the switch), so the first
	# power-up always flickers the lights on.
	if not _first_power_on_done:
		return
	# The player taking the light cord cancels any power flicker in progress.
	_lights_flicker_id += 1
	_light_switch_on = not _light_switch_on
	_set_stress_test_dark(not (_light_switch_on and _lights_have_power()))


## The lights run off the generator's charge: they stay lit while it drains after
## a shutdown and only go out once the electricity is completely at 0%.
func _lights_have_power() -> bool:
	return _generator_running or _electricity_percent > 0.0


## Watches the generator: when the power runs out (drained to 0% after the
## emergency button, or a stall at 0%) the lit bulb flickers out, and when it
## comes back (rip cord) a switched-on bulb flickers back on.
func _update_light_power() -> void:
	# The first time tonight the generator starts putting out power, the bulb flickers
	# on with it (switching itself on). Only once - after that the switch is the
	# player's, via the pull cord.
	if not _first_power_on_done and _electricity_percent > 0.0:
		_first_power_on_done = true
		_light_switch_on = true
		_flicker_lights_to(false)
	var has_power := _lights_have_power()
	if has_power == _lights_had_power:
		return
	_lights_had_power = has_power
	if _light_switch_on:
		_flicker_lights_to(not has_power)


## The lights stutter 1-2 times, quickly, then settle on the target state. Does
## nothing if they are already there.
func _flicker_lights_to(dark: bool) -> void:
	if _stress_test_dark == dark:
		return
	_lights_flicker_id += 1
	var flicker_id := _lights_flicker_id
	var flickers := _rng.randi_range(1, 2)
	for i in flickers:
		_set_stress_test_dark(dark)
		await get_tree().create_timer(_rng.randf_range(0.04, 0.08)).timeout
		if flicker_id != _lights_flicker_id or _night_finished:
			return
		_set_stress_test_dark(not dark)
		await get_tree().create_timer(_rng.randf_range(0.04, 0.08)).timeout
		if flicker_id != _lights_flicker_id or _night_finished:
			return
	_set_stress_test_dark(dark)


func _initialize_curtain() -> void:
	if curtain_toggle != null:
		var gui_callable := Callable(self, "_on_curtain_toggle_gui_input")
		if not curtain_toggle.gui_input.is_connected(gui_callable):
			curtain_toggle.gui_input.connect(gui_callable)
	_apply_curtain_availability()
	_apply_curtain_state()


## True when the player owns the curtains upgrade. Curtains are an unlockable
## ability tracked in GameState's owned_tools ledger; a fresh game does not have
## them until they are bought (or granted via the debug give-item menu).
func _player_has_curtains() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and state.has_method("has_tool") and bool(state.call("has_tool", "curtains"))


## Show or hide the whole curtain feature based on whether the player owns it. With
## no curtains there is nothing to see and the window is not clickable. Safe to call
## again at runtime, e.g. after the debug menu grants the item mid-night.
func _apply_curtain_availability() -> void:
	var owned := _player_has_curtains()
	if curtains_root != null:
		curtains_root.visible = owned
	if curtain_toggle != null:
		curtain_toggle.visible = owned
		curtain_toggle.mouse_filter = Control.MOUSE_FILTER_PASS if owned else Control.MOUSE_FILTER_IGNORE


func _on_curtain_toggle_gui_input(event: InputEvent) -> void:
	if _night_finished or not _player_has_curtains():
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_set_curtain_open(not _curtain_open)
		curtain_toggle.accept_event()


func _set_curtain_open(value: bool) -> void:
	if _curtain_open == value:
		return
	_curtain_open = value
	_apply_curtain_state()
	if not value:
		_try_curtain_drone_escape()


## Desperate last resort: shutting the curtains on a drone at the window has a small
## chance (drone_curtain_escape_chance, rolled once per drone) of making it give up and
## leave, even mid-aim. Too late once it has fired.
func _try_curtain_drone_escape() -> void:
	if _drone_curtain_rolled or not (_drone_state == DRONE_IDLE or _drone_state == DRONE_GUNS):
		return
	_drone_curtain_rolled = true
	if _rng.randf() < drone_curtain_escape_chance:
		_clear_patrol_drone()


## Show the open or closed curtain art for the current toggle state. Only meaningful
## while the player owns curtains (otherwise curtains_root is hidden as a whole).
func _apply_curtain_state() -> void:
	if curtain_opened != null:
		curtain_opened.visible = _curtain_open
	if curtain_closed != null:
		curtain_closed.visible = not _curtain_open


func _set_stress_test_dark(value: bool) -> void:
	var was_dark := _stress_test_dark
	_stress_test_dark = value
	# Minigames played in here dim with the lights (see Minigame.room_dark).
	Minigame.room_dark = value
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
	if engine_lever != null:
		engine_lever.modulate = lights_modulate
	_apply_laptop_lights()
	# The curtains sit above the lights-off layers, so they are not darkened by it -
	# dim the whole curtain group here instead so a closed curtain reads just as dark
	# as the rest of the room (no bright rectangle over the window) when the lights
	# are off, while an open curtain still lets the window show through its gap.
	if curtains_root != null:
		curtains_root.modulate = curtain_lights_off_modulate if _stress_test_dark else robot_lights_on_modulate
	# The bulb swaps between its own lit / dead art (see _apply_background_light_state),
	# so it isn't tinted here.
	# The drone is not dimmed by modulate: it swaps to dedicated lights-off art
	# (silhouette + lens glow) instead, handled in _apply_patrol_drone_visual.


func _apply_background_light_state() -> void:
	if light_placeholder != null:
		light_placeholder.visible = true
	for layer in lights_off_layers:
		if layer != null:
			layer.visible = _stress_test_dark
	# The bulb shows its lit art (bulb_on) with its glow while the lights are on, and its
	# dead art (bulb_off) - still hanging in front of the window - while they're off.
	if shed_light != null:
		shed_light.visible = not _stress_test_dark
	if bulb_on != null:
		bulb_on.visible = not _stress_test_dark
	if bulb_off != null:
		bulb_off.visible = _stress_test_dark


# --- flashlight ---------------------------------------------------------------------

## Uniforms and the beam falloff shared by both flashlight shaders.
const FLASHLIGHT_SHADER_COMMON := """
shader_type canvas_item;
uniform bool enabled = false;
// Mouse position in the layer's canvas space (CanvasItem.get_global_mouse_position).
uniform vec2 light_center = vec2(0.0);
uniform float core_radius = 110.0;
uniform float falloff_radius = 240.0;
uniform float core_strength = 1.0;
uniform float edge_strength = 0.5;
varying vec2 canvas_pos;
void vertex() {
	canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
// How lit this pixel is, 0..1.
float beam() {
	float d = distance(canvas_pos, light_center);
	float t = clamp((d - core_radius) / max(1.0, falloff_radius - core_radius), 0.0, 1.0);
	float glow = edge_strength * (1.0 - t) * (1.0 - t);
	// Hard core edge (a pixel or two of smoothing), then the quick drop into the glow.
	return mix(core_strength, glow, smoothstep(core_radius - 1.5, core_radius + 1.5, d));
}
"""
## Darkness layers: the beam cuts them away.
const FLASHLIGHT_CUT_SHADER_CODE := FLASHLIGHT_SHADER_COMMON + """
void fragment() {
	// COLOR already holds the texture times modulate.
	vec4 c = COLOR;
	if (enabled) {
		c.a *= 1.0 - beam();
	}
	COLOR = c;
}
"""
## Things dimmed with robot_lights_off_modulate (the robot, lever, button, cords): the
## beam undoes that dimming, back up to their lights-on brightness.
const FLASHLIGHT_BRIGHTEN_SHADER_CODE := FLASHLIGHT_SHADER_COMMON + """
// robot_lights_off_modulate relative to robot_lights_on_modulate.
uniform vec3 dark_tint = vec3(0.3);
void fragment() {
	// COLOR already holds the texture times modulate.
	vec4 c = COLOR;
	if (enabled) {
		c.rgb *= mix(vec3(1.0), 1.0 / max(dark_tint, vec3(0.01)), beam());
	}
	COLOR = c;
}
"""


## Gives every darkness layer in the shed (the lights-off layers, the Dark* shading and
## the dark overlays on the lever and emergency button) one shared flashlight material,
## including the per-part pieces _split_shed cut them into. The robot, lever,
## button and cords get the brightening material instead, as do parts added to them
## later in the night (screws, zaps, ...).
func _initialize_flashlight() -> void:
	_flashlight_material = _new_flashlight_material(FLASHLIGHT_CUT_SHADER_CODE)
	_flashlight_brighten_material = _new_flashlight_material(FLASHLIGHT_BRIGHTEN_SHADER_CODE)
	var layers: Array[CanvasItem] = []
	layers.append_array(lights_off_layers)
	for parent in [light_placeholder, bottom_third]:
		if parent == null:
			continue
		for child in parent.get_children():
			if child is CanvasItem and String(child.name).begins_with("Dark"):
				layers.append(child)
	for overlay_path in [^"Lever/DarkOverlay", ^"EmergencyPowerButton/Button/DarkOverlay",
			^"EmergencyPowerButton/ButtonPressed/DarkOverlay"]:
		var overlay := scene_canvas.get_node_or_null(overlay_path) as CanvasItem
		if overlay != null:
			layers.append(overlay)
	for layer in layers:
		if layer != null:
			_apply_flashlight_material(layer)
	for item in _flashlight_brightened_roots():
		_apply_flashlight_brighten_material(item)
	# The curtains are dimmed by curtain_lights_off_modulate instead, so they get their
	# own copy of the brightening shader with a matching dark_tint.
	_flashlight_curtain_material = _new_flashlight_material(FLASHLIGHT_BRIGHTEN_SHADER_CODE)
	if curtains_root != null:
		_apply_flashlight_brighten_material(curtains_root, _flashlight_curtain_material)
	get_tree().node_added.connect(_on_node_added_for_flashlight)


func _new_flashlight_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _apply_flashlight_material(item: CanvasItem) -> void:
	item.material = _flashlight_material
	for child in item.get_children():
		if child is TextureRect:
			_apply_flashlight_material(child)


## The nodes tinted by robot_lights_off_modulate in _apply_lights_off_modulate.
func _flashlight_brightened_roots() -> Array[CanvasItem]:
	var roots: Array[CanvasItem] = []
	for item in [stress_test_robot, pull_cord, electrical_cord, emergency_power_button, engine_lever]:
		if item != null:
			roots.append(item)
	return roots


## Brightening material for item and everything under it, leaving alone anything that
## already has a material of its own (the dark overlays keep the cut material).
func _apply_flashlight_brighten_material(item: CanvasItem, mat: ShaderMaterial = null) -> void:
	if mat == null:
		mat = _flashlight_brighten_material
	if item.material == null:
		item.material = mat
	for child in item.get_children():
		if child is CanvasItem:
			_apply_flashlight_brighten_material(child, mat)


func _on_node_added_for_flashlight(node: Node) -> void:
	var item := node as CanvasItem
	if item == null or item.material != null:
		return
	# Not things on their own canvas layer (the limb minigames opened under the robot):
	# the beam only reaches the shed.
	if item.get_canvas_layer_node() != scene_canvas.get_canvas_layer_node():
		return
	for root in _flashlight_brightened_roots():
		if root.is_ancestor_of(item):
			item.material = _flashlight_brighten_material
			return


func _player_has_flashlight() -> bool:
	return GameState.has_tool("flashlight")


## The beam only shines in here, so leaving the scene always turns it off (and lets go
## of the hand cursor).
func _exit_tree() -> void:
	GameState.set_flashlight_on(false)
	CursorTheme.set_grab(self, CursorTheme.Grab.NONE)
	Minigame.room_dark = false


## The grab cursor for the shed: an open hand over anything the player can click or
## grab - the engine lever, the light's pull string and the generator's rip cord, the
## emergency button, the curtains, the gas valve, and on the robot her loose screws,
## zaps and clickable spots - and a closed hand while the lever or a cord is held. Left
## alone while the laptop (or an overlay minigame, the limb minigame, the inventory)
## is up, so those keep their own cursor. Her limbs report their own grab cursor too
## (StressTestRobot._update_limb_cursor).
func _update_interactable_cursor() -> void:
	var state: int = CursorTheme.Grab.NONE
	var blocked := _night_finished or _drone_death_active or _drone_forced_look_active \
			or awareness_meter.is_waking() or _laptop_open() or _overlay_minigame_open() \
			or _limb_minigame_open() or InventoryOverlay.is_open(get_tree())
	if not blocked:
		if _dragging_lever or _cord_held(pull_cord) or _cord_held(electrical_cord):
			state = CursorTheme.Grab.CLOSED
		elif _mouse_over_interactable():
			state = CursorTheme.Grab.OPEN
	CursorTheme.set_grab(self, state)


func _cord_held(cord: Control) -> bool:
	return cord != null and cord.has_method("is_dragging") and bool(cord.call("is_dragging"))


## Whether a click where the mouse is would act on something in the shed (each check is
## the same hit test its own click handling uses).
func _mouse_over_interactable() -> bool:
	if engine_lever != null and engine_lever.is_visible_in_tree() \
			and LEVER_BOX.has_point(_lever_local(get_viewport().get_mouse_position())):
		return true
	for cord in [pull_cord, electrical_cord]:
		if cord != null and cord.is_visible_in_tree() and cord.is_processing_input() \
				and cord.has_method("is_mouse_over") and bool(cord.call("is_mouse_over")):
			return true
	if emergency_power_button != null and emergency_power_button.is_visible_in_tree() \
			and emergency_power_button.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and emergency_power_button.has_method("is_mouse_over") and bool(emergency_power_button.call("is_mouse_over")):
		return true
	for clickable: Control in [curtain_toggle, gas_valve]:
		if clickable == null or not clickable.is_visible_in_tree() or clickable.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if clickable == curtain_toggle and not _player_has_curtains():
			continue
		if Rect2(Vector2.ZERO, clickable.size).has_point(clickable.get_local_mouse_position()):
			return true
	if _robot_zaps != null and _robot_zaps.is_mouse_over_zap():
		return true
	for repair in _screw_repair_controllers():
		if repair.has_method("is_mouse_over_loose_screw") and bool(repair.call("is_mouse_over_loose_screw")):
			return true
	return stress_test_robot != null and stress_test_robot.has_method("is_mouse_over_clickable") \
			and bool(stress_test_robot.call("is_mouse_over_clickable"))


## Turns the beam on while the flashlight is owned and the shed is dark, and keeps it
## centred on the mouse. It goes out for good the moment the drone shoots.
func _update_flashlight() -> void:
	if _flashlight_material == null:
		return
	var shot := _drone_state == DRONE_SHOT or _drone_death_active
	var on := _stress_test_dark and not _night_finished and not shot and _player_has_flashlight()
	var materials: Array[ShaderMaterial] = [_flashlight_material, _flashlight_brighten_material, _flashlight_curtain_material]
	if on != _flashlight_on:
		_flashlight_on = on
		GameState.set_flashlight_on(on)
		for mat in materials:
			mat.set_shader_parameter("enabled", on)
	if not on:
		return
	var tint := robot_lights_off_modulate / robot_lights_on_modulate
	_flashlight_brighten_material.set_shader_parameter("dark_tint", Vector3(tint.r, tint.g, tint.b))
	var curtain_tint := curtain_lights_off_modulate / robot_lights_on_modulate
	_flashlight_curtain_material.set_shader_parameter("dark_tint", Vector3(curtain_tint.r, curtain_tint.g, curtain_tint.b))
	for mat in materials:
		mat.set_shader_parameter("light_center", scene_canvas.get_global_mouse_position())
		mat.set_shader_parameter("core_radius", maxf(0.0, flashlight_core_radius))
		mat.set_shader_parameter("falloff_radius", maxf(flashlight_core_radius, flashlight_falloff_radius))
		mat.set_shader_parameter("core_strength", flashlight_core_strength)
		mat.set_shader_parameter("edge_strength", flashlight_edge_strength)


## How far something at scene x sits sideways from where the art draws it: the left wall
## moves SIDE_WALL_GAP + LEFT_WALL_EXTRA_GAP left, the right wall SIDE_WALL_GAP right, the
## front stays.
func _side_wall_shift(x: float) -> float:
	if x < SIDE_WALL_LEFT_CUT_X:
		return -(SIDE_WALL_GAP + LEFT_WALL_EXTRA_GAP)
	if x >= SIDE_WALL_RIGHT_CUT_X:
		return SIDE_WALL_GAP
	return 0.0


## How far the art at scene point `p` moves when the shed is pulled apart. The side walls
## go sideways (_side_wall_shift). The roof (`roof`, the Roof layer's rect - including the
## bits of the side walls' darkness that overlap it) and the front wall above
## FRONT_FLOOR_Y lift FRONT_LIFT; the table and floor below stay put. A roof layer
## (`roof_layer`, see SHED_ROOF_LAYERS) never goes sideways; a table layer
## (`table_layer`, see SHED_TABLE_LAYERS) never goes right.
func _shed_shift(p: Vector2, roof: Rect2, roof_layer: bool, table_layer: bool = false) -> Vector2:
	if not roof_layer and not roof.has_point(p):
		var side := _side_wall_shift(p.x)
		if side < 0.0 or (side > 0.0 and not table_layer):
			return Vector2(side, 0.0)
	return Vector2(0.0, -FRONT_LIFT) if p.y < FRONT_FLOOR_Y else Vector2.ZERO


## Cuts `rect` along the wall seams and the roof's and front wall's edges, then joins
## neighbouring cells in each row that move the same way (_shed_shift). Each entry is
## [Rect2, Vector2 shift]. A cut that would leave a sliver thinner than
## SHED_MIN_PIECE_PX at the rect's edge is skipped (a wall layer that starts a pixel
## above the roof's bottom edge stays whole instead of leaving a stray line up there).
func _shed_pieces(rect: Rect2, roof: Rect2, roof_layer: bool, table_layer: bool = false) -> Array:
	var xs: Array[float] = [rect.position.x, rect.end.x]
	for x in [SIDE_WALL_LEFT_CUT_X, SIDE_WALL_RIGHT_CUT_X, roof.position.x, roof.end.x]:
		if x > rect.position.x + SHED_MIN_PIECE_PX and x < rect.end.x - SHED_MIN_PIECE_PX and not xs.has(x):
			xs.append(x)
	xs.sort()
	var ys: Array[float] = [rect.position.y, rect.end.y]
	for y in [roof.end.y, FRONT_FLOOR_Y]:
		if y > rect.position.y + SHED_MIN_PIECE_PX and y < rect.end.y - SHED_MIN_PIECE_PX and not ys.has(y):
			ys.append(y)
	ys.sort()
	var pieces := []
	for j in ys.size() - 1:
		var mid_y := (ys[j] + ys[j + 1]) * 0.5
		var run_start := xs[0]
		var run_shift := _shed_shift(Vector2((xs[0] + xs[1]) * 0.5, mid_y), roof, roof_layer, table_layer)
		for i in range(1, xs.size()):
			var shift := Vector2.INF
			if i < xs.size() - 1:
				shift = _shed_shift(Vector2((xs[i] + xs[i + 1]) * 0.5, mid_y), roof, roof_layer, table_layer)
			if shift != run_shift:
				pieces.append([Rect2(run_start, ys[j], xs[i] - run_start, ys[j + 1] - ys[j]), run_shift])
				run_start = xs[i]
				run_shift = shift
	return pieces


## Pulls the shed apart, leaving black between the parts: the left and right walls go
## out sideways, and the roof and front wall lift off the table and floor (_shed_shift).
## Every shed layer in the main room (LightPlaceholder, not the bottom section) that lies
## in one part just moves; a layer that spans parts (the dark and lights-off layers, ...)
## is cut into per-part pieces - children of the original node, so showing / hiding /
## tinting the layer still works as one. Then the room's own props and camera views move
## with their part. The left wall is lifted so its view sits level with the window view,
## then turned on its side (LEFT_WALL_TURN). Done at load, so it keeps working however
## the Aseprite file is re-exported.
func _split_shed() -> void:
	if light_placeholder == null:
		return
	var roof_node := light_placeholder.get_node_or_null(^"Roof") as Control
	var roof := Rect2(roof_node.position, roof_node.size) if roof_node != null else Rect2()
	var left_wall: Array[Control] = []
	for child in light_placeholder.get_children():
		if child is ColorRect and child.name == &"BottomGapBarrier":
			# Widen the black band under the room to span the spread-out walls.
			child.offset_left += _side_wall_shift(SIDE_WALL_LEFT_CUT_X - 1.0)
			child.offset_right += SIDE_WALL_GAP
			continue
		var tr := child as TextureRect
		if tr == null:
			continue
		var roof_layer := tr.name in SHED_ROOF_LAYERS
		var table_layer := tr.name in SHED_TABLE_LAYERS
		var rect := Rect2(tr.position, tr.size)
		var pieces := _shed_pieces(rect, roof, roof_layer, table_layer)
		var atlas_tex := tr.texture as AtlasTexture
		if pieces.size() <= 1 or atlas_tex == null or tr.get_child_count() > 0:
			var shift := _shed_shift(rect.get_center(), roof, roof_layer, table_layer)
			tr.position += shift
			if shift.x < 0.0:
				left_wall.append(tr)
			continue
		# Cut into pieces, one per part it spans.
		var texture_scale := rect.size / atlas_tex.region.size.max(Vector2.ONE)
		for i in pieces.size():
			var piece_rect: Rect2 = pieces[i][0]
			var shift: Vector2 = pieces[i][1]
			var piece_tex := AtlasTexture.new()
			piece_tex.atlas = atlas_tex.atlas
			piece_tex.region = Rect2(atlas_tex.region.position + (piece_rect.position - rect.position) / texture_scale,
					piece_rect.size / texture_scale)
			var piece := TextureRect.new()
			piece.name = "%sPiece%d" % [tr.name, i]
			piece.texture = piece_tex
			piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			piece.stretch_mode = tr.stretch_mode
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.position = piece_rect.position - rect.position + shift
			piece.size = piece_rect.size
			tr.add_child(piece)
			if shift.x < 0.0:
				left_wall.append(piece)
		tr.texture = null

	# The room's props and camera views move with their part. A container as big as the
	# whole scene (the curtains) goes by where its contents sit.
	var zoom_root := first_zoom_regions.get_parent() if first_zoom_regions != null else null
	for child in scene_canvas.get_children():
		var control := child as Control
		if control == null or control == light_placeholder or control == zoom_root:
			continue
		var bounds := Rect2(control.position, control.size * control.scale)
		if control.size.x >= BASE_SCENE_SIZE.x:
			var contents := Rect2()
			for item in control.get_children():
				var c := item as Control
				if c != null:
					var c_rect := Rect2(control.position + c.position, c.size * c.scale)
					contents = c_rect if contents.size == Vector2.ZERO else contents.merge(c_rect)
			if contents.size == Vector2.ZERO:
				continue
			bounds = contents
		var shift := _shed_shift(bounds.get_center(), roof, false)
		control.position += shift
		if shift.x < 0.0:
			left_wall.append(control)
	for level in [first_zoom_regions, second_zoom_regions]:
		if level == null:
			continue
		for region in level.get_children():
			var r := region as Control
			if r != null:
				r.position += _shed_shift(_region_center(r), roof, false)

	var left_area := _zoom_region_by_name(ZOOM_LEVEL_FIRST, LEFT_AREA_ZOOM_REGION)
	if left_area == null:
		return
	# Lift the whole left wall, its view with it, so the view sits level with the window
	# view and the slide between them runs straight across.
	var window := _zoom_region_by_name(ZOOM_LEVEL_FIRST, WINDOW_ZOOM_REGION)
	if window != null:
		var lift := _region_center(window).y - _region_center(left_area).y
		left_area.position.y += lift
		for control in left_wall:
			control.position.y += lift
	# Lay the left wall on its side about the left area view's centre. The view itself
	# stays put; the camera turns to it instead (see _rest_rotation_for_region).
	var pivot := _region_center(left_area)
	for control in left_wall:
		_turn_control_about(control, pivot, LEFT_WALL_TURN)

	# Note where the black lies for the window<->left slide: the sideways wall's bounds,
	# and the middle of the gap between it and the rest of the room.
	var room_left := INF
	for item in light_placeholder.find_children("*", "TextureRect", true, false):
		var rect_item := item as TextureRect
		# Hidden layers count too: the lights-off ones show up later in the night.
		if rect_item.texture == null or (bottom_third != null and bottom_third.is_ancestor_of(rect_item)):
			continue
		var on_left_wall := false
		for wall_item in left_wall:
			if wall_item == rect_item or wall_item.is_ancestor_of(rect_item):
				on_left_wall = true
				break
		if not on_left_wall:
			var item_bounds := _canvas_transform_of(rect_item) * Rect2(Vector2.ZERO, rect_item.size)
			room_left = minf(room_left, item_bounds.position.x)
	# Only what is drawn at load: the hidden layers (an unused table, the lights-off
	# overlays whose rects run far past their art) would overstate the wall.
	_left_wall_bounds = Rect2()
	var first_bounds := true
	for control in left_wall:
		if not control.is_visible_in_tree():
			continue
		var bounds := _canvas_transform_of(control) * Rect2(Vector2.ZERO, control.size)
		_left_wall_bounds = bounds if first_bounds else _left_wall_bounds.merge(bounds)
		first_bounds = false
	# The window<->left slide snaps its turn in the black between the left wall and the
	# room, so that gap has to be wider than a whole view (plus margins): when the wall's
	# art reaches too far toward the room (the camera window is 4:3, so a view is 4/3 as
	# wide as its region is tall), push the whole left wall, its view with it, further out.
	var window_region := _zoom_region_by_name(ZOOM_LEVEL_FIRST, WINDOW_ZOOM_REGION)
	var view_height := _region_rect(left_area).size.y
	if window_region != null:
		view_height = maxf(view_height, _region_rect(window_region).size.y)
	var needed_gap := view_height * 4.0 / 3.0 + 2.0 * LEFT_SLIDE_BLACK_MARGIN
	var deficit := needed_gap - (room_left - _left_wall_bounds.end.x)
	if deficit > 0.0:
		for control in left_wall:
			control.position.x -= deficit
		left_area.position.x -= deficit
		_left_wall_bounds.position.x -= deficit
	_left_gap_center_x = (_left_wall_bounds.end.x + room_left) * 0.5
	_full_scene_rect = FULL_SCENE_RECT.merge(_left_wall_bounds.grow(LEFT_SLIDE_BLACK_MARGIN))


## The transform from `control`'s own space to the scene canvas's.
func _canvas_transform_of(control: Control) -> Transform2D:
	var xform := Transform2D.IDENTITY
	var node := control
	while node != null and node != scene_canvas:
		xform = node.get_transform() * xform
		node = node.get_parent() as Control
	return xform


## Turns `control` by `angle` about `pivot` (a point in the scene canvas's space) on top
## of wherever it already sits, keeping its own pivot_offset and scale.
func _turn_control_about(control: Control, pivot: Vector2, angle: float) -> void:
	# The pivot in the control's parent's space (the parents are plain offsets).
	var local_pivot := _canvas_transform_of(control.get_parent() as Control).affine_inverse() * pivot
	# A Control turns about position + pivot_offset, so swing that point around the
	# pivot and re-seat the control on it.
	var own_pivot := control.position + control.pivot_offset
	control.rotation += angle
	control.position = local_pivot + (own_pivot - local_pivot).rotated(angle) - control.pivot_offset


func _create_mouse_tooltip() -> void:
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "TooltipLayer"
	_tooltip_layer.layer = 200
	add_child(_tooltip_layer)

	_mouse_tooltip = MOUSE_TOOLTIP_SCRIPT.new() as MouseFollowTooltip
	_mouse_tooltip.show_delay_seconds = 0.0
	_tooltip_layer.add_child(_mouse_tooltip)


func _update_hover_box_tooltip() -> void:
	if stress_test_robot == null or not stress_test_robot.has_method("hovered_hover_box_description") \
			or _overlay_minigame_open() or _limb_minigame_open() or _laptop_open():
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

	if stress_test_robot != null:
		stress_test_robot.set("limb_move_minigames_enabled", limb_move_minigames_enabled)
	if stress_test_robot != null and stress_test_robot.has_signal("body_part_moved"):
		var moved_callable := Callable(self, "_on_body_part_moved")
		if not stress_test_robot.is_connected("body_part_moved", moved_callable):
			stress_test_robot.connect("body_part_moved", moved_callable)

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


## True while the robot still uses the head-centric camera profile. This covers
## more than a bare head: a chest and/or a loose upper-arm sub-assembly keep the
## robot on this profile. Only a stomach, leg, full arm (which brings a forearm /
## "lower arm") or hand switches it to the full-body camera. The bare-head vs
## chest/upper-arm split *within* this profile is decided by
## _robot_uses_new_head_camera().
func _is_head_only_robot() -> bool:
	return _robot_part_count("stomach") <= 0 \
			and _robot_part_count("arm") <= 0 \
			and _robot_part_count("hand") <= 0 \
			and _robot_part_count("leg") <= 0


## Within the head-centric camera profile, true once the robot has grown past a
## bare head — a chest and/or at least one upper arm is attached. This sub-state
## gets the lowered "new" camera framing (head_only_camera_drop_px); a bare head
## keeps the original framing.
func _robot_uses_new_head_camera() -> bool:
	return _is_head_only_robot() \
			and (_robot_part_count("chest") >= 1 or _upper_arm_side_count() >= 1)


func _robot_part_count(id: String) -> int:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return 0
	# What's on her - the parts in her slots (GameState.equipped_parts).
	if state.has_method("get_attached_part_count"):
		return int(state.call("get_attached_part_count", id))
	if state.has_method("get_robot_part_count"):
		return int(state.call("get_robot_part_count", id))
	if id == "leg":
		return int(state.get("equipped_limbs"))
	return 0


## Total number of parts fitted to the robot across every part type. Used to
## scale the night length (see GameState.night_duration_seconds).
func _total_robot_parts() -> int:
	var total: int = 0
	for id in GameState.ROBOT_PART_IDS:
		total += _robot_part_count(id)
	return total


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

	_zap_sound = load(ZAP_SOUND_PATH) as AudioStream
	if _zap_sound != null:
		_zap_audio_player = AudioStreamPlayer.new()
		_zap_audio_player.name = "ZapAudioPlayer"
		_zap_audio_player.volume_db = linear_to_db(ZAP_VOLUME_SCALE)
		add_child(_zap_audio_player)

	_jumpscare_sound = load(JUMPSCARE_SOUND_PATH) as AudioStream
	if _jumpscare_sound != null:
		_jumpscare_audio_player = AudioStreamPlayer.new()
		_jumpscare_audio_player.name = "JumpscareAudioPlayer"
		_jumpscare_audio_player.volume_db = linear_to_db(JUMPSCARE_VOLUME_SCALE)
		add_child(_jumpscare_audio_player)

	_gunshot_sound = load(GUNSHOT_SOUND_PATH) as AudioStream
	if _gunshot_sound != null:
		_gunshot_audio_player = AudioStreamPlayer.new()
		_gunshot_audio_player.name = "GunshotAudioPlayer"
		_gunshot_audio_player.volume_db = linear_to_db(GUNSHOT_VOLUME_SCALE)
		add_child(_gunshot_audio_player)

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

	_plane_sound = load(PLANE_SOUND_PATH) as AudioStream
	if _plane_sound != null:
		_plane_audio_player = AudioStreamPlayer.new()
		_plane_audio_player.name = "NightPlaneAudioPlayer"
		add_child(_plane_audio_player)

	_police_siren_sounds.clear()
	for path in POLICE_SIREN_SOUND_PATHS:
		var siren := load(path) as AudioStream
		if siren == null:
			continue
		_police_siren_sounds.append(siren)
		var player := AudioStreamPlayer.new()
		player.name = "NightPoliceSirenAudioPlayer%d" % _police_siren_audio_players.size()
		add_child(player)
		_police_siren_audio_players.append(player)

	_wood_creak_sound = load(WOOD_CREAK_SOUND_PATH) as AudioStream
	if _wood_creak_sound != null:
		_wood_creak_audio_player = AudioStreamPlayer.new()
		_wood_creak_audio_player.name = "NightWoodCreakAudioPlayer"
		add_child(_wood_creak_audio_player)


func _play_rip_cord_full_extend_sound() -> void:
	if _rip_cord_audio_player == null or _rip_cord_full_extend_sound == null:
		return
	_rip_cord_audio_player.stream = _rip_cord_full_extend_sound
	_rip_cord_audio_player.pitch_scale = 1.0
	_rip_cord_audio_player.volume_db = linear_to_db(RIP_CORD_VOLUME_SCALE)
	_rip_cord_audio_player.play()


func _update_generator_power_sound() -> void:
	var has_power := _generator_running or _electricity_percent > 0.001
	if _generator_had_power and not has_power and not _night_finished:
		_play_generator_no_power_sound()
	_generator_had_power = has_power

	if _night_finished or _emergency_power_shutoff_pressed:
		_apply_generator_loop_volume(_generator_hum_audio_player, 0.0)
		_apply_generator_loop_volume(_generator_chug_audio_player, 0.0)
		return

	_apply_generator_loop_volume(_generator_hum_audio_player, _generator_hum_volume())
	_apply_generator_loop_volume(_generator_chug_audio_player, _generator_chug_volume())


## The hum is the low-power loop: as the electricity falls from 50% to 20% it
## swells in, and below 20% it holds at full until the power runs out.
func _generator_hum_volume() -> float:
	if _electricity_percent <= 0.0:
		return 0.0
	if _electricity_percent < 20.0:
		return 1.0
	return clampf((50.0 - _electricity_percent) / 30.0, 0.0, 1.0)


## The chug is the high-power loop: it fades in from 20% and is at full from 50% up.
func _generator_chug_volume() -> float:
	return clampf((_electricity_percent - 20.0) / 30.0, 0.0, 1.0)


func _apply_generator_loop_volume(player: AudioStreamPlayer, volume: float) -> void:
	if player == null:
		return
	var clamped_volume := clampf(volume, 0.0, 1.0)
	if clamped_volume <= 0.001:
		if player.playing:
			player.stop()
		return
	player.volume_db = linear_to_db(clamped_volume * GENERATOR_VOLUME_SCALE)
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
	_generator_shutdown_audio_player.volume_db = linear_to_db(GENERATOR_SHUTTING_OFF_VOLUME_SCALE)
	_generator_shutdown_audio_player.play()


func _play_generator_no_power_sound() -> void:
	if _generator_no_power_audio_player == null or _generator_no_power_sound == null:
		return
	_generator_no_power_audio_player.stream = _generator_no_power_sound
	_generator_no_power_audio_player.pitch_scale = 1.0
	# The out-of-battery chugging matches the running generator loops at 20%.
	_generator_no_power_audio_player.volume_db = linear_to_db(GENERATOR_VOLUME_SCALE)
	_generator_no_power_audio_player.play()


func _play_emergency_power_button_sound() -> void:
	if _emergency_power_button_audio_player == null or _emergency_power_button_sound == null:
		return
	_emergency_power_button_audio_player.stream = _emergency_power_button_sound
	_emergency_power_button_audio_player.pitch_scale = 1.0
	_emergency_power_button_audio_player.volume_db = linear_to_db(GameState.DEFAULT_SFX_VOLUME_SCALE)
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
	_night_ambient_audio_player.volume_db = linear_to_db(NIGHT_AMBIENT_LOUD_VOLUME_SCALE) if _is_loud_night_ambient(path) else linear_to_db(GameState.DEFAULT_SFX_VOLUME_SCALE)
	_night_ambient_audio_player.play()


func _stop_night_ambient() -> void:
	if _night_ambient_audio_player != null:
		_night_ambient_audio_player.stop()
	if _plane_audio_player != null:
		_plane_audio_player.stop()
	for player in _police_siren_audio_players:
		if player != null:
			player.stop()
	if _wood_creak_audio_player != null:
		_wood_creak_audio_player.stop()


## Clear the plane/siren bookkeeping so each night starts fresh.
func _reset_night_special_sounds() -> void:
	_night_special_last_minute = -1
	_plane_played = false
	_plane_scheduled_time = -1.0
	_police_scheduled_time = -1.0
	_police_scheduled_index = -1
	_police_sirens_remaining.clear()
	for i in _police_siren_sounds.size():
		_police_sirens_remaining.append(i)
	_wood_creak_scheduled_time = -1.0


## Per-frame driver for the one-off night flyover/sirens. Rolls once for each
## in-game minute that has newly begun, then fires anything whose scheduled moment
## has arrived. Skips ahead cleanly if a debug speedrun jumps several minutes.
func _update_night_special_sounds() -> void:
	if _night_finished:
		return

	var minute := int(_night_elapsed / NIGHT_SPECIAL_MINUTE_SECONDS)
	while _night_special_last_minute < minute:
		_night_special_last_minute += 1
		_roll_night_special_sounds_for_minute(_night_special_last_minute)

	if _plane_scheduled_time >= 0.0 and _night_elapsed >= _plane_scheduled_time:
		_plane_scheduled_time = -1.0
		_play_night_plane()

	if _police_scheduled_time >= 0.0 and _night_elapsed >= _police_scheduled_time:
		var index := _police_scheduled_index
		_police_scheduled_time = -1.0
		_police_scheduled_index = -1
		_play_night_police_siren(index)

	if _wood_creak_scheduled_time >= 0.0 and _night_elapsed >= _wood_creak_scheduled_time:
		_wood_creak_scheduled_time = -1.0
		_play_night_wood_creak()


## Roll the minute's odds. A successful roll schedules the sound at a random moment
## inside the minute (never on the boundary). Only one of each can be pending, and
## the plane is capped at one per night, the sirens at one play each.
func _roll_night_special_sounds_for_minute(minute: int) -> void:
	var minute_start := float(minute) * NIGHT_SPECIAL_MINUTE_SECONDS

	if not _plane_played and _plane_scheduled_time < 0.0 and _plane_audio_player != null:
		if _rng.randi_range(1, PLANE_CHANCE_ONE_IN) == 1:
			_plane_scheduled_time = minute_start + _rng.randf_range(
				NIGHT_SPECIAL_MIN_OFFSET, NIGHT_SPECIAL_MAX_OFFSET)

	if not _police_sirens_remaining.is_empty() and _police_scheduled_time < 0.0:
		if _rng.randi_range(1, POLICE_CHANCE_ONE_IN) == 1:
			var pick_pos := _rng.randi_range(0, _police_sirens_remaining.size() - 1)
			_police_scheduled_index = _police_sirens_remaining[pick_pos]
			_police_sirens_remaining.remove_at(pick_pos)
			_police_scheduled_time = minute_start + _rng.randf_range(
				NIGHT_SPECIAL_MIN_OFFSET, NIGHT_SPECIAL_MAX_OFFSET)

	# Repeatable through the night, but never scheduled while one is already
	# pending or still creaking (the clip is long), so it can't stack on itself.
	if _wood_creak_scheduled_time < 0.0 and _wood_creak_audio_player != null \
			and not _wood_creak_audio_player.playing:
		if _rng.randi_range(1, WOOD_CREAK_CHANCE_ONE_IN) == 1:
			_wood_creak_scheduled_time = minute_start + _rng.randf_range(
				NIGHT_SPECIAL_MIN_OFFSET, NIGHT_SPECIAL_MAX_OFFSET)


func _play_night_plane() -> void:
	if _plane_audio_player == null or _plane_sound == null:
		return
	_plane_played = true
	_plane_audio_player.stream = _plane_sound
	_plane_audio_player.pitch_scale = 1.0
	_plane_audio_player.volume_db = linear_to_db(PLANE_VOLUME_SCALE)
	_plane_audio_player.play()


func _play_night_police_siren(index: int) -> void:
	if index < 0 or index >= _police_siren_audio_players.size():
		return
	var player := _police_siren_audio_players[index]
	if player == null:
		return
	player.stream = _police_siren_sounds[index]
	player.pitch_scale = 1.0
	player.volume_db = linear_to_db(POLICE_SIREN_VOLUME_SCALE)
	player.play()


func _play_night_wood_creak() -> void:
	if _wood_creak_audio_player == null or _wood_creak_sound == null:
		return
	if _wood_creak_audio_player.playing:
		return
	_wood_creak_audio_player.stream = _wood_creak_sound
	_wood_creak_audio_player.pitch_scale = 1.0
	_wood_creak_audio_player.volume_db = linear_to_db(WOOD_CREAK_VOLUME_SCALE)
	_wood_creak_audio_player.play()


func _is_loud_night_ambient(path: String) -> bool:
	return path.get_file().begins_with("loud_")


func _initialize_stress_systems() -> void:
	_rng.randomize()
	if end_button != null:
		# The gold-bordered corner button every scene's END shares.
		style_corner_button(end_button)
		var show_end_button := not _is_intro_tutorial_stress_test()
		end_button.visible = show_end_button
		end_button.disabled = not show_end_button
	_night_elapsed = 0.0
	_night_finished = false
	_reset_night_special_sounds()
	_play_random_night_ambient()
	_generator_running = true
	# Put the lever on its start stage before reading the meter level off it.
	# Otherwise the night opens at stage 0 (full power) and the generator loop starts
	# for a frame before _initialize_engine_lever pulls it back down.
	lever_stage = clampi(lever_start_stage, 0, LEVER_STAGE_COUNT - 1)
	_electricity_percent = _lever_electricity_percent()
	awareness_meter.reset()
	# Effective awareness fail point. Every day that passes raises the base
	# threshold (so she tolerates more tampering the further you get), then the
	# laptop's "double threshold" debug cheat scales the result. The per-day bonus
	# only applies to real nights, not the fixed-difficulty intro tutorial.
	var base_threshold: float = awareness_fail_threshold
	if not _is_intro_tutorial_stress_test():
		base_threshold += AWARENESS_THRESHOLD_PER_DAY * float(maxi(0, GameState.day - 1))
	awareness_meter.threshold = maxf(1.0, base_threshold * maxf(0.0, GameState.stress_test_awareness_threshold_multiplier))
	_electricity_generated = 0.0
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
	_drone_death_red_done = false
	_failure_transition_playing = false
	_intro_failure_restart_pending = false
	_intro_head_interaction_unlocked = not _is_intro_tutorial_stress_test()
	_summary_result = {}
	_summary_registers_completion = false
	_ended_early = false
	_electricity_consequence_pause_until = 0.0
	_consequence_pause_intervals.clear()
	_generator_had_power = false
	_screw_started_count = 0
	_screw_repaired_count = 0
	_screw_late_count = 0
	_screw_late_penalty_total = 0.0
	_screw_active_events.clear()
	_screw_spawn_timer = 0.0
	_screw_spawn_bonus = _random_screw_bonus_seconds()
	_ripcord_failed_pulls = 0
	_apply_body_part_screw_availability()
	_connect_screw_summary_tracking()

	var optimal_count := _random_event_count(gas_optimal_event_count_min, gas_optimal_event_count_max)
	var drift_count := _random_event_count(gas_drift_event_count_min, gas_drift_event_count_max)
	var alert_count := _random_event_count(window_alert_event_count_min, window_alert_event_count_max)
	# If the uncle drank himself to sleep during the hang-out event, he never
	# checks the window tonight — no uncle window alerts at all.
	if DayCycle.uncle_out_for_the_night:
		alert_count = 0
	_gas_optimal_event_times = _evenly_spaced_times(optimal_count, night_duration_seconds)
	_gas_drift_event_times = _evenly_spaced_times(drift_count, night_duration_seconds)
	_window_alert_event_times = _random_window_alert_times(alert_count)
	_drone_state = DRONE_NONE
	_drone_elapsed = 0.0
	_drone_event_index = 0
	_drone_ready_time = maxf(0.0, drone_opening_grace_seconds)
	_drone_forced_look_active = false
	_drone_committed_to_fire = false
	# Space the drone appearances around the uncle's so the two never overlap.
	_drone_event_times = _deconflict_drone_schedule(_random_drone_event_times(), _window_alert_event_times)
	_build_drone_routes()
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
				_fail_stress_test(uncle_failure_text if _player_has_curtains() else uncle_failure_no_curtains_text, false)
				if window_alert_indicator != null:
					window_alert_indicator.visible = false
				return
		else:
			_window_alert_safe_elapsed += delta
			if _window_alert_safe_elapsed >= _uncle_leave_seconds():
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
	# Closed curtains hide the window, so the player gets no warning that the uncle
	# is there - an incentive not to leave them shut all night.
	var curtains_closed := _player_has_curtains() and not _curtain_open
	var should_show := _window_alert_state != WINDOW_ALERT_NONE \
			and _window_alert_total_elapsed >= _window_alert_indicator_start_time() \
			and not _is_window_alert_in_camera_view() \
			and not curtains_closed
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


## Silence any looping screw-in sound without disturbing repair state. Called when
## the night ends so the loop can't leak a sliver of audio onto the results screen.
func _stop_screw_repair_audio() -> void:
	for repair in _screw_repair_controllers():
		if repair.has_method("stop_repair_audio"):
			repair.call("stop_repair_audio")


## Every audio player the night uses, so the end-of-night fade can catch whatever
## happens to be playing - looping ambience and one-shots alike.
func _all_night_audio_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = [
		_rip_cord_audio_player,
		_generator_hum_audio_player,
		_generator_chug_audio_player,
		_generator_shutdown_audio_player,
		_generator_no_power_audio_player,
		_emergency_power_button_audio_player,
		_zap_audio_player,
		_jumpscare_audio_player,
		_gunshot_audio_player,
		_night_ambient_audio_player,
		_plane_audio_player,
		_wood_creak_audio_player,
	]
	players.append_array(_police_siren_audio_players)
	return players


## Fades every currently-playing night sound down to silence over the results
## wipe, then hard-stops everything. Replaces the old abrupt cut: it keeps loops
## from bleeding through and, crucially, silences one-shots before the results
## screen pauses the tree - a paused sound would otherwise resume for a sliver
## when the player continues to the bedroom.
func _begin_summary_audio_fadeout() -> void:
	var fade := maxf(0.0, SUMMARY_AUDIO_FADE_SECONDS)
	# Screw-repair loops live on the child controllers; let them fade themselves.
	for repair in _screw_repair_controllers():
		if repair.has_method("fade_out_audio"):
			repair.call("fade_out_audio", fade)
	if fade <= 0.0:
		_stop_all_night_audio()
		return
	var tween := create_tween()
	# Keep fading through the results screen's tree pause. A sound frozen mid-fade
	# leaks a sliver of audio (the generator most of all) when DONE / TRY AGAIN
	# finally stops it.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	var faded_any := false
	for player in _all_night_audio_players():
		if player != null and player.playing:
			player.process_mode = Node.PROCESS_MODE_ALWAYS
			tween.tween_property(player, "volume_db", SUMMARY_AUDIO_SILENCE_DB, fade)
			faded_any = true
	if not faded_any:
		tween.tween_interval(fade)
	tween.chain().tween_callback(_stop_all_night_audio)


## Leaving the results (DONE / TRY AGAIN) runs the game again. The night's sounds froze
## with it when the results came up - mid-fade if they came straight in (shot by the
## drone) - so they're stopped for good first; otherwise they'd play on for a moment
## (the generator most of all) until the scene changes.
func _unpause_after_summary() -> void:
	_stop_all_night_audio()
	get_tree().paused = false


## Hard-stops every night sound once the fade has reached silence.
func _stop_all_night_audio() -> void:
	_stop_generator_power_sound()
	_stop_night_ambient()
	_stop_screw_repair_audio()
	for player in _all_night_audio_players():
		if player != null:
			player.stop()
			player.process_mode = Node.PROCESS_MODE_INHERIT


## Seconds the uncle needs to be kept out before he leaves the window: the
## current silhouette time, stretched while the player has no curtains.
func _uncle_leave_seconds() -> float:
	return _window_alert_silhouette_leave_seconds * _uncle_leave_multiplier()


func _uncle_leave_multiplier() -> float:
	if _player_has_curtains():
		return 1.0
	return maxf(1.0, window_alert_no_curtains_leave_multiplier)


## The uncle spots you unless the lights are off and the curtains are closed. The
## generator no longer matters. Without the curtains upgrade there is nothing to
## close, so turning the lights off is enough.
func _is_uncle_exposure_active() -> bool:
	if not _stress_test_dark:
		return true
	return _player_has_curtains() and _curtain_open


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
			# Same for the cooldown after the last drone left (the schedule already
			# spaces them out; this covers a drone that was held back by the uncle).
			if _night_elapsed < _drone_ready_time:
				if _drone_ready_time > _latest_drone_start_time():
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
				# Aim just finished: lock on. If the player is not watching, yank the
				# camera over first (that time is added to the hold below).
				if not _drone_committed_to_fire:
					_drone_committed_to_fire = true
					if not _is_window_alert_in_camera_view():
						_begin_forced_drone_look()
				# Hold the aim for the pre-shot beat (plus the forced look-up), then
				# fire — so the gunshot lands a moment after the player is looking.
				var fire_delay := maxf(0.0, drone_pre_shot_delay_seconds)
				if _drone_forced_look_active:
					fire_delay += _forced_look_pan_duration()
				if _drone_elapsed >= maxf(0.0, drone_guns_seconds) + fire_delay:
					_set_drone_state(DRONE_SHOT)
		DRONE_SHOT:
			if _drone_elapsed >= maxf(0.0, drone_shot_seconds):
				if drone_death_sequence_enabled and not _is_intro_tutorial_stress_test():
					_begin_drone_death_sequence()
				else:
					_fail_stress_test(drone_failure_text, false)
		DRONE_ZAP:
			if _drone_elapsed >= maxf(0.0, drone_zap_seconds):
				_clear_patrol_drone()
			else:
				# Advance the arc animation (frame 1 -> 2 -> 3) as time passes.
				_show_accessory(_current_zap_texture())


## PROTOTYPE: the drone-shot death sequence (see drone_death_sequence_enabled). The night
## is frozen (_process / _unhandled_input bail while _drone_death_active), the HUD hides,
## the camera pans up into the black above the background, a red gradient sweeps down,
## and then the normal drone failure runs.
func _begin_drone_death_sequence() -> void:
	if _drone_death_active or _night_finished:
		return
	_drone_death_active = true
	_hide_mouse_tooltip()
	_set_stress_test_interaction_enabled(false)
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	for hud_name in ["StressHud", "ElectricityMeter", "WindowAlertIndicator", "EndButton", "WakeButton"]:
		var hud := camera_window.get_node_or_null(NodePath(hud_name)) as CanvasItem
		if hud != null:
			hud.visible = false

	# Red sweep overlay over the camera view (under the failure overlay, z 100).
	var red := ColorRect.new()
	red.name = "DroneDeathRed"
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red.z_index = 90
	red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float progress = 0.0;
uniform float softness = 0.35;
uniform vec4 tint : source_color = vec4(0.7, 0.0, 0.0, 1.0);
void fragment() {
	// The leading edge travels from above the top (0) to past the bottom (1).
	float edge = progress * (1.0 + softness);
	float a = 1.0 - smoothstep(edge - softness, edge, UV.y);
	COLOR = vec4(tint.rgb, tint.a * a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("softness", maxf(0.001, drone_death_red_softness))
	mat.set_shader_parameter("tint", drone_death_red_color)
	red.material = mat
	camera_window.add_child(red)

	# The camera window can be taller than the screen (4:3 cover crop), so measure the pan
	# in VISIBLE screen heights, in the window's local units.
	var window_scale := camera_window.get_global_transform_with_canvas().get_scale().y
	var visible_h := minf(camera_window.size.y, get_viewport_rect().size.y / maxf(0.001, window_scale))
	var pan_offset := Vector2(0.0, visible_h * drone_death_pan_screens)
	var start_position := scene_canvas.position
	var start_scale := scene_canvas.scale
	# Zoom about the middle of the camera window (the visible screen centre): keep the
	# canvas point under it fixed while scaling, then add the eased pan on top.
	var view_center := camera_window.size * 0.5
	var focus := (view_center - start_position) / start_scale
	var zoom := maxf(0.01, drone_death_zoom)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var s := start_scale * lerpf(1.0, zoom, t)
		scene_canvas.scale = s
		scene_canvas.position = view_center - focus * s + pan_offset * t
	, 0.0, 1.0, maxf(0.01, drone_death_pan_seconds)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if drone_death_pan_and_red_together:
		# Run the red sweep alongside the pan (from the tween's start, not after it).
		tween.parallel()
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v),
			0.0, 1.0, maxf(0.01, drone_death_red_fade_seconds))
	tween.tween_callback(func() -> void:
		_drone_death_active = false
		_drone_death_red_done = true
		_fail_stress_test(drone_failure_text, false)
	)


func _start_patrol_drone() -> void:
	_drone_curtain_rolled = false
	_set_drone_state(DRONE_IDLE)


## Emergency-button response: if a drone is present (and not already being
## driven off), show the electrocution placeholder for a moment before it
## vanishes instead of clearing it instantly. Once the drone has committed to
## firing — the forced look-up has begun, or it is already in the shot state — it
## is too late to fend it off, so the button no longer clears it.
func _zap_patrol_drone_if_active() -> void:
	if _drone_state == DRONE_NONE or _drone_state == DRONE_ZAP \
			or _drone_state == DRONE_SHOT or _drone_committed_to_fire:
		return
	_set_drone_state(DRONE_ZAP)
	if _zap_audio_player != null and _zap_sound != null:
		_zap_audio_player.stream = _zap_sound
		_zap_audio_player.pitch_scale = 1.0
		_zap_audio_player.play()


## Removes the drone and resets its timeline. Safe to call when no drone is
## present, so the emergency button and night-end path can call it freely.
func _clear_patrol_drone() -> void:
	if _drone_state == DRONE_NONE:
		_apply_patrol_drone_visual()
		return
	_drone_state = DRONE_NONE
	_drone_elapsed = 0.0
	_drone_forced_look_active = false
	_drone_committed_to_fire = false
	_drone_ready_time = _night_elapsed + _random_drone_cooldown()
	_skip_elapsed_drone_events()
	_apply_patrol_drone_visual()


func _random_drone_cooldown() -> float:
	var low := maxf(0.0, minf(drone_cooldown_seconds_range.x, drone_cooldown_seconds_range.y))
	return _rng.randf_range(low, maxf(low, drone_cooldown_seconds_range.y))


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
	var start := maxf(edge, drone_opening_grace_seconds)
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
## window (or each other, with a random cooldown between drones), dropping any
## that no longer fit before the end exclusion. The uncle schedule is treated as fixed, so the drone is the one
## that yields — and it is only dropped when there is genuinely no room, never
## pushed into the final seconds of the night.
func _deconflict_drone_schedule(drone_times: Array[float], uncle_times: Array[float]) -> Array[float]:
	var result: Array[float] = []
	var latest_start := _latest_drone_start_time()
	var earliest_start := maxf(maxf(0.0, drone_edge_exclusion_seconds), drone_opening_grace_seconds)
	if latest_start < earliest_start:
		return result
	var gap := 1.0
	var drone_dur := _drone_reserved_seconds()
	var uncle_dur := _window_alert_schedule_duration()
	for original in drone_times:
		var t := maxf(original, earliest_start)
		var cooldown := maxf(gap, _random_drone_cooldown())
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
				if t < placed + drone_dur + cooldown and t + drone_dur + cooldown > placed:
					t = placed + drone_dur + cooldown
					settled = false
					break
		if settled and t <= latest_start:
			result.append(t)
	result.sort()
	return result


func _set_drone_state(state: int) -> void:
	_drone_state = state
	_drone_elapsed = 0.0
	if state == DRONE_SHOT:
		_play_gunshot_sound()
	_apply_patrol_drone_visual()


## Read-only snapshot of the patrol drone's threat state, for the laptop's drone-monitor
## app to visualize (no gameplay effect). Returns the DRONE_* constant of the current
## state: NONE=0 (parked), IDLE=1 (arrived at the window), GUNS=2 (aiming), SHOT=3/ZAP=4.
func get_drone_visual_state() -> int:
	return _drone_state


## Seconds until the patrol drone's next scheduled arrival at the window, for the
## laptop's PATROL early warning (no gameplay effect). -1 while a drone is already
## present or none are left tonight; 0 while an arrival is held back by the uncle.
func get_drone_seconds_until_arrival() -> float:
	if _drone_state != DRONE_NONE or _drone_event_index >= _drone_event_times.size():
		return -1.0
	return maxf(0.0, _drone_event_times[_drone_event_index] - _night_elapsed)


# --- night store ------------------------------------------------------------------

## How many of a once-per-night item the laptop's night store has sold tonight.
func night_store_bought_count(item_id: String) -> int:
	return int(_night_store_purchases.get(item_id, 0))


func record_night_store_purchase(item_id: String) -> void:
	_night_store_purchases[item_id] = night_store_bought_count(item_id) + 1


# --- electrical shorts (zaps) -------------------------------------------------------

func _initialize_robot_zaps() -> void:
	if stress_test_robot == null or _is_intro_tutorial_stress_test():
		return
	_robot_zaps = RobotZaps.new()
	_robot_zaps.name = "RobotZaps"
	_robot_zaps.zap_clicked.connect(_on_zap_clicked)
	# Last child, so its clicks are read before the robot's hover boxes and screws.
	stress_test_robot.add_child(_robot_zaps)
	_zap_spawn_timer = _next_zap_interval()


func _next_zap_interval() -> float:
	var low := maxf(1.0, minf(zap_spawn_interval_range.x, zap_spawn_interval_range.y))
	return _rng.randf_range(low, maxf(low, zap_spawn_interval_range.y))


func _update_zaps(delta: float) -> void:
	if _robot_zaps == null:
		return
	_robot_zaps.enabled = not (_laptop_open() or _overlay_minigame_open() or _limb_minigame_open()
			or _night_finished or _drone_death_active)
	# The zaps (and the fix-it minigame behind them) are debug-only for now.
	if not _debug_mode_enabled():
		return
	if _robot_zaps.zaps.size() >= maxi(0, zap_max_active):
		return
	_zap_spawn_timer -= delta
	if _zap_spawn_timer > 0.0:
		return
	_zap_spawn_timer = _next_zap_interval()
	var ingredient: String = RobotZaps.INGREDIENTS[_rng.randi() % RobotZaps.INGREDIENTS.size()]
	_robot_zaps.spawn(ingredient, _rng)


## A zap was clicked: fix it by dragging its part into place. Winning uses one up.
func _on_zap_clicked(zap_id: int) -> void:
	if _overlay_minigame_open():
		return
	var zap := _robot_zaps.get_zap(zap_id)
	if zap.is_empty():
		return
	var ingredient := String(zap["ingredient"])
	var game := ZapFixMinigame.new()
	game.ingredient = ingredient
	for id in RobotZaps.INGREDIENTS:
		game.counts[id] = int(GameState.ingredients.get(id, 0))
	game.delivery_pending = night_delivery_pending(ingredient)
	_hide_mouse_tooltip()
	_open_overlay_minigame(game, "zap", func(won: bool) -> void:
		if not won or _robot_zaps == null:
			return
		GameState.add_ingredient(ingredient, -1)
		_robot_zaps.remove_zap(zap_id)
	)


# --- delivery drone ---------------------------------------------------------------

## Tonight's depot, picked at nightfall (see _pick_delivery_depot).
func _delivery_depot() -> Vector2i:
	return _delivery_depot_node


## The depot sits right next to the police station (bottom-left), so deliveries start
## out in the patrol drone's backyard: randomly just above it or just to its right.
func _pick_delivery_depot() -> void:
	var g := maxi(3, drone_route_grid_size)
	var station := Vector2i(0, g - 1)
	_delivery_depot_node = station + (Vector2i.UP if _rng.randf() < 0.5 else Vector2i.RIGHT)


func _delivery_home() -> Vector2i:
	return Vector2i(maxi(3, drone_route_grid_size) - 1, 0)


## The night store's order hook: the item rides the delivery drone (launching it from
## the depot if it isn't already out). Ordering a part eases the zaps that need it.
func queue_night_delivery(item: Dictionary) -> void:
	_delivery_cargo.append(item)
	if not _delivery_active:
		_delivery_active = true
		_reset_delivery_to_depot()
	if _robot_zaps != null and String(item.get("kind", "")) == "ingredient":
		_robot_zaps.reduce_for_ingredient(String(item["id"]), _night_elapsed + maxf(0.0, zap_reduced_seconds))


## Whether an item with this id is on the delivery drone right now.
func night_delivery_pending(item_id: String) -> bool:
	for item in _delivery_cargo:
		if String(item.get("id", "")) == item_id:
			return true
	return false


## Back to the depot with the default plan: straight up the left side, then across the
## top to home.
func _reset_delivery_to_depot() -> void:
	_delivery_node = _delivery_depot()
	_delivery_next = _delivery_node
	_delivery_t = 0.0
	_delivery_path.clear()
	var home := _delivery_home()
	var p := _delivery_node
	while p != home:
		p += Vector2i.UP if p.y > home.y else Vector2i(signi(home.x - p.x), 0)
		_delivery_path.append(p)


## The node a new route starts from: where it's flying to, or where it sits.
func _delivery_anchor() -> Vector2i:
	return _delivery_next


## PATROL app: replaces the delivery drone's route. `nodes` must step one grid edge at a
## time, starting next to the anchor (the node it is flying to / sitting at).
func set_delivery_path(nodes: Array) -> void:
	if not _delivery_active:
		return
	var g := maxi(3, drone_route_grid_size)
	var last := _delivery_anchor()
	var clean: Array[Vector2i] = []
	for n in nodes:
		var v := Vector2i(n)
		if v.x < 0 or v.y < 0 or v.x >= g or v.y >= g or absi(v.x - last.x) + absi(v.y - last.y) != 1:
			break
		clean.append(v)
		last = v
	_delivery_path = clean


## Grid position of the delivery drone.
func _delivery_position() -> Vector2:
	return Vector2(_delivery_node).lerp(Vector2(_delivery_next), _delivery_t)


## Grid position of the patrol drone while it's on the map, or null.
func _patrol_drone_grid_position() -> Variant:
	if _drone_state != DRONE_NONE:
		return Vector2(_delivery_home())
	var route := _current_drone_route()
	if route == null or _night_elapsed <= route.leave[0]:
		return null
	return route.position_at(_night_elapsed)


## Flies the delivery drone at the patrol drone's pace (one edge per
## drone_route_seconds_per_edge). Meeting the patrol drone sends it back to the depot;
## reaching home hands over the cargo.
func _update_delivery_drone(delta: float) -> void:
	if not _delivery_active:
		return
	if _delivery_next == _delivery_node and not _delivery_path.is_empty():
		_delivery_next = _delivery_path.pop_front()
		_delivery_t = 0.0
	if _delivery_next != _delivery_node:
		_delivery_t += delta / maxf(0.1, drone_route_seconds_per_edge)
		if _delivery_t >= 1.0:
			_delivery_node = _delivery_next
			_delivery_t = 0.0
			if _delivery_node == _delivery_home():
				# A patrol drone at the window is waiting right there.
				var at_home: Variant = _patrol_drone_grid_position()
				if at_home != null and (at_home as Vector2).distance_to(Vector2(_delivery_home())) < 0.4:
					_intercept_delivery()
				else:
					_complete_delivery()
				return
			if not _delivery_path.is_empty():
				_delivery_next = _delivery_path.pop_front()
	var patrol: Variant = _patrol_drone_grid_position()
	if patrol != null and _delivery_node != _delivery_depot() \
			and (patrol as Vector2).distance_to(_delivery_position()) < 0.4:
		_intercept_delivery()


## Caught by the patrol drone: the delivery drone flees back to the depot and starts over.
func _intercept_delivery() -> void:
	_reset_delivery_to_depot()
	_show_banner("DELIVERY DRONE INTERCEPTED - BACK TO THE DEPOT", Color(1.0, 0.4, 0.35))


func _complete_delivery() -> void:
	var names: Array[String] = []
	for item in _delivery_cargo:
		DeliveryApp.grant_item(item)
		names.append(String(item.get("name", "?")))
	_delivery_cargo.clear()
	_delivery_active = false
	_delivery_path.clear()
	_show_banner("DELIVERY ARRIVED: " + ", ".join(names), Color(0.55, 1.0, 0.6))


## Read-only snapshot of the delivery drone for the PATROL monitor.
func get_delivery_info() -> Dictionary:
	var info := {"active": _delivery_active, "depot": _delivery_depot()}
	if not _delivery_active:
		return info
	info["position"] = _delivery_position()
	info["anchor"] = _delivery_anchor()
	info["path"] = _delivery_path.duplicate()
	var names: Array[String] = []
	for item in _delivery_cargo:
		names.append(String(item.get("name", "?")))
	info["cargo"] = names
	return info


# --- drone routes & hacks -------------------------------------------------------

## One random route per scheduled arrival, timed to reach home as the drone arrives.
func _build_drone_routes() -> void:
	_end_drone_hack()
	_drone_stun_until = -1.0
	_pick_delivery_depot()
	_drone_routes.clear()
	# Hacks are debug-only: outside debug mode the laptop (in the left area) is out of
	# reach, so the player could not block one.
	var hacks_allowed := _debug_mode_enabled() and not _is_intro_tutorial_stress_test()
	for arrival in _drone_event_times:
		var route := DroneRoute.generate(_rng, maxi(3, drone_route_grid_size), arrival,
				maxf(0.1, drone_route_seconds_per_edge),
				_rng.randi_range(drone_checkpoint_count_min, maxi(drone_checkpoint_count_min, drone_checkpoint_count_max)),
				maxf(0.0, drone_checkpoint_pause_seconds),
				drone_hack_chance if hacks_allowed else 0.0,
				maxf(0.1, drone_hack_buffer_seconds),
				maxi(0, drone_hack_max_per_route))
		# A route already under way at nightfall skips the hacks it has flown past.
		for k in route.hack_checkpoints:
			if route.arrive[k] < 1.0:
				route.handled_hacks[k] = true
		_drone_routes.append(route)


## The route of the drone that's on its way (none while one is at the window).
func _current_drone_route() -> DroneRoute:
	if _drone_state != DRONE_NONE or _drone_event_index >= _drone_routes.size():
		return null
	return _drone_routes[_drone_event_index]


## Runs the checkpoint hacks: a hack checkpoint opens the stun window (BUFFER) as the
## drone reaches it; if the drone leaves unstunned, the hack goes live and lands unless
## a minigame is won by the deadline.
func _update_drone_hacks() -> void:
	# Debug turned off mid-night: drop any hack under way and start no more.
	if not _debug_mode_enabled():
		if _hack_phase != HACK_NONE:
			_end_drone_hack()
		return
	var t := _night_elapsed
	if _hack_phase == HACK_LIVE:
		_sync_hack_screen()
		if t >= _hack_deadline:
			_land_drone_hack()
		return
	if _hack_phase == HACK_BUFFER:
		if _hack_route != _current_drone_route():
			_hack_phase = HACK_NONE
			_hack_route = null
		elif t >= _hack_route.leave[_hack_node]:
			_begin_live_hack()
		return
	var route := _current_drone_route()
	if route == null:
		return
	for k in route.hack_checkpoints:
		if route.handled_hacks.has(k):
			continue
		if t >= route.leave[k]:
			# Flew past while busy (e.g. another drone was at the window).
			route.handled_hacks[k] = true
		elif t >= route.arrive[k]:
			route.handled_hacks[k] = true
			_hack_phase = HACK_BUFFER
			_hack_route = route
			_hack_node = k
			return


## PATROL monitor: clicking the drone while it sets up a hack foils the hack and stuns
## the drone for a random few seconds, pushing its whole approach (and arrival) back.
## Returns the stun length, or 0 if there was nothing to stun.
func stun_patrol_drone() -> float:
	if _hack_phase != HACK_BUFFER or _hack_route == null or _night_finished:
		return 0.0
	var stun := _rng.randf_range(drone_stun_seconds_range.x, maxf(drone_stun_seconds_range.x, drone_stun_seconds_range.y))
	_hack_route.shift_after(_hack_node, stun)
	_drone_event_times[_drone_event_index] = _hack_route.arrival_time()
	_drone_stun_until = _night_elapsed + stun
	_hack_phase = HACK_NONE
	_hack_route = null
	return stun


func _begin_live_hack() -> void:
	_hack_phase = HACK_LIVE
	_hack_route = null
	_hack_deadline = _night_elapsed + maxf(1.0, drone_hack_block_seconds)
	_sync_hack_screen()


## A live hack shows ONLY on the laptop: while the laptop is open it's taken over by the
## hack warning screen (LaptopHackScreen), where the block minigame is played. Nothing
## in the shed itself gives the hack away. Creates / removes / updates that screen.
func _sync_hack_screen() -> void:
	var want := _hack_phase == HACK_LIVE and _laptop_open()
	var have := _hack_screen != null and is_instance_valid(_hack_screen)
	if want and not have:
		var host := _laptop_overlay.get("screen_content") as Control
		if host == null:
			return
		_hack_screen = LaptopHackScreen.new()
		_hack_screen.blocked.connect(func() -> void:
			if _hack_phase == HACK_LIVE:
				_end_drone_hack()
		)
		host.add_child(_hack_screen)
	elif not want and have:
		_hack_screen.queue_free()
		_hack_screen = null
	if want and _hack_screen != null:
		_hack_screen.time_left = maxf(0.0, _hack_deadline - _night_elapsed)


## Whether a stress-test overlay minigame (zap fix) is up.
func _hack_minigame_open() -> bool:
	return _overlay_minigame_open()


func _overlay_minigame_open() -> bool:
	return _hack_minigame != null and is_instance_valid(_hack_minigame)


## Shows `game` over everything (laptop included) with the shed's own click handling
## muted; `on_closed` gets whether it was won once it closes.
func _open_overlay_minigame(game: Minigame, kind: String, on_closed: Callable) -> void:
	if _overlay_minigame_open():
		return
	game.auto_close_on_result = true
	var layer := CanvasLayer.new()
	layer.name = "OverlayMinigameLayer"
	layer.layer = HACK_MINIGAME_LAYER
	layer.add_child(game)
	add_child(layer)
	_hack_minigame = game
	_overlay_minigame_kind = kind
	_set_hack_minigame_input_block(true)
	game.closed.connect(func() -> void:
		var won := game.solved
		_close_overlay_minigame()
		on_closed.call(won)
	)


## Tears down the overlay minigame (if any) without reporting a result.
func _close_overlay_minigame() -> void:
	if _hack_minigame == null:
		return
	_set_hack_minigame_input_block(false)
	if is_instance_valid(_hack_minigame):
		var layer := _hack_minigame.get_parent()
		if layer != null and is_instance_valid(layer):
			layer.queue_free()
	_hack_minigame = null
	_overlay_minigame_kind = ""


## The robot, cords and zaps read clicks in _input (ahead of the GUI), so mute them while
## an overlay minigame is up, then put each back the way it was.
func _set_hack_minigame_input_block(blocked: bool) -> void:
	if blocked:
		_hack_muted_input.clear()
		for node in [stress_test_robot, pull_cord, electrical_cord, _robot_zaps]:
			if node != null and is_instance_valid(node):
				_hack_muted_input[node] = node.is_processing_input()
				node.set_process_input(false)
	else:
		for node in _hack_muted_input:
			if is_instance_valid(node):
				node.set_process_input(bool(_hack_muted_input[node]))
		_hack_muted_input.clear()


## Time ran out: the hack lands and cuts the power - the generator dies (the rip cord
## restarts it). This is the drone's own doing, so unlike the emergency button it never
## zaps the drone, even one sitting at the window.
func _land_drone_hack() -> void:
	_end_drone_hack()
	if not _generator_running:
		return
	if _electricity_percent > 0.001:
		_play_generator_shutting_off_sound()
	_generator_running = false
	_update_light_power()
	_update_generator_power_sound()
	_refresh_stress_hud()


## A brief banner across the top of the screen (above the laptop).
func _show_banner(text: String, color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = HACK_ALERT_LAYER
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = 16.0
	label.offset_bottom = 48.0
	layer.add_child(label)
	get_tree().create_timer(2.5).timeout.connect(layer.queue_free)


## Clears any hack in progress (blocked, landed, or the night ending) and its UI.
func _end_drone_hack() -> void:
	_hack_phase = HACK_NONE
	_hack_route = null
	_hack_node = -1
	if _hack_screen != null and is_instance_valid(_hack_screen):
		_hack_screen.queue_free()
	_hack_screen = null


## Read-only snapshot of the drone's approach for the PATROL monitor (no gameplay
## effect): grid size, the route path / checkpoints, the drone's position in grid
## coordinates, and the hack / stun state.
func get_drone_route_info() -> Dictionary:
	var t := _night_elapsed
	var info := {"grid": maxi(3, drone_route_grid_size), "hack_phase": _hack_phase,
			"stunned": t < _drone_stun_until}
	if _hack_phase == HACK_BUFFER and _hack_route != null:
		info["hack_time_left"] = maxf(0.0, _hack_route.leave[_hack_node] - t)
	elif _hack_phase == HACK_LIVE:
		info["hack_time_left"] = maxf(0.0, _hack_deadline - t)
	var route: DroneRoute = null
	var at_home := _drone_state != DRONE_NONE
	if at_home:
		var i := _drone_event_index - 1
		if i >= 0 and i < _drone_routes.size():
			route = _drone_routes[i]
	else:
		route = _current_drone_route()
	if route == null:
		return info
	info["path"] = route.path
	info["checkpoints"] = route.checkpoints
	info["position"] = Vector2(route.path[route.path.size() - 1]) if at_home else route.position_at(t)
	info["flown_index"] = route.path.size() - 1 if at_home else route.current_index(t)
	# Where it heads next (for the PATROL "next move" arrow); none once it's home.
	var next_i: int = int(info["flown_index"]) + 1
	if not at_home and next_i < route.path.size():
		info["next_node"] = route.path[next_i]
	info["departed"] = at_home or t > route.leave[0]
	info["paused"] = not at_home and route.paused_index(t) > 0
	return info


## Begins the forced look when the drone is ready to fire but the player is not
## watching the window: yank the camera over (jump-scare sting), hold the aim, and
## let _update_patrol_drone fire once the look-up finishes (see the GUNS branch).
func _begin_forced_drone_look() -> void:
	_drone_forced_look_active = true
	_force_camera_to_window()
	_play_jumpscare_sound()


## How long the forced camera yank onto the window takes — the normal pan time
## sped up by FORCED_LOOK_PAN_SPEED_MULTIPLIER — which is also how long the shot
## is withheld so the drone only fires once the player has fully looked up.
func _forced_look_pan_duration() -> float:
	return PAN_DURATION / maxf(0.01, FORCED_LOOK_PAN_SPEED_MULTIPLIER)


## Yanks the camera onto the window (zoom level 1, centred on the window) at twice
## the normal pan speed so the drone at the window is unmistakably in view.
func _force_camera_to_window() -> void:
	if window_alert_rect == null or scene_canvas == null:
		return
	var focus := _region_rect(window_alert_rect).get_center()
	var region := _find_region_for_focus(ZOOM_LEVEL_FIRST, focus)
	if region == null:
		return
	# Off the sideways left wall the yank still slides across the black to turn unseen.
	var from_region: Control = null
	if _current_zoom_region != null and StringName(String(_current_zoom_region.name)) == LEFT_AREA_ZOOM_REGION:
		from_region = _current_zoom_region
	_zoom_level = _zoom_level_for_region(region)
	_current_zoom_region = region
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_apply_zoom_region(true, _forced_look_pan_duration(), from_region)


## Same yank as _force_camera_to_window, onto the robot's resting view (the one the night
## opens on), for when she wakes up.
func _force_camera_to_robot() -> void:
	var region := _initial_zoom_region()
	if region == null or scene_canvas == null:
		return
	_zoom_level = _zoom_level_for_region(region)
	_current_zoom_region = region
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_apply_zoom_region(true, _forced_look_pan_duration())


func _play_jumpscare_sound() -> void:
	if _jumpscare_audio_player == null or _jumpscare_sound == null:
		return
	_jumpscare_audio_player.stream = _jumpscare_sound
	_jumpscare_audio_player.pitch_scale = 1.0
	_jumpscare_audio_player.play()


func _play_gunshot_sound() -> void:
	if _gunshot_audio_player == null or _gunshot_sound == null:
		return
	_gunshot_audio_player.stream = _gunshot_sound
	_gunshot_audio_player.pitch_scale = 1.0
	_gunshot_audio_player.play()


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
			# The drone wears its dark shading overlays (DroneDark1-4) whenever it is
			# on screen, in BOTH light states, so the deployed guns are dimmed to sit
			# within that shading. The lit gun art is used (the dedicated dark art is
			# too dull to read as guns) but darkened by drone_guns_dim_modulate so it
			# stays legible without popping bright over the shadows.
			# (DRONE_SHOT is left untouched: it turns the guns off so the bright firing
			# pose can flash through - that darkness-reduction-on-fire still works.)
			_show_accessory(DRONE_GUNS_TEXTURE)
			patrol_drone_accessory.modulate = drone_guns_dim_modulate
			# Lights off: overlay the dark-guns shadow on top of the lit guns so the
			# deployed barrels darken to match the rest of the dark drone. Lights-on is
			# left exactly as it was (no dark-guns overlay).
			if dark:
				_show_node(patrol_drone_guns_dark)
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
	patrol_drone_accessory.modulate = Color.WHITE
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
			+ maxf(0.0, window_alert_late_safe_silhouette_seconds) * _uncle_leave_multiplier() \
			+ maxf(0.0, window_alert_seen_failure_seconds)


func _on_electrical_cord_max_pull_reached() -> void:
	if _night_finished:
		return
	_play_rip_cord_full_extend_sound()
	# The rip cord only (re)starts a stopped generator, and only sometimes catches -
	# but the guaranteed pull always does, so bad luck costs at most that many pulls.
	if not _generator_running:
		_ripcord_failed_pulls += 1
		if _ripcord_failed_pulls >= maxi(1, generator_ripcord_guaranteed_pull) \
				or _rng.randf() < clampf(generator_ripcord_start_chance, 0.0, 1.0):
			_ripcord_failed_pulls = 0
			_start_generator()
	if _rng.randf() < clampf(screw_electrical_pull_chance, 0.0, 1.0):
		_trigger_random_screw()


func _is_screw_repair_on_raised_arm(repair: Node) -> bool:
	if stress_test_robot == null or not stress_test_robot.has_method("is_arm_raised"):
		return false
	if repair == left_arm_screw_repair:
		return bool(stress_test_robot.call("is_arm_raised", 0))
	if repair == right_arm_screw_repair:
		return bool(stress_test_robot.call("is_arm_raised", 1))
	return false


func _trigger_random_screw() -> bool:
	# No screw art fits a raised arm or her back, so screws stay put on a raised
	# arm, and anywhere while she lies face down.
	if stress_test_robot != null and stress_test_robot.has_method("is_face_down") \
			and bool(stress_test_robot.call("is_face_down")):
		return false
	var controllers := _screw_repair_controllers()
	controllers.shuffle()
	for repair in controllers:
		if _is_screw_repair_on_raised_arm(repair):
			continue
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


## Lever clicks are read here, before the GUI: the stress test's container controls
## consume mouse buttons, so they never reach _unhandled_input (same as PullCord).
func _input(event: InputEvent) -> void:
	if _night_finished or _drone_death_active or _drone_forced_look_active:
		_dragging_lever = false
		return
	if _limb_minigame_open() or _laptop_open() or _hack_minigame_open():
		return
	if _handle_lever_input(event):
		get_viewport().set_input_as_handled()


func _limb_minigame_open() -> bool:
	return stress_test_robot != null and stress_test_robot.has_method("get_limb_minigame_box") \
			and stress_test_robot.call("get_limb_minigame_box") != null


# --- laptop -------------------------------------------------------------------

## FNAF-style laptop bar: a wide strip along the bottom of the screen, shown only while
## the camera is on the left area. Swiping the mouse down onto it flips the laptop up,
## and - since it stays on screen over the open laptop - swiping down onto it again puts
## the laptop away. After each flip the cursor has to leave the bar before it can trigger
## again, so one swipe never opens and closes it in one go.
##
## The bar lives on its own canvas layer just above the laptop's, and each frame copies
## the placement of an invisible anchor laid out in the camera window, so it keeps the
## exact spot and size it would have down in the scene.
func _create_laptop_bar() -> void:
	var camera_window := get_node_or_null(^"FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow") as Control
	if camera_window == null:
		return
	_laptop_bar_anchor = Control.new()
	_laptop_bar_anchor.name = "LaptopBarAnchor"
	_laptop_bar_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_laptop_bar_anchor.anchor_left = 0.22
	_laptop_bar_anchor.anchor_right = 0.78
	_laptop_bar_anchor.anchor_top = 1.0
	_laptop_bar_anchor.anchor_bottom = 1.0
	# The bar art at 3x (600 x 60) fits this slot (see LaptopDragBar).
	_laptop_bar_anchor.offset_top = -187.0
	_laptop_bar_anchor.offset_bottom = -127.0
	_laptop_bar_anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	camera_window.add_child(_laptop_bar_anchor)

	var layer := CanvasLayer.new()
	layer.name = "LaptopBarLayer"
	layer.layer = LAPTOP_BAR_CANVAS_LAYER
	add_child(layer)
	_laptop_bar = LaptopDragBar.new()
	_laptop_bar.name = "LaptopBar"
	_laptop_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_laptop_bar.visible = false
	_laptop_bar.gui_input.connect(_on_laptop_bar_input)
	layer.add_child(_laptop_bar)


## Swipe down onto the bar: open the laptop, or close it if it's already open.
func _on_laptop_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.y > 0.0 and _laptop_bar_armed:
		_laptop_bar_armed = false
		if _laptop_open():
			_close_laptop()
		else:
			_open_laptop_overlay()


func _laptop_open() -> bool:
	return _laptop_overlay != null and is_instance_valid(_laptop_overlay)


## Shows the laptop bar while looking at the left area. A drone yank, death, wake-up
## or the end of the night hides it and shuts an open laptop.
func _update_laptop_bar() -> void:
	var blocked := _night_finished or _drone_death_active or _drone_forced_look_active \
			or (awareness_meter != null and awareness_meter.is_waking())
	if blocked and _laptop_open():
		_close_laptop()
	if blocked and _hack_phase != HACK_NONE:
		_end_drone_hack()
	if blocked and _overlay_minigame_open():
		_close_overlay_minigame()
	if _laptop_bar == null:
		return
	var looking_left := _is_zoomed_in() and _current_zoom_region != null \
			and StringName(String(_current_zoom_region.name)) == LEFT_AREA_ZOOM_REGION
	# Stays up while the laptop is open too, so the same swipe puts it away.
	_laptop_bar.visible = looking_left and not blocked
	if _laptop_bar.visible:
		if _laptop_bar_anchor != null:
			_laptop_bar.position = _laptop_bar_anchor.global_position
			_laptop_bar.size = _laptop_bar_anchor.size
			_laptop_bar.scale = _laptop_bar_anchor.get_global_transform().get_scale()
		_laptop_bar.queue_redraw()
		# Re-arm once the cursor is off the bar.
		if not _laptop_bar.contains_global_point(_laptop_bar.get_global_mouse_position()):
			_laptop_bar_armed = true


## Opens the laptop as an overlay (maintenance / patrol / store) over the stress test.
## The open animation plays every time; a click on the transparent background shuts it
## immediately (no close animation).
func _open_laptop_overlay() -> void:
	if _laptop_open():
		return
	var packed := load(LAPTOP_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var laptop := packed.instantiate()
	# Laptop.gd has no class_name, so drive it dynamically.
	laptop.set("overlay_mode", true)
	laptop.set("instant", true)
	laptop.set("desktop_context", "stresstest")
	_laptop_overlay = laptop
	_hide_mouse_tooltip()
	if laptop.has_signal("closed"):
		laptop.connect("closed", _on_laptop_overlay_closed)
	add_child(laptop)
	_apply_laptop_lights()


## The open laptop's body darkens with the shed's lights like the rest of the room; its
## screen (a separate node) stays lit.
func _apply_laptop_lights() -> void:
	if not _laptop_open():
		return
	var body := _laptop_overlay.get("laptop_sprite") as CanvasItem
	if body != null:
		body.modulate = robot_lights_off_modulate if _stress_test_dark else robot_lights_on_modulate


func _on_laptop_overlay_closed() -> void:
	_laptop_overlay = null


## Shuts the laptop, playing its own close animation when it has one.
func _close_laptop() -> void:
	if not _laptop_open():
		return
	# Drop the reference first: the laptop frees itself once its close animation ends.
	var laptop := _laptop_overlay
	_laptop_overlay = null
	if laptop.has_method("_on_leave_pressed"):
		laptop.call("_on_leave_pressed")
	else:
		laptop.queue_free()


## The lever's AtlasTexture lives in the (cached) scene, so give this night its own
## copy before moving the region - otherwise the stage would carry over to the next.
func _initialize_engine_lever() -> void:
	lever_stage = clampi(lever_start_stage, 0, LEVER_STAGE_COUNT - 1)
	# The night opens with the meter already at the start stage's level, rather
	# than easing toward it from whatever the stress systems initialised it to.
	_electricity_percent = _lever_electricity_percent()
	# Already putting out power at nightfall: the generator was never "turned on", so
	# there's no first power-up flicker tonight.
	_first_power_on_done = _electricity_percent > 0.0
	if engine_lever == null or engine_lever.texture == null:
		return
	engine_lever.texture = engine_lever.texture.duplicate()
	_strip_lever_plate()
	_apply_lever_frame(lever_stage)
	_smooth_lever_dark_overlay()


## The lever sheet bakes a copper plate into every frame, sitting exactly over the shed's
## own back_panel art. Strip it so only the moving handle draws: the back_panel underneath
## then shows with dark1's shading exactly as painted. The plate is whatever every frame
## agrees on (each pixel's most common colour across the stages); the handle is what
## differs from it. The sheet file isn't touched.
func _strip_lever_plate() -> void:
	var atlas_tex := engine_lever.texture as AtlasTexture
	if atlas_tex == null or atlas_tex.atlas == null:
		return
	var img := atlas_tex.atlas.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var size := int(LEVER_FRAME_SIZE)
	var frames := mini(LEVER_STAGE_COUNT, img.get_height() / size)
	if frames < 2:
		return
	for y in size:
		for x in size:
			var counts := {}
			for f in frames:
				var c := img.get_pixel(x, f * size + y)
				counts[c] = int(counts.get(c, 0)) + 1
			var plate: Color = counts.keys()[0]
			for c in counts:
				if int(counts[c]) > int(counts[plate]):
					plate = c
			for f in frames:
				if img.get_pixel(x, f * size + y) == plate:
					img.set_pixel(x, f * size + y, Color(0, 0, 0, 0))
	atlas_tex.atlas = ImageTexture.create_from_image(img)


## How far (pixels) the lever's copy of the dark1 shading is smoothed.
const LEVER_DARK_SMOOTH_RADIUS: int = 6

## The lever wears the dark1 shading that sits over it in the art (Lever/DarkOverlay,
## clipped to the lever's pixels). dark1 has the back panel's slot shape painted into it,
## which printed onto the lever handle and made it look see-through, so the lever's copy
## of that shading is blurred here: same darkness, no slot shape. The art isn't touched.
func _smooth_lever_dark_overlay() -> void:
	var overlay := engine_lever.get_node_or_null(^"DarkOverlay") as TextureRect if engine_lever != null else null
	var atlas_tex := overlay.texture as AtlasTexture if overlay != null else null
	if atlas_tex == null or atlas_tex.atlas == null:
		return
	var sheet := atlas_tex.atlas.get_image()
	if sheet == null:
		return
	if sheet.is_compressed():
		sheet.decompress()
	var img := sheet.get_region(Rect2i(atlas_tex.region))
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	for y in h:
		for x in w:
			alpha[y * w + x] = img.get_pixel(x, y).a
	# Two passes of a separable box blur (close to a gaussian).
	for _pass in 2:
		alpha = _box_blur_alpha(alpha, w, h, LEVER_DARK_SMOOTH_RADIUS, true)
		alpha = _box_blur_alpha(alpha, w, h, LEVER_DARK_SMOOTH_RADIUS, false)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			c.a = alpha[y * w + x]
			img.set_pixel(x, y, c)
	overlay.texture = ImageTexture.create_from_image(img)


func _box_blur_alpha(src: PackedFloat32Array, w: int, h: int, radius: int, horizontal: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var total := 0.0
			var count := 0
			for d in range(-radius, radius + 1):
				var sx := clampi(x + d, 0, w - 1) if horizontal else x
				var sy := y if horizontal else clampi(y + d, 0, h - 1)
				total += src[sy * w + sx]
				count += 1
			out[y * w + x] = total / count
	return out


## Press on the engine lever to grab it, drag up/down to move it through its stages,
## release to leave it wherever it is.
func _handle_lever_input(event: InputEvent) -> bool:
	if engine_lever == null or not engine_lever.is_visible_in_tree():
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mouse_event.pressed and LEVER_BOX.has_point(_lever_local(mouse_event.global_position)):
			_dragging_lever = true
			_set_lever_stage(_lever_stage_at(mouse_event.global_position))
			return true
		if not mouse_event.pressed and _dragging_lever:
			_dragging_lever = false
			return true
	if event is InputEventMouseMotion and _dragging_lever:
		_set_lever_stage(_lever_stage_at((event as InputEventMouseMotion).global_position))
		return true
	return false


## Mouse position in the lever's own 96x96 frame space (handles camera zoom and roll).
func _lever_local(global_position: Vector2) -> Vector2:
	var local := engine_lever.get_global_transform().affine_inverse() * global_position
	# The TextureRect may be stretched; map back into source frame pixels.
	return local * (LEVER_FRAME_SIZE / maxf(1.0, engine_lever.size.y))


func _lever_stage_at(global_position: Vector2) -> int:
	var y := _lever_local(global_position).y
	var best := 0
	for i in LEVER_HANDLE_Y.size():
		if absf(LEVER_HANDLE_Y[i] - y) < absf(LEVER_HANDLE_Y[best] - y):
			best = i
	return best


func _set_lever_stage(stage: int) -> void:
	stage = clampi(stage, 0, LEVER_STAGE_COUNT - 1)
	_apply_lever_frame(stage)
	if stage == lever_stage:
		return
	lever_stage = stage
	_update_electricity(0.0)
	_refresh_stress_hud()
	lever_stage_changed.emit(stage)


func _apply_lever_frame(stage: int) -> void:
	var atlas := engine_lever.texture as AtlasTexture if engine_lever != null else null
	if atlas == null:
		return
	atlas.region = Rect2(0.0, float(stage) * LEVER_FRAME_SIZE, LEVER_FRAME_SIZE, LEVER_FRAME_SIZE)


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
	# Hitting the emergency button drives off a patrol drone at the window, flashing the
	# electrocution placeholder before it vanishes - but only if there's power to dump.
	# With the power already off (button already down, the generator stalled, or a drone
	# hack cut it) there's nothing to zap it with.
	if _generator_running and not _emergency_power_shutoff_pressed and _electricity_percent > 0.001:
		_zap_patrol_drone_if_active()
	# The clunk of the button stirs her toward waking.
	_add_awareness(awareness_emergency_button_gain)
	_play_emergency_power_button_sound()
	if _electricity_percent > 0.001:
		_play_generator_shutting_off_sound()
	if _can_start_emergency_consequence_pause():
		_start_emergency_consequence_pause()
	_generator_running = false
	_set_emergency_power_shutoff_pressed(true)
	_update_light_power()
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
	# Outside debug mode the exact electricity number is hidden too: the player
	# reads the power off the electricity meter bar instead.
	if electricity_value_label != null:
		electricity_value_label.visible = debug_mode
		if debug_mode:
			electricity_value_label.text = "%s: %.0f%% (lever %d, generator %s)" % [
				electricity_label_text,
				_electricity_percent,
				lever_stage,
				"on" if _generator_running else "off",
			]
	if gas_value_label != null:
		gas_value_label.text = "%s: %.0f%% / %.0f%% (%+.1f%%)" % [
			gas_label_text,
			_gas_flow_percent,
			_gas_optimal_percent,
			_gas_last_change_percent,
		]
	if uncle_value_label != null:
		# The light/uncle readout is a debug-only diagnostic now: the player is not
		# told how long the light lingers, so hide it entirely outside debug mode.
		uncle_value_label.visible = debug_mode
		if debug_mode:
			uncle_value_label.text = _format_uncle_meter_text()
	# The intro tutorial hides the awareness and endurance readouts (like the light).
	var show_awareness_endurance := not _is_intro_tutorial_stress_test()
	# Outside debug mode the exact awareness number is hidden: the player only gets
	# the stress-indicator eyes, so they can't see exactly how close she is to waking.
	if awareness_value_label != null:
		awareness_value_label.visible = show_awareness_endurance and debug_mode
		if debug_mode:
			awareness_value_label.text = "%s: %.0f / %.0f (%+.1f/s)" % [
				awareness_label_text,
				awareness_meter.awareness,
				awareness_meter.threshold,
				_current_awareness_rate_per_second(),
			]
	if endurance_value_label != null:
		endurance_value_label.visible = show_awareness_endurance
		endurance_value_label.text = "%s: %.0f / %.0f" % [
			endurance_label_text,
			awareness_meter.endurance,
			awareness_meter.endurance_threshold,
		]
	if robot_endurance_value_label != null:
		robot_endurance_value_label.visible = show_awareness_endurance
		robot_endurance_value_label.text = "%s: %.0f / %.0f" % [
			robot_endurance_label_text,
			awareness_meter.robot_endurance,
			awareness_meter.robot_endurance_threshold,
		]
		# Debug: the seconds left on the awareness lock while it holds.
		if debug_mode and awareness_meter.is_awareness_locked():
			robot_endurance_value_label.text += " (%.1fs)" % awareness_meter.awareness_lock_remaining
	_refresh_electricity_meter()


## The full light/uncle diagnostic, shown only in debug mode (see _refresh_stress_hud,
## which hides the label entirely otherwise - the player is never told the timing).
func _format_uncle_meter_text() -> String:
	var light_text := "--"
	if _window_alert_state == WINDOW_ALERT_YELLOW:
		var light_remaining := maxf(0.0, _window_alert_light_duration - _window_alert_elapsed)
		light_text = "%.1fs" % light_remaining
	var seen_limit := maxf(0.0, window_alert_seen_failure_seconds)
	var leave_text := "--"
	if _window_alert_state == WINDOW_ALERT_RED and not _is_uncle_exposure_active():
		var leave_remaining := maxf(0.0, _uncle_leave_seconds() - _window_alert_safe_elapsed)
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


## While the generator runs the meter eases toward the lever's setting. Once it is
## shut down (emergency button) the charge drains away at the emergency rate.
## Falling to 0% stalls the engine: it stays off until the rip cord restarts it.
## Idling at 0% (the night starts with the lever down) is not a stall.
func _update_electricity(delta: float) -> void:
	if _generator_running and not _emergency_power_shutoff_pressed:
		var previous := _electricity_percent
		_electricity_percent = move_toward(
			_electricity_percent,
			_lever_electricity_percent(),
			maxf(0.0, electricity_change_percent_per_second) * delta
		)
		if previous > 0.0 and _electricity_percent <= 0.0 and delta > 0.0:
			_generator_running = false
	else:
		_electricity_percent = maxf(0.0, _electricity_percent - emergency_power_electricity_decay_per_second * delta)


func _lever_electricity_percent() -> float:
	if lever_stage_electricity_percents.is_empty():
		return 0.0
	var index := clampi(lever_stage, 0, lever_stage_electricity_percents.size() - 1)
	return lever_stage_electricity_percents[index]


func _start_generator() -> void:
	_generator_running = true
	_set_emergency_power_shutoff_pressed(false)
	_update_electricity(0.0)
	_update_generator_power_sound()
	_refresh_stress_hud()


## Hooks the shared awareness meter up to the robot and puts its eyes in the
## screen's top-left corner. They hang off FullscreenRoot (the visible screen)
## rather than the camera window, which is cropped to fit the screen and so has
## its top and bottom edges out of view. Waking her up locks the night, and the
## wake delay running out fails it.
func _initialize_awareness_meter() -> void:
	var fullscreen_root := get_node_or_null(^"FullscreenLayer/FullscreenRoot") as Control
	# The intro tutorial hides the awareness readouts, so hide the eyes too.
	awareness_meter.setup(stress_test_robot, fullscreen_root, not _is_intro_tutorial_stress_test())
	awareness_meter.woke_up.connect(_on_robot_woke_up)
	awareness_meter.wake_finished.connect(func() -> void:
		_fail_stress_test(awareness_failure_text, true)
	)


## She woke up: freeze the night; it fails once the wake delay runs out. Like the drone's
## forced look, the camera is yanked onto her so the player sees her wake.
func _on_robot_woke_up() -> void:
	_hide_mouse_tooltip()
	_set_stress_test_interaction_enabled(false)
	_force_camera_to_robot()


## Signed awareness rate right now (positive while animating, negative decay
## otherwise), for the debug HUD readout.
func _current_awareness_rate_per_second() -> float:
	return awareness_meter.awareness_rate_per_second(_passive_awareness_gain_per_second(), _current_awareness_decay_per_second())


## Steady awareness gain that runs whether or not she is animating: the power
## level plus every loose screw.
func _passive_awareness_gain_per_second() -> float:
	var zaps := 0.0
	if _robot_zaps != null:
		zaps = _robot_zaps.awareness_per_second(_night_elapsed, maxf(0.0, zap_awareness_per_second),
				maxf(0.0, zap_reduced_awareness_per_second))
	return _power_awareness_gain_per_second() \
			+ float(_screw_active_events.size()) * maxf(0.0, awareness_per_loose_screw_per_second) \
			+ zaps


## Awareness added per second by the power level: nothing up to the start
## percent, scaling to the full rate at 100%, then on to the overload rate.
func _power_awareness_gain_per_second() -> float:
	var power := _electricity_percent
	var start := awareness_power_gain_start_percent
	if power <= start:
		return 0.0
	if power <= 100.0:
		return lerpf(0.0, awareness_power_gain_full_per_second,
				clampf((power - start) / maxf(0.001, 100.0 - start), 0.0, 1.0))
	return lerpf(awareness_power_gain_full_per_second, awareness_power_gain_overload_per_second,
			clampf((power - 100.0) / maxf(0.001, awareness_power_gain_overload_percent - 100.0), 0.0, 1.0))


## Decay per second while undisturbed, set by the power: nothing at the power-gain
## start percent (50%, neutral), scaling up to the max rate at 0% power.
func _current_awareness_decay_per_second() -> float:
	var neutral := maxf(0.001, awareness_power_gain_start_percent)
	var low_power := clampf((neutral - _electricity_percent) / neutral, 0.0, 1.0)
	return awareness_decay_max_per_second * low_power


## Discrete awareness bump from a player action (a body-part move or the emergency
## button). Also refreshes the HUD so the jump shows immediately.
func _add_awareness(amount: float) -> void:
	if _night_finished:
		return
	awareness_meter.add(amount)
	_refresh_stress_hud()


func _on_body_part_moved(is_leg_raise: bool) -> void:
	if _night_finished:
		return
	awareness_meter.add_for_move(is_leg_raise)
	_refresh_stress_hud()


## The night's electricity produced (scored at the end, see _electricity_summary): it
## starts at 0 and adds the current meter level's rate every second.
func _accumulate_electricity_generated(delta: float) -> void:
	if delta <= 0.0:
		return
	_electricity_generated += _electricity_generation_rate_per_second() * delta


## Electricity produced per second at the current meter level: a straight line from
## nothing at 0% to electricity_produced_per_second_at_full at 100%, then on to
## electricity_produced_per_second_at_overload at ELECTRICITY_OVERLOAD_PERCENT, held there past it.
func _electricity_generation_rate_per_second() -> float:
	var percent := maxf(0.0, _electricity_percent)
	if percent <= 100.0:
		return electricity_produced_per_second_at_full * percent / 100.0
	var overload := clampf((percent - 100.0) / (ELECTRICITY_OVERLOAD_PERCENT - 100.0), 0.0, 1.0)
	return lerpf(electricity_produced_per_second_at_full, electricity_produced_per_second_at_overload, overload)


## Debug (number-4 give-items): re-derive which limbs expose screws now that new
## parts may have been granted, and refresh the screwdriver/manual repair mode.
## The robot's limb visuals already update live via robot_parts_changed; the
## screw wiring is intentionally only recomputed on this explicit trigger, never
## polled, so there is no per-frame cost.
func debug_recalibrate() -> void:
	_apply_body_part_screw_availability()
	_connect_screw_summary_tracking()
	# Picks up a curtains grant made from the debug menu mid-night.
	_apply_curtain_availability()


# --- Debug actions panel entry points (driven by Main's Shift+Tab menu) ---

## Forces a patrol drone to appear right now (if the night is live and no drone
## is already on screen).
## Debug-menu cheat toggles: "no_awareness", "no_enemies" and "infinite_time".
## Returns the cheat's new state.
func debug_toggle_cheat(cheat: String) -> bool:
	match cheat:
		"no_awareness":
			_debug_no_awareness = not _debug_no_awareness
			awareness_meter.pinned_at_zero = _debug_no_awareness
			if _debug_no_awareness:
				awareness_meter.awareness = 0.0
		"no_enemies":
			_debug_no_enemies = not _debug_no_enemies
			if _debug_no_enemies:
				_suppress_uncle_appearance()
				_suppress_patrol_drone()
		"infinite_time":
			_debug_infinite_time = not _debug_infinite_time
	_refresh_stress_hud()
	return debug_cheat_enabled(cheat)


func debug_cheat_enabled(cheat: String) -> bool:
	match cheat:
		"no_awareness":
			return _debug_no_awareness
		"no_enemies":
			return _debug_no_enemies
		"infinite_time":
			return _debug_infinite_time
	return false


func debug_summon_drone() -> void:
	if _night_finished or _drone_state != DRONE_NONE:
		return
	_start_patrol_drone()


## Forces an uncle window check right now (if the night is live and no window
## alert is already running).
func debug_summon_uncle() -> void:
	if _night_finished or _window_alert_state != WINDOW_ALERT_NONE:
		return
	_start_window_alert()


func debug_toggle_human_skin() -> void:
	_call_robot_debug("debug_toggle_human_skin")


func debug_toggle_squint() -> void:
	_call_robot_debug("debug_toggle_squint_eyes")


func debug_swap_head_style() -> void:
	_call_robot_debug("debug_swap_head_texture")


func debug_swap_hand_grip() -> void:
	_call_robot_debug("debug_toggle_hand_grip")


## Cycle the animation loop-slurp sound override on the robot (Default -> each
## sound -> Default) for whichever animation last played.
func debug_cycle_anim_sound() -> void:
	_call_robot_debug("debug_cycle_anim_sound")


## Current override label for the debug menu button (e.g. "Pelvis Sound: Plap 3").
func debug_anim_sound_label() -> String:
	if stress_test_robot != null and stress_test_robot.has_method("debug_anim_sound_label"):
		return String(stress_test_robot.call("debug_anim_sound_label"))
	return "Anim Sound: Default"


func _call_robot_debug(method: String) -> void:
	if stress_test_robot != null and stress_test_robot.has_method(method):
		stress_test_robot.call(method)


## Sides (0-2) with at least an upper arm on her: a full arm, or one built as far as its
## upper arm in maintenance.
func _upper_arm_side_count() -> int:
	var count := 0
	for side in GameState.PART_SIDES:
		if _side_has_upper_arm(side):
			count += 1
	return count


## Whether paired part `id` (arm / leg / hand) is on her on `side` ("left" / "right") - the
## laptop can take off one particular side.
func _side_has_part(id: String, side: String) -> bool:
	return GameState.is_part_attached_on(id, side)


## Whether `side` has at least an upper arm on her: its full arm, or one part-built in
## maintenance as far as its upper arm (never the upper arms in the inventory).
func _side_has_upper_arm(side: String) -> bool:
	return _side_has_part("arm", side) or GameState.get_limb_segments("arm", side).has("upper_arm")


func _apply_body_part_screw_availability() -> void:
	# The arm screws all sit on the upper arm, so they're reachable whenever a side
	# has any arm - including a loose upper-arm sub-assembly with no forearm.
	_set_screw_repair_available(left_arm_screw_repair, _side_has_upper_arm("left"))
	_set_screw_repair_available(right_arm_screw_repair, _side_has_upper_arm("right"))
	# The torso screw plate spans both mid-body parts, so it is reachable if
	# either the chest or the stomach is attached. The two waist screws sit on the
	# stomach, so they additionally require it (and stay hidden under an arm).
	var chest_count := _robot_part_count("chest")
	var stomach_count := _robot_part_count("stomach")
	_set_screw_repair_available(torso_screw_repair, chest_count >= 1 or stomach_count >= 1)
	if torso_screw_repair != null and torso_screw_repair.has_method("set_screw_available"):
		# Each waist screw hides under that side's arm.
		torso_screw_repair.call("set_screw_available", TORSO_SCREW_INDEX_LEFT_WAIST, stomach_count >= 1 and not _side_has_part("arm", "left"))
		torso_screw_repair.call("set_screw_available", TORSO_SCREW_INDEX_RIGHT_WAIST, stomach_count >= 1 and not _side_has_part("arm", "right"))
	var left_leg := _side_has_part("leg", "left")
	var right_leg := _side_has_part("leg", "right")
	_set_screw_repair_available(left_leg_screw_repair, left_leg)
	_set_screw_repair_available(right_leg_screw_repair, right_leg)
	# The inner knee is hidden between the legs, so it is only exposed once a
	# leg is missing. Keep it unavailable while both legs are still attached.
	for leg_repair in [left_leg_screw_repair, right_leg_screw_repair]:
		if leg_repair != null and leg_repair.has_method("set_screw_available"):
			leg_repair.call("set_screw_available", LEG_SCREW_INDEX_INNER_KNEE, not (left_leg and right_leg))


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
		# Per-screw tool choice: screwdrivers are a shared budget across all limbs,
		# so a starting repair uses one only if a screwdriver is still free.
		if repair.has_method("set_manual_decider"):
			repair.call("set_manual_decider", Callable(self, "_screw_repair_should_use_hand"))
		if repair.has_method("set_hand_screw_offset"):
			repair.call("set_hand_screw_offset", hand_screw_animation_offset)
		_connect_screw_signal(repair, "screw_loosened", "_on_screw_loosened")
		_connect_screw_signal(repair, "repair_started", "_on_screw_repair_started")
		_connect_screw_signal(repair, "repair_interrupted", "_on_screw_repair_interrupted")
		_connect_screw_signal(repair, "screw_repaired", "_on_screw_repaired")


## Permission gate handed to each screw repair controller. Concurrency is bounded
## by the player's two hands: one left-side and one right-side repair may run at
## once, never two on the same side - regardless of screwdriver count. The tool
## each repair uses (screwdriver vs bare hand) is decided separately, see
## _screw_repair_should_use_hand.
func _can_begin_screw_repair(side: String) -> bool:
	return not _is_side_screw_repair_active(side)


## Per-screw tool choice for a repair about to start on the given side. The player
## owns _screwdriver_count() screwdrivers, shared across the whole robot; each is
## used by at most one in-progress repair. When they're all busy (or the player
## owns none) the repair is driven by hand instead. So: two screwdrivers drive two
## screws at once; a single screwdriver drives the first while the second uses a
## hand; zero screwdrivers means hands only.
func _screw_repair_should_use_hand(_side: String) -> bool:
	var screwdriver_count := _screwdriver_count()
	if screwdriver_count <= 0:
		return true
	return _active_screwdriver_repair_count() >= screwdriver_count


## How many in-progress repairs across every limb are currently using a screwdriver
## (rather than a hand). Used to see whether a free screwdriver remains.
func _active_screwdriver_repair_count() -> int:
	var count := 0
	for repair in _screw_repair_controllers():
		if repair.has_method("active_screwdriver_side_count"):
			count += int(repair.call("active_screwdriver_side_count"))
	return count


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


## Loosens one random screw each time the power has stayed high enough for the
## current gap (power-scaled interval plus the random bonus). Dropping below the
## minimum power resets the countdown.
func _update_screw_spawns(delta: float) -> void:
	if _electricity_percent < screw_spawn_min_power_percent:
		_screw_spawn_timer = 0.0
		return
	_screw_spawn_timer += delta
	if _screw_spawn_timer < _screw_spawn_interval_seconds() + _screw_spawn_bonus:
		return
	_screw_spawn_timer = 0.0
	_screw_spawn_bonus = _random_screw_bonus_seconds()
	_trigger_random_screw()


## Gap between screws at the current power, before the random bonus.
func _screw_spawn_interval_seconds() -> float:
	if _electricity_percent > 100.0:
		return maxf(0.1, screw_interval_overload_seconds)
	var t := clampf(
		(_electricity_percent - screw_spawn_min_power_percent) / maxf(0.001, 100.0 - screw_spawn_min_power_percent),
		0.0,
		1.0
	)
	return maxf(0.1, lerpf(screw_interval_at_min_power_seconds, screw_interval_at_full_power_seconds, t))


func _random_screw_bonus_seconds() -> float:
	var low := maxf(0.0, minf(screw_interval_bonus_min_seconds, screw_interval_bonus_max_seconds))
	return _rng.randf_range(low, maxf(low, screw_interval_bonus_max_seconds))


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
			"suspicion_delta": _electricity_bonus_suspicion_delta(),
			"anger_delta": _stress_test_anger_delta(),
			"fatigue_delta": _electricity_bonus_fatigue_delta(),
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
	# Only the uncle catching you or the drone shooting you is a failure now; simply
	# running out the clock always completes the night, whatever the electricity was.
	_complete_stress_test_success()


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
			# Leaving it with DONE counts as a night without a stress test (Main adds
			# the skipped-test anger; the night's fatigue applies as usual).
			"stress_test_failed": true,
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
	_stop_screw_repair_audio()
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
	_summary_shot = _drone_state == DRONE_SHOT
	# Leave the drone on screen (frozen on its shot pose) when it is the one that
	# ended the night, so it stays visible through the failure wipe instead of
	# blinking out on the last frame; clear it for any other cause.
	if _drone_state != DRONE_SHOT:
		_clear_patrol_drone()
	_begin_summary_audio_fadeout()
	_hide_mouse_tooltip()
	_set_stress_test_interaction_enabled(false)
	_summary_success = success
	_summary_reason = reason
	_summary_result = result
	_summary_registers_completion = registers_completion
	_pending_failure_registers_wake = registers_wake
	# Log this night to the laptop's stress-test history - real nights only, not the
	# intro tutorial retry (which sets _intro_failure_restart_pending before coming here).
	if not _intro_failure_restart_pending:
		GameState.record_stress_test_result({
			"day": GameState.day,
			"success": success,
			"reason": reason,
			"electricity": float(_electricity_summary()["percent"]),
			"screws": float(_screw_summary()["percent"]),
		})
	_dragging_gas_valve = false
	_update_summary_text()

	if failure_overlay == null:
		_finish_stress_test_summary()
		return

	# Shot, the view is already a wall of red: the results come straight in on it.
	var main := _main_controller() if not _drone_death_red_done else null
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


## The dialog's own good/bad text colours (see the .dlg files): green for a
## positive outcome, red for a negative one. Reused here so a drop in anger reads
## green and a rise reads red, matching the rest of the game.
const SUMMARY_ANGER_GOOD_COLOR := Color("7fdf7f")
const SUMMARY_ANGER_BAD_COLOR := Color("df7f7f")


func _update_summary_text() -> void:
	if failure_title_label != null:
		failure_title_label.text = "You failed" if _intro_failure_restart_pending else summary_title_text
	if failure_reason_label != null:
		failure_reason_label.text = _build_summary_text()
	_update_anger_summary_label()
	if failure_continue_button != null:
		failure_continue_button.text = "RETRY" if _intro_failure_restart_pending else "CONTINUE"


## Fills the anger line as its own label so it can be coloured on its own: green
## when the night removes anger, red when it adds anger, and the default text
## colour (white) when it is a wash. Only shown on a completed stress test.
func _update_anger_summary_label() -> void:
	if anger_value_label == null:
		return
	if _intro_failure_restart_pending or not _summary_success:
		anger_value_label.visible = false
		return

	anger_value_label.visible = true
	var anger_delta := _stress_test_anger_delta()
	if anger_delta == 0:
		anger_value_label.text = "Anger: no change"
		anger_value_label.remove_theme_color_override("font_color")
	else:
		anger_value_label.text = "Anger: %+d" % anger_delta
		anger_value_label.add_theme_color_override(
			"font_color",
			SUMMARY_ANGER_GOOD_COLOR if anger_delta < 0 else SUMMARY_ANGER_BAD_COLOR
		)


func _build_summary_text() -> String:
	if _intro_failure_restart_pending:
		return _summary_reason if not _summary_reason.is_empty() else "The stress test has to be repeated."

	var lines: Array[String] = []
	if not _summary_success:
		# A failure (uncle caught you / drone shot you) shows only the reason - the
		# electricity and screw scores are irrelevant to a night that was cut short.
		lines.append("Result: Failed")
		if not _summary_reason.is_empty():
			lines.append("Reason: %s" % _summary_reason)
		return "\n".join(lines)

	lines.append("Result: %s" % summary_success_text)

	var electricity := _electricity_summary()
	var electricity_percent := float(electricity["percent"])
	lines.append("Electricity: %s  %.0f%%" % [
		_stars_for_score(electricity_percent),
		electricity_percent,
	])

	var screws := _screw_summary()
	lines.append("Screws: %s  %d / %d  (%.0f%%)" % [
		_stars_for_score(float(screws["percent"])),
		int(screws["repaired"]),
		int(screws["total"]),
		float(screws["percent"]),
	])

	return "\n".join(lines)


## Electricity result: the electricity produced over the night against its targets,
## both set by the night's full length in seconds (T) - never the time actually
## played, so ending early cannot dodge the power the rest of the night would have
## needed. Break-even is T x electricity_break_even_per_second, the top score
## T x electricity_top_score_per_second; the percent is produced against the top score
## (capped at 100), and "bonus" is set when production beat the top score.
func _electricity_summary() -> Dictionary:
	var full_night := maxf(0.001, night_duration_seconds)
	var break_even := full_night * maxf(0.0, electricity_break_even_per_second)
	var top_score := maxf(break_even + 0.001, full_night * electricity_top_score_per_second)
	return {
		"percent": clampf(_electricity_generated / top_score, 0.0, 1.0) * 100.0,
		"generated": _electricity_generated,
		"break_even": break_even,
		"top_score": top_score,
		"bonus": _electricity_generated > top_score,
	}


## Screw result: a clean percentage of how many screws were screwed back in out
## of how many total loosened over the night. When the night is ended early the
## screws that had appeared so far are not a fair total (bail out at second one
## and zero screws would read as a free 100%), so the denominator becomes the
## night's average predicted screw count instead.
func _screw_summary() -> Dictionary:
	var repaired := maxi(0, _screw_repaired_count)
	var total: int
	if _ended_early:
		total = maxi(_screw_started_count, int(round(_predicted_total_screws())))
	else:
		total = maxi(0, _screw_started_count)
	var percent := 100.0
	if total > 0:
		percent = clampf(float(repaired) / float(total), 0.0, 1.0) * 100.0
	return {
		"percent": percent,
		"repaired": repaired,
		"total": total,
	}


## Screws a full night would have loosened: the ones so far plus the rest of the
## night at the current power's average gap (interval plus mean bonus). Used only
## to fill in a fair screw total when the player ends the night early, before the
## real screws could appear.
func _predicted_total_screws() -> float:
	var started := float(maxi(0, _screw_started_count))
	if _electricity_percent < screw_spawn_min_power_percent or _active_screw_limb_count() <= 0:
		return started
	var remaining := maxf(0.0, night_duration_seconds - _night_elapsed)
	var avg_bonus := (maxf(0.0, screw_interval_bonus_min_seconds) + maxf(0.0, screw_interval_bonus_max_seconds)) * 0.5
	return started + remaining / maxf(0.1, _screw_spawn_interval_seconds() + avg_bonus)


## Number of screw-bearing limbs currently exposed on the robot (an unattached or
## covered part has its repair controller disabled and loosens nothing).
func _active_screw_limb_count() -> int:
	var count := 0
	for repair in _screw_repair_controllers():
		if bool(repair.get("enabled")):
			count += 1
	return count


## A stress test where BOTH electricity and screws come in at 10% or lower applies
## this fixed anger delta instead of the graduated calculation.
const ANGER_MINIMAL_EFFORT_THRESHOLD_PERCENT: float = 10.0
const ANGER_MINIMAL_EFFORT_DELTA: int = -15


## Total anger the completed stress test applies, from the two results. With the
## default settings a top night removes eleven anger (ten from electricity, one from
## screws); a worst-case night adds twelve (ten from no electricity, two from the screw
## bracket). The anger stat itself is floored at zero by GameState, so it never runs
## negative.
func _stress_test_anger_delta() -> int:
	var electricity := _electricity_summary()
	var electricity_percent := float(electricity["percent"])
	var screw_percent := float(_screw_summary()["percent"])
	if electricity_percent <= ANGER_MINIMAL_EFFORT_THRESHOLD_PERCENT \
			and screw_percent <= ANGER_MINIMAL_EFFORT_THRESHOLD_PERCENT:
		return ANGER_MINIMAL_EFFORT_DELTA
	return _electricity_anger_delta(electricity) + _screw_anger_delta(screw_percent)


## Electricity anger from the produced total: electricity_anger_max_gain with nothing
## produced, falling in a straight line to no change at break-even, then on down to
## -electricity_anger_max_removal at the top score (held there past it).
func _electricity_anger_delta(electricity: Dictionary) -> int:
	var generated := float(electricity["generated"])
	var break_even := float(electricity["break_even"])
	var top_score := float(electricity["top_score"])
	if generated < break_even:
		return roundi(lerpf(float(electricity_anger_max_gain), 0.0, generated / maxf(0.001, break_even)))
	var past_break_even := clampf((generated - break_even) / (top_score - break_even), 0.0, 1.0)
	return -roundi(float(electricity_anger_max_removal) * past_break_even)


## The extra fatigue and temporary-suspicion change a completed night earns by
## producing more electricity than the top score (0 otherwise).
func _electricity_bonus_fatigue_delta() -> int:
	return electricity_bonus_fatigue_delta if bool(_electricity_summary()["bonus"]) else 0


func _electricity_bonus_suspicion_delta() -> int:
	return electricity_bonus_suspicion_delta if bool(_electricity_summary()["bonus"]) else 0


## Screw anger bracket: a flawless 100% pulls one anger off; 80-99% is neutral;
## 40-79% adds one; 39% or lower adds two.
func _screw_anger_delta(percent: float) -> int:
	if percent >= 100.0:
		return -1
	if percent >= 80.0:
		return 0
	if percent >= 40.0:
		return 1
	return 2


## A five-star rating from a 0-100 percentage: one filled star per 20 points.
func _stars_for_score(score: float) -> String:
	var full_count := _star_count_for_score(score)
	var stars := ""
	for i in range(5):
		stars += "★" if i < full_count else "☆"
	return stars


## How many of five stars a 0-100 percentage earns: one per 20 points.
func _star_count_for_score(score: float) -> int:
	return clampi(int(floor(clampf(score, 0.0, 100.0) / 20.0)), 0, 5)


func _show_failure_overlay() -> void:
	if failure_overlay == null:
		return
	_update_summary_text()
	awareness_meter.set_hud_visible(false)
	failure_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	failure_overlay.visible = true
	if failure_continue_button != null:
		failure_continue_button.disabled = true
	_show_results_screen()


func _on_failure_transition_finished() -> void:
	_failure_transition_playing = false
	if failure_continue_button != null:
		failure_continue_button.disabled = false
	get_tree().paused = true
	# Once the wipe has uncovered it, the results panel drops in from the top.
	if _results_screen != null:
		_results_screen.slide_in()


## Puts the results screen up over the failure overlay, in place of its summary panel
## (and that panel's grey backdrop): a failed night's reason with DONE and TRY AGAIN, or a
## completed night's scores with DONE.
func _show_results_screen() -> void:
	for child_name in ["FailureDim", "FailurePanel"]:
		var child := failure_overlay.get_node_or_null(child_name) as CanvasItem
		if child != null:
			child.visible = false
	if _results_screen != null:
		return
	var screen := StressTestResultsScreen.new()
	screen.name = "ResultsScreen"
	screen.success = _summary_success
	screen.shot = _summary_shot
	screen.shot_color = Color(drone_death_red_color, 1.0)
	if _drone_death_red_done:
		screen.rain_fade_in = RESULTS_AFTER_RED_RAIN_FADE
	if _summary_success:
		screen.result_text = summary_success_result_text
		screen.stats = _summary_stats()
		screen.show_try_again = false
	else:
		screen.reason = _summary_reason if not _summary_reason.is_empty() \
				else "The stress test has to be repeated."
		# The intro's stress test has to be passed, so it only offers another go.
		screen.show_done = not _intro_failure_restart_pending
	screen.done_pressed.connect(_on_failure_continue_button_pressed)
	screen.try_again_pressed.connect(_on_failure_try_again_pressed)
	failure_overlay.add_child(screen)
	_results_screen = screen


## A completed night's scores for the results screen: electricity (produced / top
## score) and screws with their star ratings, then the change in anger - green when it
## falls, red when it rises - and the fatigue and suspicion bonus for beating the top
## electricity score.
func _summary_stats() -> Array[Dictionary]:
	var electricity := _electricity_summary()
	var electricity_percent := float(electricity["percent"])
	var screws := _screw_summary()
	var screws_percent := float(screws["percent"])
	var stats: Array[Dictionary] = [
		{
			"label": "Electricity:",
			"stars": _star_count_for_score(electricity_percent),
			"value": "%d / %d" % [floori(float(electricity["generated"])), roundi(float(electricity["top_score"]))],
		},
		{
			"label": "Screws:",
			"stars": _star_count_for_score(screws_percent),
			"value": "%d / %d  (%.0f%%)" % [int(screws["repaired"]), int(screws["total"]), screws_percent],
		},
	]
	var anger_delta := _stress_test_anger_delta()
	var anger := {"label": "Anger: no change" if anger_delta == 0 else "Anger: %+d" % anger_delta, "space_before": 2.0}
	if anger_delta != 0:
		anger["color"] = StressTestResultsScreen.RESULT_GOOD_COLOR if anger_delta < 0 \
				else StressTestResultsScreen.RESULT_BAD_COLOR
	stats.append(anger)
	for bonus in [["Fatigue", _electricity_bonus_fatigue_delta()], ["Suspicion", _electricity_bonus_suspicion_delta()]]:
		var delta: int = bonus[1]
		if delta != 0:
			stats.append({
				"label": "%s: %+d" % [bonus[0], delta],
				"color": StressTestResultsScreen.RESULT_GOOD_COLOR if delta < 0 else StressTestResultsScreen.RESULT_BAD_COLOR,
			})
	return stats


## TRY AGAIN: the stress test starts over from the beginning, the failed night left
## behind (like restarting the night in the Sleep scene).
func _on_failure_try_again_pressed() -> void:
	if _failure_transition_playing:
		return
	if _intro_failure_restart_pending:
		_restart_intro_tutorial_stress_test()
		return
	_unpause_after_summary()
	var main := _main_controller()
	if main != null and main.has_method("restart_stress_test"):
		main.call("restart_stress_test")
	else:
		get_tree().reload_current_scene()


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
	_unpause_after_summary()
	if _summary_registers_completion:
		DayCycle.register_stress_test_completed()
		_summary_registers_completion = false
	if _pending_failure_registers_wake:
		DayCycle.register_stress_test_wake()
		_pending_failure_registers_wake = false
	# finish() carries no fatigue, so the night's fatigue change is applied here.
	var fatigue_delta := int(_summary_result.get("fatigue_delta", 0))
	if fatigue_delta != 0:
		GameState.add_fatigue(fatigue_delta)
	finish(
		int(_summary_result.get("money_delta", 0)),
		int(_summary_result.get("suspicion_delta", 0)),
		int(_summary_result.get("anger_delta", 0)),
		_summary_result.get("ingredients", {}),
		bool(_summary_result.get("skip_advance", false)),
		"",
		{"stress_test_failed": bool(_summary_result.get("stress_test_failed", false))}
	)


func _on_end_button_pressed() -> void:
	if _is_intro_tutorial_stress_test():
		return
	# Ending the night manually still scores as if the full night had run: the
	# results predict the screws that would have appeared and measure electricity
	# against the whole intended night (see _screw_summary / _electricity_summary).
	_ended_early = true
	_complete_stress_test_success()


func _on_wake_button_pressed() -> void:
	_fail_robot_wake()


func _on_failure_continue_button_pressed() -> void:
	if _failure_transition_playing:
		return
	if _intro_failure_restart_pending:
		_restart_intro_tutorial_stress_test()
		return
	_finish_stress_test_summary()


func _restart_intro_tutorial_stress_test() -> void:
	_intro_failure_restart_pending = false
	_unpause_after_summary()
	var main := _main_controller()
	if main != null and main.has_method("restart_intro_current_step"):
		main.call("restart_intro_current_step")
	else:
		get_tree().reload_current_scene()


func _update_intro_head_interaction_gate() -> void:
	# The intro tutorial keeps the robot un-animatable for its entire length. There
	# is no longer a final-seconds unlock, so the player can never animate her here.
	pass


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
