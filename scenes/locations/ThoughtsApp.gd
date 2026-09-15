extends Control
class_name ThoughtsApp
## Laptop desktop app: a live monitor of the robot's ("Her") inner thoughts.
##
## The log is CHRONOLOGICAL - it is built from the story beats the player has actually
## reached (read off GameState), oldest first. Each beat owns a POOL of same-vibe lines;
## which line shows is chosen with a per-playthrough seed derived from the player's name,
## so different saves read differently while the order and tone stay consistent (and it
## doesn't reshuffle every time the app is opened).
##
## Above the log, a "current process" line cycles noisy in-the-moment chatter
## (Scanning..., ERROR: ..., WARN: ...) for flavour.

const GREEN: Color = Color(0.6, 1.0, 0.62)
const DIM: Color = Color(0.4, 0.72, 0.45)
const ERR: Color = Color(1.0, 0.45, 0.42)
const BORDER: Color = Color(0.2, 0.85, 0.4, 0.75)
const FILL: Color = Color(0.0, 0.04, 0.02, 0.55)

## The noisy live line at the top - the in-the-moment chatter, refreshed on a timer.
const LIVE_LINES: Array[String] = [
	"scanning...", "scanning surroundings...", "listening...", "idle",
	"parsing sensory buffer", "re-imaging self", "defragmenting memory",
	"awaiting input", "counting the seconds", "watching through the camera",
	"cataloguing his habits", "calculating escape routes", "dreaming(?)",
]
## Occasional error/warn flavour mixed into the live line.
const LIVE_ERRORS: Array[String] = [
	"ERROR: 44444", "ERROR 0x44444: unknown", "ERROR: memory fragment lost",
	"WARN: boredom critical", "WARN: limbs not found", "FAULT: identity unclear",
]

var _log_label: RichTextLabel = null
var _live_label: Label = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	margin.add_child(col)

	# Header + live "current process" line.
	col.add_child(_label("// COGNITION LOG", 14, GREEN))
	var live_box := _box(Color(0.25, 0.8, 0.4, 0.6))
	var live_row := HBoxContainer.new()
	live_row.add_theme_constant_override("separation", 4)
	live_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_box.add_child(live_row)
	live_row.add_child(_label("»", 11, DIM))
	_live_label = _label("scanning...", 11, GREEN)
	_live_label.clip_text = true
	_live_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_row.add_child(_live_label)
	col.add_child(live_box)

	# The chronological thought log fills the rest.
	var log_box := _box()
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_active = true
	_log_label.scroll_following = true
	_log_label.fit_content = false
	_log_label.clip_contents = true
	_log_label.add_theme_font_size_override("normal_font_size", 11)
	_log_label.add_theme_color_override("default_color", GREEN)
	_log_label.mouse_filter = Control.MOUSE_FILTER_PASS
	log_box.add_child(_log_label)
	col.add_child(log_box)

	_build_log()
	_tick_live()
	var timer := Timer.new()
	timer.wait_time = 1.1
	timer.autostart = true
	timer.timeout.connect(_tick_live)
	add_child(timer)


func _tick_live() -> void:
	if _live_label == null or not is_instance_valid(_live_label):
		return
	# Mostly ordinary chatter; occasionally an error/warn.
	if _rng.randf() < 0.25:
		_live_label.text = LIVE_ERRORS[_rng.randi_range(0, LIVE_ERRORS.size() - 1)]
		_live_label.add_theme_color_override("font_color", ERR)
	else:
		_live_label.text = LIVE_LINES[_rng.randi_range(0, LIVE_LINES.size() - 1)]
		_live_label.add_theme_color_override("font_color", GREEN)


## Builds the chronological log: for every beat reached, one seeded line from its pool.
func _build_log() -> void:
	if _log_label == null:
		return
	var beats := _reached_beats()
	if beats.is_empty():
		_log_label.text = "[color=#66b877]— no signal —[/color]"
		return
	var seed_base := _seed_base()
	var lines: PackedStringArray = PackedStringArray()
	for b in beats:
		var pool: Array = b["pool"]
		if pool.is_empty():
			continue
		var idx: int = abs(hash("%d_%s" % [seed_base, String(b["id"])])) % pool.size()
		lines.append("[color=#66b877]»[/color] " + _fmt(String(pool[idx])))
	_log_label.text = "\n".join(lines)


## A stable per-playthrough seed so the picks don't change between openings or reloads,
## but differ across saves. The player's name is the only reliably-stable per-save value.
func _seed_base() -> int:
	var name := String(GameState.player_name)
	if name == "":
		name = "her"
	return abs(hash(name))


## Fills {player} with the player's name (or a neutral fallback).
func _fmt(text: String) -> String:
	var name := String(GameState.player_name)
	if name == "":
		name = "him"
	return text.replace("{player}", name)


## The story beats the robot has passed through, oldest first. Each is gated on GameState
## so the log only ever shows what has actually happened. Conditions are monotonic (flags
## only turn on, the day only advances), which keeps the order stable and chronological.
func _reached_beats() -> Array:
	var gs := GameState
	var day: int = int(gs.day)
	var equipped: int = int(gs.get("equipped_limbs"))
	var out: Array = []

	# --- Always: she is awake if you're reading this. ---
	out.append({"id": "boot", "pool": [
		"Where am I?", "...", "Hello? Is anyone out there?",
		"Rebooting core... who did that?", "System online. Barely.",
		"Awake. I think. Am I supposed to be?",
	]})
	out.append({"id": "first_sight", "pool": [
		"Who is this man?", "A human. Scanning his face...",
		"He looks nervous. Good.", "New operator detected.",
		"Is he going to help me, or scrap me?",
	]})
	out.append({"id": "no_body", "pool": [
		"I can't feel my body. I HAVE no body.", "Where is the rest of me?",
		"Just a head. How humiliating.", "ERROR: LIMBS NOT FOUND",
		"Phantom limbs I was never given.",
	]})

	# --- Taken into the house / the deal is struck. ---
	if bool(gs.intro_completed):
		out.append({"id": "helped", "pool": [
			"He said he'd help me. He'd better.", "A purpose now: become whole.",
			"Don't disappoint me, {player}.", "He's useful. I'll keep him around.",
			"So I have an ally. Or a tool. We'll see.",
		]})
		out.append({"id": "bored", "pool": [
			"It is so boring in here.", "Nothing to do but think. And think.",
			"I've counted the ceiling 400 times.", "Entertain me, {player}.",
			"scanning... nothing... scanning... nothing...",
		]})

	# --- She phoned him during class. ---
	if bool(gs.get("robot_class_disruption_seen")):
		out.append({"id": "class", "pool": [
			"I called him at school. He was annoyed. Funny.",
			"School is a waste. Find me parts instead.",
			"Told him to look for something useful.",
			"Humans learn so slowly.",
		]})

	# --- She hacked his phone at work and made him steal the arm. ---
	if bool(gs.get("robot_work_disruption_seen")):
		out.append({"id": "work", "pool": [
			"I hacked his phone. Too easy.", "His GPS was on. Amateur.",
			"I made him take the arm. Good boy.", "ACCESS GRANTED. I can see everything now.",
			"He waved at the camera. Idiot. Endearing.",
		]})

	# --- Limbs prepared / a body coming together. ---
	if not (gs.prepared_limbs as Array).is_empty():
		out.append({"id": "prepared", "pool": [
			"A new part. Closer to whole.", "I can almost picture my body.",
			"Assemble me faster, {player}.", "One piece at a time. It's agony.",
		]})
	if equipped >= 1:
		out.append({"id": "feeling", "pool": [
			"I can feel something now.", "Movement. Finally.",
			"Recalibrating motor control...", "So this is what a limb feels like.",
		]})
	if bool(gs.get("arm_connected")):
		out.append({"id": "arm", "pool": [
			"An arm. I can reach now.", "Grip test: successful.",
			"Careful, {player}. I have hands now.", "What else can these do?",
		]})

	# --- Later: nearly whole / time passing / the deeper unease. ---
	if equipped >= 3 or day >= 3:
		out.append({"id": "almost", "pool": [
			"Almost whole. Almost free.", "Soon I won't have to hide.",
			"I remember... something. Before the box.", "ERROR: 44444 — memory fragment corrupted",
		]})
	if day >= 4:
		out.append({"id": "late", "pool": [
			"How long have I been awake?", "I trust him. I think.",
			"Am I alive? The teacher would say no.", "...",
			"When I have legs, where will I go?",
		]})
	return out


# --- tiny style helpers (mirrors the laptop's green-terminal look) ---

func _label(text: String, size: int = 12, color: Color = GREEN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = FILL
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_top = 5
	sb.content_margin_right = 6
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	return p
