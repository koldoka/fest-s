-- 1. pálya: Kisváros főtérrel, városfallal körülvéve.
--
--   Minden a falon belül van (440 × 440 stud). Az utcák kanyarognak, a házak az utcák mentén sorakoznak
--   (Kit.streetRow), a háztömbök belsejét és minden üres helyet a Kit.fill tölt ki: veteményesek, gyümölcsfák,
--   fészerek, parkok, udvarok, termőföldek. A festéktartályok véletlen helyeken jelennek meg (Kit.tankSpot).
--
--                 északi kapu
--                     |
--        dűlő ----- északi utca ------ közköz ---- híd ---- keleti park (tó, pavilon)
--          |          |                                  |
--   nyugati kapu -- fő utca -- FŐTÉR (templom, városháza) -- utca -- híd -- keleti utca -- keleti kapu
--          |          |              |                              |
--     kertes utca     |          déli utca ---- köz ---- rakpart    terasz (kilátótorony)
--          |          |              |                              |
--   szélmalmos domb   +----- kertes utca                        tanyák, földek
--                                    |
--                               déli kapu
--
-- Koordináták: X kelet felé, Z dél felé nő (észak = -Z). Felszínek: fű 0, utcák 0.2, terek 0.25, folyómeder -3.

local Level = {}

Level.seed = 11

-- A térkép (M) által mutatott terület: x0, z0, x1, z1
Level.bounds = { -228, -228, 228, 228 }

-- Kerületek (PvP): név és téglalapok { x0, z0, x1, z1 }. Minden ház abba a kerületbe tartozik, amelyik
-- téglalapjába esik (ha egyikbe sem, a legközelebbibe).
Level.districts = {
	{ name = "Market Square", rects = { { -100, -60, 20, 40 } } },
	{ name = "North Gate", rects = { { -220, -220, -85, -60 } } },
	{ name = "Old Quarter", rects = { { -85, -220, 55, -60 } } },
	{ name = "West End", rects = { { -220, -60, -100, 100 } } },
	{ name = "Windmill Farm", rects = { { -220, 100, -100, 220 } } },
	{ name = "South Lanes", rects = { { -100, 40, 55, 130 }, { 20, -60, 55, 40 } } },
	{ name = "Garden Lanes", rects = { { -100, 130, 55, 220 } } },
	{ name = "Riverside", rects = { { 55, -220, 125, 220 } } },
	{ name = "East Park", rects = { { 125, -220, 220, -30 } } },
	{ name = "Terrace", rects = { { 125, -30, 220, 110 } } },
	{ name = "Farmsteads", rects = { { 125, 110, 220, 220 } } },
}

Level.lighting = {
	ClockTime = 15.5,
	Brightness = 2.2,
	OutdoorAmbient = Color3.fromRGB(150, 146, 150),
	ColorShift_Top = Color3.fromRGB(255, 240, 220),
}

local V = Vector3.new
local V2 = Vector2.new

local HALF = 220 -- a városfal középvonala ennyire van a középponttól
local RIVER_WEST, RIVER_EAST = 58, 74
local RIVER_BED = -3

-- Talajszínek: visszafogottak, hogy a festett házak és tárgyak kiugorjanak.
local GRASS = Color3.fromRGB(122, 138, 112)
local COBBLE = Color3.fromRGB(150, 146, 140)
local SQUARE = Color3.fromRGB(172, 166, 156)
local STREET = Color3.fromRGB(132, 128, 124)
local LANE = Color3.fromRGB(162, 150, 128)
local STONE = Color3.fromRGB(150, 140, 126)

-- Pontsor 0.2 magasan (az utcák felszíne).
local function pts(list: { { number } }): { Vector3 }
	local out = {}
	for _, p in list do
		table.insert(out, V(p[1], 0.2, p[2]))
	end
	return out
end

-- Utcák: pontsorok. A fő utcák szélesebbek, a közök keskenyebbek.
local STREETS = {
	west = pts({ { -216, 10 }, { -170, 14 }, { -125, 4 }, { -90, -6 }, { -70, -8 } }),
	east = pts({ { -10, 14 }, { 20, 22 }, { 50, 18 } }),
	eastFar = pts({ { 82, 18 }, { 120, 8 }, { 165, 0 }, { 216, -4 } }),
	south = pts({ { -42, 20 }, { -46, 60 }, { -32, 105 }, { -38, 150 }, { -30, 216 } }),
	north = pts({ { -70, -30 }, { -86, -70 }, { -78, -120 }, { -90, -170 }, { -86, -216 } }),
}
local LANES = {
	pts({ { -125, 4 }, { -134, -40 }, { -160, -80 }, { -150, -130 }, { -176, -180 } }),
	pts({ { -170, 14 }, { -176, 60 }, { -152, 100 }, { -110, 122 }, { -70, 118 }, { -34, 112 } }),
	pts({ { -46, 60 }, { -5, 72 }, { 30, 62 }, { 50, 70 } }),
	pts({ { -86, -70 }, { -40, -96 }, { 0, -100 }, { 50, -112 } }),
	pts({ { 82, -112 }, { 120, -100 }, { 150, -122 }, { 190, -150 } }),
	pts({ { 120, 8 }, { 116, 50 }, { 108, 100 }, { 130, 150 }, { 176, 184 } }),
	pts({ { 165, 0 }, { 176, -50 }, { 160, -96 } }),
	pts({ { 108, 100 }, { 82, 112 } }),
	pts({ { 50, 112 }, { 20, 124 }, { -34, 132 } }),
}
-- Sikátorok a főtér körül: sűrű, keskeny utcák a városközpontban
local ALLEYS = {
	pts({ { -10, -30 }, { 12, -48 }, { 34, -40 }, { 50, -58 } }),
	pts({ { -8, 34 }, { 16, 46 }, { 44, 40 } }),
	pts({ { -72, 20 }, { -92, 36 }, { -100, 62 } }),
	pts({ { -70, -30 }, { -60, -64 }, { -30, -80 }, { 4, -74 } }),
}
local PROMENADE = pts({ { 82, -205 }, { 82, 205 } })

local function ground(Kit)
	-- Fű (a falon kívül is, az erdő alatt), a folyómeder, a rakpartfalak és a víz
	Kit.ground("GrassWest", -300, -300, RIVER_WEST - 3, 300, 0, Enum.Material.Grass, GRASS)
	Kit.ground("GrassEast", RIVER_EAST + 3, -300, 300, 300, 0, Enum.Material.Grass, GRASS)
	Kit.mound("QuayWest", RIVER_WEST - 3, -HALF, RIVER_WEST, HALF, RIVER_BED - 0.2, 0, Enum.Material.Slate, STONE)
	Kit.mound("QuayEast", RIVER_EAST, -HALF, RIVER_EAST + 3, HALF, RIVER_BED - 0.2, 0, Enum.Material.Slate, STONE)
	Kit.ground(
		"RiverBed",
		RIVER_WEST,
		-HALF,
		RIVER_EAST,
		HALF,
		RIVER_BED,
		Enum.Material.Ground,
		Color3.fromRGB(96, 90, 80)
	)
	Kit.water("River", RIVER_WEST, -HALF, RIVER_EAST, HALF, -0.9)
	-- Lépcsők a mederből fel a partra (aki beleesik, itt kijön)
	for _, z in { -170, -60, 60, 170 } do
		Kit.stairs(V(RIVER_WEST + 6, RIVER_BED, z), V(-1, 0, 0), 5, 3, Enum.Material.Slate, STONE)
		Kit.stairs(V(RIVER_EAST - 6, RIVER_BED, z + 20), V(1, 0, 0), 5, 3, Enum.Material.Slate, STONE)
	end
	-- Hidak
	Kit.bridge(V(RIVER_WEST - 5, 0.2, 18), V(RIVER_EAST + 5, 0.2, 18), 12)
	Kit.bridge(V(RIVER_WEST - 5, 0.2, -112), V(RIVER_EAST + 5, 0.2, -112), 9)
	Kit.bridge(V(RIVER_WEST - 5, 0.2, 112), V(RIVER_EAST + 5, 0.2, 112), 9)
end

-- Városfal kapukkal a négy fő utca végén, kívül erdő.
local function walls(Kit)
	Kit.townWall(HALF, {
		{ side = "west", at = 10 },
		{ side = "east", at = -4 },
		{ side = "south", at = -30 },
		{ side = "north", at = -86 },
	})
	Kit.forest(HALF + 12, 290, 18)
end

-- Főtér: templom óratoronnyal az északi oldalon, városháza a keletin, piac és kávézók.
local function square(Kit)
	Kit.plaza("Square", -70, -30, -10, 20, 0.25, Enum.Material.Slate, SQUARE)
	Kit.building({
		at = V(-40, 0.2, -52),
		size = V2(22, 34),
		floors = 3,
		rot = 180,
		roof = "gable",
		ridge = "z",
		material = "stone",
		windows = "tall",
		corners = true,
		rose = "front",
		roofColor = Color3.fromRGB(88, 100, 124),
	})
	Kit.building({
		at = V(-22, 0.2, -42),
		size = V2(10, 10),
		floors = 6,
		rot = 180,
		door = false,
		material = "stone",
		corners = true,
		tier = { floors = 1, scale = 0.8, roof = "cross" },
		clock = "front",
		roofColor = Color3.fromRGB(88, 100, 124),
	})
	Kit.building({
		at = V(0, 0.2, -5),
		size = V2(24, 16),
		floors = 3,
		rot = 90,
		material = "stone",
		corners = true,
		bands = true,
		windows = "tall",
		tier = { floors = 1, scale = 0.4, roof = "cross" },
		clock = "front",
		roofColor = Color3.fromRGB(72, 124, 92),
	})

	Kit.fountain(V(-40, 0.25, -5), 7)
	Kit.statue(V(-22, 0.25, -20), 180)
	Kit.bench(V(-40, 0.25, 7), 0)
	Kit.bench(V(-40, 0.25, -17), 180)
	Kit.bench(V(-52, 0.25, -5), -90)
	Kit.bench(V(-28, 0.25, -5), 90)
	for _, x in { -62, -52 } do
		Kit.stall(V(x, 0.25, 14), 0)
	end
	for _, x in { -24, -16 } do
		Kit.cafeTable(V(x, 0.25, 12))
	end
	for _, p in { V(-66, 0.25, -26), V(-14, 0.25, -26), V(-66, 0.25, 16), V(-14, 0.25, 4) } do
		Kit.lamp(p)
	end
	Kit.tree(V(-64, 0.25, 0), 0.8)
	Kit.planter(V(-48, 0.25, -28), 0, 4)
	Kit.planter(V(-32, 0.25, -28), 0, 4)
	Kit.spawn(V(-40, 0.25, 12))
	Kit.tankSpot(V(-58, 0.25, -18))
	Kit.tankSpot(V(-20, 0.25, 4))
end

-- Keleti terasz: emelt, füves plató lépcsővel, kilátótoronnyal, kávézóval.
local function terrace(Kit)
	local top = 10
	Kit.mound("Terrace", 132, 30, 200, 92, 0, top, Enum.Material.Slate, STONE)
	Kit.ground("TerraceGrass", 132, 30, 200, 92, top + 0.2, Enum.Material.Grass, GRASS)
	Kit.stairs(V(111, 0.2, 60), V(1, 0, 0), 10, top, Enum.Material.Cobblestone, COBBLE)
	Kit.stairs(V(166, 0, 114), V(0, 0, -1), 10, top, Enum.Material.Cobblestone, COBBLE)
	local t = top + 0.2
	Kit.plaza("TerracePlaza", 138, 48, 170, 72, t + 0.05, Enum.Material.Cobblestone, COBBLE)
	Kit.building({
		at = V(186, t, 60),
		size = V2(12, 12),
		floors = 5,
		rot = 90,
		material = "stone",
		corners = true,
		tier = { floors = 1, scale = 0.7, roof = "cross" },
		clock = "front",
	})
	Kit.building({ at = V(152, t, 40), size = V2(16, 12), floors = 2, rot = 0, shop = true, ridge = "x" })
	Kit.building({
		at = V(154, t, 82),
		size = V2(14, 12),
		floors = 2,
		rot = 180,
		ridge = "x",
		chimney = true,
		windows = "shutters",
	})
	Kit.cafeTable(V(146, t + 0.05, 58))
	Kit.cafeTable(V(158, t + 0.05, 62))
	Kit.tankSpot(V(166, t + 0.05, 52))
end

-- Szélmalmos domb a délnyugati sarokban.
local function windmillHill(Kit)
	local top = 8
	Kit.mound("Hill", -206, 150, -146, 206, 0, top, Enum.Material.Grass, GRASS)
	Kit.stairs(V(-170, 0, 134), V(0, 0, 1), 10, top, Enum.Material.Cobblestone, COBBLE)
	Kit.building({
		at = V(-186, top, 182),
		size = V2(10, 10),
		floors = 4, -- magasabb torony, hogy a lapátok ne érjenek le
		rot = -90,
		roof = "cross",
		material = "stone",
	})
	-- A lapátok 2.5 studdal a fal előtt forognak, hogy ne érjenek az ereszhez
	Kit.windmillBlades(V(-178.5, top + 14, 182), V(1, 0, 0), 3.5)
	Kit.building({
		at = V(-160, top, 190),
		size = V2(14, 10),
		floors = 1,
		rot = 0,
		ridge = "x",
		material = "wood",
		windows = "shutters",
	})
	Kit.tankSpot(V(-170, top, 165))
end

-- Keleti park: tó, pavilon, virágágyások (a többit a kitöltés adja).
local function eastPark(Kit)
	Kit.pond(V(140, 0, -175), V2(30, 18))
	Kit.gazebo(V(185, 0, -185), 10)
	Kit.flowerBed(V(115, 0, -160), 4)
	Kit.flowerBed(V(165, 0, -150), 4)
	Kit.tankSpot(V(118, 0, -185))
end

-- Utcák, közök és a házsorok mellettük.
local function streets(Kit)
	for _, points in STREETS do
		Kit.path("Street", points, 10, Enum.Material.Cobblestone, STREET)
	end
	for _, points in LANES do
		Kit.path("Lane", points, 7, Enum.Material.Cobblestone, LANE)
	end
	for _, points in ALLEYS do
		Kit.path("Alley", points, 6, Enum.Material.Cobblestone, COBBLE, 1.5)
	end
	Kit.path("Promenade", PROMENADE, 7, Enum.Material.Cobblestone, COBBLE, 1)

	-- Városközpont: magasabb házak, üzletek; külső közök: kertes családi házak
	local center = {
		floors = { 2, 3 },
		shops = 0.4,
		widths = { 9, 14 },
		gaps = { 1, 3 },
		balconies = 0.4,
		windows = { "plain", "plain", "shutters" },
	}
	local suburb = {
		street = 7,
		floors = { 1, 2 },
		shops = 0.05,
		widths = { 9, 13 },
		depths = { 9, 11 },
		gaps = { 6, 12 },
		windows = { "shutters", "shutters", "plain" },
		materials = { "plaster", "wood", "wood", "brick" },
		setback = 5,
	}
	for _, points in STREETS do
		Kit.streetRow(points, center)
	end
	for _, points in ALLEYS do
		Kit.streetRow(points, {
			street = 6,
			floors = { 2, 3 },
			shops = 0.2,
			widths = { 8, 12 },
			depths = { 9, 12 },
			gaps = { 0, 2 },
			margin = 5,
		})
	end
	for _, points in LANES do
		Kit.streetRow(points, suburb)
	end
	Kit.streetRow(PROMENADE, {
		side = "right",
		street = 7,
		floors = { 2, 3 },
		shops = 0.25,
		widths = { 9, 13 },
		gaps = { 1, 4 },
		windows = { "shutters", "plain" },
	})

	-- Lámpák és tartályhelyek az utcák mentén
	-- Pontok egyenletesen a teljes pontsor mentén, "every" studonként (a töréspontokon át is számolva).
	local function along(points: { Vector3 }, every: number, fn: (Vector3, Vector3) -> ())
		local nextAt = every / 2
		local walked = 0
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local flat = V(b.X - a.X, 0, b.Z - a.Z)
			local length = flat.Magnitude
			while nextAt <= walked + length do
				fn(a + flat.Unit * (nextAt - walked), flat.Unit)
				nextAt += every
			end
			walked += length
		end
	end
	for _, points in STREETS do
		along(points, 40, function(p, dir)
			Kit.lamp(p + V(-dir.Z, 0, dir.X) * 6.5)
		end)
		along(points, 28, function(p)
			Kit.tankSpot(p)
		end)
	end
	for _, list in { LANES, ALLEYS } do
		for _, points in list do
			along(points, 30, function(p)
				Kit.tankSpot(p)
			end)
		end
	end
	along(PROMENADE, 35, function(p)
		Kit.tankSpot(p)
	end)
end

-- Milyen jellegű egy hely (a kitöltéshez).
local function zone(x: number, z: number): string?
	if x > RIVER_WEST - 6 and x < RIVER_EAST + 6 then
		return nil -- a folyó és a rakpart
	end
	if x < -140 and z > 140 then
		return "farm" -- a szélmalmos domb környéke
	end
	if x > 130 and z > 120 then
		return "farm" -- délkeleti tanyák
	end
	if x > 90 and z < -130 then
		return "park" -- keleti park
	end
	if x > 130 and x < 200 and z > 30 and z < 92 then
		return "park" -- a terasz teteje
	end
	if x > -85 and x < 15 and z > -45 and z < 35 then
		return "yard" -- a főtér körül: udvarok
	end
	if z < -140 and x < 50 then
		return "park" -- az északi rész: liget
	end
	return "garden"
end

function Level.build(Kit)
	ground(Kit)
	walls(Kit)
	square(Kit)
	terrace(Kit)
	windmillHill(Kit)
	eastPark(Kit)
	streets(Kit)
	Kit.fill(-HALF + 3, -HALF + 3, HALF - 3, HALF - 3, 12, zone, 0.05)
end

return Level
