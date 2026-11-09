// A cartoon puff (ToolFx): fire, steam, smoke, flurries of snow. Each particle
// is a lumpy blob with hard edges, drawn in three flat colours (edge, middle,
// core) like cel animation, that gets eaten away from the outside as it ages.
// `shade` moves the bright colours up the blob, so steam looks lit from above.
//
// The particle's age and a random number come from CPUParticles3D:
// INSTANCE_CUSTOM.y is its age (0..1) and .z its "animation offset" (set the
// emitter's anim_offset_max to 1 to get a different shape per particle).

uniform vec3 col_core : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 col_mid : source_color = vec3(1.0, 0.7, 0.2);
uniform vec3 col_edge : source_color = vec3(0.95, 0.35, 0.08);
uniform vec3 col_end : source_color = vec3(0.3, 0.25, 0.25);   // what it turns into as it dies
uniform float end_from = 2.0;     // the age it starts turning (above 1: never)
uniform float band_mid = 0.16;    // how far in from the edge the middle colour starts
uniform float band_core = 0.36;   // and the core
uniform float lump = 0.3;         // how lumpy its outline is
uniform float erode = 0.75;       // how much of it is eaten away by the end of its life
uniform float shade = 0.0;
uniform float alpha = 1.0;
uniform float gain = 1.0;          // above 1: brighter than the daylight (the scene's tonemap dulls plain white)
uniform float churn = 0.35;       // how fast the lumps crawl
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

varying float age;
varying float seed;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.z;
	// Face the camera, keeping the particle's size.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV - 0.5;
	float n = texture(noise, UV * 0.45 + vec2(seed * 7.31, seed * 3.17 - age * churn)).r;
	float f = 1.0 - length(p) * 2.0 + (n - 0.5) * 2.0 * lump;
	float cut = 0.1 + erode * age * age;
	float aa = fwidth(f) + 0.0005;
	float h = f - cut + shade * (0.4 - UV.y);
	vec3 c = mix(col_edge, col_mid, smoothstep(band_mid, band_mid + aa, h));
	c = mix(c, col_core, smoothstep(band_core, band_core + aa, h));
	c = mix(c, col_end, clamp((age - end_from) / max(1.0 - end_from, 0.001), 0.0, 1.0));
	ALBEDO = c * COLOR.rgb * gain;
	ALPHA = alpha * COLOR.a * smoothstep(cut, cut + aa, f);
}
