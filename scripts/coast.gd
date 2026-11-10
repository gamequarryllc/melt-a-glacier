class_name Coast
extends RefCounted
## The ground of a map by the sea (Frozen Harbor): a strip of shore under the
## mountains instead of a valley floor, with open water in front of it out to
## the horizon. The level's "valley" dictionary says where everything is
## (see Levels.HARBOR): the quay and the cove are flat ground, the sea starts
## at the shore line, and headlands, skerries and the breakwater are rock
## standing in it. Scenery builds the mountains from flat_distance(), Ground
## colours the shore from the same shapes, and the world asks where you can walk.

const SLOPE_FROM := 0.4          # the ground starts to dip this far before the water's edge
const SEA_Y := -0.04
const FAR := 3000.0              # the sea goes on this far
const LAND_WEST := -112.0        # the ground's mesh runs between these (the rest is under the mountains)
const LAND_EAST := 84.0
const LAND_NORTH := -64.0


static func is_coast(level: Dictionary) -> bool:
	return bool(level.valley.get("coast", false))


# =====================================================================================
# Where things are
# =====================================================================================
static func shore(v: Dictionary, x: float) -> float:
	## z of the water's edge at x. Dead straight along the quay, wandering a
	## little beyond it, and bending away north far off, so the coast runs
	## out of sight instead of stopping.
	var c: Vector2 = v.center
	var quay: Array = v.land[0]
	var past := maxf(absf(x - float(quay[0])) - float(quay[2]), 0.0)   # metres past the quay's ends
	var wander := 2.5 * sin(x * 0.085) * minf(past / 12.0, 1.0)
	var far := minf(maxf(absf(x - c.x) - 90.0, 0.0), 200.0)
	return float(v.shore_z) + wander - 0.004 * far * far


static func _oval(s: Array, x: float, z: float) -> float:
	## Metres outside an oval [x, z, radius x, radius z], roughly (negative inside).
	var ex := (x - float(s[0])) / float(s[2])
	var ez := (z - float(s[1])) / float(s[3])
	return (sqrt(ex * ex + ez * ez) - 1.0) * minf(float(s[2]), float(s[3]))


static func _shape(s: Array, x: float, z: float) -> float:
	## Metres outside a patch of ground [x, z, half x, half z, oval?].
	if int(s[4]) == 1:
		return _oval(s, x, z)
	var qx := absf(x - float(s[0])) - float(s[2])
	var qz := absf(z - float(s[1])) - float(s[3])
	return Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0)


static func _mole(v: Dictionary, x: float, z: float) -> float:
	## Metres outside the breakwater's rubble (negative inside it).
	if not v.has("mole"):
		return 1000.0
	var m: Array = v.mole
	var ex := (x - float(m[0])) / float(m[2])
	var ez := (z - float(m[1])) / float(m[3])
	var k := sqrt(ex * ex + ez * ez)
	var angle := atan2(ez, ex)
	var from: float = m[5]
	var to: float = m[6]
	if angle < from - 0.6:
		angle += TAU
	# Past either end it narrows to nothing over a few metres.
	var mean_r := (float(m[2]) + float(m[3])) * 0.5
	var over := maxf(maxf(from - angle, angle - to), 0.0) * mean_r
	return Vector2(absf(k - 1.0) * minf(float(m[2]), float(m[3])), over).length() - float(m[4])


static func rock_distance(v: Dictionary, x: float, z: float) -> float:
	## Metres from the nearest rock standing in the sea (negative inside one).
	var d := _mole(v, x, z)
	for r in v.get("rocks", []):
		d = minf(d, _oval(r, x, z))
	return d


static func land_distance(v: Dictionary, x: float, z: float) -> float:
	## Metres outside the ground you can walk on (negative on it): the flat
	## patches, as far as the water's edge.
	var d := 1000.0
	for s in v.land:
		d = minf(d, _shape(s, x, z))
	return maxf(d, z - shore(v, x))


static func flat_distance(v: Dictionary, x: float, z: float) -> float:
	## Metres outside everything flat, the shore and the sea together
	## (negative on it). Positive is rock: the mountains, the headlands, the
	## skerries and the breakwater.
	var d := shore(v, x) - z          # the sea
	for s in v.land:
		d = minf(d, _shape(s, x, z))
	return maxf(d, -rock_distance(v, x, z))


static func bay_distance(v: Dictionary, x: float, z: float) -> float:
	## Metres outside the sea you can walk on once the pier is open (negative
	## on it): inside the breakwater, clear of the rocks.
	var d := maxf(_oval(v.bay, x, z), shore(v, x) - z)
	return maxf(d, -rock_distance(v, x, z))


static func on_pier(v: Dictionary, x: float, z: float, margin: float = 0.0) -> bool:
	var g: Vector2 = v.gate
	return absf(x - g.x) < 1.3 + margin and z > g.y - 1.5 and z < g.y + float(v.pier) + 1.0 + margin


static func random_land(v: Dictionary, rng: RandomNumberGenerator, margin: float) -> Vector2:
	## A random spot on the walkable ground, at least `margin` from its edge.
	var lo := Vector2(1000.0, 1000.0)
	var hi := Vector2(-1000.0, -1000.0)
	for s in v.land:
		lo = lo.min(Vector2(float(s[0]) - float(s[2]), float(s[1]) - float(s[3])))
		hi = hi.max(Vector2(float(s[0]) + float(s[2]), float(s[1]) + float(s[3])))
	for _t in 40:
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if land_distance(v, p.x, p.y) < -margin:
			return p
	return Vector2.INF


# =====================================================================================
# The ground and the sea
# =====================================================================================
static func floor_node(level: Dictionary) -> MeshInstance3D:
	## The shore as one mesh: flat ground from under the mountains down to
	## the water's edge, then a shelf of shingle sloping away under the sea.
	var v: Dictionary = level.valley
	var xs := PackedFloat32Array()
	var x := LAND_WEST
	while x <= LAND_EAST + 0.01:
		xs.append(x)
		x += 1.0
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idxs := PackedInt32Array()
	# Rows from the back to the sea bed: z offset from the water's edge, and height.
	var offs := [0.0, -SLOPE_FROM, 0.8, 4.2, 9.2]
	var ys := [0.0, 0.0, -0.14, -0.6, -0.9]
	var rows := offs.size()
	for i in xs.size():
		var edge := shore(v, xs[i])
		for r in rows:
			var z: float = LAND_NORTH if r == 0 else edge + float(offs[r])
			verts.append(Vector3(xs[i], ys[r], z))
			var n := Vector3.UP
			if r > 1 and r < rows - 1:
				var slope := (float(ys[r + 1]) - float(ys[r - 1])) / (float(offs[r + 1]) - float(offs[r - 1]))
				n = Vector3(0.0, 1.0, -slope).normalized()
			normals.append(n)
	for i in xs.size() - 1:
		for r in rows - 1:
			var a := i * rows + r
			var b := a + rows
			# Front faces are clockwise seen from above.
			idxs.append_array([a, b, b + 1, a, b + 1, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	Ground.bind(level, mat, "floor")
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func sea(level: Dictionary) -> MeshInstance3D:
	## The sea, from the water's edge to the horizon. Vertex alpha = depth
	## (0 at the shore, 1 out in the deep), as the lake has it.
	var v: Dictionary = level.valley
	var c: Vector2 = v.center
	var reach := Scenery.EXTENT + 8.0        # past the mountains' mesh the sea is all there is
	var xs := PackedFloat32Array([-FAR, -1200.0, -600.0, -400.0])
	var x := c.x - reach - 4.0
	while x < c.x + reach + 4.0:
		xs.append(x)
		x += 2.0 if absf(x - c.x) < 110.0 else 7.0
	xs.append_array(PackedFloat32Array([c.x + reach + 4.0, 400.0, 600.0, 1200.0, FAR]))
	var offs := [-0.7, 2.5, 9.0, 30.0, 260.0, FAR]
	var depths := [0.0, 0.3, 0.75, 1.0, 1.0, 1.0]
	var rows := offs.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for i in xs.size():
		var edge := shore(v, xs[i]) if absf(xs[i] - c.x) <= reach else -FAR
		for r in rows:
			var z: float = FAR if r == rows - 1 else edge + float(offs[r])
			verts.append(Vector3(xs[i], 0.0, z))
			normals.append(Vector3.UP)
			colors.append(Color(1, 1, 1, depths[r]))
	var idxs := PackedInt32Array()
	for i in xs.size() - 1:
		for r in rows - 1:
			var a := i * rows + r
			var b := a + rows
			idxs.append_array([a, b, b + 1, a, b + 1, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-FAR, -1.0, -FAR), Vector3(FAR * 2.0, 2.0, FAR * 2.0))
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = mesh
	mi.position.y = SEA_Y
	mi.material_override = Scenery.water_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
