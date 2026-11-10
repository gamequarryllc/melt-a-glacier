class_name Ground
extends RefCounted
## The valley floor: bare moraine that grows over with grass as the glacier
## melts, with a river bed, trodden paths, a sandy lake shore, tufts of grass
## and pebbles.
##
## What's where comes from one small "map" texture of distances (to the
## river, the lake, the paths and the glacier), baked from the level
## description. shaders/valley_floor.gdshaderinc turns it into colour; the
## mountains and boulders use the same code for their feet, so the floor
## carries on up the slopes without a seam.

const MAP_SIZE := 256
const MAP_MIN := Vector2(-72.0, -50.0)   # world x, z of the map's corner
const MAP_SPAN := 144.0                  # metres across
const BANK := 1.3                        # the river's banks, metres past the water's edge
const STREAM_Y := -0.1                   # the river's surface (the floor is at 0)
const LAKE_Y := -0.04
const LAKE_BANK := 1.6                   # the ground stops this far outside the lake's outline
const LAKE_WATERLINE := 1.2              # where the sloping shore meets the water
# Grass cover against how much of the glacier has melted (see valley_floor.gdshaderinc).
const GREEN_BASE := 0.27
const GREEN_GAIN := 0.6

static var _stream_cache := {}
static var _lake_noise: FastNoiseLite
static var _map_img: Image
static var _map_tex: ImageTexture
static var _tex_img: Image
static var _tex: ImageTexture
static var _map_level := ""
static var _users := {}                  # materials that draw the valley floor, by name
static var _green := 0.0
static var _tufts: MultiMesh
static var _tuft_at := PackedFloat32Array()   # how green the valley is when each tuft comes up, sorted


# =====================================================================================
# The river's course
# =====================================================================================
static func stream_path(level: Dictionary) -> Dictionary:
	## The river as a smooth line of points about half a metre apart:
	## pts (x, z), half (half its width there), dist (metres from the start).
	var key := str(level.name)
	if _stream_cache.has(key):
		return _stream_cache[key]
	var out := {"pts": PackedVector2Array(), "half": PackedFloat32Array(), "dist": PackedFloat32Array(), "length": 0.0}
	var pts: Array = level.valley.get("stream", [])
	if pts.size() >= 2:
		var curve := Curve2D.new()
		for i in pts.size():
			var p: Vector2 = pts[i]
			var prev: Vector2 = pts[maxi(i - 1, 0)]
			var nxt: Vector2 = pts[mini(i + 1, pts.size() - 1)]
			var tangent := (nxt - prev) * 0.25
			curve.add_point(p, -tangent, tangent)
		curve.bake_interval = 0.5
		var baked := curve.get_baked_points()
		var dist := PackedFloat32Array()
		dist.resize(baked.size())
		var d := 0.0
		for i in baked.size():
			if i > 0:
				d += baked[i].distance_to(baked[i - 1])
			dist[i] = d
		var pool_at := (pts[1] as Vector2).distance_to(pts[0])   # the plunge pool under the falls
		var half := PackedFloat32Array()
		half.resize(baked.size())
		for i in baked.size():
			var w := lerpf(0.7, 1.25, dist[i] / d) * (1.0 + 0.14 * sin(dist[i] * 0.7))
			half[i] = w + 1.0 * exp(-pow((dist[i] - pool_at) / 1.6, 2.0))
		out = {"pts": baked, "half": half, "dist": dist, "length": d}
	_stream_cache[key] = out
	return out


static func stream_distance(level: Dictionary, x: float, z: float) -> float:
	## Metres from the river's edge (negative in the water).
	var sp := stream_path(level)
	var pts: PackedVector2Array = sp.pts
	var half: PackedFloat32Array = sp.half
	var p := Vector2(x, z)
	var best := 1000.0
	for i in pts.size():
		best = minf(best, p.distance_to(pts[i]) - half[i])
	return best


static func _sides(sp: Dictionary, extra: float) -> Array:
	## The river's left and right edges, `extra` metres out from the water.
	var pts: PackedVector2Array = sp.pts
	var half: PackedFloat32Array = sp.half
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in pts.size():
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x)
		left.append(pts[i] + side * (half[i] + extra))
		right.append(pts[i] - side * (half[i] + extra))
	return [left, right]


# =====================================================================================
# The lake's outline
# =====================================================================================
static func lake_wobble(level: Dictionary, angle: float) -> float:
	## The lake isn't a perfect oval: its radius times this, at each angle.
	if _lake_noise == null:
		_lake_noise = FastNoiseLite.new()
		_lake_noise.frequency = 1.3
	_lake_noise.seed = int(level.seed) + 61
	return 1.0 + 0.09 * _lake_noise.get_noise_2d(cos(angle), sin(angle))


static func lake_point(level: Dictionary, angle: float, out: float) -> Vector2:
	## A point `out` metres outside the lake's outline (negative = inside).
	var lk: Array = level.valley.lake
	var wob := lake_wobble(level, angle)
	var p := Vector2(lk[0] + cos(angle) * lk[2] * wob, lk[1] + sin(angle) * lk[3] * wob)
	var n := Vector2(cos(angle) / lk[2], sin(angle) / lk[3]).normalized()
	return p + n * out


static func lake_distance(level: Dictionary, x: float, z: float) -> float:
	## Metres outside the lake's outline (negative on the lake).
	var lk: Array = level.valley.lake
	var dx: float = x - lk[0]
	var dz: float = z - lk[1]
	var wob := lake_wobble(level, atan2(dz / lk[3], dx / lk[2]))
	var rx: float = lk[2] * wob
	var rz: float = lk[3] * wob
	var ex := dx / rx
	var ez := dz / rz
	var k := sqrt(ex * ex + ez * ez)
	if k < 0.001:
		return -minf(rx, rz)
	return (k - 1.0) * k / sqrt(ex * ex / (rx * rx) + ez * ez / (rz * rz))


static func _glacier_distance(g: Dictionary, x: float, z: float) -> float:
	## Metres outside the first glacier's footprint, roughly (negative under it).
	if g.get("kind", "tongue") == "blobs":
		var best := 100.0
		for b in g.blobs:
			var ex := (x - float(b[0])) / float(b[2])
			var ez := (z - float(b[1])) / float(b[3])
			best = minf(best, (sqrt(ex * ex + ez * ez) - 1.0) * minf(float(b[2]), float(b[3])))
		return best
	if g.get("kind", "tongue") != "tongue":
		return 100.0
	var t := clampf((z - float(g.full_z)) / (float(g.snout_z) - float(g.full_z)), 0.0, 1.0)
	var hw := lerpf(float(g.half_width_back), float(g.half_width_snout), t)
	return maxf(absf(x) - hw, maxf(z - (float(g.snout_z) - 0.6), float(g.back_z) - z))


# =====================================================================================
# The map and the detail texture
# =====================================================================================
static func _splat(field: PackedFloat32Array, p: Vector2, sub: float, radius: float) -> void:
	## Lowers `field` to (distance from p) - sub, for the texels within radius.
	var texel := MAP_SPAN / MAP_SIZE
	var c := (p - MAP_MIN) / texel - Vector2(0.5, 0.5)
	var r := int(ceil(radius / texel))
	var cx := int(round(c.x))
	var cy := int(round(c.y))
	for y in range(maxi(cy - r, 0), mini(cy + r, MAP_SIZE - 1) + 1):
		for x in range(maxi(cx - r, 0), mini(cx + r, MAP_SIZE - 1) + 1):
			var d := Vector2(x - c.x, y - c.y).length() * texel - sub
			var i := y * MAP_SIZE + x
			if d < field[i]:
				field[i] = d


static func _enc(v: float, lo: float, hi: float) -> int:
	return clampi(int(round((v - lo) / (hi - lo) * 255.0)), 0, 255)


static func _ensure(level: Dictionary) -> void:
	if _map_level == str(level.name) and _map_tex != null:
		return
	_map_level = str(level.name)
	var n := MAP_SIZE
	var texel := MAP_SPAN / n
	# R: metres from the river's edge (-2..6). B: metres from a path (0..6).
	var stream := PackedFloat32Array()
	stream.resize(n * n)
	stream.fill(99.0)
	var sp := stream_path(level)
	for i in sp.pts.size():
		_splat(stream, sp.pts[i], sp.half[i], 6.5)
	var path := PackedFloat32Array()
	path.resize(n * n)
	path.fill(99.0)
	for line in level.valley.get("paths", []):
		for i in (line as Array).size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var steps := int(ceil(a.distance_to(b) / 0.4))
			for s in steps + 1:
				_splat(path, a.lerp(b, float(s) / steps), 0.0, 5.0)
	# G: metres from the lake's waterline (-4..12). A: metres from the glacier (-4..12).
	var g0: Dictionary = level.glaciers[0]
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var o := 0
	var coast := Coast.is_coast(level)
	var lk: Array = level.valley.get("lake", [0.0, 0.0, 1.0, 1.0])
	var lake_from: float = lk[1] - lk[3] * 1.1 - 14.0   # nearer rows are nowhere near the lake
	var ice_to := float(g0.get("snout_z", 0.0)) + 14.0
	for row in n:
		var z := MAP_MIN.y + (row + 0.5) * texel
		for col in n:
			var x := MAP_MIN.x + (col + 0.5) * texel
			var i := row * n + col
			data[o] = _enc(stream[i], -2.0, 6.0)
			if coast:   # the sea is its "lake": metres up the shore from the water's edge
				data[o + 1] = _enc(Coast.shore(level.valley, x) - z, -4.0, 12.0)
				data[o + 3] = _enc(_glacier_distance(g0, x, z), -4.0, 12.0)
			else:
				data[o + 1] = _enc(lake_distance(level, x, z) - LAKE_WATERLINE, -4.0, 12.0) if z > lake_from else 255
				data[o + 3] = _enc(_glacier_distance(g0, x, z), -4.0, 12.0) if z < ice_to else 255
			data[o + 2] = _enc(path[i], 0.0, 6.0)
			o += 4
	_map_img = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	_map_tex = ImageTexture.create_from_image(_map_img)

	# Detail, tiled over the floor at three sizes. R: pebbles (cells, dark in
	# the middle of each). G: fine grain, with each pebble's own shade mixed
	# in. B, A: big soft blotches, read at the larger sizes for where the
	# grass grows and how it's coloured.
	var seed_base := int(level.seed)
	var cells := FastNoiseLite.new()
	cells.seed = seed_base + 71
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	cells.cellular_jitter = 0.9
	cells.frequency = 0.085
	cells.fractal_type = FastNoiseLite.FRACTAL_NONE
	var shade: FastNoiseLite = cells.duplicate()
	shade.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var shades := shade.get_seamless_image(n, n).get_data()
	var grain := FastNoiseLite.new()
	grain.seed = seed_base + 72
	grain.frequency = 0.16
	grain.fractal_octaves = 3
	var blotch := FastNoiseLite.new()
	blotch.seed = seed_base + 73
	blotch.frequency = 0.014
	blotch.fractal_octaves = 4
	var blotch2 := FastNoiseLite.new()
	blotch2.seed = seed_base + 74
	blotch2.frequency = 0.022
	blotch2.fractal_octaves = 3
	var planes: Array = []
	for nz in [cells, grain, blotch, blotch2]:
		planes.append((nz as FastNoiseLite).get_seamless_image(n, n).get_data())   # L8
	var rgba := PackedByteArray()
	rgba.resize(n * n * 4)
	for i in n * n:
		rgba[i * 4] = planes[0][i]
		rgba[i * 4 + 1] = int(float(planes[1][i]) * 0.45 + float(shades[i]) * 0.55)
		rgba[i * 4 + 2] = planes[2][i]
		rgba[i * 4 + 3] = planes[3][i]
	_tex_img = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, rgba)
	var mipped: Image = _tex_img.duplicate()
	mipped.generate_mipmaps()
	_tex = ImageTexture.create_from_image(mipped)


static func bind(level: Dictionary, mat: ShaderMaterial, key: String) -> void:
	## Gives a material that includes valley_floor.gdshaderinc what it needs,
	## and keeps it greening with the valley.
	_ensure(level)
	mat.set_shader_parameter("floor_map", _map_tex)
	mat.set_shader_parameter("floor_tex", _tex)
	mat.set_shader_parameter("floor_map_rect", Vector3(MAP_MIN.x, MAP_MIN.y, 1.0 / MAP_SPAN))
	mat.set_shader_parameter("green", _green)
	# A map can have ground of its own colours (Frozen Harbor: snow and tundra).
	var palette: Dictionary = level.get("look", {}).get("ground", {})
	for name in palette:
		mat.set_shader_parameter(name, palette[name])
	_users[key] = mat


static func set_green(green: float) -> void:
	## 0 = bare moraine, 1 = the whole valley is meadow.
	if is_equal_approx(green, _green) and green > 0.0:
		return
	_green = green
	for key in _users:
		(_users[key] as ShaderMaterial).set_shader_parameter("green", green)
	if _tufts != null:
		_tufts.visible_instance_count = _tuft_at.bsearch(green, false)


static func _map_at(x: float, z: float) -> Color:
	var u := clampi(int((x - MAP_MIN.x) / MAP_SPAN * MAP_SIZE), 0, MAP_SIZE - 1)
	var v := clampi(int((z - MAP_MIN.y) / MAP_SPAN * MAP_SIZE), 0, MAP_SIZE - 1)
	return _map_img.get_pixel(u, v)


static func _tex_at(x: float, z: float, scale: float, offset: Vector2) -> Color:
	var u := posmod(int(floor((x * scale + offset.x) * MAP_SIZE)), MAP_SIZE)
	var v := posmod(int(floor((z * scale + offset.y) * MAP_SIZE)), MAP_SIZE)
	return _tex_img.get_pixel(u, v)


static func grass_at(level: Dictionary, x: float, z: float) -> float:
	## How green the valley has to be (0..1) before grass grows here; above 1
	## means never (paths, banks, the shore). Mirrors valley_floor.gdshaderinc.
	_ensure(level)
	var m := _map_at(x, z)
	var d_stream := m.r * 8.0 - 2.0
	var d_lake := m.g * 16.0 - 4.0
	var d_path := m.b * 6.0
	var block := (1.0 - smoothstep(0.55, 0.95, d_path)) + (1.0 - smoothstep(0.8, 2.6, d_lake)) \
			+ (1.0 - smoothstep(0.1, 0.8, d_stream))
	var arrive := _tex_at(x, z, 0.021, Vector2(0.37, 0.11)).b * 0.62 + _tex_at(x, z, 0.083, Vector2(0.13, 0.71)).b * 0.3
	return (arrive + block - GREEN_BASE) / GREEN_GAIN


# =====================================================================================
# The floor's mesh
# =====================================================================================
static func floor_node(level: Dictionary) -> MeshInstance3D:
	## The valley floor as one mesh: flat ground with the river's course and
	## the lake cut out of it, the river bed, and the lake's sloping shore.
	var st := {"v": PackedVector3Array(), "n": PackedVector3Array(), "i": PackedInt32Array()}
	var sp := stream_path(level)
	var lk: Array = level.valley.lake
	var cut := PackedVector2Array()
	var segs := 96
	var ring := PackedVector2Array()
	for s in segs:
		ring.append(lake_point(level, TAU * float(s) / segs, LAKE_BANK))
	cut = ring
	# A slot from the lake out past the far edge, and one from the river's
	# start out past the back, so what's left of the floor has no holes in it.
	var slots: Array = [PackedVector2Array([Vector2(lk[0] - 10.0, lk[1]), Vector2(lk[0] + 10.0, lk[1]),
			Vector2(lk[0] + 10.0, 130.0), Vector2(lk[0] - 10.0, 130.0)])]
	if sp.pts.size() > 1:
		var sides := _sides(sp, BANK)
		var corridor: PackedVector2Array = sides[0].duplicate()
		var right: PackedVector2Array = sides[1].duplicate()
		right.reverse()
		corridor.append_array(right)
		slots.append(corridor)
		var s0: Vector2 = sp.pts[0]
		slots.append(PackedVector2Array([Vector2(s0.x - 0.5, s0.y + 0.5), Vector2(s0.x + 0.5, s0.y + 0.5),
				Vector2(s0.x + 0.5, -90.0), Vector2(s0.x - 0.5, -90.0)]))
		_add_bed(st, level, sp, sides)
	for slot in slots:
		for merged in Geometry2D.merge_polygons(cut, slot):
			if not Geometry2D.is_polygon_clockwise(merged):
				cut = merged
	_add_shore(st, level, segs)
	var rect := PackedVector2Array([Vector2(-84.0, -68.0), Vector2(84.0, -68.0), Vector2(84.0, 114.0), Vector2(-84.0, 114.0)])
	for piece in Geometry2D.clip_polygons(rect, cut):
		if Geometry2D.is_polygon_clockwise(piece):
			continue
		var tris := Geometry2D.triangulate_polygon(piece)
		if tris.is_empty():
			push_warning("Ground: couldn't triangulate a piece of the valley floor")
			continue
		var base: int = st.v.size()
		for p in piece:
			st.v.append(Vector3(p.x, 0.0, p.y))
			st.n.append(Vector3.UP)
		for t in range(0, tris.size(), 3):
			_tri(st, base + tris[t], base + tris[t + 1], base + tris[t + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st.v
	arrays[Mesh.ARRAY_NORMAL] = st.n
	arrays[Mesh.ARRAY_INDEX] = st.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	bind(level, mat, "floor")
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _tri(st: Dictionary, a: int, b: int, c: int) -> void:
	## Adds a triangle facing up (Godot's front faces are clockwise from above).
	var v: PackedVector3Array = st.v
	if (v[c] - v[a]).cross(v[b] - v[a]).y < 0.0:
		st.i.append_array([a, c, b])
	else:
		st.i.append_array([a, b, c])


static func _add_bed(st: Dictionary, level: Dictionary, sp: Dictionary, sides: Array) -> void:
	## The river bed: banks sloping down from the floor to a pebbly bottom.
	var pts: PackedVector2Array = sp.pts
	var half: PackedFloat32Array = sp.half
	var left: PackedVector2Array = sides[0]
	var right: PackedVector2Array = sides[1]
	var cols := 7
	var base: int = st.v.size()
	for i in pts.size():
		var w := half[i]
		# Across the bed, from the right bank to the left: metres from the middle, and depth.
		var full := w + BANK
		var offs := [-full, -(w + 0.35), -w * 0.55, 0.0, w * 0.55, w + 0.35, full]
		var ys := [0.0, -0.05, -0.3, -0.36, -0.3, -0.05, 0.0]
		var across := (left[i] - right[i]).normalized()
		for c in cols:
			var q: Vector2 = pts[i] + across * float(offs[c])
			if c == 0:
				q = right[i]
			elif c == cols - 1:
				q = left[i]
			# At the river's mouth the banks dip under the lake.
			var sink := 0.3 * (1.0 - smoothstep(-0.5, LAKE_BANK, lake_distance(level, q.x, q.y)))
			st.v.append(Vector3(q.x, float(ys[c]) - sink, q.y))
			var n := Vector3.UP
			if c > 0 and c < cols - 1:
				var slope := (float(ys[c + 1]) - float(ys[c - 1])) / (float(offs[c + 1]) - float(offs[c - 1]))
				n = Vector3(-across.x * slope, 1.0, -across.y * slope).normalized()
			st.n.append(n)
	for i in pts.size() - 1:
		for c in cols - 1:
			var a := base + i * cols + c
			_tri(st, a, a + 1, a + cols + 1)
			_tri(st, a, a + cols + 1, a + cols)


static func _add_shore(st: Dictionary, level: Dictionary, segs: int) -> void:
	## The lake's shore: the floor slopes down into the water all the way round.
	var outs := [LAKE_BANK, 0.4, -3.0, -8.0]
	var ys := [0.0, -0.14, -0.6, -0.9]
	var base: int = st.v.size()
	for s in segs:
		var angle := TAU * float(s) / segs
		var lk: Array = level.valley.lake
		var outward := Vector2(cos(angle) / lk[2], sin(angle) / lk[3]).normalized()
		for r in outs.size():
			var p := lake_point(level, angle, outs[r])
			st.v.append(Vector3(p.x, ys[r], p.y))
			var n := Vector3.UP
			if r > 0 and r < outs.size() - 1:
				var slope := (float(ys[r + 1]) - float(ys[r - 1])) / (float(outs[r + 1]) - float(outs[r - 1]))
				n = Vector3(-outward.x * slope, 1.0, -outward.y * slope).normalized()
			st.n.append(n)
	var rings := outs.size()
	for s in segs:
		var nx := (s + 1) % segs
		for r in rings - 1:
			var a := base + s * rings + r
			var b := base + nx * rings + r
			_tri(st, a, b, b + 1)
			_tri(st, a, b + 1, a + 1)


# =====================================================================================
# Tufts of grass and pebbles
# =====================================================================================
static func _tuft_mesh() -> ArrayMesh:
	## A tuft: a handful of blades leaning outwards. UV.y = 0 at the root, 1 at
	## the tip (the shader sways the tips in the wind).
	var rng := RandomNumberGenerator.new()
	rng.seed = 4407
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var root_col := Color(0.3, 0.46, 0.22)
	var tip_col := Color(0.5, 0.69, 0.31)
	var blades := 7
	for b in blades:
		var turn := TAU * (float(b) + rng.randf_range(-0.3, 0.3)) / blades
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var side := Vector3(-out.z, 0.0, out.x)
		var foot := out * rng.randf_range(0.02, 0.1)
		var h := rng.randf_range(0.16, 0.34)
		var lean := rng.randf_range(0.1, 0.5)
		var w := rng.randf_range(0.035, 0.055)
		var tip := foot + out * h * lean + Vector3(0.0, h, 0.0)
		var tint := rng.randf_range(0.88, 1.1)
		for v in [[foot - side * w, 0.0], [foot + side * w, 0.0], [tip, 1.0]]:
			verts.append(v[0])
			uvs.append(Vector2(0.5, v[1]))
			var c := root_col.lerp(tip_col, v[1]) * tint
			colors.append(Color(c.r, c.g, c.b, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func tufts(level: Dictionary, count: int, free: Callable) -> MultiMeshInstance3D:
	## Tufts of grass over the valley floor. Each one comes up when the grass
	## reaches its spot, so the valley fills in as the glacier melts
	## (set_green). `free` says whether a spot (x, z) is clear of buildings.
	_ensure(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.seed) + 81
	var v: Dictionary = level.valley
	var coast := Coast.is_coast(level)
	var spots: Array = []
	for _i in count * 3:
		if spots.size() >= count:
			break
		var x: float
		var z: float
		if coast:
			var p := Coast.random_land(v, rng, 0.4)
			if not p.is_finite() or not free.call(p.x, p.y):
				continue
			x = p.x
			z = p.y
		else:
			z = rng.randf_range(float(v.back_z) + 1.0, float(v.front_z))
			var hw: float = v.half_width + maxf(0.0, z - v.flare_z) * v.flare
			x = rng.randf_range(-hw, hw)
			# Mostly near where you walk: thin them out towards the far end.
			if z > 30.0 and rng.randf() < (z - 30.0) / 40.0:
				continue
			if Scenery.floor_distance(v, x, z, Vector2.INF, Vector2.ZERO) > -0.4 or not free.call(x, z):
				continue
		var at := grass_at(level, x, z) + 0.05
		if at > 1.0:
			continue
		spots.append([maxf(at, 0.0), Vector3(x, 0.0, z), rng.randf() * TAU, rng.randf_range(0.7, 1.35)])
	spots.sort_custom(func(a, b): return a[0] < b[0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tuft_mesh()
	mm.instance_count = spots.size()
	_tuft_at.resize(spots.size())
	for i in spots.size():
		var sp: Array = spots[i]
		_tuft_at[i] = sp[0]
		var s: float = sp[3]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, sp[2]).scaled(Vector3(s, s * 1.1, s)), sp[1]))
	_tufts = mm
	mm.visible_instance_count = _tuft_at.bsearch(_green, false)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tufts"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func _pebble_mesh() -> ArrayMesh:
	## A chunky little stone, flat underneath, about 1 m across (scaled down).
	var noise := FastNoiseLite.new()
	noise.seed = 917
	noise.frequency = 1.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # flat faces, like the other models
	var rings := 3
	var segs := 6
	var pts := []
	for r in rings + 1:
		var phi := PI * 0.85 * float(r) / rings   # no need for an underside
		var row := []
		for sg in segs:
			var th := TAU * (float(sg) + 0.5 * (r % 2)) / segs
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var p := dir * 0.5 * (1.0 + 0.3 * noise.get_noise_3dv(dir * 1.7)) * Vector3(1.0, 0.62, 0.85)
			p.y = maxf(p.y, -0.08)
			row.append(p)
		pts.append(row)
	var tint := Color(0.6, 0.58, 0.55)
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


static func pebbles(level: Dictionary, free: Callable) -> MultiMeshInstance3D:
	## Stones along the river's banks and in its bed, on the lake shore and
	## scattered over the moraine. Too small to trip over.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.seed) + 82
	var v: Dictionary = level.valley
	var spots: Array = []
	if Coast.is_coast(level):
		# Shingle: thick along the water's edge and under the cliffs, thin elsewhere.
		for _i in 1400:
			var p := Coast.random_land(v, rng, 0.2)
			if not p.is_finite() or not free.call(p.x, p.y):
				continue
			var wall := Scenery.floor_distance(v, p.x, p.y, Vector2.INF, Vector2.ZERO)
			var beach := Coast.shore(v, p.x) - p.y
			var near := maxf(exp(wall / 2.5), exp(-beach / 2.0))
			if rng.randf() > 0.12 + 0.88 * near:
				continue
			spots.append([Vector3(p.x, -0.02, p.y), rng.randf_range(0.1, 0.3) * (1.0 + 0.7 * near)])
		return _pebble_node(spots, rng)
	var sp := stream_path(level)
	var pts: PackedVector2Array = sp.pts
	for i in range(4, pts.size() - 4):
		for _k in 2:
			if rng.randf() > 0.6:
				continue
			var dir := (pts[i + 1] - pts[i - 1]).normalized()
			var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var out: float = float(sp.half[i]) + rng.randf_range(-0.5, 1.1)
			var p := pts[i] + side * out + dir * rng.randf_range(-0.25, 0.25)
			if lake_distance(level, p.x, p.y) < LAKE_BANK + 0.3:
				continue   # the river's mouth is under the lake
			var in_water := out < float(sp.half[i]) + 0.2
			var s := rng.randf_range(0.14, 0.34) * (1.25 if in_water else 1.0)
			spots.append([Vector3(p.x, -0.26 if in_water else -0.02, p.y), s])
	# The near shore of the lake.
	for _i in 90:
		var angle := rng.randf_range(PI * 1.1, PI * 1.9)   # the side facing the valley
		var p := lake_point(level, angle, LAKE_WATERLINE + rng.randf_range(-0.5, 1.6))
		if Scenery.floor_distance(v, p.x, p.y, Vector2.INF, Vector2.ZERO) > -0.5:
			continue
		spots.append([Vector3(p.x, -0.05, p.y), rng.randf_range(0.14, 0.4)])
	# Loose stones on the moraine, thickest near the glacier and the valley walls.
	for _i in 420:
		var z := rng.randf_range(float(v.back_z) + 1.0, 30.0)
		var hw: float = v.half_width + maxf(0.0, z - v.flare_z) * v.flare
		var x := rng.randf_range(-hw, hw)
		var wall := Scenery.floor_distance(v, x, z, Vector2.INF, Vector2.ZERO)
		if wall > -0.3 or not free.call(x, z):
			continue
		if rng.randf() > 0.25 + 0.75 * exp(wall / 3.0) and rng.randf() > 0.3:
			continue
		spots.append([Vector3(x, -0.02, z), rng.randf_range(0.1, 0.3) * (1.6 if wall > -2.0 else 1.0)])
	return _pebble_node(spots, rng)


static func _pebble_node(spots: Array, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _pebble_mesh()
	mm.instance_count = spots.size()
	for i in spots.size():
		var s: float = spots[i][1]
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.6, 1.0), s))
		mm.set_instance_transform(i, Transform3D(b, spots[i][0]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pebbles"
	mmi.multimesh = mm
	mmi.material_override = Scenery.rock_material(0.25)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
