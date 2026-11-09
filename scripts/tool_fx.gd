class_name ToolFx
extends Node3D
## What comes out of the tool in your hand, in 3D, from its nozzle to where
## the heat lands, and what the ice does when it's hit. It's drawn like a
## cartoon, to go with the chunky models: flat colours, hard edges, brush
## strokes. Every tool is its own thing:
## - Hair dryer: gusts of hot air as brush strokes curling out along a
##   widening cone. Snow flurries up where it lands.
## - Heat lamp: rays of light streaming from the bulb, dust glinting in them.
## - Blowtorch: a hard blue dart of flame at the nozzle and a tight blue jet
##   with a bright heart. Sparks sizzle off the ice.
## - Flamethrower: a roaring flame at the nozzle and fire that billows out
##   bigger as it flies, with embers. Fire splashes across the ice.
## - Lava hose: one heavy rope of lava that arcs, drips and splashes.
## - Orbital mirror: an aiming laser, and a column of sunlight from space with
##   a crown of fire where it lands.
## Clouds of steam boil up off the ice for all of them (more for the hotter tools).
## Upgrades show: Wider Nozzle makes it wider where it lands, Longer Reach lets
## it go further, Heat Output makes it hotter coloured, brighter and denser.
## The player calls update() every physics frame. It's all CPU particles and a
## few meshes shaped by their shaders, light enough for a phone.
## See the looks with tests/spray_shots.gd.

const CONE_SHADER := preload("res://shaders/tool_cone.gdshader")
const COLUMN_SHADER := preload("res://shaders/light_column.gdshader")
const SPARK_SHADER := preload("res://shaders/spark.gdshader")
const BEAM_SHADER := preload("res://shaders/heat_beam.gdshader")
const PUFF_SHADER := preload("res://shaders/toon_puff.gdshader")
const PUFF_TOP_SHADER := preload("res://shaders/toon_puff_top.gdshader")
const WIND_SHADER := preload("res://shaders/wind_lines.gdshader")
const FLAME_SHADER := preload("res://shaders/toon_flame.gdshader")
const LAVA_SHADER := preload("res://shaders/lava_stream.gdshader")
const LAVA_SPEED := 12.0                     # how fast the lava leaves the hose, m/s
const LAVA_FALL := 4.0                       # and how hard it falls
const SUN_DIR := Vector3(0.32, 1.0, 0.18)    # where the orbital mirror's sunlight comes from
const SKY_LEN := 140.0                       # how far up the sunlight column goes
# The colour the ice glows where each tool's heat lands.
const GLOW := [Color(1.0, 0.62, 0.45), Color(1.0, 0.62, 0.25), Color(0.45, 0.62, 1.0),
	Color(1.0, 0.45, 0.12), Color(1.0, 0.34, 0.05), Color(1.0, 0.86, 0.5)]

# The parts of the current tool's effect (rebuilt when the tool or its upgrades change).
var _streams: Array = []     # {p, speed, spread[, size, fall, life]}: fly from the nozzle to the ice
var _impacts: Array = []     # {p[, area, ring, size, lift]}: where it lands, facing out of the ice
var _cones: Array = []       # {mi, kind: "beam" (nozzle to ice) or "flame" (its own length), ...}
var _columns: Array = []     # {mi, width, strength}: the orbital mirror's sunlight
var _lava: MeshInstance3D    # the lava hose's stream
var _lava_head := 0.0        # how far along its arc the stream has got (0..1)
var _lava_tail := 0.0        # and how far its end has got after you let go
var _drips: CPUParticles3D   # lava dripping off the stream on its way
var _laser: MeshInstance3D   # the orbital mirror's aiming laser
var _tip: MeshInstance3D     # a glow at the nozzle
var _light: OmniLight3D
var _style: Dictionary = {}
var _built := ""             # which tool and upgrade levels the effects were built for
var _t := 0.0
var _on := 0.0               # fades the glows in and out

static var _noise: Texture2D
static var _tubes: Dictionary = {}   # rows -> the unit tube with that many rows along it


func update(active: bool, from: Vector3, to: Vector3, hit: bool, normal: Vector3, delta: float) -> void:
	## active: the melt button is held. from: the nozzle. to: where it lands
	## (the ice, or as far as the tool reaches). hit: it's landing on ice.
	var tool_i: int = GameState.tool_index
	var gold: bool = GameState.golden_equipped and tool_i == 0
	var key := "%d/%s/%d/%d" % [tool_i, gold, int(GameState.upgrade_levels.get("nozzle", 0)), int(GameState.upgrade_levels.get("heat", 0))]
	if key != _built:
		_build(tool_i, gold)
		_built = key
	_t += delta
	_on = move_toward(_on, 1.0 if active else 0.0, delta * (8.0 if active else 5.0))
	var s := _style
	var d := to - from
	var dist := maxf(d.length(), 0.05)
	var dir := d / dist
	var radius: float = GameState.tool_radius()
	var heat: float = s.heat
	var aim_basis := _facing(dir)

	# What flies out of the nozzle, aimed so it lands on the spot.
	for st in _streams:
		var p: CPUParticles3D = st.p
		p.emitting = active
		if not active:
			continue
		var life := clampf(dist / float(st.speed), 0.05, 3.0)
		p.global_transform = Transform3D(aim_basis, from)
		p.lifetime = life * float(st.get("life", 1.0))
		p.spread = clampf(rad_to_deg(atan2(radius * float(st.spread), dist)), 0.3, 60.0)
		if st.has("size"):   # grows to this share of the heat zone by the time it lands
			var sz: float = radius * float(st.size)
			p.scale_amount_min = sz * 0.8
			p.scale_amount_max = sz * 1.2

	# The lava hose: a rope of lava thrown in an arc that lands on the spot. It
	# takes a moment to get there, and what's in the air when you let go flies on.
	if _lava != null:
		var flight := clampf(dist / LAVA_SPEED, 0.05, 3.0)
		if active:
			_lava_head = minf(_lava_head + delta / flight, 1.0)
			_lava_tail = 0.0
		else:
			_lava_tail = minf(_lava_tail + delta / flight, 1.0)
			if _lava_tail >= _lava_head:
				_lava_head = 0.0
				_lava_tail = 0.0
		var g := Vector3(0.0, -LAVA_FALL, 0.0)
		var v0 := (to - from - 0.5 * g * flight * flight) / flight
		_lava.visible = _lava_head > _lava_tail
		if _lava.visible:
			var m := _lava.material_override as ShaderMaterial
			m.set_shader_parameter("start", from)
			m.set_shader_parameter("v0", v0)
			m.set_shader_parameter("flight", flight)
			m.set_shader_parameter("head", _lava_head)
			m.set_shader_parameter("tail", _lava_tail)
		# Lava drips off it along the way.
		_drips.emitting = active and _lava_head > 0.5
		if _drips.emitting:
			var pts := PackedVector3Array()
			for k in 7:
				var tt := (k + 1.5) / 9.0 * flight
				pts.append(from + v0 * tt + 0.5 * g * tt * tt)
			_drips.emission_points = pts

	# Where it lands: steam, sparks, splashes, snow.
	var land := Transform3D(_facing(normal), to + normal * 0.06)
	for im in _impacts:
		var p: CPUParticles3D = im.p
		p.emitting = active and hit and (_lava == null or _lava_head >= 1.0)
		if not p.emitting:
			continue
		p.global_transform = land
		if im.has("lift"):
			p.global_position += normal * float(im.lift)
		if im.has("area"):
			p.emission_sphere_radius = maxf(radius * float(im.area), 0.05)
		if im.has("ring"):
			p.emission_ring_radius = radius * float(im.ring)
			p.emission_ring_inner_radius = radius * float(im.ring) * 0.75
		if im.has("size"):
			var sz: float = radius * float(im.size)
			p.scale_amount_min = sz * 0.7
			p.scale_amount_max = sz * 1.3

	# Flames and beams: soft glowing cones from the nozzle.
	for c in _cones:
		var mi: MeshInstance3D = c.mi
		mi.visible = _on > 0.01
		if not mi.visible:
			continue
		var m := mi.material_override as ShaderMaterial
		mi.global_transform = Transform3D(aim_basis, from)
		var flick := 1.0
		if c.has("flicker"):
			flick += float(c.flicker) * (0.6 * sin(_t * 41.0) + 0.4 * sin(_t * 23.0 + 1.7))
		if c.kind == "beam":
			m.set_shader_parameter("len", dist)
			m.set_shader_parameter("r1", radius * float(c.width))
		else:
			m.set_shader_parameter("len", float(c.len) * flick * (0.5 + 0.5 * _on))
		m.set_shader_parameter("strength", float(c.strength) * _on * (0.92 + 0.08 * flick))

	# The orbital mirror: sunlight from space, and the laser you aim it with.
	for c in _columns:
		var mi: MeshInstance3D = c.mi
		mi.visible = _on > 0.01 and hit
		if not mi.visible:
			continue
		var up := SUN_DIR.normalized()
		mi.global_transform = Transform3D(_facing(-up), to + up * SKY_LEN)
		var m := mi.material_override as ShaderMaterial
		var w: float = radius * float(c.width) * (0.97 + 0.03 * sin(_t * 9.0))
		m.set_shader_parameter("r0", w)
		m.set_shader_parameter("r1", w)
		m.set_shader_parameter("strength", float(c.strength) * _on * (1.0 if c.has("steady") else 0.8 + 0.2 * heat))
	if _laser != null:
		_laser.visible = _on > 0.01
		if _laser.visible:
			var m := _laser.material_override as ShaderMaterial
			m.set_shader_parameter("start", from)
			m.set_shader_parameter("dir", dir)
			m.set_shader_parameter("len", dist)
			m.set_shader_parameter("strength", 0.85 * _on)
			m.set_shader_parameter("fade_out", 0.9 if hit else 0.45)   # into thin air when it falls short

	if _tip != null:
		_tip.visible = _on > 0.01
		_tip.global_position = from
		var tm := _tip.material_override as StandardMaterial3D
		var tc: Color = _tip.get_meta("color")
		tm.albedo_color = Color(tc.r, tc.g, tc.b, tc.a * _on * (0.85 + 0.15 * sin(_t * 23.0)))
	# Light where it lands, flickering for flames.
	var flick_l: float = s.get("flicker", 0.0)
	var e: float = float(s.light) * heat * _on * (1.0 + flick_l * 0.3 * sin(_t * 27.0) * sin(_t * 11.0 + 0.7))
	_light.visible = e > 0.01
	if _light.visible:
		_light.global_position = (to if hit else from.lerp(to, 0.7)) + normal * (0.4 + radius * 0.35)
		_light.light_energy = e
		_light.omni_range = 2.5 + radius * 2.5


static func glow_color(tool_i: int) -> Color:
	return GLOW[clampi(tool_i, 0, GLOW.size() - 1)]


static func _facing(dir: Vector3) -> Basis:
	## A basis with -Z along dir.
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK
	return Basis.looking_at(dir, up)


# =====================================================================================
# The looks, one per tool
# =====================================================================================
func _build(tool_i: int, gold: bool) -> void:
	for n in get_children():
		n.queue_free()
	_streams.clear()
	_impacts.clear()
	_cones.clear()
	_columns.clear()
	_drips = null
	_lava = null
	_laser = null
	_tip = null
	var heat_lv := int(GameState.upgrade_levels.get("heat", 0))
	var heat := 1.0 + heat_lv / 25.0               # 1 .. 2 with Heat Output maxed
	var hot := clampf(heat_lv / 25.0, 0.0, 1.0)    # 0 .. 1: hotter looks brighter and whiter
	var more := 0.85 + 0.35 * hot                  # and denser
	var nozzle: float = GameState.upgrade_mult("nozzle")   # 1 .. 1.7
	var fat := 0.85 + 0.25 * (nozzle - 1.0) / 0.7  # lava blobs get a bit bigger with the nozzle
	_light = OmniLight3D.new()
	_light.top_level = true
	_light.shadow_enabled = false
	_light.omni_attenuation = 1.4
	_light.visible = false
	add_child(_light)
	match tool_i:
		0:
			_build_hair_dryer(gold, heat, hot, more)
		1:
			_build_heat_lamp(heat, hot, more)
		2:
			_build_blowtorch(heat, hot, more)
		3:
			_build_flamethrower(heat, hot, more)
		4:
			_build_lava_hose(heat, hot, more, fat)
		_:
			_build_orbital_mirror(heat, hot, more)


func _build_hair_dryer(gold: bool, heat: float, hot: float, more: float) -> void:
	_style = {"heat": heat, "light": 0.0}
	# Hot air, drawn like a cartoon draws wind: brush strokes rushing out along a
	# widening cone and curling round it. Hotter air blushes from pink to orange.
	var rim := Color(1.0, 0.5, 0.42).lerp(Color(1.0, 0.4, 0.12), hot)
	var mid := Color(1.0, 0.96, 0.93).lerp(Color(1.0, 0.92, 0.7), hot)
	if gold:
		rim = Color(0.95, 0.62, 0.08)
		mid = Color(1.0, 0.96, 0.62)
	# A blush of warm air round them.
	_add_cone("beam", Color(1.0, 0.8, 0.7), rim, {"r0": 0.05, "width": 0.8, "strength": 0.07 + 0.06 * hot,
		"soft_edge": 0.6, "fade_in": 0.05, "fade_out": 0.6, "noise_amount": 0.5, "noise_scale": 0.3, "scroll": 5.0})
	_add_wind(mid, rim, {"r0": 0.06, "width": 0.8, "lines": 7.0 + roundf(4.0 * hot), "speed": 6.0 + 3.0 * hot,
		"twist": 0.5, "gap": 1.7, "fill": 0.6, "line": 0.036, "gain": 1.5})
	_add_wind(mid, rim, {"r0": 0.03, "width": 0.4, "lines": 4.0 + roundf(2.0 * hot), "speed": 7.5 + 3.0 * hot,
		"twist": -0.7, "gap": 1.4, "fill": 0.55, "line": 0.03, "gain": 1.5})
	if gold:   # the golden hair dryer blows glitter
		var glitter := _sparks([Color(1.0, 0.9, 0.4, 1.0), Color(1.0, 0.75, 0.2, 0.9), Color(1.0, 0.7, 0.15, 0.0)], 0.04, 1.6, 26)
		glitter.initial_velocity_min = 5.0
		glitter.initial_velocity_max = 7.0
		_streams.append({"p": glitter, "speed": 6.0, "spread": 0.6})
	# Snow blown up off the ice where it lands.
	var flurry := _toon(int(22 * more), false, {"col_core": Color.WHITE, "col_mid": Color.WHITE,
		"col_edge": Color(0.58, 0.76, 1.0), "lump": 0.45, "erode": 0.9, "band_mid": 0.1, "band_core": 0.2, "gain": 1.3})
	_spray(flurry, 60.0, 1.4, 3.0, -3.5, 0.8)
	flurry.damping_min = 1.0
	flurry.damping_max = 2.0
	flurry.scale_amount_min = 0.1
	flurry.scale_amount_max = 0.24
	flurry.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_impacts.append({"p": flurry, "area": 0.4})
	_tip = _glow_tip(0.1, Color(rim, 0.6))
	_add_steam(int(9 * more), 0.5, 1.4)


func _build_heat_lamp(heat: float, hot: float, more: float) -> void:
	_style = {"heat": heat, "light": 0.9 + 0.4 * hot}
	# A cone of warm light from the lamp to the ice: a soft outer glow, a
	# brighter middle, and rays of light sliding along it.
	var lc := Color(1.0, 0.8, 0.32).lerp(Color(1.0, 0.9, 0.55), hot * 0.6)
	_add_cone("beam", lc, Color(1.0, 0.66, 0.2), {"r0": 0.13, "width": 1.0, "strength": 0.07 + 0.03 * hot,
		"soft_edge": 0.5, "fade_in": 0.02, "fade_out": 0.8, "noise_amount": 0.0})
	var ray := Color(1.0, 0.97, 0.7)
	var ray_rim := Color(1.0, 0.72, 0.15)
	_add_wind(ray, ray_rim, {"r0": 0.13, "width": 0.98, "lines": 9.0 + roundf(5.0 * hot), "speed": 2.6,
		"twist": 0.0, "wiggle": 0.0, "gap": 2.0, "fill": 0.62, "line": 0.03, "gain": 1.7})
	_add_wind(ray, ray_rim, {"r0": 0.07, "width": 0.5, "lines": 5.0 + roundf(3.0 * hot), "speed": 3.2,
		"twist": 0.0, "wiggle": 0.0, "gap": 1.7, "fill": 0.6, "line": 0.026, "gain": 1.7})
	# Dust glinting in the light, drifting along.
	var motes := _sparks([Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.95, 0.65, 1.0), Color(1.0, 0.85, 0.4, 0.15),
		Color(1.0, 0.95, 0.6, 0.95), Color(1.0, 0.85, 0.35, 0.0)], 0.06, 1.0, int(24 * more))
	(motes.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("gain", 2.0)
	motes.initial_velocity_min = 1.0
	motes.initial_velocity_max = 1.6
	_streams.append({"p": motes, "speed": 1.3, "spread": 0.8})
	_tip = _glow_tip(0.24, Color(1.0, 0.85, 0.5, 0.8))
	_add_steam(int(11 * more), 0.55, 1.6)


func _build_blowtorch(heat: float, hot: float, more: float) -> void:
	_style = {"heat": heat, "light": 1.1 + 0.4 * hot, "flicker": 0.6}
	var core := Color(0.82, 0.94, 1.0).lerp(Color.WHITE, hot * 0.6)
	var blue := Color(0.3, 0.62, 1.0)
	var deep := Color(0.16, 0.3, 0.92)
	# The jet roaring out to the ice: a faint blue glow with fire racing down it.
	_add_cone("beam", blue, deep, {"r0": 0.03, "width": 0.3, "strength": 0.2 + 0.1 * hot, "soft_edge": 0.5,
		"fade_in": 0.05, "fade_out": 0.85, "noise_amount": 0.4, "noise_scale": 0.6, "scroll": 10.0})
	var jet := _toon(int(30 * more), true, {"col_core": blue, "col_mid": blue.lerp(deep, 0.45), "col_edge": deep,
		"lump": 0.4, "erode": 0.35, "churn": 0.8})
	jet.initial_velocity_min = 11.0
	jet.initial_velocity_max = 13.0
	jet.scale_amount_curve = _curve(0.2, 1.0)
	_streams.append({"p": jet, "speed": 12.0, "spread": 0.1, "size": 0.3})
	var hotjet := _toon(int(34 * more), true, {"col_core": core, "col_mid": Color(0.5, 0.9, 1.0), "col_edge": Color(0.3, 0.74, 1.0),
		"lump": 0.35, "erode": 0.7, "churn": 0.8, "band_mid": 0.12, "band_core": 0.42, "gain": 1.3}, 1)
	hotjet.initial_velocity_min = 11.5
	hotjet.initial_velocity_max = 12.5
	hotjet.scale_amount_curve = _curve(0.45, 1.0)
	_streams.append({"p": hotjet, "speed": 12.0, "spread": 0.03, "size": 0.15 + 0.04 * hot, "life": 0.8})
	# The flame at the nozzle: a white-hot dart inside a blue one.
	_add_flame(Color(0.5, 0.75, 1.0), blue, deep, {"len": 0.55 + 0.2 * hot, "r0": 0.04, "r1": 0.008, "bulge": 0.035,
		"rough": 0.5, "scroll": 8.0, "flicker": 0.12})
	_add_flame(Color.WHITE, core, Color(0.6, 0.85, 1.0), {"len": 0.26, "r0": 0.026, "r1": 0.004, "bulge": 0.012,
		"rough": 0.3, "scroll": 6.0, "flicker": 0.08, "tail": 0.3})
	# Sparks sizzling off the ice.
	var sparks := _sparks([Color(1, 1, 1, 1), Color(0.7, 0.85, 1.0, 1.0), Color(0.4, 0.6, 1.0, 0.0)], 0.035, 6.0, int(22 * more))
	_spray(sparks, 65.0, 3.0, 6.5, -9.0, 0.55)
	_impacts.append({"p": sparks, "area": 0.2})
	_tip = _glow_tip(0.2, Color(0.55, 0.75, 1.0, 1.0))
	_add_steam(int(13 * more), 0.6, 2.2)


func _build_flamethrower(heat: float, hot: float, more: float) -> void:
	_style = {"heat": heat, "light": 2.0 + 0.6 * hot, "flicker": 1.0}
	var core := Color(1.0, 0.97, 0.72).lerp(Color.WHITE, hot * 0.5)
	var yellow := Color(1.0, 0.82, 0.22)
	var orange := Color(1.0, 0.5, 0.08)
	var red := Color(0.86, 0.2, 0.05)
	# Fire billowing out, growing as it flies and going to smoke at its edges...
	var fire := _toon(int(30 * more), true, {"col_core": orange.lerp(yellow, 0.45), "col_mid": orange, "col_edge": red,
		"col_end": Color(0.24, 0.2, 0.2), "end_from": 0.8, "lump": 0.45, "erode": 0.5, "churn": 0.9})
	fire.initial_velocity_min = 9.5
	fire.initial_velocity_max = 11.0
	fire.scale_amount_curve = _curve(0.08, 1.0)
	fire.gravity = Vector3(0, 2.0, 0)
	_streams.append({"p": fire, "speed": 10.0, "spread": 0.4, "size": 0.72})
	# ...round a hotter heart.
	var heart := _toon(int(22 * more), true, {"col_core": core, "col_mid": yellow.lerp(core, 0.4), "col_edge": yellow,
		"lump": 0.45, "erode": 1.0, "churn": 0.9}, 1)
	heart.initial_velocity_min = 10.0
	heart.initial_velocity_max = 11.0
	heart.scale_amount_curve = _curve(0.12, 1.0)
	heart.gravity = Vector3(0, 2.0, 0)
	_streams.append({"p": heart, "speed": 10.5, "spread": 0.16, "size": 0.44 + 0.08 * hot})
	# A roaring flame at the nozzle.
	_add_flame(core, yellow, orange, {"len": 0.5, "r0": 0.055, "r1": 0.02, "bulge": 0.07, "rough": 0.6,
		"scroll": 7.0, "flicker": 0.15})
	# Embers.
	var embers := _sparks([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(1.0, 0.3, 0.05, 0.0)], 0.03, 4.0, 22)
	embers.initial_velocity_min = 7.0
	embers.initial_velocity_max = 11.0
	embers.gravity = Vector3(0, 3.0, 0)
	_streams.append({"p": embers, "speed": 9.0, "spread": 0.8, "life": 1.3})
	# Fire splashing across the ice.
	var splash := _toon(int(14 * more), false, {"col_core": yellow, "col_mid": orange, "col_edge": red,
		"col_end": Color(0.24, 0.2, 0.2), "end_from": 0.7, "lump": 0.45, "erode": 1.0, "churn": 0.9})
	_spray(splash, 80.0, 2.0, 4.5, 1.0, 0.55)
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_impacts.append({"p": splash, "area": 0.3, "size": 0.4})
	_tip = _glow_tip(0.3, Color(1.0, 0.6, 0.2, 0.9))
	_add_steam(int(15 * more), 0.7, 2.6)


func _build_lava_hose(heat: float, hot: float, more: float, fat: float) -> void:
	_style = {"heat": heat, "light": 2.4 + 0.6 * hot, "flicker": 0.4}
	var bright := Color(1.0, 0.62, 0.1).lerp(Color(1.0, 0.85, 0.35), hot * 0.6)
	# One heavy rope of lava, arcing from the hose to the ice.
	_lava = MeshInstance3D.new()
	_lava.mesh = _tube_mesh(40)
	var lm := ShaderMaterial.new()
	lm.shader = LAVA_SHADER
	lm.set_shader_parameter("noise", noise_texture())
	lm.set_shader_parameter("r0", 0.05)
	lm.set_shader_parameter("r1", 0.15 * fat)
	lm.set_shader_parameter("heat", hot)
	lm.set_shader_parameter("col_hot", Color(1.0, 0.86, 0.3).lerp(Color(1.0, 0.96, 0.62), hot))
	lm.set_shader_parameter("fall", LAVA_FALL)
	_lava.material_override = lm
	_lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lava.top_level = true
	_lava.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))   # placed by the shader
	_lava.visible = false
	add_child(_lava)
	_lava.global_transform = Transform3D.IDENTITY
	# Drips falling off it on the way.
	_drips = _blobs([bright, Color(0.95, 0.35, 0.05), Color(0.6, 0.12, 0.04)], 0.08 * fat, 12, 1.0, false)
	_drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_drips.emission_points = PackedVector3Array([Vector3.ZERO])
	_drips.direction = Vector3(0, -1, 0)
	_drips.spread = 20.0
	_drips.initial_velocity_min = 0.0
	_drips.initial_velocity_max = 0.5
	_drips.gravity = Vector3(0, -12.0, 0)
	_drips.lifetime = 0.7
	_drips.scale_amount_curve = _curve(1.0, 0.3)
	_drips.global_transform = Transform3D.IDENTITY   # the drip points are in the world
	# Splashing where it lands: gobs of lava thrown up, and a flare of fire.
	var splash := _blobs([bright, Color(0.95, 0.3, 0.05), Color(0.45, 0.09, 0.03)], 0.12 * fat, int(24 * more), 1.0, false)
	_spray(splash, 65.0, 2.5, 5.5, -14.0, 0.75)
	splash.scale_amount_curve = _curve(1.0, 0.25)
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_impacts.append({"p": splash, "area": 0.3})
	var flare := _toon(int(10 * more), false, {"col_core": Color(1.0, 0.9, 0.4), "col_mid": bright,
		"col_edge": Color(0.9, 0.25, 0.04), "lump": 0.45, "erode": 1.0, "churn": 0.8})
	_spray(flare, 60.0, 1.0, 2.5, 1.5, 0.5)
	flare.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_impacts.append({"p": flare, "area": 0.25, "size": 0.3})
	_tip = _glow_tip(0.24, Color(1.0, 0.5, 0.15, 0.8))
	_add_steam(int(16 * more), 0.75, 3.2)


func _build_orbital_mirror(heat: float, hot: float, more: float) -> void:
	_style = {"heat": heat, "light": 3.2 + 0.8 * hot}
	# A thin aiming laser from the remote.
	_laser = MeshInstance3D.new()
	_laser.mesh = _strip_mesh()
	var lm := ShaderMaterial.new()
	lm.shader = BEAM_SHADER
	lm.set_shader_parameter("color_near", Vector3(1.0, 0.8, 0.3))
	lm.set_shader_parameter("color_far", Vector3(1.0, 0.7, 0.25))
	lm.set_shader_parameter("r0", 0.008)
	lm.set_shader_parameter("r1", 0.012)
	lm.set_shader_parameter("core", 0.6)
	_laser.material_override = lm
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.top_level = true
	_laser.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))   # placed by the shader
	_laser.visible = false
	add_child(_laser)
	# A column of sunlight from space, with a white-hot middle.
	var sun := Color(1.0, 0.95, 0.75).lerp(Color.WHITE, hot * 0.5)
	_add_column(sun, Color(1.0, 0.88, 0.55), 0.62, 0.36 + 0.1 * hot, 0.7)
	_add_column(Color.WHITE, Color(1.0, 0.97, 0.85), 0.22, 0.5, 0.3)
	# Rays of it streaming down.
	var rays := _fx_mesh(WIND_SHADER)
	var rm := rays.material_override as ShaderMaterial
	for k in [["color", Color.WHITE], ["color_rim", Color(1.0, 0.86, 0.4)], ["len", SKY_LEN + 1.0], ["lines", 7.0 + roundf(4.0 * hot)],
			["speed", 70.0], ["gap", 16.0], ["fill", 0.6], ["width", 0.07], ["twist", 0.0], ["wiggle", 0.0], ["flare", 0.0],
			["fade_in", 0.45], ["fade_out", 0.995], ["gain", 1.6]]:
		rm.set_shader_parameter(k[0], k[1])
	_columns.append({"mi": rays, "width": 0.6, "strength": 1.0, "steady": true})
	# A crown of white fire where it lands.
	var crown := _toon(int(22 * more), false, {"col_core": Color(1.0, 0.97, 0.7), "col_mid": Color(1.0, 0.82, 0.25),
		"col_edge": Color(1.0, 0.56, 0.1), "lump": 0.45, "erode": 1.0, "churn": 0.9})
	crown.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	crown.emission_ring_axis = Vector3(0, 0, 1)
	crown.emission_ring_height = 0.1
	_spray(crown, 20.0, 1.5, 3.5, 2.0, 0.55)
	_impacts.append({"p": crown, "ring": 0.7, "size": 0.2})
	# Sparkles rising in a ring round the spot.
	var sparkle := _sparks([Color(1.0, 0.97, 0.7, 1.0), Color(1.0, 0.85, 0.4, 0.8), Color(1.0, 0.8, 0.3, 0.0)], 0.06, 2.5, int(40 * more))
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparkle.emission_ring_axis = Vector3(0, 0, 1)
	sparkle.emission_ring_height = 0.1
	_spray(sparkle, 15.0, 1.0, 3.0, 3.0, 1.0)
	_impacts.append({"p": sparkle, "ring": 0.8})
	_add_steam(int(18 * more), 0.8, 3.6)


# =====================================================================================
# Building blocks
# =====================================================================================
func _add_steam(amount: int, size: float, rise: float) -> void:
	## Cartoon clouds of steam boiling up off the ice where the heat lands: white
	## on top, blue-grey underneath, thinning out as they rise.
	var p := _toon(amount, false, {"col_core": Color.WHITE, "col_mid": Color(0.9, 0.94, 1.0),
		"col_edge": Color(0.6, 0.72, 0.9), "lump": 0.4, "erode": 1.0, "shade": 0.55, "band_mid": 0.12,
		"band_core": 0.34, "churn": 0.25, "alpha": 0.94, "gain": 1.3})
	_spray(p, 30.0, rise * 0.6, rise * 1.2, 2.0, 1.7)
	p.damping_min = 0.5
	p.damping_max = 1.0
	p.scale_amount_curve = _curve(0.4, 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_impacts.append({"p": p, "area": 0.3, "size": size * 1.1, "lift": 0.2})


func _spray(p: CPUParticles3D, spread: float, v_min: float, v_max: float, up: float, life: float) -> void:
	## Out of the ice: `spread` degrees round the way it faces, `up` = gravity (+ rises).
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector3(0, up, 0)
	p.lifetime = life


func _add_cone(kind: String, near: Color, far: Color, params: Dictionary) -> void:
	## A soft glow: a "beam" from the nozzle to the ice, as wide as `width` times the heat
	## zone where it lands (or a "flame": its own length at the nozzle).
	var mi := _cone_mesh(CONE_SHADER, near, far)
	_cones.append(_cone_entry(mi, kind, params, 0.6))


func _add_wind(mid: Color, rim: Color, params: Dictionary) -> void:
	## Brush strokes rushing from the nozzle to the ice (wind_lines.gdshader). `line` is
	## how thick they are; the rest are the shader's own settings.
	var mi := _fx_mesh(WIND_SHADER)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", mid)
	m.set_shader_parameter("color_rim", rim)
	m.set_shader_parameter("width", params.get("line", 0.03))
	_cones.append(_cone_entry(mi, "beam", params, 1.0))


func _add_flame(core: Color, mid: Color, edge: Color, params: Dictionary) -> void:
	## A cartoon flame at the nozzle (toon_flame.gdshader), `len` long.
	var mi := _fx_mesh(FLAME_SHADER)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("noise", noise_texture())
	m.set_shader_parameter("col_core", core)
	m.set_shader_parameter("col_mid", mid)
	m.set_shader_parameter("col_edge", edge)
	_cones.append(_cone_entry(mi, "flame", params, 1.0))


func _cone_entry(mi: MeshInstance3D, kind: String, params: Dictionary, strength: float) -> Dictionary:
	## Hands `params` to the shader, except the ones update() works out each frame.
	var m := mi.material_override as ShaderMaterial
	var entry := {"mi": mi, "kind": kind, "strength": params.get("strength", strength)}
	for k in params:
		match k:
			"width", "len", "flicker":
				entry[k] = params[k]
			"strength", "line":
				pass
			_:
				m.set_shader_parameter(k, params[k])
	if kind == "flame":
		m.set_shader_parameter("len", params.get("len", 0.5))
	return entry


func _add_column(near: Color, far: Color, width: float, strength: float, stripes: float) -> void:
	## A column of sunlight from the sky down to the spot (orbital mirror).
	var mi := _cone_mesh(COLUMN_SHADER, near, far)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("len", SKY_LEN + 1.0)
	m.set_shader_parameter("soft_edge", 0.55)
	m.set_shader_parameter("fade_in", 0.45)
	m.set_shader_parameter("fade_out", 0.995)
	m.set_shader_parameter("noise_amount", 0.35)
	m.set_shader_parameter("noise_scale", 0.06)
	m.set_shader_parameter("scroll", 25.0)
	m.set_shader_parameter("stripes", stripes)
	_columns.append({"mi": mi, "width": width, "strength": strength})


func _cone_mesh(shader: Shader, near: Color, far: Color) -> MeshInstance3D:
	var mi := _fx_mesh(shader)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("noise", noise_texture())
	m.set_shader_parameter("color_start", Vector3(near.r, near.g, near.b))
	m.set_shader_parameter("color_end", Vector3(far.r, far.g, far.b))
	return mi


func _fx_mesh(shader: Shader) -> MeshInstance3D:
	## The unit tube with `shader` on it, which gives it its shape.
	var mi := MeshInstance3D.new()
	mi.mesh = _tube_mesh()
	var m := ShaderMaterial.new()
	m.shader = shader
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))   # shaped by the shader
	mi.visible = false
	add_child(mi)
	return mi


func _particles(amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.emitting = false
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = Vector3(0, 0, -1)
	p.gravity = Vector3.ZERO
	p.top_level = true
	add_child(p)
	return p


func _toon(amount: int, on_top: bool, params: Dictionary, priority: int = 0) -> CPUParticles3D:
	## Cartoon puffs (toon_puff.gdshaderinc): fire, steam, snow. `params` are the shader's
	## colours and settings. on_top: drawn over the snow (what flies from the nozzle; see
	## tool_cone.gdshader). priority: higher is drawn over lower (a fire's hot heart).
	var p := _particles(amount)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := ShaderMaterial.new()
	m.shader = PUFF_TOP_SHADER if on_top else PUFF_SHADER
	m.render_priority = priority
	m.set_shader_parameter("noise", noise_texture())
	for k in params:
		m.set_shader_parameter(k, params[k])
	quad.material = m
	p.mesh = quad
	p.anim_offset_min = 0.0   # a random number for the shader: a different shape each
	p.anim_offset_max = 1.0
	return p


func _sparks(colors: Array, width: float, stretch: float, amount: int) -> CPUParticles3D:
	## Bright streaks stretched out along the way they fly: sparks, embers, wind.
	var p := _particles(amount)
	p.particle_flag_align_y = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := ShaderMaterial.new()
	m.shader = SPARK_SHADER
	m.set_shader_parameter("tex", UiTheme.soft_dot())
	m.set_shader_parameter("stretch", stretch)
	quad.material = m
	p.mesh = quad
	p.color_ramp = _ramp(colors)
	p.scale_amount_min = width * 0.7
	p.scale_amount_max = width * 1.3
	return p


func _blobs(colors: Array, size: float, amount: int, stretch: float = 1.0, on_top: bool = true) -> CPUParticles3D:
	## Lumps of lava, drawn out along the way they fly.
	var p := _particles(amount)
	var sm := SphereMesh.new()
	sm.radius = size * 0.5
	sm.height = size * stretch
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = on_top
	sm.material = m
	p.mesh = sm
	p.color_ramp = _ramp(colors)
	p.particle_flag_align_y = stretch > 1.0
	return p


func _glow_tip(size: float, color: Color) -> MeshInstance3D:
	## A soft glow at the nozzle.
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = UiTheme.soft_dot()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	mi.set_meta("color", color)
	add_child(mi)
	return mi


static func _ramp(colors: Array, offsets: Array = []) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(offsets[i]) if i < offsets.size() else float(i) / float(maxi(colors.size() - 1, 1)))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	return g


static func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	return c


static func noise_texture() -> Texture2D:
	## Seamless cloudy noise for the flames and beams to scroll along.
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.seed = 3
		fn.frequency = 0.03
		fn.fractal_octaves = 3
		var img := fn.get_seamless_image(128, 128)
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise


static func _tube_mesh(rows: int = 12) -> ArrayMesh:
	## A unit tube: x, y round it (radius 1), UV.x round it, UV.y = 0..1 along it.
	## The shader on it gives it its length and widths.
	if not _tubes.has(rows):
		var seg := 16
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		for j in rows + 1:
			for i in seg + 1:
				var a := TAU * i / seg
				var v := Vector3(cos(a), sin(a), 0.0)
				verts.append(v)
				norms.append(v)
				uvs.append(Vector2(float(i) / seg, float(j) / rows))
		var idx := PackedInt32Array()
		for j in rows:
			for i in seg:
				var a := j * (seg + 1) + i
				var b := a + seg + 1
				idx.append_array([a, b, a + 1, a + 1, b, b + 1])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_tubes[rows] = mesh
	return _tubes[rows]


static var _strip: ArrayMesh


static func _strip_mesh() -> ArrayMesh:
	## For the laser (heat_beam.gdshader): UV.x across, UV.y = 0..1 along.
	if _strip == null:
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var steps := 24
		for k in steps + 1:
			var y := float(k) / steps
			verts.append(Vector3(-0.5, y, 0.0))
			verts.append(Vector3(0.5, y, 0.0))
			uvs.append(Vector2(0.0, y))
			uvs.append(Vector2(1.0, y))
		var idx := PackedInt32Array()
		for k in steps:
			var a := k * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		_strip = ArrayMesh.new()
		_strip.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _strip
