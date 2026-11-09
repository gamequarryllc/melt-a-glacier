shader_type spatial;
// A cartoon flame at a tool's nozzle (ToolFx): hard-edged tongues of fire in
// three flat colours, licking along a cone. Same unit tube as
// tool_cone.gdshaderinc; drawn over the snow for the same reason.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

uniform float len = 0.5;
uniform float r0 = 0.05;
uniform float r1 = 0.01;
uniform float bulge = 0.04;
uniform vec3 col_core : source_color = vec3(1.0, 1.0, 0.9);
uniform vec3 col_mid : source_color = vec3(1.0, 0.8, 0.3);
uniform vec3 col_edge : source_color = vec3(1.0, 0.45, 0.1);
uniform float strength = 1.0;
uniform float rough = 0.6;        // how ragged the tongues are
uniform float noise_scale = 2.0;
uniform float scroll = 6.0;
uniform float tail = 0.55;        // how much thinner it burns towards its tip
uniform float band_mid = 0.22;
uniform float band_core = 0.5;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

varying float t;

void vertex() {
	t = UV.y;
	float r = mix(r0, r1, t) + bulge * sin(t * PI);
	vec2 around = VERTEX.xy;
	VERTEX = vec3(around * r, -t * len);
	NORMAL = normalize(vec3(around * len, r1 - r0));
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float n = texture(noise, vec2(UV.x * 2.0, (t * len - TIME * scroll) * noise_scale)).r;
	float f = facing + (n - 0.5) * 2.0 * rough * (0.3 + t) - t * tail;
	float aa = fwidth(f) + 0.0005;
	vec3 c = mix(col_edge, col_mid, smoothstep(band_mid, band_mid + aa, f));
	c = mix(c, col_core, smoothstep(band_core, band_core + aa, f));
	ALBEDO = c;
	ALPHA = strength * smoothstep(0.06, 0.06 + aa, f) * (1.0 - smoothstep(0.9, 1.0, t));
}
