shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The mountains: chiselled rock, a grassy apron and pine woods up to the tree
// line, and snow on the gentle high slopes, all worked out per pixel. The
// bottom few metres take the valley floor's colour so the two meet without a
// seam. Vertex colour = the rock's own tint; vertex alpha < 1 marks glowing
// lava (Kevin's streaks). Also used for boulders (no snow, no plants).
// Colours are used as they are: the Compatibility renderer lights them in
// display space, like StandardMaterial3D's albedo.

#include "res://shaders/valley_floor.gdshaderinc"

uniform sampler2D rock_tex : filter_linear_mipmap, repeat_enable;   // R cracks, G slabs, B soft blotches
uniform vec3 snow_color : source_color = vec3(0.79, 0.84, 0.91);
uniform vec3 snow_shade : source_color = vec3(0.5, 0.63, 0.86);       // snow facing away from the sun
uniform vec3 forest_color : source_color = vec3(0.16, 0.29, 0.19);   // the ground under the pines
uniform vec3 slope_grass : source_color = vec3(0.4, 0.52, 0.27);
uniform vec3 slope_dry : source_color = vec3(0.55, 0.5, 0.35);
uniform float snow_line = 17.0;
uniform float tree_line = 12.0;           // 0 = nothing grows on it
uniform float foot_amount = 0.9;          // how much the bottom few metres take the floor's colour
uniform float facets = 0.0;               // 1 = each triangle is a flat face, like cut stone
uniform float settle = 0.0;               // 1 = the foot is lit like the flat floor it runs into
uniform vec3 sun_dir = vec3(0.58, 0.6, 0.55);
uniform vec3 lava_color : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 glacier_source = vec3(0.0, 0.0, -36.0);   // the snowfield the glacier comes from

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 face = cross(dFdx(wpos), dFdy(wpos));
	float area = dot(face, face);
	if (area > 0.0) {
		face *= inversesqrt(area) * sign(dot(face, n) + 0.0001);
		n = normalize(mix(n, face, facets));
	}
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	vec3 p = wpos * vec3(0.07, 0.19, 0.07);   // squashed: the rock lies in slabs
	vec3 d = texture(rock_tex, p.zy).rgb * bw.x
		+ texture(rock_tex, p.xz).rgb * bw.y
		+ texture(rock_tex, p.xy).rgb * bw.z;
	vec3 wide = texture(rock_tex, wpos.xz * 0.011 + wpos.y * 0.007).rgb;

	// Rock: slabs of slightly different shades with dark cracks wandering
	// through them, darker on the cliff faces, in layers.
	vec3 rock = COLOR.rgb;
	float steep = 1.0 - smoothstep(0.35, 0.75, n.y);
	rock *= mix(1.08, 0.84, steep);
	rock *= 0.86 + 0.26 * d.g;
	rock *= 1.0 - 0.26 * d.r;
	rock *= 0.93 + 0.1 * smoothstep(-0.25, 0.25, sin(wpos.y * 1.3 + wide.b * 7.0 + d.b * 1.5));
	rock = mix(rock, rock * vec3(1.1, 0.99, 0.87), wide.g);          // warmer patches

	// Grass on the gentle slopes below the tree line, dark under the pines.
	float plants_to = tree_line + (wide.b - 0.5) * 9.0;
	float plants = (1.0 - smoothstep(plants_to - 1.5, plants_to + 1.5, wpos.y))
		* smoothstep(0.5, 0.66, n.y + (d.b - 0.5) * 0.25) * step(0.5, tree_line);
	vec3 turf = mix(slope_dry, slope_grass, 0.3 + 0.7 * green) * (0.84 + 0.32 * d.b);
	float woods = smoothstep(0.4, 0.5, wide.g + (d.g - 0.5) * 0.25);
	turf = mix(turf, forest_color * (0.8 + 0.4 * d.b), woods * 0.85);
	vec3 col = mix(rock, turf, plants);

	// The valley floor's own colour where the slopes meet the ground (only
	// worked out down there: most of a mountain is nowhere near the floor).
	float foot = (1.0 - smoothstep(0.3, 2.2, wpos.y + (d.b - 0.5) * 2.0)) * foot_amount;
	if (foot > 0.0) {
		float wet;
		col = mix(col, valley_floor(wpos.xz, wet), foot);
	}

	// Snow: on the gentle slopes above a ragged snow line, which drops low
	// around the snowfield that feeds the glacier. Blue where it faces away
	// from the sun, so far-off peaks keep their shape.
	float source = 1.0 - smoothstep(8.0, 30.0, length(wpos.xz - glacier_source.xz));
	float line = snow_line + (wide.b - 0.5) * 10.0 - source * 9.0;
	float high = smoothstep(line - 1.0, line + 1.0, wpos.y);
	float flat_enough = smoothstep(0.46, 0.62, n.y + (d.b - 0.5) * 0.3 + source * 0.16
		+ clamp((wpos.y - line) * 0.012, 0.0, 0.3));
	float snow = high * flat_enough;
	float lit = smoothstep(0.45, 1.0, dot(n, normalize(sun_dir)));
	col = mix(col, mix(snow_shade, snow_color, lit) * (0.94 + 0.08 * d.b), snow);

	float lava = 1.0 - COLOR.a;
	vec3 hot = lava_color * (0.75 + 0.5 * d.b);
	col = mix(col, hot, lava);

	ALBEDO = col;
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), settle * (1.0 - smoothstep(0.0, 1.4, wpos.y))));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(mix(0.93, 0.7, snow), 0.4, lava);
	SPECULAR = mix(0.25, 0.4, snow);
	EMISSION = hot * lava * 1.2;
}
