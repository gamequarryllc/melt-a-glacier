shader_type spatial;
// Cartoon puffs flying from the nozzle, drawn over the snow: the straight line
// from the nozzle to where you're aiming dips into a bulging slope on the way
// (see tool_cone.gdshader).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/toon_puff.gdshaderinc"
