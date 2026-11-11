class_name Balance
extends RefCounted
## All tunable game numbers for the first-person glacier game live here.
## Pacing: tests/pacing.gd plays a whole run and prints how long each part took.

const WORLD_SEED := 20261101

# Ice layers by depth below a glacier's original surface (0 = the top), each
# layer_depth thick (see Levels). Deeper ice is older and much harder (hp),
# and worth that much more meltwater per m³: each new tool opens up the next
# layer or two, and the hair dryer barely scratches Glacial Ice. Each glacier
# names its set; the frozen lake's ice comes in colours you won't see in the valley.
const LAYER_SETS = {
	"valley": [
		{"name": "Fresh Snow", "hp": 1.0, "color": Color(0.88, 0.94, 1.0)},
		{"name": "Crunchy Firn", "hp": 2.5, "color": Color(0.78, 0.89, 0.99)},
		{"name": "Slushy Ice", "hp": 6.0, "color": Color(0.66, 0.84, 0.98)},
		{"name": "Blue Ice", "hp": 15.0, "color": Color(0.5, 0.76, 0.96)},
		{"name": "Old Blue Ice", "hp": 40.0, "color": Color(0.38, 0.67, 0.93)},
		{"name": "Glacial Ice", "hp": 100.0, "color": Color(0.28, 0.57, 0.88)},
		{"name": "Ancient Ice", "hp": 250.0, "color": Color(0.2, 0.46, 0.8)},
		{"name": "Ice Age Ice", "hp": 500.0, "color": Color(0.16, 0.37, 0.72)},
		{"name": "Dinosaur Ice", "hp": 1100.0, "color": Color(0.17, 0.29, 0.64)},
		{"name": "The Last Chunk", "hp": 2500.0, "color": Color(0.2, 0.22, 0.55)},
	],
	"lake": [
		{"name": "Lake Snow", "hp": 10.0, "color": Color(0.9, 0.96, 1.0)},
		{"name": "Hoarfrost", "hp": 30.0, "color": Color(0.8, 0.95, 0.98)},
		{"name": "Clear Lake Ice", "hp": 90.0, "color": Color(0.62, 0.9, 0.95)},
		{"name": "Turquoise Ice", "hp": 250.0, "color": Color(0.36, 0.82, 0.86)},
		{"name": "Jade Ice", "hp": 700.0, "color": Color(0.3, 0.72, 0.62)},
		{"name": "Black Ice", "hp": 1500.0, "color": Color(0.22, 0.32, 0.4)},
		{"name": "Moonstone Ice", "hp": 4500.0, "color": Color(0.6, 0.58, 0.82)},
		{"name": "Midnight Ice", "hp": 11000.0, "color": Color(0.3, 0.24, 0.6)},
		{"name": "Starlight Ice", "hp": 26000.0, "color": Color(0.42, 0.22, 0.62)},
		{"name": "The Lake's Heart", "hp": 60000.0, "color": Color(0.62, 0.2, 0.5)},
	],
	# Frozen Harbor: sea ice, salty and green near the top, then deep-sea blues.
	"harbor": [
		{"name": "Sea Snow", "hp": 6160.0, "color": Color(0.9, 0.96, 0.98)},
		{"name": "Salty Firn", "hp": 15400.0, "color": Color(0.78, 0.93, 0.95)},
		{"name": "Brine Slush", "hp": 36960.0, "color": Color(0.62, 0.88, 0.9)},
		{"name": "Seaglass Ice", "hp": 92400.0, "color": Color(0.48, 0.84, 0.8)},
		{"name": "Kelp Ice", "hp": 246400.0, "color": Color(0.36, 0.7, 0.6)},
		{"name": "Deep Harbour Ice", "hp": 616000.0, "color": Color(0.24, 0.55, 0.66)},
		{"name": "Whale-Song Ice", "hp": 1540000.0, "color": Color(0.2, 0.42, 0.7)},
		{"name": "Kraken Ice", "hp": 3080000.0, "color": Color(0.22, 0.3, 0.62)},
		{"name": "Shipwreck Ice", "hp": 6776000.0, "color": Color(0.18, 0.22, 0.48)},
		{"name": "The Old Anchor", "hp": 15400000.0, "color": Color(0.14, 0.16, 0.36)},
	],
	# ...and the bay, frozen under the northern lights: the deeper you go the
	# stranger the colours get.
	"bay": [
		{"name": "Pack Ice", "hp": 67200.0, "color": Color(0.92, 0.97, 1.0)},
		{"name": "Sea Frost", "hp": 201600.0, "color": Color(0.82, 0.95, 1.0)},
		{"name": "Iceberg Blue", "hp": 604800.0, "color": Color(0.55, 0.82, 0.98)},
		{"name": "Narwhal Ice", "hp": 1680000.0, "color": Color(0.42, 0.74, 0.92)},
		{"name": "Aurora Ice", "hp": 3292800.0, "color": Color(0.36, 0.88, 0.62)},
		{"name": "Abyss Ice", "hp": 7056000.0, "color": Color(0.14, 0.3, 0.42)},
		{"name": "Pearl Ice", "hp": 21168000.0, "color": Color(0.9, 0.82, 0.92)},
		{"name": "Leviathan Ice", "hp": 51744000.0, "color": Color(0.46, 0.22, 0.6)},
		{"name": "Moon-Tide Ice", "hp": 122304000.0, "color": Color(0.82, 0.3, 0.7)},
		{"name": "The Ocean's Heart", "hp": 282240000.0, "color": Color(0.95, 0.42, 0.3)},
	],
}

# --- Player -------------------------------------------------------------------------
const WALK_SPEED := 4.5         # m/s
const JUMP_VELOCITY := 6.6      # enough to hop up about 1.2 m
const LOOK_SENSITIVITY_TOUCH := 0.0031   # radians per pixel of finger drag
const LOOK_SENSITIVITY_MOUSE := 0.0025   # radians per pixel of mouse motion

# Jetpack: tap JUMP to hop, keep holding it to fly. Fuel refills on the ground.
const JET_ACCEL := 34.0          # m/s^2 of thrust (gravity pulls 18)
const JET_MAX_RISE := 5.5        # fastest climb, m/s
const JET_FUEL := 2.2            # seconds of thrust on a full tank (upgradable)
const JET_REFILL := 0.8          # tanks per second while standing on something
const JET_HOLD_DELAY := 0.16     # hold JUMP this long before the jetpack fires
const JET_CEILING := 24.0        # can't fly higher than this

# --- Tools (bought in order at the shed) ------------------------------------------------
# power: hp per second at the centre of the heat zone; radius / range in metres.
const VALLEY_TOOLS = [
	{"name": "Hair Dryer", "fx": "hair_dryer", "model": "Tool0", "icon": "💨", "power": 2.0, "radius": 0.9, "range": 4.5, "cost": 0.0,
		"color": Color(0.95, 0.5, 0.7), "desc": "Borrowed from your aunt."},
	{"name": "Heat Lamp", "fx": "heat_lamp", "model": "Tool1", "icon": "💡", "power": 6.0, "radius": 1.15, "range": 5.5, "cost": 120.0,
		"color": Color(1.0, 0.82, 0.3), "desc": "Keeps fries and glaciers warm."},
	{"name": "Blowtorch", "fx": "blowtorch", "model": "Tool2", "icon": "🔥", "power": 18.0, "radius": 1.4, "range": 6.5, "cost": 4000.0,
		"color": Color(0.35, 0.55, 0.95), "desc": "Crème brûlée, but it's a glacier."},
	{"name": "Flamethrower", "fx": "flamethrower", "model": "Tool3", "icon": "🐉", "power": 55.0, "radius": 1.8, "range": 9.0, "cost": 100000.0,
		"color": Color(0.9, 0.35, 0.15), "desc": "Probably needs a permit."},
	{"name": "Lava Hose", "fx": "lava_hose", "model": "Tool4", "icon": "🌋", "power": 160.0, "radius": 2.3, "range": 11.0, "cost": 3000000.0,
		"color": Color(0.85, 0.2, 0.1), "desc": "Garden hose, but lava."},
	{"name": "Orbital Mirror", "fx": "orbital_mirror", "model": "Tool5", "icon": "🛰️", "power": 450.0, "radius": 3.2, "range": 45.0, "cost": 30000000.0,
		"color": Color(0.85, 0.9, 1.0), "desc": "A magnifying glass in space."},
]

# Frozen Harbor's tools. You start with the Orbital Mirror you finished the
# valley with, and every tool after it is sillier and stronger than the last.
# Their heat zones hardly grow (they start big), so the power has to grow
# faster than the valley's: each tool melts about 4-5x as much as the one
# before, like in the valley. The Orbital Mirror melts about 2800x as much as
# the hair dryer; prices, ice and finds are about 6200x the valley's, and the
# bay's ice another 1.1x on top, so the harbour lasts longer than the valley
# (see Balance.MAPS and tests/pacing.gd map=harbor).
const HARBOR_TOOLS = [
	{"name": "Orbital Mirror", "fx": "orbital_mirror", "model": "Tool5", "icon": "🛰️", "power": 450.0, "radius": 3.2, "range": 45.0,
		"cost": 0.0, "color": Color(0.85, 0.9, 1.0), "desc": "You brought it from the valley."},
	{"name": "Dragon Puppet", "fx": "dragon_puppet", "model": "Tool6", "icon": "🐲", "power": 2000.0, "radius": 3.4, "range": 34.0,
		"cost": 739200.0, "color": Color(0.3, 0.72, 0.36), "desc": "A sock puppet. A real dragon. Don't ask."},
	{"name": "Lightning Rod", "fx": "lightning_rod", "model": "Tool7", "icon": "⚡", "power": 7500.0, "radius": 3.6, "range": 50.0,
		"cost": 24640000.0, "color": Color(0.32, 0.45, 0.95), "desc": "Calls down a storm. Wear rubber boots."},
	{"name": "Meteor Remote", "fx": "meteor_remote", "model": "Tool8", "icon": "☄️", "power": 33000.0, "radius": 3.9, "range": 60.0,
		"cost": 616000000.0, "color": Color(0.95, 0.45, 0.15), "desc": "One button. Many meteors. No refunds."},
	{"name": "Pocket Sun", "fx": "pocket_sun", "model": "Tool9", "icon": "☀️", "power": 135000.0, "radius": 4.2, "range": 55.0,
		"cost": 18480000000.0, "color": Color(1.0, 0.75, 0.15), "desc": "A whole star in a lantern. Mind your eyebrows."},
	{"name": "Supernova in a Jar", "fx": "supernova_jar", "model": "Tool10", "icon": "🌌", "power": 600000.0, "radius": 4.6, "range": 70.0,
		"cost": 184800000000.0, "color": Color(0.7, 0.35, 0.95), "desc": "Shake well. Point away from face."},
]

# Shed upgrades. Effect = 1 + per_level * level. Cost = base * growth^level.
# Heat Output keeps going past its first 25 levels ("overdrive"): each level
# from over_from up multiplies the heat by over_mult instead, and its price
# goes up by over_growth. Those cost hundreds of millions, so they only come
# into play at the bottom of the frozen lake, where everything else is bought
# and the ice is at its hardest (Alex: the end dragged with nothing left to
# buy). Income grows about as fast as their price, so there's another one to
# buy every couple of minutes until the lake is free.
const BASE_UPGRADES = [
	{"key": "heat", "name": "Heat Output", "icon": "🌡️", "base": 25.0, "growth": 1.85, "per_level": 0.25, "max": 35,
		"over_from": 25, "over_mult": 1.3, "over_growth": 1.5,
		"desc": "+25% melting power", "over_desc": "Overdrive! x1.3 melting power"},
	{"key": "nozzle", "name": "Wider Nozzle", "icon": "📏", "base": 100.0, "growth": 2.8, "per_level": 0.07, "max": 10,
		"desc": "+7% heat zone size"},
	{"key": "reach", "name": "Longer Reach", "icon": "🎯", "base": 40.0, "growth": 1.7, "per_level": 0.12, "max": 12,
		"desc": "+12% melting range"},
	{"key": "sell", "name": "Steam Sell", "icon": "💧", "base": 100.0, "growth": 1.9, "per_level": 0.15, "max": 20,
		"desc": "+15% meltwater per block"},
	{"key": "boots", "name": "Crampon Boots", "icon": "🥾", "base": 50.0, "growth": 2.2, "per_level": 0.1, "max": 8,
		"desc": "+10% walking speed"},
	{"key": "jet", "name": "Bigger Fuel Tank", "icon": "🚀", "base": 60.0, "growth": 2.1, "per_level": 0.35, "max": 8,
		"desc": "+35% jetpack flying time"},
]

# Helpers melt on their own. Penguins and the sauna crew waddle around on the
# ice; the volcano lobs lava bombs. power = hp x m³ of ice each one melts per
# second (water per second at x1 sell), less on soft snow where heat is wasted.
# There's only one Kevin: you adopt him, then each time you buy him again he
# goes up a level (to max_level) and throws bigger lava bombs, more often.
# Every level adds `power`, so the count in GameState.helper_counts is his level.
const HELPER_GROWTH := 1.2
const BASE_HELPERS = [
	{"key": "penguin", "name": "Penguin with Tiny Torch", "icon": "🐧", "power": 0.5, "base": 30.0,
		"desc": "Waddles around melting the surface."},
	{"key": "sauna", "name": "Sauna Crew", "icon": "🧖", "power": 6.0, "base": 600.0,
		"desc": "Very relaxed. Very hot."},
	{"key": "volcano", "name": "Kevin the Volcano", "icon": "🌋", "power": 150.0, "base": 25000.0, "max_level": 15,
		"desc": "Your very own volcano. He lobs lava bombs at the ice."},
]
const MAX_VISIBLE_WALKERS := 18   # per helper type; more helpers just work harder
# When the village is free your helpers retire and you hire a new crew for the
# frozen lake, at the same prices (Alex: keep everything else the same).

# How special a find is. Rarer finds get a bigger reveal (more shards, a
# brighter flash) and their colour on the name tag, the card and the shelf.
const RARITIES = [
	{"name": "Common", "color": Color(0.62, 0.66, 0.7)},
	{"name": "Uncommon", "color": Color(0.36, 0.74, 0.34)},
	{"name": "Rare", "color": Color(0.27, 0.56, 0.95)},
	{"name": "Epic", "color": Color(0.67, 0.38, 0.92)},
	{"name": "Legendary", "color": Color(1.0, 0.66, 0.12)},
]

# Buried things, frozen at a depth (layer) in one of the glaciers (0 = the
# village glacier, 1 = the frozen lake). Each sells for a burst of meltwater.
# rarity: an index into RARITIES. model: which model in models/finds.glb
# (FindN, see World.find_mesh) when it isn't the same number as the find.
const VALLEY_DISCOVERIES = [
	{"name": "Lost Mitten", "icon": "🧤", "glacier": 0, "layer": 1, "rarity": 0, "value": 30.0, "flavor": "Still damp. Somehow."},
	{"name": "Frozen Pizza", "icon": "🍕", "glacier": 0, "layer": 2, "rarity": 0, "value": 150.0, "flavor": "Best before 1987."},
	{"name": "Mixtape", "icon": "📼", "glacier": 0, "layer": 2, "rarity": 1, "value": 200.0, "flavor": "Side B is all whale songs."},
	{"name": "Lost Snowmobile", "icon": "🛷", "glacier": 0, "layer": 3, "rarity": 1, "value": 700.0, "flavor": "Keys still in it."},
	{"name": "Viking Helmet", "icon": "🪖", "glacier": 0, "layer": 4, "model": 5, "rarity": 2, "value": 2000.0, "flavor": "No horns. Historians were right."},
	{"name": "1970s Caveman", "icon": "🕺", "glacier": 0, "layer": 5, "model": 6, "rarity": 2, "value": 4000.0, "flavor": "Thawed out mid-dance move."},
	{"name": "Message in a Bottle", "icon": "🍾", "glacier": 0, "layer": 5, "model": 9, "rarity": 1, "value": 4500.0, "flavor": "It says 'help, cold'."},
	{"name": "Yeti's Phone", "icon": "📱", "glacier": 0, "layer": 6, "model": 8, "rarity": 3, "value": 10000.0, "flavor": "4,812 unread messages."},
	{"name": "Frozen Mammoth", "icon": "🦣", "glacier": 0, "layer": 7, "model": 4, "rarity": 3, "value": 20000.0, "flavor": "He looks annoyed."},
	{"name": "Prehistoric Fish", "icon": "🐟", "glacier": 0, "layer": 8, "model": 7, "rarity": 3, "value": 35000.0, "flavor": "Do not microwave."},
	{"name": "Dinosaur Egg", "icon": "🥚", "glacier": 0, "layer": 9, "rarity": 4, "value": 70000.0, "flavor": "It's warm now. Uh oh."},
	{"name": "Ice Skater", "icon": "⛸️", "glacier": 1, "layer": 1, "rarity": 1, "value": 8000.0, "flavor": "Mid-spin since 1952. Very dizzy."},
	{"name": "Rowboat", "icon": "🚣", "glacier": 1, "layer": 2, "rarity": 1, "value": 25000.0, "flavor": "Someone really wanted to go fishing."},
	{"name": "Pirate Treasure", "icon": "💰", "glacier": 1, "layer": 3, "rarity": 2, "value": 80000.0, "flavor": "Wrong ocean. Very wrong ocean."},
	{"name": "Frozen Whale", "icon": "🐋", "glacier": 1, "layer": 5, "rarity": 3, "value": 200000.0, "flavor": "Nobody knows how he got into a lake."},
	{"name": "Lake Monster", "icon": "🦕", "glacier": 1, "layer": 6, "rarity": 3, "value": 500000.0, "flavor": "Real. Shy. Would like a towel."},
	{"name": "Crashed UFO", "icon": "🛸", "glacier": 1, "layer": 8, "rarity": 4, "value": 3000000.0, "flavor": "They came for the ice. They stayed."},
	{"name": "The Sun's Lost Ray", "icon": "🌟", "glacier": 1, "layer": 9, "rarity": 4, "value": 8000000.0, "flavor": "So that's where summer went."},
]

# Frozen Harbor's finds: 0 = the harbour town's glacier, 1 = the frozen bay.
# model: FindN in models/finds.glb (the harbour's are Find18 on).
const HARBOR_DISCOVERIES = [
	{"name": "Rubber Duck Captain", "icon": "🦆", "glacier": 0, "layer": 1, "model": 18, "rarity": 0, "value": 185000.0, "flavor": "Still on duty. Still squeaks."},
	{"name": "Lobster in a Bow Tie", "icon": "🦞", "glacier": 0, "layer": 2, "model": 19, "rarity": 1, "value": 1100000.0, "flavor": "Dressed for a party in 1904."},
	{"name": "Diving Helmet", "icon": "🤿", "glacier": 0, "layer": 3, "model": 20, "rarity": 1, "value": 4180000.0, "flavor": "Someone's humming in there."},
	{"name": "Treasure Map", "icon": "🗺️", "glacier": 0, "layer": 4, "model": 21, "rarity": 2, "value": 12320000.0, "flavor": "X marks this exact glacier."},
	{"name": "Mermaid's Guitar", "icon": "🎸", "glacier": 0, "layer": 5, "model": 22, "rarity": 2, "value": 26400000.0, "flavor": "Only plays sea shanties."},
	{"name": "Robot Seagull", "icon": "🤖", "glacier": 0, "layer": 6, "model": 23, "rarity": 3, "value": 61600000.0, "flavor": "Steals chips. Very efficiently."},
	{"name": "Frozen Narwhal", "icon": "🦄", "glacier": 0, "layer": 7, "model": 24, "rarity": 3, "value": 123200000.0, "flavor": "The unicorn of the sea. Grumpy."},
	{"name": "Golden Anchor", "icon": "⚓", "glacier": 0, "layer": 9, "model": 25, "rarity": 4, "value": 418000000.0, "flavor": "It held the whole harbour still."},
	{"name": "Pirate Parrot", "icon": "🦜", "glacier": 1, "layer": 1, "model": 26, "rarity": 1, "value": 48400000.0, "flavor": "Says 'cold' in nine languages."},
	{"name": "Yellow Submarine", "icon": "🟡", "glacier": 1, "layer": 3, "model": 27, "rarity": 2, "value": 484000000.0, "flavor": "Periscope up. Crew asleep."},
	{"name": "Giant Pearl", "icon": "🦪", "glacier": 1, "layer": 4, "model": 28, "rarity": 3, "value": 990000000.0, "flavor": "The oyster is fine. Just tired."},
	{"name": "The Kraken", "icon": "🦑", "glacier": 1, "layer": 6, "model": 29, "rarity": 3, "value": 3080000000.0, "flavor": "Eight arms, all waving hello."},
	{"name": "Mermaid Throne", "icon": "🔱", "glacier": 1, "layer": 8, "model": 30, "rarity": 4, "value": 18480000000.0, "flavor": "The queen went out for snacks."},
	{"name": "A Frozen Comet", "icon": "☄️", "glacier": 1, "layer": 9, "model": 31, "rarity": 4, "value": 48400000000.0, "flavor": "Fell in the sea. Still fizzing."},
]

# --- Boosts, ads -----------------------------------------------------------------------
# Nothing melts while you're away: it's a game you play in a sitting.
const BOOST_DURATION := 300.0          # "watch an ad for 2x heat for 5 min"
const BOOST_MULT := 2.0
const PERMANENT_MULT := 2.0            # from the "Remove ads + permanent 2x" IAP
const INTERSTITIAL_COOLDOWN := 240.0
const INTERSTITIAL_MIN_PROGRESS := 0.15  # no interstitials before 15% of the ice is gone
const HELPER_RUSH_DURATION := 180.0    # "watch an ad: helpers work 3x for 3 min"
const HELPER_RUSH_MULT := 3.0
# "Double your water" pays your water again, up to this many minutes of your
# recent income (so saving up for ages doesn't turn one ad into a whole tool).
const DOUBLE_WATER_MINUTES := 4.0
const DOUBLE_WATER_MIN := 100.0        # not worth an ad below this

# Ad offers: now and then a paper tag swings down under the catalogue button
# offering one of the rewards above for a short ad. Players of idle games hate
# being nagged, so offers are rare, never block play, go away on their own,
# and come round less often the more of them you let pass.
const OFFER_FIRST_AFTER := 150.0       # seconds of play before the first one
const OFFER_GAP := 200.0               # seconds between one offer going and the next
const OFFER_GAP_MAX := 480.0           # ...growing up to this as offers are ignored
const OFFER_GAP_GROWTH := 1.5
const OFFER_LIFETIME := 40.0           # how long a tag stays up
const AD_REWARDS = {
	"double_water": {"icon": "💧", "title": "Double your water", "placement": "double_water"},
	"heat_rush": {"icon": "🔥", "title": "2x heat for 5 min", "placement": "boost_2x_heat"},
	"helper_rush": {"icon": "🐧", "title": "Helpers work 3x for 3 min", "placement": "helper_rush"},
}


# --- Maps ----------------------------------------------------------------------------
# What changes from one map to the next (see Levels for each map's shape).
# Upgrades and helpers are the same on every map, with prices times `scale`
# and helpers' power times `helper_power`. Frozen Harbor: its tools melt about
# 2800x as much as the valley's, so helpers do too, and everything costs about
# 6200x as much, so it takes a good while longer (tests/pacing.gd map=harbor).
const MAPS = {
	"valley": {"tools": VALLEY_TOOLS, "finds": VALLEY_DISCOVERIES, "scale": 1.0},
	"harbor": {"tools": HARBOR_TOOLS, "finds": HARBOR_DISCOVERIES, "scale": 6200.0, "helper_power": 2800.0},
}

# The map being played (Levels.use() sets them): GameState, the shed and the
# HUD read these as if they were plain constants.
static var map := "valley"
static var scale := 1.0
static var TOOLS: Array = VALLEY_TOOLS
static var DISCOVERIES: Array = VALLEY_DISCOVERIES
static var UPGRADES: Array = BASE_UPGRADES
static var HELPERS: Array = BASE_HELPERS


static func use_map(key: String) -> void:
	if not MAPS.has(key):
		key = "valley"
	var m: Dictionary = MAPS[key]
	map = key
	scale = float(m.scale)
	TOOLS = m.tools
	DISCOVERIES = m.finds
	UPGRADES = []
	for u in BASE_UPGRADES:
		var c: Dictionary = u.duplicate()
		c.base = float(u.base) * scale
		UPGRADES.append(c)
	HELPERS = []
	for h in BASE_HELPERS:
		var c: Dictionary = h.duplicate()
		c.base = float(h.base) * scale
		c.power = float(h.power) * float(m.get("helper_power", scale))
		HELPERS.append(c)


static func rarity(d: int) -> Dictionary:
	return RARITIES[int(DISCOVERIES[d].get("rarity", 0))]


static func finds_in(glacier: int) -> Array:
	## Indices into DISCOVERIES frozen in this glacier.
	var out: Array = []
	for d in DISCOVERIES.size():
		if int(DISCOVERIES[d].glacier) == glacier:
			out.append(d)
	return out
