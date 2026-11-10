class_name Levels
extends RefCounted
## Level descriptions: the shape of each glacier and what's frozen inside it.
## A map is a dictionary like VALLEY (Frozen Harbor is VALLEY with HARBOR_CHANGES).
## Balance.map says which one is being played.
##
## A level has one or more glaciers, melted in order: when one is gone, the
## next one opens up (the valley's village glacier, then the frozen lake).
## Each glacier is its own block of ice (IceField) with its own grid, shape
## and ice layers (Balance.LAYER_SETS). Its finds are Balance.DISCOVERIES
## entries with that glacier's index.

const VALLEY := {
	"name": "The Valley",
	"seed": 20261101,
	"glaciers": [
		{
			"name": "the village glacier",
			"title": "Village glacier",
			"kind": "tongue",           # a tongue of ice down the valley (IceField._height)
			# The box the ice can fill (world metres). Points on its edges are always air.
			"field_min": Vector3(-19.5, 0.0, -30.0),
			"field_max": Vector3(19.5, 13.5, 5.0),
			"res": 0.5,                 # metres between grid points
			"height": 12.0,             # thickness in the middle, behind full_z
			"half_width_back": 16.6,
			"half_width_snout": 13.4,
			"back_z": -28.5,            # its back end (the valley floor goes on behind it)
			"full_z": -14.0,            # full thickness behind this line
			"snout_z": 4.6,             # the toe of the glacier
			"bumps": 0.6,               # metres of lumpiness
			"layers": "valley",         # Balance.LAYER_SETS
			"layer_depth": 1.2,         # metres of ice per layer, from the top down
			"finds_box": [Vector2(-14.0, -26.0), Vector2(14.0, 1.0)],   # where finds may be frozen (x, z)
			# Cracks across the glacier: z of the middle, how far the middle bows
			# downstream, depth, half-width at the top, and how far across they run.
			"crevasses": [
				{"z": -25.5, "bow": 1.2, "depth": 3.2, "width": 0.55, "x0": -11.0, "x1": 9.0},
				{"z": -7.5, "bow": 1.6, "depth": 2.6, "width": 0.5, "x0": -13.0, "x1": -2.5},
				{"z": -6.0, "bow": 1.2, "depth": 2.4, "width": 0.5, "x0": 4.5, "x1": 13.0},
				{"z": -1.8, "bow": 1.0, "depth": 1.8, "width": 0.45, "x0": -9.5, "x1": 7.5},
			],
			# Ice caves where the river goes in at the back and comes out at the
			# snout: tunnels from a to b (x, z), with the arch's half-width and height.
			"caves": [
				{"a": Vector2(-2.7, 4.2), "b": Vector2(-2.2, -4.5), "half": 1.5, "height": 1.7},
				{"a": Vector2(12.2, -30.5), "b": Vector2(11.6, -25.5), "half": 1.4, "height": 1.6},
			],
		},
		{
			# The lake froze solid and disappeared under an ice cap. You can see
			# it from the start, but the gate stays locked until the village is free.
			"name": "the frozen lake",
			"title": "Frozen lake",
			"kind": "dome",             # a round ice cap (IceField._dome_height)
			"field_min": Vector3(-66.0, 0.0, 29.0),
			"field_max": Vector3(66.0, 18.0, 103.0),
			"res": 1.0,                 # it's huge: a coarser grid keeps it quick
			"center": Vector2(0.0, 66.0),
			"radius": Vector2(61.0, 33.0),
			"height": 14.0,
			"edge": 0.5,                # how steep the edge is (smaller = steeper cliffs)
			"wobble": 0.08,             # how far the edge wanders from a perfect oval
			"hills": 2.2,               # big rolls on top
			"bumps": 0.7,
			"layers": "lake",
			"layer_depth": 1.4,
			"worth": 2.0,               # its ice sells for twice as much per hp (see IceField.worth)
			"finds_box": [Vector2(-50.0, 40.0), Vector2(50.0, 92.0)],
			"crevasses": [
				{"z": 52.0, "bow": 3.0, "depth": 4.0, "width": 1.2, "x0": -34.0, "x1": -6.0},
				{"z": 60.0, "bow": -2.5, "depth": 3.5, "width": 1.1, "x0": 10.0, "x1": 38.0},
				{"z": 80.0, "bow": 2.0, "depth": 3.0, "width": 1.0, "x0": -18.0, "x1": 16.0},
			],
			# A goblin pirate fleet froze in with the lake (PirateFleet). Each ship's
			# hull is hollowed out of the ice; its masts poke out of the top. "yaw"
			# turns the bow (which points to -Z) round; keep it to quarter turns so
			# the hollow fits the hull. "bounty" is what the crew pays you for
			# thawing them out.
			"ships": [
				{"name": "The Rusty Gob", "mesh": "Galleon", "pos": Vector3(4.0, 0.0, 50.0), "yaw": 0.0,
					"bounty": 600000.0},
				{"name": "The Soggy Sock", "mesh": "Sloop", "pos": Vector3(-25.0, 0.0, 61.0), "yaw": 0.0,
					"bounty": 150000.0},
				{"name": "The Wet Biscuit", "mesh": "Sloop", "pos": Vector3(27.0, 0.0, 73.0), "yaw": PI,
					"bounty": 300000.0},
			],
		},
	],
	# The valley around the glaciers: a flat floor where you can walk, mountains
	# everywhere else (see Scenery). Distances in metres.
	"valley": {
		"half_width": 24.5,       # the side walls start just past where you can walk (x = ±23)
		"back_z": -37.5,          # the back wall: the glacier ends at -29.5, so you can walk round it
		"front_z": 64.0,          # the valley floor ends here (the lake reaches further)
		"flare_z": 21.0,          # past here the valley opens out toward the lake
		"flare": 1.0,             # metres wider per metre further out
		"lake": [0.0, 66.0, 70.0, 38.0],   # middle x, middle z, radius across, radius along
		"peaks": 1.0,             # mountain height scale
		"snow_line": 17.0,
		# The fence across the valley that keeps you off the lake until the village is free.
		"gate_z": 21.0,
		# The river. It starts as a waterfall off the snowfield on the back wall,
		# runs under the glacier (down the east side of the village, then across
		# in front of the square), comes out of an ice cave at the snout and
		# goes on down to the lake. The first point is hidden in the foot of the
		# back wall; the second is the plunge pool.
		"stream": [Vector2(12.8, -39.8), Vector2(12.6, -36.2), Vector2(12.0, -31.0), Vector2(11.4, -24.0),
				Vector2(11.1, -16.5), Vector2(10.8, -11.0), Vector2(7.0, -7.0), Vector2(0.5, -5.2),
				Vector2(-2.3, -2.0), Vector2(-2.6, 2.5), Vector2(-4.0, 8.0), Vector2(-8.0, 13.5),
				Vector2(-10.0, 19.0), Vector2(-11.5, 25.0), Vector2(-13.5, 33.0)],
		"falls_top": Vector2(13.6, -47.5),   # where the waterfall starts, up on the back wall
		# Trodden paths (bare earth): shed door to the gate and on to the lake,
		# and up to the glacier and the village under it.
		"paths": [
			[Vector2(8.7, 11.5), Vector2(5.5, 12.6), Vector2(2.0, 15.2), Vector2(0.3, 18.0), Vector2(0.0, 21.0),
				Vector2(-0.5, 25.0), Vector2(0.5, 29.5)],
			[Vector2(2.0, 15.2), Vector2(1.8, 9.5), Vector2(1.0, 4.0), Vector2(1.6, -3.0), Vector2(1.0, -9.0)],
		],
	},
}


# Frozen Harbor: the same shape of valley (a fjord now, with the sea where
# the lake was), but the ice is taller and much harder, a fishing town is
# frozen under it with its lighthouse poking out of the top, and the whole
# bay froze solid with the fishing fleet in it. It's built from VALLEY with
# these changes (see harbor()).
const HARBOR_CHANGES := {
	"name": "Frozen Harbor",
	"seed": 20261202,
	"town": "harbor",
	"glaciers": [
		{
			"name": "the harbour glacier",
			"title": "Harbour glacier",
			"field_max": Vector3(19.5, 17.5, 5.5),
			"res": 0.75,                # the harbour's tools are big: a coarser grid keeps phones quick
			"height": 16.0,             # a third taller than the village glacier
			"half_width_back": 17.0,
			"half_width_snout": 14.0,
			"snout_z": 5.0,
			"bumps": 0.8,
			"layers": "harbor",
			"layer_depth": 1.6,
			"crevasses": [
				{"z": -24.0, "bow": -1.4, "depth": 3.6, "width": 0.6, "x0": -12.0, "x1": 10.0},
				{"z": -9.0, "bow": 1.8, "depth": 3.0, "width": 0.55, "x0": -14.0, "x1": -1.0},
				{"z": -4.5, "bow": 1.4, "depth": 2.6, "width": 0.5, "x0": 3.0, "x1": 14.0},
			],
		},
		{
			"name": "the frozen bay",
			"title": "Frozen bay",
			"field_max": Vector3(66.0, 23.0, 103.0),
			"height": 20.0,
			"hills": 3.0,
			"layers": "bay",
			"layer_depth": 2.0,
			"worth": 2.0,
			"crevasses": [
				{"z": 48.0, "bow": -2.5, "depth": 4.5, "width": 1.3, "x0": -30.0, "x1": 4.0},
				{"z": 64.0, "bow": 3.0, "depth": 4.0, "width": 1.2, "x0": 8.0, "x1": 40.0},
				{"z": 82.0, "bow": -2.0, "depth": 3.5, "width": 1.0, "x0": -24.0, "x1": 12.0},
			],
			# The fishing fleet, frozen mid-catch (PirateFleet.HULLS).
			"ships": [
				{"name": "The Salty Herring", "mesh": "Trawler", "pos": Vector3(-3.0, 0.0, 52.0), "yaw": 0.0,
					"bounty": 3500000000.0},
				{"name": "The Lucky Cod", "mesh": "Skiff", "pos": Vector3(-27.0, 0.0, 66.0), "yaw": PI,
					"bounty": 900000000.0},
				{"name": "The Wobbly Whelk", "mesh": "Skiff", "pos": Vector3(25.0, 0.0, 58.0), "yaw": 0.0,
					"bounty": 1800000000.0},
				{"name": "The Big Kipper", "mesh": "Trawler", "pos": Vector3(14.0, 0.0, 80.0), "yaw": PI,
					"bounty": 6600000000.0},
			],
		},
	],
	"valley": {"snow_line": 12.0, "tree_line": 8.0},
	# How it looks: an arctic evening with the northern lights out.
	"look": {
		"sky_top": Color(0.13, 0.2, 0.42), "sky_horizon": Color(0.98, 0.74, 0.6), "sky_ground": Color(0.3, 0.32, 0.42),
		"cloud_light": Color(1.0, 0.86, 0.8), "cloud_shade": Color(0.58, 0.55, 0.72), "cover": 0.3, "aurora": 1.0,
		"sun_color": Color(1.0, 0.84, 0.7), "sun_energy": 0.8, "sun_dir": Vector3(-0.7, -0.42, -0.55),
		"fog": Color(0.8, 0.76, 0.86), "ambient": Color(0.6, 0.6, 0.7),
		"water_shallow": Color(0.2, 0.55, 0.62), "water_deep": Color(0.04, 0.22, 0.4),
	},
	# What the signs and pop-ups say.
	"story": {
		"gate_closed": "🔒 THE FROZEN BAY\nClosed until the\nharbour is free",
		"gate_open": "THE FROZEN BAY\nThe gate's open.\nGo melt it!",
		"stage_title": "The harbour is free!",
		"stage_body": "The fishermen are back on the quay, and your helpers are off for a well-earned fish supper.\n\nBut look past the fence. The whole bay froze solid, with the fleet still in it, and the gate is open now.\nHire a new crew at the shed and go melt %s!",
		"stage_button": "To the bay!",
		"ending": "The last of the sea ice drifted away and the boats can sail again.\nThe harbour is open!",
		"walk": "Walk around the harbour",
		"ship_freed": "⚓ %s is free! The crew pays you %s meltwater",
		"done_label": "The harbour is open!",
	},
}

# The valley's own words, for maps that don't change them.
const VALLEY_STORY := {
	"gate_closed": "🔒 THE FROZEN LAKE\nClosed until the\nvillage is free",
	"gate_open": "THE FROZEN LAKE\nThe gate's open.\nGo melt it!",
	"stage_title": "The village is free!",
	"stage_body": "Everyone's home again, and your helpers have earned a holiday: they're partying in the village square.\n\nBut look past the fence. The whole lake froze solid, and the gate is open now.\nHire a new crew at the shed and go melt %s!",
	"stage_button": "To the lake!",
	"ending": "The last chunk dripped away and the lake is free.\nSummer is back!",
	"walk": "Walk around the village",
	"ship_freed": "☠️ %s is free! The goblins pay you %s meltwater",
	"done_label": "Summer is back!",
}

static var _harbor: Dictionary = {}


static func harbor() -> Dictionary:
	if _harbor.is_empty():
		_harbor = VALLEY.duplicate(true)
		for k in HARBOR_CHANGES:
			if k == "glaciers":
				continue
			if k == "valley":
				for vk in HARBOR_CHANGES.valley:
					_harbor.valley[vk] = HARBOR_CHANGES.valley[vk]
			else:
				_harbor[k] = HARBOR_CHANGES[k]
		for g in HARBOR_CHANGES.glaciers.size():
			var spec: Dictionary = _harbor.glaciers[g]
			spec.erase("ships")
			for gk in HARBOR_CHANGES.glaciers[g]:
				spec[gk] = HARBOR_CHANGES.glaciers[g][gk]
	return _harbor


static func current() -> Dictionary:
	return harbor() if Balance.map == "harbor" else VALLEY


static func story(key: String) -> String:
	return str(current().get("story", VALLEY_STORY).get(key, VALLEY_STORY[key]))


static func look(key: String, fallback):
	return current().get("look", {}).get(key, fallback)


static func map_index(key: String) -> int:
	for i in MAPS.size():
		if str(MAPS[i].get("key", "")) == key:
			return i
	return 0


## Every map, in the order they come out. Only the first is built so far; the
## rest are on the level menu after the ending, stamped COMING SOON, to show
## what's on the way (LevelMenu). "ready" maps can be played.
const MAPS := [
	{"name": "Alpine Valley", "key": "valley", "icon": "🏔️", "ready": true,
		"blurb": "A mountain village under a glacier, and a whole frozen lake behind it."},
	{"name": "Frozen Harbor", "key": "harbor", "icon": "⚓", "ready": true, "after": "valley",
		"blurb": "A fishing town and its whole fleet, frozen mid-catch. Bring your Orbital Mirror."},
	{"name": "Arctic Research Base", "icon": "📡",
		"blurb": "The scientists froze along with their experiments. Careful what you thaw."},
	{"name": "Ice Cave City", "icon": "💎",
		"blurb": "A whole city deep under the ice, lit by glowing crystals."},
	{"name": "Mammoth Graveyard", "icon": "🦣",
		"blurb": "The herd never made it out of the Ice Age. Until now."},
	{"name": "Frozen Volcano", "icon": "🌋",
		"blurb": "Fire trapped under the ice. Is this where Kevin comes from?"},
	{"name": "The Polar Cap", "icon": "🧭",
		"blurb": "The biggest ice in the world. The very last glacier."},
]
