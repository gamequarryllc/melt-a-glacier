shader_type spatial;
render_mode blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Running water: the river, and (falls = 1) white water down the waterfall.
// A ribbon with UV.x = 0..1 across it and UV.y = metres along it; streaks of
// foam slide downstream and the edges are see-through, so the pebbly bed
// shows. Vertex alpha fades the whole thing (the top of the waterfall);
// vertex red < 1 churns it white (the pool under the falls).

uniform sampler2D ripples : filter_linear_mipmap, repeat_enable;
uniform float falls = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.52, 0.76, 0.76);
uniform vec3 deep_color : source_color = vec3(0.2, 0.5, 0.58);
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 0.98);

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;   // 0 in the middle, 1 at the banks
	float t = TIME * mix(1.0, 2.6, falls);
	float a = texture(ripples, vec2(UV.x * 1.5, UV.y * 0.07 - t * 0.2)).r;
	float b = texture(ripples, vec2(UV.x * 2.6 + 0.37, UV.y * 0.13 - t * 0.31)).r;
	float flow = a * 0.6 + b * 0.4;

	vec3 col = mix(deep_color, shallow_color, smoothstep(0.25, 0.95, across));
	col *= 0.9 + 0.2 * flow;
	// Foam: streaks down the fast middle, and a line lapping along each bank.
	float streak = smoothstep(0.63, 0.68, flow + falls * 0.2) * (1.0 - smoothstep(0.55, 0.9, across) * (1.0 - falls));
	float lap = smoothstep(0.62, 0.7, across + (b - 0.5) * 0.3) * (1.0 - smoothstep(0.86, 0.97, across));
	float churn = 1.0 - COLOR.r;
	float foam = clamp(streak * mix(0.6, 1.0, falls) + lap * 0.55 + smoothstep(0.75 - churn * 0.5, 0.8 - churn * 0.45, flow) * churn, 0.0, 1.0);
	col = mix(col, foam_color, foam);

	ALBEDO = col;
	float body = mix(0.86, 0.35, smoothstep(0.5, 1.0, across));
	ALPHA = COLOR.a * mix(body, 1.0, max(foam * 0.8, falls * 0.55 * (1.0 - smoothstep(0.8, 1.0, across))));
	ROUGHNESS = mix(0.15, 0.7, foam);
	SPECULAR = 0.4;
}
