shader_type spatial;
// Gusts of air drawn the way a cartoon draws wind (ToolFx, the hair dryer):
// tapered brush strokes rushing along a widening cone from the nozzle to the
// ice, curling round it as they go. Each stroke has a pale middle and a darker
// rim so it shows against snow.
//
// The mesh is the unit tube (see tool_cone.gdshaderinc): UV.x goes round it and
// UV.y runs 0 (nozzle) .. 1 (ice).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

uniform float len = 4.0;
uniform float r0 = 0.05;
uniform float r1 = 1.0;
uniform float lines = 6.0;       // how many strokes round the cone
uniform float speed = 6.0;       // m/s
uniform float gap = 2.2;         // metres from one stroke to the next on a line
uniform float fill = 0.5;        // how much of that is stroke
uniform float width = 0.03;      // half its thickness, metres
uniform float twist = 0.5;       // how much they curl round the cone, per metre
uniform float wiggle = 0.12;
uniform float flare = 0.4;        // how much thicker they get per metre they travel
uniform vec3 color : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 color_rim : source_color = vec3(1.0, 0.6, 0.4);
uniform float strength = 1.0;
uniform float gain = 1.0;        // above 1: brighter than the daylight
uniform float fade_in = 0.06;
uniform float fade_out = 0.8;

varying vec3 at;   // where on the cone, in its own space
float hash(float x) {
	return fract(sin(x * 91.7 + 3.1) * 43758.5);
}

void vertex() {
	VERTEX = vec3(VERTEX.xy * mix(r0, r1, UV.y), -UV.y * len);
	at = VERTEX;
}

void fragment() {
	// Worked out from the position, not the UVs: UVs stretched over a cone's
	// triangles zigzag, and so would the strokes.
	float z = -at.z;
	float t = z / len;
	float rad = mix(r0, r1, t);
	float u = (atan(at.y, at.x) / 6.2832 + 0.5) * lines + z * twist + wiggle * sin(z * 2.1 - TIME * 2.6);
	float id = mod(floor(u), lines);
	float h = hash(id);
	// Where along its stroke this is: 0 at the tail, 1 at the head.
	float s = fract((z - TIME * speed * (0.75 + 0.5 * h)) / gap + h * 5.0) / fill;
	float taper = sin(clamp(s, 0.0, 1.0) * PI);
	taper = taper * (0.45 + 0.55 * s);   // fatter towards the head, like a brush stroke
	float d = abs(fract(u) - 0.5) * (6.2832 * rad / lines);   // metres from the line's middle
	float w = width * (0.6 + 0.8 * hash(id + 17.0)) * taper * (0.6 + flare * z);
	float aa = fwidth(d) + 0.0002;
	float a = (1.0 - smoothstep(w - aa, w + aa, d)) * step(s, 1.0);
	ALBEDO = mix(color_rim, color, 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, d)) * gain;
	a *= smoothstep(0.0, max(fade_in, 0.0001), t) * (1.0 - smoothstep(fade_out, 1.0, t));
	ALPHA = clamp(a * strength, 0.0, 1.0);
}
