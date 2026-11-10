shader_type spatial;
// The pocket sun (ToolFx): a ball drawn like a cartoon sun, in hard bands of
// colour, white-hot in the middle to orange at the rim, with flame shapes
// churning across it.
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float time = 0.0;
uniform float hot = 0.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = texture(noise, UV * vec2(3.0, 1.5) + vec2(time * 0.08, time * 0.05)).r;
	float v = facing + (n - 0.5) * 0.45;
	vec3 rim = vec3(1.0, 0.42, 0.08);
	vec3 mid = vec3(1.0, 0.72, 0.18);
	vec3 core = mix(vec3(1.0, 0.95, 0.62), vec3(1.0), hot * 0.5);
	vec3 col = rim;
	col = mix(col, mid, step(0.35, v));
	col = mix(col, core, step(0.68, v));
	ALBEDO = col * 1.5;
}
