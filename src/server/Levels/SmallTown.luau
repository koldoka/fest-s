-- 1. pálya: Kisváros főtérrel.
--
--            park (tavacska, pavilon) --híd--  szélmalmos domb (tanya, csűr, virágföldek)
--                    |                  F
--       [torony][  templom  ][ ]        O
--   [ ] +--------------------+ [ ]      L
--  lakó-|       F Ő T É R    |--utca----Y--híd-- lépcső -> terasz (kilátótorony, kávézó)
--  utca |  (szökőkút, padok, |          Ó
--       |  kávézók, standok) |          |
--   [ ] +--------------------+ [ ]      |   rakparti sétány
--                 |                     |   folyóparti negyed
--  városháza   piac utca ---------------híd-- keresztutca
--    tér          |
--             városkapu
--
-- Koordináták: X kelet felé, Z dél felé nő (észak = -Z). A főtér közepe az origó.
-- Felszínek: fű 0, burkolt részek 0.2, főtér 0.25, terasz 12.4, domb 10, folyómeder -3.

local Level = {}

Level.seed = 7

Level.lighting = {
	ClockTime = 15.5,
	Brightness = 2.2,
	OutdoorAmbient = Color3.fromRGB(150, 146, 150),
	ColorShift_Top = Color3.fromRGB(255, 240, 220),
}

local V = Vector3.new
local V2 = Vector2.new

-- Talajszínek: visszafogottak, hogy a festett házak és tárgyak kiugorjanak.
local GRASS = Color3.fromRGB(122, 138, 112)
local COBBLE = Color3.fromRGB(150, 146, 140)
local SQUARE = Color3.fromRGB(172, 166, 156)
local STREET = Color3.fromRGB(128, 126, 124)
local DIRT = Color3.fromRGB(176, 160, 128)
local STONE = Color3.fromRGB(150, 140, 126)
local FIELD = Color3.fromRGB(138, 112, 84)

local RIVER_WEST, RIVER_EAST = 66, 82 -- a meder két széle
local RIVER_BED = -3

-- Egy spec kiegészítése extra mezőkkel (a házsorokhoz).
local function with(spec: { [string]: any }, extra: { [string]: any }): { [string]: any }
	for key, value in extra do
		spec[key] = value
	end
	return spec
end

local function ground(Kit)
	-- Fű a folyó két oldalán, a folyómeder, a rakpartfalak és a víz
	Kit.ground("GrassWest", -300, -260, RIVER_WEST - 3, 280, 0, Enum.Material.Grass, GRASS)
	Kit.ground("GrassEast", RIVER_EAST + 3, -260, 300, 280, 0, Enum.Material.Grass, GRASS)
	Kit.mound("QuayWest", RIVER_WEST - 3, -260, RIVER_WEST, 280, RIVER_BED - 0.2, 0, Enum.Material.Slate, STONE)
	Kit.mound("QuayEast", RIVER_EAST, -260, RIVER_EAST + 3, 280, RIVER_BED - 0.2, 0, Enum.Material.Slate, STONE)
	Kit.ground(
		"RiverBed",
		RIVER_WEST,
		-260,
		RIVER_EAST,
		280,
		RIVER_BED,
		Enum.Material.Ground,
		Color3.fromRGB(96, 90, 80)
	)
	Kit.water("River", RIVER_WEST, -260, RIVER_EAST, 280, -0.9)
	-- Lépcsők a mederből fel a partra (aki beleesik, itt kijön)
	for _, z in { -200, -60, 40, 110, 220 } do
		Kit.stairs(V(RIVER_WEST + 6, RIVER_BED, z), V(-1, 0, 0), 5, 3, Enum.Material.Slate, STONE)
		Kit.stairs(V(RIVER_EAST - 6, RIVER_BED, z + 20), V(1, 0, 0), 5, 3, Enum.Material.Slate, STONE)
	end

	-- Burkolt óváros, utcák
	Kit.ground("OldTown", -60, -72, 60, 60, 0.2, Enum.Material.Cobblestone, COBBLE)
	Kit.ground("Square", -36, -36, 36, 36, 0.25, Enum.Material.Slate, SQUARE)
	Kit.ground("WestStreet", -200, -8, -60, 8, 0.2, Enum.Material.Cobblestone, STREET)
	Kit.ground("EastStreetA", 60, -8, RIVER_WEST - 3, 8, 0.2, Enum.Material.Cobblestone, STREET)
	Kit.ground("EastStreetB", RIVER_EAST + 3, -8, 92, 8, 0.2, Enum.Material.Cobblestone, STREET)
	Kit.ground("MarketStreet", -12, 60, 12, 200, 0.2, Enum.Material.Cobblestone, STREET)
end

local function square(Kit)
	-- Templom a tér északi oldalán (kő, magas ablakok, rózsaablak), mellette óratorony
	Kit.building({
		at = V(0, 0.2, -54),
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
		at = V(-16, 0.2, -43),
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
		at = V(22, 0.2, -47),
		size = V2(16, 18),
		floors = 3,
		rot = 180,
		balconies = { face = "front" },
		material = "brick",
	})
	Kit.building({
		at = V(-30, 0.2, -47),
		size = V2(14, 18),
		floors = 2,
		rot = 180,
		chimney = true,
		windows = "shutters",
	})

	-- Sarokházak
	Kit.building({
		at = V(-47, 0.2, -47),
		size = V2(16, 18),
		floors = 3,
		rot = -90,
		roof = "gable",
		ridge = "x",
		corners = true,
	})
	Kit.building({
		at = V(47, 0.2, -47),
		size = V2(16, 18),
		floors = 4,
		rot = 90,
		balconies = { face = "front", shift = 3 },
		material = "brick",
	})
	Kit.building({
		at = V(47, 0.2, 47),
		size = V2(16, 18),
		floors = 4,
		rot = 0,
		balconies = { face = "front", shift = -3 },
		corners = true,
	})
	Kit.building({
		at = V(-47, 0.2, 47),
		size = V2(16, 18),
		floors = 2,
		rot = -90,
		chimney = true,
		windows = "shutters",
		material = "brick",
	})

	-- Keleti sor (a homlokzat nyugatra, a tér felé néz): kávézók, keskeny városi házak
	Kit.building({ at = V(47, 0.2, -27), size = V2(16, 18), floors = 2, rot = 90, shop = true, ridge = "x" })
	Kit.building({
		at = V(47, 0.2, -13.5),
		size = V2(9, 18),
		floors = 3,
		rot = 90,
		roof = "gable",
		ridge = "z",
		windows = "shutters",
	})
	Kit.building({
		at = V(47, 0.2, 16),
		size = V2(14, 18),
		floors = 2,
		rot = 90,
		shop = true,
		ridge = "x",
		material = "brick",
	})
	Kit.building({ at = V(47, 0.2, 30.5), size = V2(11, 18), floors = 3, rot = 90, balconies = { face = "front" } })

	-- Déli sor (a homlokzat északra néz)
	Kit.building({
		at = V(-27, 0.2, 47),
		size = V2(16, 18),
		floors = 2,
		rot = 0,
		shop = true,
		ridge = "x",
		material = "wood",
	})
	Kit.building({
		at = V(-13.5, 0.2, 47),
		size = V2(9, 18),
		floors = 3,
		rot = 0,
		roof = "gable",
		ridge = "z",
		corners = true,
	})
	Kit.building({
		at = V(13.5, 0.2, 47),
		size = V2(9, 18),
		floors = 2,
		rot = 0,
		ridge = "z",
		chimney = true,
		windows = "shutters",
		material = "brick",
	})
	Kit.building({ at = V(27.5, 0.2, 47), size = V2(16, 18), floors = 3, rot = 0, shop = true })

	-- Nyugati sor (a homlokzat keletre néz): magas oromzatos polgárházak
	Kit.building({
		at = V(-47, 0.2, -27),
		size = V2(16, 18),
		floors = 3,
		rot = -90,
		roof = "gable",
		ridge = "x",
		chimney = true,
		material = "brick",
		corners = true,
	})
	Kit.building({ at = V(-47, 0.2, -13.5), size = V2(9, 18), floors = 2, rot = -90, ridge = "z", windows = "shutters" })
	Kit.building({
		at = V(-47, 0.2, 13.5),
		size = V2(9, 18),
		floors = 4,
		rot = -90,
		balconies = { face = "front" },
		material = "brick",
	})
	Kit.building({ at = V(-47, 0.2, 30.5), size = V2(11, 18), floors = 2, rot = -90, shop = true, ridge = "x" })

	-- A tér berendezése
	Kit.fountain(V(0, 0.25, 0), 9)
	Kit.bench(V(15, 0.25, 0), 90)
	Kit.bench(V(-15, 0.25, 0), -90)
	Kit.bench(V(0, 0.25, 15), 0)
	Kit.bench(V(0, 0.25, -15), 180)
	Kit.tree(V(-26, 0.25, 26))
	Kit.tree(V(26, 0.25, -26))
	Kit.tree(V(-26, 0.25, -12), 0.8)
	Kit.tree(V(26, 0.25, 12), 0.8)
	for _, p in { V(-32, 0.25, -32), V(32, 0.25, -32), V(-32, 0.25, 32), V(32, 0.25, 32) } do
		Kit.lamp(p)
	end
	for _, p in { V(31, 0.25, -31), V(31, 0.25, -23), V(31, 0.25, 12), V(31, 0.25, 20) } do
		Kit.cafeTable(p)
	end
	for _, x in { -24, -12, 12, 24 } do
		Kit.stall(V(x, 0.25, 30), 0)
	end
	Kit.planter(V(-7, 0.25, -34), 0, 5)
	Kit.planter(V(7, 0.25, -34), 0, 5)
	for _, p in { V(-34, 0.25, -6), V(-34, 0.25, 6), V(34, 0.25, -6), V(34, 0.25, 6) } do
		Kit.bollard(p)
	end

	Kit.paintTank(V(-28, 0.25, -28), "Red")
	Kit.paintTank(V(28, 0.25, 28), "Yellow")
	Kit.spawn(V(0, 0.25, 22))
end

-- Nyugati lakóutca: kertes családi házak kerítéssel, fákkal, bokrokkal.
local function residentialLane(Kit)
	local materials = { "plaster", "wood", "brick", "plaster" }
	local count = 0
	local function house(x: number, width: number, depth: number, north: boolean, chimney: boolean)
		count += 1
		local facade = if north then -14 else 14 -- 6 stud előkert az utca és a ház között
		local z = if north then facade - depth / 2 else facade + depth / 2
		Kit.building({
			at = V(x, 0, z),
			size = V2(width, depth),
			floors = 2,
			rot = if north then 180 else 0,
			ridge = if count % 3 == 0 then "z" else "x",
			chimney = chimney,
			windows = "shutters",
			material = materials[count % #materials + 1],
		})
		-- Kerítés az előkert szélén, a kapunál réssel; bokor az előkertben
		local fz = if north then -9.5 else 9.5
		Kit.fence(V(x - width / 2 - 1, 0, fz), V(x - 1.8, 0, fz))
		Kit.fence(V(x + 1.8, 0, fz), V(x + width / 2 + 1, 0, fz))
		Kit.ground(
			"GardenPath",
			x - 1.5,
			math.min(fz, facade),
			x + 1.5,
			math.max(fz, facade),
			0.08,
			Enum.Material.Pavement,
			DIRT
		)
		Kit.bush(V(x - width / 2 + 2, 0, (fz + facade) / 2), 0.8)
	end

	house(-70, 14, 12, true, true)
	house(-89, 12, 12, true, false)
	house(-110, 16, 14, true, true)
	house(-130.5, 13, 12, true, false)
	house(-151.5, 15, 13, true, true)
	house(-172, 12, 12, true, false)

	house(-72, 13, 12, false, false)
	house(-93, 15, 13, false, true)
	house(-113, 12, 12, false, false)
	house(-134, 16, 14, false, true)
	house(-155, 13, 12, false, false)
	house(-176, 14, 12, false, true)

	-- Fák a házak között, hátrébb
	for _, p in
		{
			V(-80, 0, -26),
			V(-99, 0, -24),
			V(-141, 0, -26),
			V(-162, 0, -24),
			V(-82, 0, 26),
			V(-123, 0, 25),
			V(-145, 0, 27),
			V(-186, 0, 24),
		}
	do
		Kit.tree(p)
	end
	for _, p in { V(-80, 0.2, -8.5), V(-120, 0.2, 8.5), V(-160, 0.2, -8.5) } do
		Kit.lamp(p)
	end
	Kit.planter(V(-190, 0.2, -6), 90, 4)
	Kit.planter(V(-190, 0.2, 6), 90, 4)

	Kit.paintTank(V(-192, 0.2, 0), "Blue")
end

-- Keleti utca a hídon át, lépcső fel a teraszra; a teraszon kis tér, kilátótorony, kávézó.
local function terrace(Kit)
	local top = 12.4
	Kit.bridge(V(RIVER_WEST - 4, 0.2, 0), V(RIVER_EAST + 4, 0.2, 0), 14)
	for _, p in { V(60, 0.2, -9), V(60, 0.2, 9), V(90, 0.2, -9), V(90, 0.2, 9) } do
		Kit.lamp(p)
	end

	Kit.stairs(V(92, 0.2, 0), V(1, 0, 0), 16, 12, Enum.Material.Cobblestone, COBBLE)
	Kit.block({
		Name = "TerraceWall",
		Size = V(84, 12.2, 100),
		Position = V(158, 6.1, 0),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	Kit.ground("TerraceGrass", 116, -50, 200, 50, top, Enum.Material.Grass, GRASS)
	Kit.ground("TerracePlaza", 124, -18, 176, 18, top + 0.1, Enum.Material.Cobblestone, COBBLE)
	-- Hátsó lépcső a teraszról le a folyóparti negyed felé (dél felé)
	Kit.stairs(V(150, 0, 76), V(0, 0, -1), 12, top, Enum.Material.Cobblestone, COBBLE)

	local plaza = top + 0.1
	Kit.building({
		at = V(185, top, 0),
		size = V2(12, 12),
		floors = 5,
		rot = 90,
		material = "stone",
		corners = true,
		tier = { floors = 1, scale = 0.7, roof = "cross" },
		clock = "front",
	})
	Kit.building({
		at = V(140, top, -30),
		size = V2(16, 14),
		floors = 2,
		rot = 180,
		chimney = true,
		ridge = "x",
		windows = "shutters",
		material = "wood",
	})
	Kit.building({
		at = V(162, top, -30),
		size = V2(14, 14),
		floors = 3,
		rot = 180,
		balconies = { face = "front" },
		material = "brick",
	})
	Kit.building({ at = V(140, top, 30), size = V2(16, 14), floors = 2, rot = 0, shop = true, ridge = "x" })
	Kit.building({
		at = V(162, top, 30),
		size = V2(14, 14),
		floors = 2,
		rot = 0,
		ridge = "z",
		chimney = true,
		windows = "shutters",
	})

	-- Kerítés a terasz szélén (a lépcsőnél nyitva)
	Kit.fence(V(117, top, -49), V(117, top, -9))
	Kit.fence(V(117, top, 9), V(117, top, 49))
	for _, p in { V(125, top, -42), V(125, top, 42), V(195, top, -42), V(195, top, 42) } do
		Kit.tree(p)
	end
	Kit.bench(V(150, plaza, -14), 180)
	Kit.bench(V(150, plaza, 14), 0)
	Kit.cafeTable(V(134, plaza, 16))
	Kit.cafeTable(V(146, plaza, 20))
	Kit.lamp(V(128, plaza, -16))
	Kit.lamp(V(128, plaza, 16))

	Kit.paintTank(V(156, plaza, 0), "Green")
	Kit.tree(V(100, 0, -18))
	Kit.tree(V(100, 0, 18))
end

-- Déli piac utca üzletekkel, a végén városkapu; keresztutca és híd a folyóparti negyedhez.
local function marketStreet(Kit)
	local function shop(z: number, width: number, east: boolean, floors: number, extra: { [string]: any })
		Kit.building(with({
			at = V(if east then 19 else -19, 0.2, z),
			size = V2(width, 14),
			floors = floors,
			rot = if east then 90 else -90,
		}, extra))
	end

	shop(70, 14, true, 2, { shop = true, ridge = "x", material = "brick" })
	shop(83, 10, true, 3, { roof = "gable", ridge = "z", windows = "shutters" })
	shop(99, 16, true, 2, { shop = true, ridge = "x" })
	shop(116, 12, true, 3, { balconies = { face = "front" }, corners = true })
	shop(132, 14, true, 2, { shop = true, ridge = "x", material = "wood" })

	shop(69, 12, false, 3, { shop = true, material = "brick" })
	shop(86, 16, false, 2, { shop = true, ridge = "x" })
	shop(100, 10, false, 2, { ridge = "z", chimney = true, windows = "shutters" })
	shop(114, 14, false, 3, { shop = true, corners = true })
	shop(131, 14, false, 2, { ridge = "x", chimney = true, material = "wood", windows = "shutters" })

	for _, p in { V(-10, 0.2, 78), V(10, 0.2, 92), V(-10, 0.2, 108), V(10, 0.2, 124), V(-10, 0.2, 140) } do
		Kit.lamp(p)
	end
	Kit.stall(V(0, 0.2, 146), 180)

	-- Keresztutca a folyóhoz és a déli híd
	Kit.ground("RiverLane", 12, 150, RIVER_WEST - 3, 162, 0.2, Enum.Material.Cobblestone, STREET)
	Kit.bridge(V(RIVER_WEST - 4, 0.2, 156), V(RIVER_EAST + 4, 0.2, 156), 10)
	for _, x in { 26, 42 } do
		Kit.tree(V(x, 0, 168))
		Kit.lamp(V(x + 6, 0.2, 149))
	end

	-- Városkapu: két kis torony és egy kőív
	Kit.building({
		at = V(-17, 0.2, 180),
		size = V2(8, 8),
		floors = 3,
		rot = 0,
		roof = "cross",
		door = false,
		material = "stone",
		corners = true,
	})
	Kit.building({
		at = V(17, 0.2, 180),
		size = V2(8, 8),
		floors = 3,
		rot = 0,
		roof = "cross",
		door = false,
		material = "stone",
		corners = true,
	})
	Kit.arch(V(0, 0.2, 180), 0, 20, 10)

	Kit.paintTank(V(0, 0.2, 165), "Orange")
end

-- Park a templom mögött: tavacska, pavilon, fák, padok, két villa a szélén; híd a szélmalmos domb felé.
local function park(Kit)
	Kit.ground("ParkPath", -3, -150, 3, -72, 0.08, Enum.Material.Pavement, DIRT)
	Kit.ground("ParkPathCross", -45, -113, 45, -107, 0.09, Enum.Material.Pavement, DIRT)
	Kit.ground("ParkPathEast", 45, -126, RIVER_WEST - 3, -114, 0.09, Enum.Material.Pavement, DIRT)
	Kit.pond(V(-25, 0, -128), V2(22, 14))
	Kit.gazebo(V(25, 0, -136), 10)
	for _, p in
		{
			V(-45, 0, -85),
			V(-40, 0, -145),
			V(-12, 0, -92),
			V(14, 0, -152),
			V(42, 0, -86),
			V(48, 0, -145),
			V(-52, 0, -120),
			V(-20, 0, -98),
			V(22, 0, -96),
		}
	do
		Kit.tree(p)
	end
	for _, p in { V(-35, 0, -95), V(35, 0, -100), V(-8, 0, -140), V(52, 0, -100) } do
		Kit.bush(p)
	end
	Kit.bench(V(6, 0.08, -96), 90)
	Kit.bench(V(-6, 0.08, -124), -90)
	Kit.bench(V(-30, 0.09, -104), 180)
	Kit.hedge(V(-40, 0, -76), V(-8, 0, -76))
	Kit.hedge(V(8, 0, -76), V(40, 0, -76))

	Kit.building({
		at = V(-40, 0, -168),
		size = V2(16, 14),
		floors = 2,
		rot = 180,
		chimney = true,
		ridge = "x",
		windows = "shutters",
		material = "wood",
	})
	Kit.building({
		at = V(40, 0, -168),
		size = V2(16, 14),
		floors = 3,
		rot = 180,
		roof = "gable",
		ridge = "x",
		corners = true,
		material = "brick",
	})

	Kit.bridge(V(RIVER_WEST - 4, 0.09, -120), V(RIVER_EAST + 4, 0.09, -120), 10)
	Kit.paintTank(V(0, 0.08, -110), "Purple")
end

-- Szélmalmos domb a folyón túl: tanya, csűr, szélmalom; a domb lábánál virágföldek.
local function windmillHill(Kit)
	local top = 10
	Kit.ground("HillPath", RIVER_EAST + 3, -125, 110, -115, 0.08, Enum.Material.Pavement, DIRT)
	Kit.mound("Hill", 130, -190, 210, -110, 0, top, Enum.Material.Grass, GRASS)
	Kit.stairs(V(110, 0, -120), V(1, 0, 0), 10, top, Enum.Material.Cobblestone, COBBLE)
	Kit.stairs(V(170, 0, -90), V(0, 0, -1), 10, top, Enum.Material.Cobblestone, COBBLE)

	-- Szélmalom: kőtorony kereszttetővel, a lapátok nyugatra (a város felé) néznek
	Kit.building({ at = V(185, top, -150), size = V2(10, 10), floors = 3, rot = 90, roof = "cross", material = "stone" })
	Kit.windmillBlades(V(179.2, top + 14, -150), V(-1, 0, 0))
	Kit.building({
		at = V(150, top, -172),
		size = V2(16, 12),
		floors = 2,
		rot = 0,
		chimney = true,
		ridge = "x",
		windows = "shutters",
	})
	Kit.building({
		at = V(195, top, -122),
		size = V2(18, 12),
		floors = 2,
		rot = 180,
		ridge = "x",
		material = "wood",
		windows = "none",
		roofColor = Color3.fromRGB(184, 78, 60),
	})
	Kit.building({
		at = V(150, top, -128),
		size = V2(12, 10),
		floors = 1,
		rot = 180,
		ridge = "x",
		material = "wood",
		windows = "shutters",
	})

	Kit.fence(V(132, top, -112), V(163, top, -112))
	Kit.fence(V(177, top, -112), V(208, top, -112))
	for _, p in { V(140, top, -150), V(205, top, -182), V(168, top, -186), V(205, top, -142) } do
		Kit.tree(p)
	end
	Kit.bench(V(160, top, -150), -90)
	Kit.paintTank(V(168, top, -135), "Yellow")

	-- Virágföld a domb lábánál: sorokba ültetett bokrok
	Kit.ground("Field", 96, -210, 126, -150, 0.06, Enum.Material.Ground, FIELD)
	for row = 0, 4 do
		for i = 0, 5 do
			Kit.bush(V(100 + row * 6, 0, -205 + i * 10), 0.55)
		end
	end
	Kit.fence(V(95, 0, -211), V(127, 0, -211))
	Kit.fence(V(95, 0, -149), V(127, 0, -149))
end

-- Folyóparti negyed: rakparti sétány a keleti parton, házsor a folyó felé, keresztutca két házsorral.
local function riverside(Kit)
	local promenade = RIVER_EAST + 3
	Kit.ground("Promenade", promenade, 60, promenade + 12, 240, 0.2, Enum.Material.Cobblestone, COBBLE)
	Kit.ground("CrossStreet", promenade + 12, 150, 232, 162, 0.2, Enum.Material.Cobblestone, STREET)

	-- Házsor a sétány mentén (a homlokzat nyugatra, a folyó felé néz)
	local x = promenade + 13 + 7
	for _, h in
		{
			{ 72, 12, 3, { windows = "shutters" } },
			{ 86, 14, 2, { ridge = "x", material = "wood", chimney = true } },
			{ 101, 12, 4, { balconies = { face = "front" }, material = "brick" } },
			{ 115, 12, 3, { roof = "gable", ridge = "x", corners = true } },
			{ 131, 14, 2, { shop = true, ridge = "x" } },
			{ 144, 8, 3, { roof = "gable", ridge = "z", windows = "shutters", material = "brick" } },
			{ 170, 14, 2, { shop = true, ridge = "x", material = "brick" } },
			{ 185, 12, 3, { balconies = { face = "front" } } },
			{ 200, 14, 2, { ridge = "x", chimney = true, windows = "shutters", material = "wood" } },
			{ 215, 12, 3, { roof = "gable", ridge = "x", corners = true } },
			{ 229, 12, 2, { shop = true, ridge = "z" } },
		}
	do
		Kit.building(with({ at = V(x, 0.2, h[1]), size = V2(h[2], 14), floors = h[3], rot = 90 }, h[4]))
	end

	-- A keresztutca két oldala (a sétány menti házsor mögött, keletre)
	for _, h in
		{
			{ 128, 14, 2, { shop = true, ridge = "x" } },
			{ 144, 12, 3, { windows = "shutters", material = "brick" } },
			{ 161, 16, 2, { ridge = "x", chimney = true, material = "wood" } },
			{ 179, 14, 3, { balconies = { face = "front" }, corners = true } },
			{ 196, 12, 2, { ridge = "z", windows = "shutters" } },
		}
	do
		Kit.building(with({ at = V(h[1], 0.2, 171), size = V2(h[2], 14), floors = h[3], rot = 0 }, h[4]))
	end
	for _, h in
		{
			{ 126, 12, 3, { roof = "gable", ridge = "x", material = "brick" } },
			{ 142, 14, 2, { shop = true, ridge = "x", material = "wood" } },
			{ 158, 12, 4, { balconies = { face = "front" } } },
			{ 175, 16, 2, { ridge = "x", chimney = true, windows = "shutters" } },
			{ 193, 14, 3, { corners = true, material = "brick" } },
		}
	do
		Kit.building(with({ at = V(h[1], 0.2, 141), size = V2(h[2], 14), floors = h[3], rot = 180 }, h[4]))
	end

	-- Sétány: lámpák, padok a folyó felé, kikötőbakok
	for z = 70, 230, 25 do
		Kit.lamp(V(promenade + 1.5, 0.2, z))
		Kit.bollard(V(promenade + 0.8, 0.2, z + 12))
	end
	for _, z in { 82, 122, 182, 222 } do
		Kit.bench(V(promenade + 4, 0.2, z), 90)
	end
	for _, tx in { 136, 170, 204 } do
		Kit.tree(V(tx, 0.2, 156))
	end
	Kit.fountain(V(222, 0.2, 156), 5)
	Kit.paintTank(V(212, 0.2, 156), "Red")
end

-- Városháza tér az óváros délnyugati sarkánál: városháza órával, házak körben, szobor.
local function townHall(Kit)
	Kit.ground("TownHallPlaza", -130, 62, -66, 140, 0.2, Enum.Material.Slate, SQUARE)
	Kit.ground("TownHallLink", -66, 56, -60, 70, 0.2, Enum.Material.Cobblestone, COBBLE)

	Kit.building({
		at = V(-98, 0.2, 128),
		size = V2(30, 16),
		floors = 3,
		rot = 0,
		material = "stone",
		corners = true,
		bands = true,
		windows = "tall",
		tier = { floors = 1, scale = 0.4, roof = "cross" },
		clock = "front",
		roofColor = Color3.fromRGB(72, 124, 92),
	})
	for _, h in
		{ { 76, 14, 2, "shutters", "wood" }, { 92, 12, 3, "plain", "brick" }, { 106, 12, 2, "shutters", "plaster" } }
	do
		Kit.building({
			at = V(-137, 0.2, h[1]),
			size = V2(h[2], 14),
			floors = h[3],
			rot = -90,
			windows = h[4],
			material = h[5],
			ridge = "x",
			chimney = h[3] == 2,
		})
	end
	Kit.building({ at = V(-59, 0.2, 76), size = V2(14, 14), floors = 2, rot = 90, shop = true, ridge = "x" })
	Kit.building({
		at = V(-59, 0.2, 92),
		size = V2(12, 14),
		floors = 3,
		rot = 90,
		balconies = { face = "front" },
		material = "brick",
	})
	Kit.building({
		at = V(-59, 0.2, 108),
		size = V2(14, 14),
		floors = 2,
		rot = 90,
		ridge = "z",
		windows = "shutters",
		chimney = true,
	})

	Kit.statue(V(-98, 0.2, 96), 180)
	for _, p in { V(-116, 0.2, 80), V(-80, 0.2, 80), V(-116, 0.2, 112), V(-80, 0.2, 112) } do
		Kit.tree(p, 0.9)
	end
	Kit.bench(V(-98, 0.2, 86), 180)
	Kit.planter(V(-108, 0.2, 118), 0, 5)
	Kit.planter(V(-88, 0.2, 118), 0, 5)
	for _, p in { V(-126, 0.2, 66), V(-70, 0.2, 66), V(-126, 0.2, 136), V(-70, 0.2, 136) } do
		Kit.lamp(p)
	end
	Kit.paintTank(V(-112, 0.2, 96), "Green")
end

function Level.build(Kit)
	ground(Kit)
	square(Kit)
	residentialLane(Kit)
	terrace(Kit)
	marketStreet(Kit)
	park(Kit)
	windmillHill(Kit)
	riverside(Kit)
	townHall(Kit)
end

return Level
