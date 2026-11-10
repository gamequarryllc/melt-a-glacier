shader_type sky;
// A blue sky that pales toward the horizon, a soft sun, and fluffy clouds on a
// flat layer high above. No TIME, so Godot only has to light the scene from
// it once.

uniform vec3 top_color : source_color = vec3(0.26, 0.5, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.85, 0.96);
uniform vec3 ground_color : source_color = vec3(0.35, 0.4, 0.45);
uniform vec3 bounce_color : source_color = vec3(0.6, 0.53, 0.44);
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.7, 0.76, 0.86);
uniform float cover = 0.42;
// The northern lights (Frozen Harbor): ribbons of green with pink hems.
uniform float aurora = 0.0;
uniform vec3 aurora_color : source_color = vec3(0.35, 1.0, 0.6);
uniform vec3 aurora_hem : source_color = vec3(1.0, 0.45, 0.78);
uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;
uniform sampler2D puffs : filter_linear_mipmap, repeat_enable;

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, 0.55, h));
	if (AT_CUBEMAP_PASS) {
		// The light-probe pass lights the scene: a paler sky (as if partly
		// cloudy) and warm light bounced up from the valley floor, so shade
		// isn't deep blue-black.
		col = mix(col, vec3(0.6, 0.66, 0.78), 0.35);
		col = mix(col, bounce_color, smoothstep(0.02, -0.2, h));
	} else {
		col = mix(col, ground_color, smoothstep(0.0, -0.25, h));
	}

	float sun = 0.0;
	if (LIGHT0_ENABLED) {
		sun = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (pow(sun, 12.0) * 0.16 + pow(sun, 120.0) * 0.35);
	}

	// Clouds only where you can see them: in the light-probe pass (AT_CUBEMAP_PASS)
	// they'd brighten the whole scene's ambient light.
	if (h > 0.0 && !AT_CUBEMAP_PASS) {
		vec2 uv = d.xz / (h + 0.09);
		float big = texture(clouds, uv * 0.11 + vec2(0.31, 0.17)).r;
		float small = texture(puffs, uv * 0.34).r;
		float shape = big * 0.75 + (1.0 - small) * 0.35;
		float c = smoothstep(1.0 - cover, 1.0 - cover + 0.22, shape);
		c *= smoothstep(0.015, 0.16, h);          // melt into the haze near the horizon
		float lit = smoothstep(0.2, 0.9, shape - small * 0.25);
		vec3 cloud = mix(cloud_light, cloud_shade, lit * 0.8);
		cloud += LIGHT0_COLOR * pow(sun, 8.0) * 0.25 * (1.0 - lit);   // silver lining near the sun
		col = mix(col, cloud, c * 0.92);
	}
	// The northern lights: a few curtains hanging across the sky, each a wavy
	// ribbon with bright vertical rays, a green body and a pink hem along the
	// bottom, drawn with hard-ish edges like the rest of the game.
	if (aurora > 0.0 && h > 0.04 && !AT_CUBEMAP_PASS) {
		float az = atan(d.x, -d.z);
		float glow = 0.0;
		float hem = 0.0;
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float wave = texture(clouds, vec2(az * 0.18 + fk * 0.37, 0.21 + fk * 0.13)).r;
			float base = 0.16 + fk * 0.1 + (wave - 0.5) * 0.22;
			float tall = 0.12 + 0.08 * fk;
			float up = (h - base) / tall;
			float band = smoothstep(0.0, 0.08, up) * smoothstep(1.0, 0.25, up);
			float rays = texture(clouds, vec2(az * (0.9 + fk * 0.3), 0.6 + fk * 0.3)).r;
			band *= 0.55 + 0.45 * smoothstep(0.4, 0.6, rays);
			band *= smoothstep(-0.9, 0.2, sin(az * (1.3 + fk * 0.4) + fk * 2.0));   // gaps between curtains
			glow = max(glow, band * (1.0 - fk * 0.2));
			hem = max(hem, smoothstep(0.0, 0.06, up) * smoothstep(0.24, 0.1, up) * band);
		}
		glow = smoothstep(0.08, 0.5, glow);
		vec3 a = mix(aurora_color, aurora_hem, smoothstep(0.3, 0.9, hem));
		col = mix(col, a, glow * aurora * 0.55 * smoothstep(0.04, 0.2, h));
	}
	// The sun's disc, drawn over thin cloud.
	if (LIGHT0_ENABLED && !AT_CUBEMAP_PASS) {
		col += LIGHT0_COLOR * LIGHT0_ENERGY * smoothstep(0.9994, 0.99975, sun) * 4.0;
	}
	COLOR = col;
}
