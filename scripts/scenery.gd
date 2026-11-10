class_name Scenery
extends RefCounted
## The valley around the glacier: mountains (one heightfield, rock and snow
## shaded per pixel), a sky with clouds, the lake and the meltwater stream.
## Everything is generated from the level description, so a new level with a
## different valley gets its own mountains.

const EXTENT := 230.0        # the mountains reach this far from the middle
const SAMPLES := 150         # grid cells across; spacing grows with distance
const WARP := 1.6            # how strongly the grid bunches up near the valley
const CENTER_Z := -5.0       # the grid's middle (the valley isn't centred on z = 0)
const HOLLOW_RADIUS := 14.0  # Kevin's flat spot (he's 20 m across)
const GAP_RADIUS := 7.0      # half-width of the gap you see Kevin through
const APRON_HEIGHT := 3.4    # the scree at the foot of the cliffs
const NEAR_TREES := 6.0      # slope pines this close to the valley floor are the detailed ones


# =====================================================================================
# Mountains
# =====================================================================================
static func floor_distance(v: Dictionary, x: float, z: float, hollow: Vector2, gap_to: Vector2) -> float:
	## Metres outside the flat valley floor (negative inside it).
	if v.get("coast", false):
		return Coast.flat_distance(v, x, z)   # a shore and the sea instead (no hollow: Kevin has an island)
	var hw: float = v.half_width + maxf(0.0, z - v.flare_z) * v.flare
	var d := maxf(absf(x) - hw, maxf(v.back_z - z, z - v.front_z))
	var lk: Array = v.lake
	var ex: float = (x - lk[0]) / lk[2]
	var ez: float = (z - lk[1]) / lk[3]
	d = minf(d, (sqrt(ex * ex + ez * ez) - 1.0) * minf(lk[2], lk[3]))
	if hollow.is_finite():
		var p := Vector2(x, z)
		d = minf(d, p.distance_to(hollow) - HOLLOW_RADIUS)
		d = minf(d, _segment_distance(p, hollow, gap_to) - GAP_RADIUS)
	return d


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _axis(i: int) -> float:
	## Grid line i (0..SAMPLES) -> metres from the middle, closer together near it.
	var u := float(i) / SAMPLES * 2.0 - 1.0
	return signf(u) * EXTENT * pow(absf(u), WARP)


static var _hf := {}   # the mountains' heights as built: {xs, zs, h, n, v, hollow, gap_to, cx, cz}


static func mountains(level: Dictionary, hollow: Vector2) -> MeshInstance3D:
	## The ring of mountains around the valley as one mesh. `hollow` is a flat
	## spot outside the valley (Kevin the volcano lives there), with a gap
	## toward the glacier so you can see him.
	var v: Dictionary = level.valley
	var seed_base := int(level.seed)
	var ridged := FastNoiseLite.new()
	ridged.seed = seed_base + 41
	ridged.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridged.frequency = 0.012
	ridged.fractal_octaves = 4
	var soft := FastNoiseLite.new()
	soft.seed = seed_base + 42
	soft.frequency = 0.007
	soft.fractal_octaves = 2
	var tint := FastNoiseLite.new()
	tint.seed = seed_base + 43
	tint.frequency = 0.02
	var gap_to := Vector2(-17.0, -24.0) if hollow.x < 0.0 else Vector2(17.0, -24.0)
	var scale: float = v.get("peaks", 1.0)
	# The waterfall runs down a gully in the back wall.
	var falls_a: Vector2 = v.get("falls_top", Vector2.INF)
	var falls_b: Vector2 = v.stream[1] if v.has("stream") else Vector2.INF

	# The grid is finest round its middle: the valley's, or the level's own.
	var mid: Vector2 = v.get("center", Vector2(0.0, CENTER_Z))
	# By the sea the land has to end somewhere: the mountains sink away
	# toward the edge of the grid instead of stopping in a wall.
	var sinks: bool = v.get("coast", false)
	var n := SAMPLES + 1
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	xs.resize(n)
	zs.resize(n)
	for i in n:
		xs[i] = mid.x + _axis(i)
		zs[i] = mid.y + _axis(i)
	var h := PackedFloat32Array()
	var outside := PackedByteArray()
	h.resize(n * n)
	outside.resize(n * n)
	for k in n:
		var z := zs[k]
		for i in n:
			var x := xs[i]
			var d := floor_distance(v, x, z, hollow, gap_to)
			var y := -1.5
			if d > 0.0:
				outside[k * n + i] = 1
				var r := ridged.get_noise_2d(x, z) * 0.5 + 0.5
				var s := soft.get_noise_2d(x, z) * 0.5 + 0.5
				var top := 10.0 + 30.0 * r * r + 12.0 * s
				top *= 1.0 + clampf((d - 25.0) / 90.0, 0.0, 1.0) * 0.9   # bigger further out
				# A grassy apron of scree at the foot, then the cliffs behind it.
				var apron := APRON_HEIGHT * (1.0 - exp(-d / 4.5))
				var apron_width := 3.5 + 6.0 * (soft.get_noise_2d(x * 3.0 + 200.0, z * 3.0) * 0.5 + 0.5)
				var rise := 1.0 - exp(-maxf(d - apron_width, 0.0) / 10.0)
				y = apron + rise * (top * scale - APRON_HEIGHT) - 0.6
				if falls_a.is_finite():
					var off := _segment_distance(Vector2(x, z), falls_a, falls_b)
					y -= 1.6 * exp(-off * off / 6.0) * minf(1.0, d / 4.0)
				if sinks:
					var out := maxf(absf(x - mid.x), absf(z - mid.y))
					y = lerpf(y, 0.2, smoothstep(EXTENT * 0.62, EXTENT - 6.0, out))
			h[k * n + i] = y
	_hf = {"xs": xs, "zs": zs, "h": h, "n": n, "v": v, "hollow": hollow, "gap_to": gap_to, "cx": mid.x, "cz": mid.y}

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	var rock_a: Color = Levels.look("rock_a", Color(0.6, 0.55, 0.49))
	var rock_b: Color = Levels.look("rock_b", Color(0.47, 0.49, 0.54))
	for k in n:
		for i in n:
			var idx := k * n + i
			var p := Vector3(xs[i], h[idx], zs[k])
			verts[idx] = p
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, n - 1)
			var k0 := maxi(k - 1, 0)
			var k1 := mini(k + 1, n - 1)
			var dx := Vector3(xs[i1] - xs[i0], h[k * n + i1] - h[k * n + i0], 0.0)
			var dz := Vector3(0.0, h[k1 * n + i] - h[k0 * n + i], zs[k1] - zs[k0])
			normals[idx] = dz.cross(dx).normalized()
			colors[idx] = rock_a.lerp(rock_b, tint.get_noise_2d(p.x, p.z) * 0.5 + 0.5)

	var idxs := PackedInt32Array()
	for k in SAMPLES:
		for i in SAMPLES:
			var a := k * n + i
			var b := a + 1
			var c := a + n
			var dd := c + 1
			if outside[a] + outside[b] + outside[c] + outside[dd] == 0:
				continue   # flat valley floor: the ground covers it
			# Godot's front faces are clockwise seen from the front (above).
			idxs.append_array([a, b, dd, a, dd, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mountain.gdshader")
	mat.set_shader_parameter("rock_tex", rock_texture(seed_base))
	mat.set_shader_parameter("snow_line", float(v.get("snow_line", 17.0)))
	mat.set_shader_parameter("tree_line", float(v.get("tree_line", 12.0)))
	mat.set_shader_parameter("facets", 0.7)
	mat.set_shader_parameter("settle", 1.0)
	mat.set_shader_parameter("glacier_source", v.get("glacier_source", Vector3(0.0, 0.0, float(v.get("back_z", 0.0)) - 7.0)))
	var sun: Vector3 = Levels.look("sun_dir", Vector3(-0.58, -0.6, -0.55))
	mat.set_shader_parameter("sun_dir", -sun.normalized())
	Ground.bind(level, mat, "mountains")
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func height_at(x: float, z: float) -> float:
	## The ground's height at a spot: 0 on the valley floor, up the slopes as
	## the mountains were built (call mountains() first).
	if _hf.is_empty():
		return 0.0
	var n: int = _hf.n
	var xs: PackedFloat32Array = _hf.xs
	var zs: PackedFloat32Array = _hf.zs
	var h: PackedFloat32Array = _hf.h
	var i := clampi(_cell(x - float(_hf.cx)), 0, n - 2)
	var k := clampi(_cell(z - float(_hf.cz)), 0, n - 2)
	var fx := clampf((x - xs[i]) / (xs[i + 1] - xs[i]), 0.0, 1.0)
	var fz := clampf((z - zs[k]) / (zs[k + 1] - zs[k]), 0.0, 1.0)
	var ha := h[k * n + i]
	var hb := h[k * n + i + 1]
	var hc := h[(k + 1) * n + i]
	var hd := h[(k + 1) * n + i + 1]
	# Each cell is two triangles (a, b, d) and (a, d, c), as in the mesh.
	var y := ha + (hb - ha) * fx + (hd - hb) * fz if fx >= fz else ha + (hd - hc) * fx + (hc - ha) * fz
	return maxf(y, 0.0)


static func _cell(m: float) -> int:
	## The grid line at or below `m` metres from the grid's middle (see _axis).
	var u := signf(m) * pow(absf(m) / EXTENT, 1.0 / WARP)
	var i := int(floor((u + 1.0) * 0.5 * SAMPLES))
	# pow() can land a hair either side of a grid line.
	while i > 0 and _axis(i) > m:
		i -= 1
	while i < SAMPLES - 1 and _axis(i + 1) <= m:
		i += 1
	return i


static func slope_normal(x: float, z: float) -> Vector3:
	var e := 1.2
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()


static func slope_forest(level: Dictionary, count: int) -> Node3D:
	## Pines on the aprons and ledges of the mountains, up to the tree line.
	var v: Dictionary = level.valley
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.seed) + 91
	var patches := FastNoiseLite.new()
	patches.seed = int(level.seed) + 92
	patches.frequency = 0.03
	var tree_line := float(v.get("tree_line", 12.0))
	var falls_a: Vector2 = v.get("falls_top", Vector2.INF)
	var falls_b: Vector2 = v.stream[1] if v.has("stream") else Vector2.INF
	var spots: Array = []
	var far: Array = []
	for _i in count * 30:
		if spots.size() + far.size() >= count:
			break
		var x := rng.randf_range(-120.0, 120.0)
		var z := rng.randf_range(-95.0, 125.0)
		var d := floor_distance(v, x, z, _hf.hollow, _hf.gap_to)
		if d < 1.2 or d > 60.0:
			continue
		if rng.randf() < d / 70.0:   # most of them close to the valley
			continue
		var y := height_at(x, z)
		if y < 0.3 or y > tree_line + patches.get_noise_2d(x, z) * 4.0:
			continue
		if slope_normal(x, z).y < 0.74 or patches.get_noise_2d(x + 300.0, z) < -0.25:
			continue
		if falls_a.is_finite() and _segment_distance(Vector2(x, z), falls_a, falls_b) < 3.5:
			continue
		var spot := [Vector3(x, y - 0.25, z), rng.randf_range(0.9, 1.6) * (1.0 + minf(d, 40.0) / 60.0), rng.randf() * TAU]
		if d < NEAR_TREES:
			spots.append(spot)
		else:
			far.append(spot)
	var f := forest(spots, false)
	f.name = "SlopeForest"
	# Further off, plainer trees: they're too small on screen to tell.
	if not far.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _far_pine_mesh()
		mm.instance_count = far.size()
		for i in far.size():
			var sp: Array = far[i]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(sp[2])).scaled(Vector3.ONE * float(sp[1])), sp[0]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = MeshKit.material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(mmi)
	return f


static var _far_pine: ArrayMesh


static func _far_pine_mesh() -> ArrayMesh:
	## A pine in a few dozen triangles: a trunk and three tiers, the size and
	## colours of the real ones (art/blender/build_nature.py).
	if _far_pine == null:
		var st := MeshKit.begin()
		MeshKit.cylinder(st, Vector3.ZERO, Vector3(0.0, 0.9, 0.0), 0.16, 0.13, Color(0.36, 0.2, 0.14), 5, false)
		var green := Color(0.15, 0.32, 0.19)
		# Each tier is a cone with its underside: you look up at these from the valley.
		MeshKit.cylinder(st, Vector3(0.0, 0.7, 0.0), Vector3(0.0, 2.5, 0.0), 1.25, 0.0, green, 7)
		MeshKit.cylinder(st, Vector3(0.0, 1.8, 0.0), Vector3(0.0, 3.4, 0.0), 0.95, 0.0, green.lightened(0.06), 7)
		MeshKit.cylinder(st, Vector3(0.0, 2.8, 0.0), Vector3(0.0, 4.1, 0.0), 0.65, 0.0, green.lightened(0.12), 7)
		_far_pine = MeshKit.finish(st)
	return _far_pine


static var _rock_tex := {}


static func rock_texture(seed_base: int) -> ImageTexture:
	## Detail for the rock shader. R = cracks (thin wandering lines), G = the
	## rock's shade in soft-edged plates, B = big soft blotches. Tiles seamlessly.
	if _rock_tex.has(seed_base):
		return _rock_tex[seed_base]
	var n := 256
	var veins := FastNoiseLite.new()
	veins.seed = seed_base + 45
	veins.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	veins.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	veins.fractal_octaves = 2
	veins.frequency = 0.012
	var plates := FastNoiseLite.new()
	plates.seed = seed_base + 46
	plates.frequency = 0.022
	plates.fractal_octaves = 3
	var blotch := FastNoiseLite.new()
	blotch.seed = seed_base + 47
	blotch.frequency = 0.011
	blotch.fractal_octaves = 4
	var crack := veins.get_seamless_image(n, n).get_data()   # L8: brightest along the ridges
	var tone := plates.get_seamless_image(n, n).get_data()
	var soft := blotch.get_seamless_image(n, n).get_data()
	var rgb := PackedByteArray()
	rgb.resize(n * n * 3)
	for i in n * n:
		rgb[i * 3] = int(clampf((float(crack[i]) - 212.0) / 32.0, 0.0, 1.0) * 255.0)
		# Six shades with soft steps between them, so the rock reads as slabs.
		var t := float(tone[i]) / 255.0 * 6.0
		rgb[i * 3 + 1] = int((floor(t) + smoothstep(0.38, 0.62, t - floor(t))) / 6.0 * 255.0)
		rgb[i * 3 + 2] = soft[i]
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, rgb)
	img.generate_mipmaps()
	_rock_tex[seed_base] = ImageTexture.create_from_image(img)
	return _rock_tex[seed_base]


static var _rock_mats := {}


static func rock_material(foot: float = 0.0) -> ShaderMaterial:
	## The mountains' rock shader without snow or plants, for boulders and
	## Kevin. foot = how much the bottom metres blend into the valley floor.
	var level := Levels.current()
	var key := "%s/%s" % [level.name, foot]   # each map has its own rock and its own ground
	if not _rock_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/mountain.gdshader")
		m.set_shader_parameter("rock_tex", rock_texture(int(level.seed)))
		m.set_shader_parameter("snow_line", 1000.0)
		m.set_shader_parameter("tree_line", 0.0)
		m.set_shader_parameter("foot_amount", foot)
		Ground.bind(level, m, "rock%s" % foot)
		_rock_mats[key] = m
	return _rock_mats[key]


static func boulder_mesh(variant: int) -> ArrayMesh:
	## A lumpy, flat-bottomed rock about 1 m across.
	var noise := FastNoiseLite.new()
	noise.seed = 300 + variant
	noise.frequency = 1.1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # flat faces, like the other models
	var rings := 5
	var segs := 8
	var pts := []
	for r in rings + 1:
		var phi := PI * float(r) / rings
		var row := []
		for sg in segs:
			var th := TAU * (float(sg) + 0.5 * (r % 2)) / segs
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var rad := 0.5 * (1.0 + 0.4 * noise.get_noise_3dv(dir * 1.5))
			var p := dir * rad * Vector3(1.0, 0.72, 0.9)
			p.y = maxf(p.y, -0.12)   # sits flat on the ground
			row.append(p)
		pts.append(row)
	var warm: Color = Levels.look("boulder", Color(0.58, 0.56, 0.53))   # a map can have stone of its own
	var cool: Color = Levels.look("boulder_b", Color(0.5, 0.51, 0.54))
	var tint := warm.lerp(cool, float(variant % 3) / 2.0)
	for r in rings:
		for sg in segs:
			var s2 := (sg + 1) % segs
			var quad := [pts[r][sg], pts[r][s2], pts[r + 1][s2], pts[r + 1][sg]]
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for t in tri:
					st.set_color(tint)
					st.add_vertex(quad[t])
	st.generate_normals()
	return st.commit()


static func pine_mesh(variant: int) -> ArrayMesh:
	## A pine tree about 4 m tall, with drooping layers of branches
	## (art/blender/build_nature.py).
	return Models.baked("nature", "Pine%d" % (variant % 4))


static func forest(spots: Array, shadows: bool) -> Node3D:
	## Pines at the given spots ([position, scale, turn]), one MultiMesh per
	## tree shape, so a whole forest is only a few draw calls.
	var root := Node3D.new()
	root.name = "Forest"
	var variants := 4
	for v in variants:
		var mine := []
		for i in spots.size():
			if i % variants == v:
				mine.append(spots[i])
		if mine.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pine_mesh(v)
		mm.instance_count = mine.size()
		for i in mine.size():
			var sp: Array = mine[i]
			var b := Basis(Vector3.UP, float(sp[2])).scaled(Vector3.ONE * float(sp[1]))
			mm.set_instance_transform(i, Transform3D(b, sp[0]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = MeshKit.material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root


static func near_stream(level: Dictionary, x: float, z: float, margin: float) -> bool:
	## Within `margin` metres of the river's water.
	return Ground.stream_distance(level, x, z) < margin


# =====================================================================================
# Sky
# =====================================================================================
static func sky(seed_base: int) -> Sky:
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/sky.gdshader")
	var big := FastNoiseLite.new()
	big.seed = seed_base + 51
	big.frequency = 0.012
	big.fractal_octaves = 5
	var puff := FastNoiseLite.new()
	puff.seed = seed_base + 52
	puff.noise_type = FastNoiseLite.TYPE_CELLULAR
	puff.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	puff.frequency = 0.03
	puff.fractal_type = FastNoiseLite.FRACTAL_FBM
	puff.fractal_octaves = 3
	var a := big.get_seamless_image(256, 256)
	var b := puff.get_seamless_image(256, 256)
	a.generate_mipmaps()
	b.generate_mipmaps()
	shader_mat.set_shader_parameter("clouds", ImageTexture.create_from_image(a))
	shader_mat.set_shader_parameter("puffs", ImageTexture.create_from_image(b))
	var s := Sky.new()
	s.sky_material = shader_mat
	s.radiance_size = Sky.RADIANCE_SIZE_64
	return s


# =====================================================================================
# Water
# =====================================================================================
static func lake(level: Dictionary) -> MeshInstance3D:
	## A lake with a wobbly shoreline (Ground cuts the same outline out of the
	## valley floor and slopes the shore down into it). Vertex alpha = depth
	## (0 at the shore, 1 in the deep middle).
	var lk: Array = level.valley.lake
	var segs := 96
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	verts.append(Vector3(lk[0], 0.0, lk[1]))
	colors.append(Color(1, 1, 1, 1))
	normals.append(Vector3.UP)
	# From the middle out: three rings inside the outline, then the bank.
	var rings := [[0.3, 1.0], [0.62, 1.0], [0.86, 0.75], [-4.0, 0.3], [Ground.LAKE_BANK, 0.0]]
	for r in rings.size():
		for sgm in segs:
			var a := TAU * float(sgm) / segs
			var p: Vector2
			if r < 3:
				var f: float = rings[r][0]
				var wob := 1.0 + (Ground.lake_wobble(level, a) - 1.0) * f
				p = Vector2(lk[0] + cos(a) * lk[2] * f * wob, lk[1] + sin(a) * lk[3] * f * wob)
			else:
				p = Ground.lake_point(level, a, rings[r][0])
			verts.append(Vector3(p.x, 0.0, p.y))
			colors.append(Color(1, 1, 1, rings[r][1]))
			normals.append(Vector3.UP)
	var idxs := PackedInt32Array()
	for sgm in segs:
		var nx := (sgm + 1) % segs
		idxs.append_array([0, 1 + sgm, 1 + nx])
	for r in range(1, rings.size()):
		var base0 := 1 + (r - 1) * segs
		var base1 := 1 + r * segs
		for sgm in segs:
			var nx := (sgm + 1) % segs
			idxs.append_array([base0 + sgm, base1 + nx, base0 + nx, base0 + sgm, base1 + sgm, base1 + nx])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	mi.mesh = mesh
	mi.position.y = Ground.LAKE_Y
	mi.material_override = water_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func stream(level: Dictionary) -> MeshInstance3D:
	## The river's water: a ribbon along its bed (Ground.stream_path), from
	## the pool under the waterfall, under the glacier and down to the lake.
	var sp := Ground.stream_path(level)
	var pts: PackedVector2Array = sp.pts
	if pts.size() < 2:
		return null
	var half: PackedFloat32Array = sp.half
	var dist: PackedFloat32Array = sp.dist
	var course: Array = level.valley.stream
	var pool_at := (course[1] as Vector2).distance_to(course[0])
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in pts.size():
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x)
		# White water in the pool where the falls land.
		var churn := exp(-pow((dist[i] - pool_at) / 2.2, 2.0))
		# It sinks under the lake at the end.
		var y := -0.12 * smoothstep(float(sp.length) - 4.0, float(sp.length) - 1.0, dist[i])
		for s in [-1.0, 1.0]:
			var q: Vector2 = pts[i] + side * (half[i] + 0.35) * s
			verts.append(Vector3(q.x, y, q.y))
			colors.append(Color(1.0 - churn, 1, 1, 1))
			normals.append(Vector3.UP)
			uvs.append(Vector2(s * 0.5 + 0.5, dist[i]))
	var idxs := PackedInt32Array()
	for i in pts.size() - 1:
		var a := i * 2
		idxs.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
	var mi := _ribbon(verts, normals, colors, uvs, idxs, stream_material(0.0))
	mi.name = "Stream"
	mi.position.y = Ground.STREAM_Y
	return mi


static func _ribbon(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		uvs: PackedVector2Array, idxs: PackedInt32Array, mat: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func falls(level: Dictionary) -> Node3D:
	## Where the river comes from: a waterfall off the snowfield on the back
	## wall, tumbling down a rocky gully into a pool on the valley floor.
	## (Call mountains() first: it follows the slope.)
	var v: Dictionary = level.valley
	if not v.has("falls_top") or not v.has("stream"):
		return null
	var top: Vector2 = v.falls_top
	var pool: Vector2 = v.stream[1]
	var root := Node3D.new()
	root.name = "Falls"
	var along := (pool - top).normalized()
	var side := Vector2(-along.y, along.x)
	var length := top.distance_to(pool)
	var steps := int(ceil(length / 0.5))
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var run := 0.0
	var last := Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.seed) + 95
	var foot := Vector3(pool.x, 0.0, pool.y)   # where it lands
	for i in steps + 1:
		var t := float(i) / steps
		var c := top.lerp(pool, t)
		var w := lerpf(0.5, 1.0, t) * (1.0 + 0.2 * sin(t * 23.0))
		var mid := Vector3(c.x, maxf(height_at(c.x, c.y) + 0.16, Ground.STREAM_Y + 0.03), c.y)
		if i > 0:
			run += mid.distance_to(last)
		var slope := (mid - last).normalized() if i > 0 else Vector3(along.x, -1.0, along.y).normalized()
		last = mid
		var n := Vector3(side.x, 0.0, side.y).cross(slope).normalized()
		if n.y < 0.0:
			n = -n
		for s in [-1.0, 1.0]:
			var q: Vector2 = c + side * w * s
			verts.append(Vector3(q.x, maxf(height_at(q.x, q.y) + 0.16, Ground.STREAM_Y + 0.03), q.y))
			# It seeps out of the snow at the top.
			colors.append(Color(1, 1, 1, smoothstep(0.0, 0.14, t)))
			normals.append(n)
			uvs.append(Vector2(s * 0.5 + 0.5, run))
		# Rocks along both sides of the gully.
		if i % 3 == 1 and mid.y > 0.4:
			for s in [-1.0, 1.0]:
				if rng.randf() < 0.25:
					continue
				var q: Vector2 = c + side * (w + rng.randf_range(0.35, 0.9)) * s + along * rng.randf_range(-0.4, 0.4)
				_rock(root, Vector3(q.x, height_at(q.x, q.y) - 0.15, q.y), rng.randf_range(0.7, 1.5), rng)
		if mid.y > 0.2:
			foot = mid
	var idxs := PackedInt32Array()
	for i in steps:
		var a := i * 2
		idxs.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
	var water := _ribbon(verts, normals, colors, uvs, idxs, stream_material(1.0))
	water.name = "Water"
	root.add_child(water)
	# Boulders round the back of the pool.
	for a in [-2.5, -1.8, -1.1, 1.2, 1.9, 2.6]:
		var q: Vector2 = pool - along.rotated(a * 0.55) * rng.randf_range(2.3, 2.9)
		_rock(root, Vector3(q.x, height_at(q.x, q.y) - 0.1, q.y), rng.randf_range(0.8, 1.4), rng)

	# Spray where it lands.
	var mist := CPUParticles3D.new()
	mist.name = "Mist"
	mist.amount = 14
	mist.lifetime = 2.4
	mist.preprocess = 2.4
	mist.position = Vector3(foot.x, 0.25, foot.z) + Vector3(along.x, 0.0, along.y) * 0.5
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 0.7
	mist.direction = Vector3(along.x, 1.6, along.y).normalized()
	mist.spread = 35.0
	mist.initial_velocity_min = 0.5
	mist.initial_velocity_max = 1.1
	mist.gravity = Vector3(0.0, -0.25, 0.0)
	mist.scale_amount_min = 1.1
	mist.scale_amount_max = 2.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	mist.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.2, Color(1, 1, 1, 0.34))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	mist.color_ramp = fade
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 48
	dot.height = 48
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.billboard_keep_scale = true   # or unused particles draw as black discs on WebGL
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.vertex_color_use_as_albedo = true
	mm.albedo_texture = dot
	var quad := QuadMesh.new()
	quad.material = mm
	mist.mesh = quad
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mist)
	return root


static func _rock(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var r := MeshInstance3D.new()
	r.mesh = boulder_mesh(rng.randi() % 4)
	r.material_override = rock_material(0.25)
	r.position = at
	r.scale = Vector3(size, size * rng.randf_range(0.75, 1.1), size)
	r.rotation.y = rng.randf() * TAU
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(r)


static var _water_mat: ShaderMaterial
static var _stream_mats := {}
static var _ripples: ImageTexture


static func _ripple_texture() -> ImageTexture:
	if _ripples == null:
		var noise := FastNoiseLite.new()
		noise.seed = 77
		noise.frequency = 0.04
		noise.fractal_octaves = 3
		var img := noise.get_seamless_image(128, 128)
		img.generate_mipmaps()
		_ripples = ImageTexture.create_from_image(img)
	return _ripples


static func water_material() -> ShaderMaterial:
	## The lake.
	if _water_mat == null:
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = load("res://shaders/water.gdshader")
		_water_mat.set_shader_parameter("ripples", _ripple_texture())
	return _water_mat


static func stream_material(falling: float) -> ShaderMaterial:
	## Running water: 0 = the river, 1 = white water down the waterfall.
	if not _stream_mats.has(falling):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/stream.gdshader")
		m.set_shader_parameter("ripples", _ripple_texture())
		m.set_shader_parameter("falls", falling)
		_stream_mats[falling] = m
	return _stream_mats[falling]


static func on_lake(level: Dictionary, x: float, z: float, margin: float = 0.0) -> bool:
	if Coast.is_coast(level):
		return z > Coast.shore(level.valley, x) - margin
	var lk: Array = level.valley.lake
	var ex: float = (x - lk[0]) / (lk[2] * 1.12 + margin)
	var ez: float = (z - lk[1]) / (lk[3] * 1.12 + margin)
	return ex * ex + ez * ez < 1.0
