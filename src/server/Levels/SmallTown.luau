-- 1. pálya: Kisváros főtérrel.
--
--                         park (tavacska, pavilon)
--                               |
--              [torony][   templom   ][ ]
--      [ ]  +---------------------------------+  [ ]
--  lakó-    |          F Ő T É R              |      utca -> lépcső -> terasz
--  utca  ---|       (szökőkút, padok,         |---   (kilátótorony, kávézó)
--           |     kávézóasztalok, standok)    |
--      [ ]  +---------------------------------+  [ ]
--                          |
--                    piac utca (üzletek)
--                          |
--                      városkapu
--
-- Koordináták: X kelet felé, Z dél felé nő (észak = -Z). A főtér közepe az origó.
-- A talaj felszíne 0 (fű), a burkolt részeké 0.2, a főtéré 0.25, a teraszé 12.4.

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

local function square(Kit)
	-- Templom a tér északi oldalán, mellette óratorony (a homlokzatok délre, a tér felé néznek)
	Kit.building({ at = V(0, 0.2, -54), size = V2(22, 34), floors = 3, rot = 180, roof = "gable", ridge = "z" })
	Kit.building({
		at = V(-16, 0.2, -43),
		size = V2(10, 10),
		floors = 6,
		rot = 180,
		door = false,
		tier = { floors = 1, scale = 0.8, roof = "cross" },
		clock = "front",
	})
	Kit.building({ at = V(22, 0.2, -47), size = V2(16, 18), floors = 3, rot = 180, balconies = { face = "front" } })
	Kit.building({ at = V(-30, 0.2, -47), size = V2(14, 18), floors = 2, rot = 180, chimney = true })

	-- Sarokházak
	Kit.building({ at = V(-47, 0.2, -47), size = V2(16, 18), floors = 3, rot = -90, roof = "gable", ridge = "x" })
	Kit.building({
		at = V(47, 0.2, -47),
		size = V2(16, 18),
		floors = 4,
		rot = 90,
		balconies = { face = "front", shift = 3 },
	})
	Kit.building({
		at = V(47, 0.2, 47),
		size = V2(16, 18),
		floors = 4,
		rot = 0,
		balconies = { face = "front", shift = -3 },
	})
	Kit.building({ at = V(-47, 0.2, 47), size = V2(16, 18), floors = 2, rot = -90, chimney = true })

	-- Keleti sor (a homlokzat nyugatra, a tér felé néz): kávézók, keskeny városi házak
	Kit.building({ at = V(47, 0.2, -27), size = V2(16, 18), floors = 2, rot = 90, shop = true, ridge = "x" })
	Kit.building({ at = V(47, 0.2, -13.5), size = V2(9, 18), floors = 3, rot = 90 })
	Kit.building({ at = V(47, 0.2, 16), size = V2(14, 18), floors = 2, rot = 90, shop = true, ridge = "x" })
	Kit.building({ at = V(47, 0.2, 30.5), size = V2(11, 18), floors = 3, rot = 90, balconies = { face = "front" } })

	-- Déli sor (a homlokzat északra néz)
	Kit.building({ at = V(-27, 0.2, 47), size = V2(16, 18), floors = 2, rot = 0, shop = true, ridge = "x" })
	Kit.building({ at = V(-13.5, 0.2, 47), size = V2(9, 18), floors = 3, rot = 0 })
	Kit.building({ at = V(13.5, 0.2, 47), size = V2(9, 18), floors = 2, rot = 0, ridge = "z", chimney = true })
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
	})
	Kit.building({ at = V(-47, 0.2, -13.5), size = V2(9, 18), floors = 2, rot = -90, ridge = "z" })
	Kit.building({ at = V(-47, 0.2, 13.5), size = V2(9, 18), floors = 4, rot = -90, balconies = { face = "front" } })
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

	Kit.paintTank(V(-28, 0.25, -28), "Red")
	Kit.paintTank(V(28, 0.25, 28), "Yellow")
	Kit.spawn(V(0, 0.25, 22))
end

-- Nyugati lakóutca: kertes családi házak kerítéssel, fákkal.
local function residentialLane(Kit)
	local function house(x: number, width: number, depth: number, north: boolean, chimney: boolean)
		local facade = if north then -14 else 14 -- 6 stud előkert az utca és a ház között
		local z = if north then facade - depth / 2 else facade + depth / 2
		Kit.building({
			at = V(x, 0, z),
			size = V2(width, depth),
			floors = 2,
			rot = if north then 180 else 0,
			ridge = "x",
			chimney = chimney,
		})
		-- Kerítés az előkert szélén, a kapunál réssel
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

-- Keleti utca, lépcső fel a teraszra; a teraszon kis tér, kilátótorony, kávézó.
local function terrace(Kit)
	local top = 12.4
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
	-- Hátsó lépcső a teraszról le a mezőre (dél felé)
	Kit.stairs(V(150, 0, 76), V(0, 0, -1), 12, top, Enum.Material.Cobblestone, COBBLE)

	local plaza = top + 0.1
	Kit.building({
		at = V(185, top, 0),
		size = V2(12, 12),
		floors = 5,
		rot = 90,
		tier = { floors = 1, scale = 0.7, roof = "cross" },
		clock = "front",
	})
	Kit.building({ at = V(140, top, -30), size = V2(16, 14), floors = 2, rot = 180, chimney = true, ridge = "x" })
	Kit.building({ at = V(162, top, -30), size = V2(14, 14), floors = 3, rot = 180, balconies = { face = "front" } })
	Kit.building({ at = V(140, top, 30), size = V2(16, 14), floors = 2, rot = 0, shop = true, ridge = "x" })
	Kit.building({ at = V(162, top, 30), size = V2(14, 14), floors = 2, rot = 0, ridge = "z", chimney = true })

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

	-- A keleti utca a tér és a lépcső között
	for _, p in { V(70, 0.2, -8.5), V(84, 0.2, 8.5) } do
		Kit.lamp(p)
	end
	Kit.tree(V(76, 0, -20))
	Kit.tree(V(76, 0, 20))
end

-- Déli piac utca üzletekkel, a végén városkapu.
local function marketStreet(Kit)
	local function shop(z: number, width: number, east: boolean, floors: number, extra: { [string]: any }?)
		local spec = {
			at = V(if east then 19 else -19, 0.2, z),
			size = V2(width, 14),
			floors = floors,
			rot = if east then 90 else -90,
		}
		for key, value in extra or {} do
			spec[key] = value
		end
		Kit.building(spec)
	end

	shop(70, 14, true, 2, { shop = true, ridge = "x" })
	shop(83, 10, true, 3, {})
	shop(99, 16, true, 2, { shop = true, ridge = "x" })
	shop(116, 12, true, 3, { balconies = { face = "front" } })
	shop(132, 14, true, 2, { shop = true, ridge = "x" })

	shop(69, 12, false, 3, { shop = true })
	shop(86, 16, false, 2, { shop = true, ridge = "x" })
	shop(100, 10, false, 2, { ridge = "z", chimney = true })
	shop(114, 14, false, 3, { shop = true })
	shop(131, 14, false, 2, { ridge = "x", chimney = true })

	for _, p in { V(-10, 0.2, 78), V(10, 0.2, 92), V(-10, 0.2, 108), V(10, 0.2, 124), V(-10, 0.2, 140) } do
		Kit.lamp(p)
	end
	Kit.stall(V(0, 0.2, 150), 180)

	-- Városkapu: két kis torony és egy kőív
	Kit.building({ at = V(-17, 0.2, 180), size = V2(8, 8), floors = 3, rot = 0, roof = "cross", door = false })
	Kit.building({ at = V(17, 0.2, 180), size = V2(8, 8), floors = 3, rot = 0, roof = "cross", door = false })
	Kit.arch(V(0, 0.2, 180), 0, 20, 10)

	Kit.paintTank(V(0, 0.2, 165), "Orange")
end

-- Park a templom mögött: tavacska, pavilon, fák, padok, két villa a szélén.
local function park(Kit)
	Kit.ground("ParkPath", -3, -150, 3, -72, 0.08, Enum.Material.Pavement, DIRT)
	Kit.ground("ParkPathCross", -45, -113, 45, -107, 0.09, Enum.Material.Pavement, DIRT)
	Kit.pond(V(-25, 0, -128), V2(22, 14))
	Kit.gazebo(V(25, 0, -128), 10)
	for _, p in
		{
			V(-45, 0, -85),
			V(-40, 0, -145),
			V(-12, 0, -92),
			V(14, 0, -142),
			V(42, 0, -86),
			V(48, 0, -145),
			V(-52, 0, -120),
			V(54, 0, -118),
			V(-20, 0, -98),
			V(22, 0, -96),
		}
	do
		Kit.tree(p)
	end
	Kit.bench(V(6, 0.08, -96), 90)
	Kit.bench(V(-6, 0.08, -124), -90)
	Kit.bench(V(-30, 0.09, -104), 180)
	Kit.hedge(V(-40, 0, -76), V(-8, 0, -76))
	Kit.hedge(V(8, 0, -76), V(40, 0, -76))

	Kit.building({ at = V(-40, 0, -168), size = V2(16, 14), floors = 2, rot = 180, chimney = true, ridge = "x" })
	Kit.building({ at = V(40, 0, -168), size = V2(16, 14), floors = 3, rot = 180, roof = "gable", ridge = "x" })

	Kit.paintTank(V(0, 0.08, -110), "Purple")
end

function Level.build(Kit)
	-- Talaj: fű mindenhol, burkolt óváros, utcák
	Kit.ground("Grass", -260, -220, 260, 240, 0, Enum.Material.Grass, GRASS)
	Kit.ground("OldTown", -60, -72, 60, 60, 0.2, Enum.Material.Cobblestone, COBBLE)
	Kit.ground("Square", -36, -36, 36, 36, 0.25, Enum.Material.Slate, SQUARE)
	Kit.ground("WestStreet", -200, -8, -60, 8, 0.2, Enum.Material.Cobblestone, STREET)
	Kit.ground("EastStreet", 60, -8, 92, 8, 0.2, Enum.Material.Cobblestone, STREET)
	Kit.ground("MarketStreet", -12, 60, 12, 200, 0.2, Enum.Material.Cobblestone, STREET)

	square(Kit)
	residentialLane(Kit)
	terrace(Kit)
	marketStreet(Kit)
	park(Kit)
end

return Level
