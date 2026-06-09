@tool
extends Label

@export var glow_color: Color = Color(0.0, 0.45, 1.0, 1.0):
	set(value):
		glow_color = value
		_apply_glow_material()

@export_range(1.0, 80.0, 1.0) var glow_radius_px: float = 28.0:
	set(value):
		glow_radius_px = value
		_apply_glow_material()

@export_range(0.0, 4.0, 0.05) var glow_strength: float = 1.45:
	set(value):
		glow_strength = value
		_apply_glow_material()

@export_range(8, 160, 1) var glow_padding_px: int = 72:
	set(value):
		glow_padding_px = value
		_queue_glow_refresh()

const _GLOW_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 0.45, 1.0, 1.0);
uniform float radius_px = 28.0;
uniform float strength = 1.45;

void fragment() {
	float alpha = 0.0;
	float total_weight = 0.0;

	for (int x = -6; x <= 6; x++) {
		for (int y = -6; y <= 6; y++) {
			vec2 sample_step = vec2(float(x), float(y));
			float dist = length(sample_step);
			float weight = exp(-(dist * dist) / 18.0);
			vec2 sample_uv = UV + sample_step * TEXTURE_PIXEL_SIZE * radius_px / 6.0;
			alpha += texture(TEXTURE, sample_uv).a * weight;
			total_weight += weight;
		}
	}

	alpha /= total_weight;
	alpha = pow(alpha, 1.25);
	COLOR = vec4(glow_color.rgb, alpha * glow_color.a * strength);
}
"""

var _glow_viewport: SubViewport
var _glow_source: Label
var _glow_rect: TextureRect
var _glow_material: ShaderMaterial
var _last_text: String = ""
var _last_size: Vector2 = Vector2.ZERO
var _last_font_size: int = -1
var _refresh_queued: bool = false


func _ready() -> void:
	_ensure_glow_nodes()
	_queue_glow_refresh()


func _process(_delta: float) -> void:
	var font_size := get_theme_font_size("font_size")
	if text != _last_text or size != _last_size or font_size != _last_font_size:
		_queue_glow_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		_queue_glow_refresh()


func _ensure_glow_nodes() -> void:
	if _glow_rect != null and is_instance_valid(_glow_rect):
		return

	_glow_viewport = SubViewport.new()
	_glow_viewport.name = "_GlowViewport"
	_glow_viewport.transparent_bg = true
	_glow_viewport.disable_3d = true
	_glow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_glow_viewport)

	_glow_source = Label.new()
	_glow_source.name = "_GlowSource"
	_glow_source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_viewport.add_child(_glow_source)

	_glow_rect = TextureRect.new()
	_glow_rect.name = "_GlowTexture"
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_rect.texture = _glow_viewport.get_texture()
	_glow_rect.show_behind_parent = true
	_glow_rect.z_index = -10
	_glow_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_glow_rect)

	var shader := Shader.new()
	shader.code = _GLOW_SHADER_CODE
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = shader
	_glow_rect.material = _glow_material
	_apply_glow_material()


func _queue_glow_refresh() -> void:
	if not is_inside_tree():
		return
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_glow")


func _refresh_glow() -> void:
	_refresh_queued = false
	_ensure_glow_nodes()

	var label_size := size
	if label_size.x <= 0.0 or label_size.y <= 0.0:
		label_size = get_combined_minimum_size()

	var padding := float(glow_padding_px)
	var viewport_size := (label_size + Vector2(padding * 2.0, padding * 2.0)).ceil()
	viewport_size.x = max(viewport_size.x, 1.0)
	viewport_size.y = max(viewport_size.y, 1.0)

	_glow_viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
	_glow_source.position = Vector2(padding, padding)
	_glow_source.size = label_size
	_glow_source.text = text
	_glow_source.horizontal_alignment = horizontal_alignment
	_glow_source.vertical_alignment = vertical_alignment
	_glow_source.autowrap_mode = autowrap_mode
	_glow_source.clip_text = clip_text
	_glow_source.text_overrun_behavior = text_overrun_behavior
	_glow_source.theme_type_variation = theme_type_variation
	_glow_source.add_theme_font_override("font", get_theme_font("font"))
	_glow_source.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	_glow_source.add_theme_color_override("font_color", Color.WHITE)
	_glow_source.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	_glow_source.add_theme_constant_override("outline_size", 0)
	_glow_source.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_glow_source.add_theme_constant_override("shadow_outline_size", 0)
	_glow_source.add_theme_constant_override("shadow_offset_x", 0)
	_glow_source.add_theme_constant_override("shadow_offset_y", 0)

	_glow_rect.position = Vector2(-padding, -padding)
	_glow_rect.size = viewport_size

	_last_text = text
	_last_size = size
	_last_font_size = get_theme_font_size("font_size")


func _apply_glow_material() -> void:
	if _glow_material == null:
		return
	_glow_material.set_shader_parameter("glow_color", glow_color)
	_glow_material.set_shader_parameter("radius_px", glow_radius_px)
	_glow_material.set_shader_parameter("strength", glow_strength)
