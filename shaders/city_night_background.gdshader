shader_type canvas_item;
// Procedural night-city background - a cousin of space_background.gdshader.
//
// Same navy sky, cool top-left glow and stars up top, but the bottom of the
// screen is a distant city at night, drawn on a coarse pixel grid so it reads
// like the game's pixel art:
//   1. Vertical gradient sky, warming to a hazy purple toward the horizon
//   2. A pulsing cool glow top-left and the city's haze glowing up from below
//   3. Single-pixel stars, fading out into the haze, a few twinkling
//   4. Two skyline layers: hazy far towers and dark near towers with a rim of
//      light, both with lit windows (gold like the UI trim, or cool cyan) - a
//      few windows switch on and off now and then
//   5. Now and then a hover-car's blinking light drifts across the sky

uniform vec3 base_top    : source_color = vec3(0.027, 0.035, 0.059);
uniform vec3 base_middle : source_color = vec3(0.039, 0.051, 0.082);
uniform vec3 base_bottom : source_color = vec3(0.071, 0.055, 0.110);

uniform vec3 sky_glow_color     : source_color = vec3(0.165, 0.200, 0.345);
uniform vec3 horizon_glow_color : source_color = vec3(0.260, 0.160, 0.380);

uniform vec3 far_tower_color  : source_color = vec3(0.070, 0.070, 0.125);
uniform vec3 near_tower_color : source_color = vec3(0.020, 0.024, 0.043);
uniform vec3 window_warm      : source_color = vec3(0.900, 0.700, 0.330);
uniform vec3 window_cool      : source_color = vec3(0.360, 0.780, 0.880);
uniform vec3 craft_light      : source_color = vec3(1.000, 0.330, 0.330);

// The art grid the city is drawn on (screen-independent: 320x180 at the 1280x720
// design size is 4 screen pixels per art pixel).
uniform vec2 art_resolution = vec2(320.0, 180.0);

uniform float glow_intensity   : hint_range(0.0, 1.0) = 0.45;
uniform float haze_intensity   : hint_range(0.0, 1.0) = 0.40;
uniform float star_density     : hint_range(0.0, 1.0) = 0.45;
uniform float star_brightness  : hint_range(0.0, 2.0) = 0.60;
// Height of the tallest far towers, as a fraction of the screen.
uniform float skyline_height   : hint_range(0.05, 0.8) = 0.30;
uniform float window_density   : hint_range(0.0, 1.0) = 0.22;
uniform float window_brightness : hint_range(0.0, 2.0) = 0.60;
// Seconds between hover-cars (0 = none).
uniform float craft_interval = 45.0;


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


// One skyline layer at art column x / height y (art pixels up from the bottom).
// Returns vec3(inside tower, window light 0..1, warm(0) / cool(1) window).
// Towers average `width` art pixels wide (each pair of them splits a 2 x width
// block at a random point) with a 1-pixel gap, `min_h`..`max_h` tall; some carry
// an antenna. Windows sit on a 3-pixel grid inside the walls.
vec3 skyline(float x, float y, float width, float min_h, float max_h, float seed) {
	float block_w = width * 2.0;
	float block = floor(x / block_w);
	float bx = x - block * block_w;
	float split = floor(mix(0.3, 0.7, hash(vec2(block, seed + 9.0))) * block_w);
	float cell = block * 2.0;
	float local_x = bx;
	float tower_w = split;
	if (bx >= split) {
		cell += 1.0;
		local_x = bx - split;
		tower_w = block_w - split;
	}
	float h = floor(mix(min_h, max_h, pow(hash(vec2(cell, seed)), 1.4)));
	// Now and then a low block between the towers.
	if (hash(vec2(cell, seed + 3.0)) < 0.18) {
		h = floor(min_h * 0.55);
	}
	float wall_w = tower_w - 1.0;
	if (local_x >= wall_w) {
		return vec3(0.0);
	}
	// A stepped crown on some towers, an antenna on others.
	float crown = hash(vec2(cell, seed + 5.0));
	if (crown > 0.7 && (local_x < 1.0 || local_x >= wall_w - 1.0)) {
		h -= 2.0;
	}
	if (crown > 0.88 && local_x == floor(wall_w * 0.5)) {
		h += 5.0;
	}
	if (y >= h) {
		return vec3(0.0);
	}

	float light = 0.0;
	float tone = 0.0;
	float wx = local_x - 1.0;
	float wy = y - 2.0;
	if (wx >= 0.0 && wx < wall_w - 2.0 && wy >= 0.0 && y < h - 3.0
			&& mod(wx, 3.0) < 2.0 && mod(wy, 3.0) < 1.0) {
		vec2 id = vec2(cell * 13.0 + floor(wx / 3.0), floor(wy / 3.0)) + seed;
		float roll = hash(id);
		float lit = step(roll, window_density);
		// A few windows switch on and off every so often.
		if (hash(id + 7.0) < 0.12) {
			float epoch = floor(TIME / 7.0 + hash(id + 11.0) * 7.0);
			lit = step(hash(id + epoch), 0.5);
		}
		light = lit * (0.65 + 0.35 * hash(id + 3.0));
		tone = step(0.72, hash(id + 19.0));
	}
	return vec3(1.0, light, tone);
}


void fragment() {
	vec2 px = floor(UV * art_resolution);
	vec2 uv = (px + 0.5) / art_resolution;
	// Art pixels up from the bottom edge.
	float y_up = art_resolution.y - 1.0 - px.y;

	// --- 1. Sky gradient ---
	vec3 color;
	if (uv.y < 0.5) {
		color = mix(base_top, base_middle, uv.y * 2.0);
	} else {
		color = mix(base_middle, base_bottom, (uv.y - 0.5) * 2.0);
	}

	// --- 2. Glows ---
	float pulse_one = 0.5 + 0.5 * sin(TIME * 0.35);
	float pulse_two = 0.5 + 0.5 * sin(TIME * 0.22 + 1.7);
	float d1 = distance(uv * vec2(1.78, 1.0), vec2(-0.18, 0.15));
	color += sky_glow_color * smoothstep(0.9, 0.0, d1) * glow_intensity * (0.7 + 0.3 * pulse_one);
	float skyline_px = skyline_height * art_resolution.y;
	float haze = smoothstep(skyline_px * 1.9, 0.0, y_up);
	color += horizon_glow_color * haze * haze_intensity * (0.8 + 0.2 * pulse_two);

	// --- 3. Stars: single art pixels, thinning out toward the haze ---
	float star_roll = hash(px + 0.37);
	if (star_roll < star_density * 0.012) {
		float twinkle = 1.0;
		if (hash(px + 9.1) < 0.25) {
			twinkle = 0.55 + 0.45 * sin(TIME * (1.0 + 2.0 * hash(px + 4.2)) + hash(px) * 6.28);
		}
		float fade = smoothstep(skyline_px * 1.1, skyline_px * 2.2, y_up);
		float bright = (0.45 + 0.55 * hash(px + 2.7)) * twinkle * fade * star_brightness;
		color += vec3(0.32, 0.36, 0.55) * bright;
	}

	// --- 5. Hover-car crossing the sky (drawn before the towers so they hide it) ---
	if (craft_interval > 0.0) {
		float pass = floor(TIME / craft_interval);
		float t = fract(TIME / craft_interval) * craft_interval / 34.0;
		if (t < 1.0) {
			bool left_to_right = hash(vec2(pass, 1.0)) < 0.5;
			float span = art_resolution.x + 8.0;
			float cx = floor((left_to_right ? t : 1.0 - t) * span - 4.0);
			float cy = floor(mix(skyline_px * 1.25, art_resolution.y * 0.8, hash(vec2(pass, 2.0))));
			if (y_up == cy && (px.x == cx || px.x == cx + 1.0)) {
				color += vec3(0.30, 0.32, 0.42);
			}
			bool blink = fract(TIME * 0.9) < 0.18;
			if (blink && y_up == cy + 1.0 && px.x == (left_to_right ? cx + 1.0 : cx)) {
				color = mix(color, craft_light, 0.85);
			}
		}
	}

	// --- 4. Skyline: far towers in the haze, near towers in silhouette ---
	vec3 far_t = skyline(px.x + 3.0, y_up, 11.0, skyline_px * 0.35, skyline_px, 1.0);
	if (far_t.x > 0.5) {
		color = mix(far_tower_color, horizon_glow_color, haze * haze_intensity * 0.35);
		vec3 win = mix(window_warm, window_cool, far_t.z);
		color = mix(color, win, far_t.y * window_brightness * 0.45);
	}
	vec3 near_t = skyline(px.x, y_up, 17.0, skyline_px * 0.18, skyline_px * 0.6, 7.0);
	if (near_t.x > 0.5) {
		color = near_tower_color;
		// A rim of haze light along each roofline.
		if (skyline(px.x, y_up + 1.0, 17.0, skyline_px * 0.18, skyline_px * 0.6, 7.0).x < 0.5) {
			color = mix(near_tower_color, horizon_glow_color, 0.45);
		}
		vec3 win = mix(window_warm, window_cool, near_t.z);
		color = mix(color, win, near_t.y * window_brightness);
	}

	COLOR = vec4(color, 1.0);
}
