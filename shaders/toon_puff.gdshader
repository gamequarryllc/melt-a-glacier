shader_type spatial;
// Cartoon puffs that the ice and the ground can hide: steam, splashes, snow.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/toon_puff.gdshaderinc"
