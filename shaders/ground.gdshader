shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The valley floor, the river bed and the lake shore (scripts/ground.gd).

#include "res://shaders/valley_floor.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wet;
	ALBEDO = valley_floor(wpos.xz, wet);
	ROUGHNESS = mix(1.0, 0.55, wet);
	SPECULAR = mix(0.2, 0.4, wet);
}
