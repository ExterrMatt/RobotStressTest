shader_type canvas_item;
// CRT scanline overlay.
// Matches mockup CSS:
//   repeating-linear-gradient(0deg,
//     rgba(0,0,0,0.18) 0px, rgba(0,0,0,0.18) 1px,
//     transparent 1px, transparent 3px)
// with opacity 0.35.
//
// Drawn over a full-screen rect on a top CanvasLayer.

uniform float line_alpha : hint_range(0.0, 1.0) = 0.18;
uniform float scanline_period_px : hint_range(1.0, 16.0) = 3.0;
uniform float global_opacity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	// FRAGCOORD.y is in pixels; modulo gives a repeating line pattern.
	float y_in_period = mod(FRAGCOORD.y, scanline_period_px);
	float on_line = step(y_in_period, 1.0);  // 1.0 on the first pixel of each period
	COLOR = vec4(0.0, 0.0, 0.0, line_alpha * on_line * global_opacity);
}
