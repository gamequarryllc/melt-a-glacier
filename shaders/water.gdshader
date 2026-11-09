shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The lake: milky turquoise glacier meltwater, darker where it's deep, with
// small drifting ripples, glints on their crests and a pale line lapping at
// the shore. Vertex alpha = depth (0 at the shore, 1 in the deep middle).

uniform sampler2D ripples : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.3, 0.68, 0.72);
uniform vec3 deep_color : source_color = vec3(0.07, 0.38, 0.55);
uniform vec3 foam_color : source_color = vec3(0.88, 0.95, 0.96);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = COLOR.a;
	vec2 p = wpos.xz;
	float a = texture(ripples, p * 0.047 + TIME * vec2(0.011, 0.006)).r;
	float b = texture(ripples, p * 0.113 - TIME * vec2(0.008, 0.014)).r;
	float c = texture(ripples, p * 0.29 + TIME * vec2(0.021, -0.016)).r;

	vec3 col = mix(shallow_color, deep_color, smoothstep(0.0, 0.4, depth));
	col *= 0.95 + 0.1 * (a * 0.6 + b * 0.4);
	// Glints: thin bright lines where two sets of ripples cross.
	float glint = (1.0 - smoothstep(0.0, 0.018, abs(b - c))) * smoothstep(0.45, 0.6, a);
	col += glint * 0.1;
	// The shore: paler shallows and a line of foam that comes and goes.
	float shallows = 1.0 - smoothstep(0.0, 0.2, depth);
	col = mix(col, foam_color, shallows * 0.3);
	float lap = 1.0 - smoothstep(0.0, 0.035 + 0.02 * sin(TIME * 0.7 + p.x * 0.3 + b * 6.0), depth + (c - 0.5) * 0.03);
	col = mix(col, foam_color, lap * 0.75);

	// Gentle ripples only: strong ones turn the sky's reflection into blotches.
	vec3 wn = normalize(vec3((b - c) * 0.22, 1.0, (a - c) * 0.22));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = 0.3;
	SPECULAR = 0.3;
}
