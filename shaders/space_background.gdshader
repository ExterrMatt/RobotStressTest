shader_type canvas_item;
// Procedural space background.
//
// Produces three layered effects, composited onto a full-screen rect:
//   1. Vertical gradient base ( #07090f → #0a0d14 → #050609 )
//   2. Two soft pulsing glow blobs (top-left, bottom-right)
//   3. Tiny static "stars" from a hashed grid
//
// The mockup also had drifting parallax stars + soft motion on the glows.
// Per user pick (option B: "static stars + pulsing glow blobs"), the stars
// stay still and only the glows breathe via TIME.

uniform vec3 base_top    : source_color = vec3(0.027, 0.035, 0.059);
uniform vec3 base_middle : source_color = vec3(0.039, 0.051, 0.078);
uniform vec3 base_bottom : source_color = vec3(0.019, 0.023, 0.035);

uniform vec3 glow_color_one : source_color = vec3(0.165, 0.200, 0.345);
uniform vec3 glow_color_two : source_color = vec3(0.227, 0.157, 0.345);

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float star_density   : hint_range(0.0, 1.0) = 0.55;
uniform float star_brightness : hint_range(0.0, 2.0) = 0.65;


// Hash function for pseudo-random per-cell value.
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


// Returns 1.0 inside a star pixel, 0.0 outside. The grid size controls
// how spread-out the stars are; each cell rolls the hash to decide if it
// contains a star and where in the cell the star sits.
float star_field(vec2 uv, float grid_size) {
	vec2 cell = floor(uv * grid_size);
	vec2 local = fract(uv * grid_size);

	float h = hash(cell);
	// Roughly 1 in every (1/star_density) cells becomes a star.
	if (h > star_density * 0.15) {
		return 0.0;
	}

	// Pick a position within the cell using more hash output.
	vec2 star_pos = vec2(hash(cell + 17.0), hash(cell + 31.0));
	float d = distance(local, star_pos);

	// Star is a single bright "pixel" - smoothstep keeps it sharp but
	// not jaggy on subpixel scales.
	return 1.0 - smoothstep(0.0, 0.04, d);
}


void fragment() {
	vec2 uv = UV;

	// --- 1. Vertical gradient base ---
	vec3 color;
	if (uv.y < 0.5) {
		color = mix(base_top, base_middle, uv.y * 2.0);
	} else {
		color = mix(base_middle, base_bottom, (uv.y - 0.5) * 2.0);
	}

	// --- 2. Glow blobs ---
	// Pulse the glow strength using TIME.
	float pulse_one = 0.5 + 0.5 * sin(TIME * 0.35);
	float pulse_two = 0.5 + 0.5 * sin(TIME * 0.28 + 1.7);

	// Top-left glow
	float d1 = distance(uv, vec2(-0.1, 0.15));
	float glow1 = smoothstep(0.6, 0.0, d1) * glow_intensity * (0.7 + 0.3 * pulse_one);
	color += glow_color_one * glow1;

	// Bottom-right glow
	float d2 = distance(uv, vec2(1.1, 0.85));
	float glow2 = smoothstep(0.6, 0.0, d2) * glow_intensity * (0.7 + 0.3 * pulse_two);
	color += glow_color_two * glow2;

	// --- 3. Stars (two layers, different densities) ---
	// Multiply by aspect to keep stars roughly square instead of stretched.
	vec2 star_uv = uv * vec2(1.78, 1.0);  // 16:9 correction
	float stars_far = star_field(star_uv, 60.0) * 0.5;
	float stars_near = star_field(star_uv + 0.5, 40.0);
	float stars = (stars_far + stars_near) * star_brightness;

	// Tint stars with a faint blue, like the mockup
	color += vec3(0.32, 0.36, 0.55) * stars;

	COLOR = vec4(color, 1.0);
}
