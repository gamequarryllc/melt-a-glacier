// The valley floor's colour at a spot (world x, z): bare moraine that grows
// over with grass as the glacier melts (green: 0..1), pebbles, trodden
// paths, wet river banks and a sandy lake shore. Used by the ground, and by
// the mountains and boulders for their feet, so they all match.
// Ground.grass_at() in scripts/ground.gd mirrors the grass part: keep them in step.
// Colours are used as they are (see mountain.gdshader).

uniform sampler2D floor_map : filter_linear, repeat_disable;   // distances: R river, G lake, B path, A glacier
uniform sampler2D floor_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // R pebbles, G grain and pebble shades, B/A blotches
uniform vec3 floor_map_rect = vec3(-72.0, -50.0, 0.00694);    // the map's corner (x, z) and 1 / its size
uniform float green = 0.0;
uniform vec3 grass_a : source_color = vec3(0.42, 0.6, 0.27);
uniform vec3 grass_b : source_color = vec3(0.34, 0.52, 0.25);
uniform vec3 grass_dry : source_color = vec3(0.6, 0.57, 0.31);
uniform vec3 earth_a : source_color = vec3(0.57, 0.47, 0.34);
uniform vec3 earth_b : source_color = vec3(0.47, 0.42, 0.36);
uniform vec3 silt_color : source_color = vec3(0.56, 0.55, 0.53);      // ground-up rock under the glacier
uniform vec3 sand_color : source_color = vec3(0.76, 0.69, 0.52);
uniform vec3 path_color : source_color = vec3(0.68, 0.57, 0.41);
uniform vec3 stone_color : source_color = vec3(0.74, 0.71, 0.66);

vec3 valley_floor(vec2 xz, out float wet) {
	vec4 m = texture(floor_map, (xz - floor_map_rect.xy) * floor_map_rect.z);
	vec4 fine = texture(floor_tex, xz * 0.47);
	vec4 mid = texture(floor_tex, xz * 0.083 + vec2(0.13, 0.71));
	vec4 big = texture(floor_tex, xz * 0.021 + vec2(0.37, 0.11));
	float ragged = mid.a - 0.5;
	float d_stream = m.r * 8.0 - 2.0;
	float d_lake = m.g * 16.0 - 4.0;
	float d_path = m.b * 6.0;
	float d_ice = m.a * 16.0 - 4.0 + ragged * 1.5;

	float path = 1.0 - smoothstep(0.55, 0.95, d_path + ragged * 0.9);
	float shore = 1.0 - smoothstep(0.8, 2.6, d_lake + ragged * 1.6);
	float bank = 1.0 - smoothstep(0.1, 0.8, d_stream + ragged * 0.6);
	float bed = 1.0 - smoothstep(-0.6, 0.6, d_ice);          // where the glacier lies, or lay
	wet = max(1.0 - smoothstep(-0.1, 0.7, d_stream + ragged * 0.5), 1.0 - smoothstep(-0.2, 0.5, d_lake + ragged));

	// Earth: two tones in big patches, greyer under the glacier, paler on the
	// paths and the shore, with pebbles lying on it (more of them by the water).
	float grain = fine.g;
	vec3 earth = mix(earth_a, earth_b, smoothstep(0.44, 0.56, big.a));
	earth = mix(earth, silt_color, bed * 0.7 * (1.0 - green * 0.6));
	earth = mix(earth, path_color, path * 0.85);
	earth = mix(earth, sand_color, shore);
	earth *= 0.84 + 0.3 * grain;
	float stony = clamp(bank * 1.1 + shore * 0.6 + bed * 0.25 + (big.a - 0.45) * 1.6 + (mid.b - 0.5) * 0.8 - path * 0.4, 0.0, 1.0);
	float edge = mix(0.9, 0.6, stony);
	float pebble = smoothstep(edge, edge + 0.05, 1.0 - fine.r);
	earth = mix(earth, stone_color * (0.5 + 0.7 * grain), pebble * 0.75);
	earth *= mix(1.0, 0.6, wet);

	// Grass: comes up in patches, yellow at first, then two greens.
	float arrive = big.b * 0.62 + mid.b * 0.3;
	float level = 0.27 + 0.6 * green - bed * 0.14 * (1.0 - green);
	float grow = level - arrive - (path + shore + bank);
	float grass_on = smoothstep(-0.012, 0.012, grow + (grain - 0.5) * 0.05);
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.46, 0.54, mid.a + (grain - 0.5) * 0.08));
	grass = mix(grass_dry, grass, smoothstep(0.0, 0.2, grow));
	grass *= 0.86 + 0.28 * grain;
	grass *= 1.0 - 0.14 * smoothstep(0.62, 0.72, 1.0 - fine.r);   // darker clumps
	return mix(earth, grass, grass_on);
}
