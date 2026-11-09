shader_type spatial;
// The lava hose's stream (ToolFx): one solid rope of lava that arcs from the
// nozzle to the ice, bulging as it pulses along, with a dark crust breaking up
// on its glowing skin. Flat cartoon colours.
//
// The unit tube (see tool_cone.gdshaderinc) is bent along the arc here, in
// world space: the node sits at the origin. `start`, `v0`, `fall` and `flight`
// describe the throw: p(s) = start + v0 * s - (0, fall, 0) * s * s / 2, for s
// from 0 to `flight` seconds.
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform vec3 start;
uniform vec3 v0 = vec3(0.0, 0.0, -12.0);
uniform float fall = 4.0;
uniform float flight = 0.5;
uniform float r0 = 0.05;
uniform float r1 = 0.14;
uniform float head = 1.0;         // how far along the arc the stream has got (0..1)
uniform float tail = 0.0;         // and where it starts, once you've let go
uniform vec3 col_hot : source_color = vec3(1.0, 0.9, 0.4);
uniform vec3 col_mid : source_color = vec3(1.0, 0.55, 0.08);
uniform vec3 col_cool : source_color = vec3(0.9, 0.25, 0.04);
uniform vec3 col_crust : source_color = vec3(0.5, 0.12, 0.05);
uniform float heat = 0.0;         // hotter: less crust
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

varying float along;   // metres down the stream
varying float t;

void vertex() {
	t = mix(tail, head, UV.y);
	float s = t * flight;
	float speed = length(v0);
	along = s * speed;
	vec3 c = start + v0 * s - vec3(0.0, 0.5 * fall * s * s, 0.0);
	vec3 tang = normalize(v0 - vec3(0.0, fall * s, 0.0));
	vec3 side = normalize(cross(tang, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(side, tang);
	float r = mix(r0, r1, smoothstep(0.0, 0.2, t));
	r *= 1.0 + 0.13 * sin(along * 4.0 - TIME * speed * 4.0) + 0.07 * sin(along * 9.0 - TIME * speed * 9.0 + 1.3);
	r *= 1.0 - smoothstep(0.9, 1.0, UV.y) * 0.7;   // a rounded end
	r *= mix(1.0, smoothstep(0.0, 0.1, UV.y), step(0.001, tail));
	vec3 out_dir = side * VERTEX.x + up * VERTEX.y;
	VERTEX = c + out_dir * r;
	NORMAL = out_dir;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float flow = along - TIME * length(v0);
	float n = texture(noise, vec2(UV.x * 2.0, flow * 0.1)).r;
	float n2 = texture(noise, vec2(UV.x * 3.0 + 0.4, flow * 0.23 + 0.3)).r;
	float f = n * 0.6 + n2 * 0.4 + (facing - 0.5) * 0.35 + heat * 0.06 - t * 0.08;
	float aa = fwidth(f) + 0.0005;
	vec3 c = mix(col_crust, col_cool, smoothstep(0.3, 0.3 + aa, f));
	c = mix(c, col_mid, smoothstep(0.38, 0.38 + aa, f));
	c = mix(c, col_hot, smoothstep(0.56, 0.56 + aa, f));
	ALBEDO = c * 1.25;
}
