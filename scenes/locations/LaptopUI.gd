extends RefCounted
class_name LaptopUI
## Shared green-terminal widget helpers for the laptop desktop apps, so each app
## (delivery, profile, drone monitor, stress-test history, save) draws in the same
## style without copy-pasting the same builders. Static-only; never instantiated.

const GREEN: Color = Color(0.6, 1.0, 0.62)
const DIM: Color = Color(0.4, 0.72, 0.45)
const OK: Color = Color(0.45, 1.0, 0.55)
const ERR: Color = Color(1.0, 0.45, 0.42)
const BORDER: Color = Color(0.2, 0.85, 0.4, 0.75)
const FILL: Color = Color(0.0, 0.04, 0.02, 0.55)
const ICON_DIR: String = "res://assets/textures/icons/"
const PLACEHOLDER_ICON: String = "res://assets/textures/icons/placeholder_item.png"


static func label(text: String, size: int = 12, color: Color = GREEN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(border: Color = BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FILL
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_top = 5
	sb.content_margin_right = 6
	sb.content_margin_bottom = 5
	return sb


static func box(border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", panel_style(border))
	return p


static func button(text: String, font_size: int = 12) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", GREEN)
	btn.add_theme_color_override("font_hover_color", OK)
	btn.add_theme_color_override("font_disabled_color", DIM)
	btn.add_theme_stylebox_override("normal", panel_style())
	btn.add_theme_stylebox_override("hover", panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("pressed", panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("disabled", panel_style(Color(0.2, 0.45, 0.28, 0.5)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


## A full-rect margin container added to `parent`, returned for filling. Keeps every app's
## inner padding consistent.
static func screen_margin(parent: Control, pad: int = 6) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	return m


## Resolves an icon: a bare name is looked up in the icons dir, a full res:// path is used
## directly. Falls back to the placeholder.
static func icon_tex(icon: String) -> Texture2D:
	if icon.begins_with("res://"):
		if ResourceLoader.exists(icon):
			return load(icon) as Texture2D
	elif icon != "":
		var path := ICON_DIR + icon + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return load(PLACEHOLDER_ICON) as Texture2D
