shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_lambert, specular_disabled;
// Tufts of grass (Ground.tufts): lit like the ground they stand on, with the
// tips swaying in the wind. Vertex colour = the blade's colour, UV.y = 0 at
// the root and 1 at the tip.

void vertex() {
	float gust = sin(TIME * 1.6 + VERTEX.x * 0.7 + VERTEX.z * 1.1) * 0.07 + sin(TIME * 3.3 + VERTEX.x * 2.3) * 0.02;
	VERTEX.x += gust * UV.y;
	VERTEX.z += gust * 0.6 * UV.y;
	// Far-off tufts shrink into the ground (they'd only shimmer, and cost time).
	VERTEX.y *= 1.0 - smoothstep(30.0, 48.0, distance(VERTEX, CAMERA_POSITION_WORLD));
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;   // both sides lit from above
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
