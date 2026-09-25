-- Építőkészlet a kézzel tervezett pályákhoz (src/server/Levels). Egy pálya így néz ki:
--   Kit.ground("Square", -36, -36, 36, 36, 0.2, Enum.Material.Cobblestone, Color3.fromRGB(150, 146, 140))
--   Kit.building({ at = Vector3.new(0, 0.2, -53), size = Vector2.new(22, 34), floors = 3, rot = 180 })
--   Kit.tree(Vector3.new(20, 0.2, 20))
--   Kit.paintTank(Vector3.new(-28, 0.2, -28), "Red")
--
-- Irányok: a "front" (homlokzat) a helyi -Z. A rot fokban, a függőleges tengely körül:
--   rot = 0   -> a homlokzat északra (-Z) néz      rot = 180 -> délre (+Z)
--   rot = 90  -> nyugatra (-X)                     rot = -90 -> keletre (+X)
--
-- Festhető dolgok:
--   épületek (Kit.building, részletek: Kit/Buildings.luau): a játékos befesti a saját színével, pont jár érte;
--   tárgyak (Kit.tree, Kit.bench…, Kit/Props.luau): érintésre színesek lesznek, ez festéket nem fogyaszt.
-- A világ többi része (talaj, lépcső, víz, híd) nem festhető.

local Common = require(script.Common)
local Buildings = require(script.Buildings)
local Props = require(script.Props)

local newPart = Common.newPart

local Kit = {}

-- Pálya eleje: a LevelLoader hívja.
function Kit.begin(levelFolders: { world: Folder, buildings: Folder, props: Folder, tanks: Folder }, seed: number)
	Common.folders = levelFolders
	Common.rng = Random.new(seed) -- fix mag: a pálya minden indításkor ugyanúgy néz ki
	Common.footprints = {}
	Common.surfaces = {}
	Kit.tankSpots = {}
	Buildings.reset()
end

-- A festéktartályok lehetséges helyei (a TankService ezek közül választ véletlenszerűen).
Kit.tankSpots = {} :: { Vector3 }

function Kit.tankSpot(at: Vector3)
	table.insert(Kit.tankSpots, at)
end

-- Pálya vége: a LevelLoader hívja, miután minden elem a helyén van.
function Kit.finish()
	Buildings.finish()
end

function Kit.random(): Random
	return Common.rng
end

Kit.building = Buildings.building
for name, fn in Props do
	(Kit :: any)[name] = fn
end

---------------------------------------------------------------------------------------------------
-- Világ: talaj, lépcső, víz, híd (nem festhetők)

function Kit.block(props: { [string]: any }): BasePart
	local part = newPart(props)
	part.Parent = Common.folders.world
	return part
end

-- Téglalap alakú talajlap (x0, z0) és (x1, z1) között; "top" a felszín magassága.
function Kit.ground(
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	top: number,
	material: Enum.Material,
	color: Color3
): BasePart
	return Kit.block({
		Name = name,
		Size = Vector3.new(math.abs(x1 - x0), 0.4, math.abs(z1 - z0)),
		Position = Vector3.new((x0 + x1) / 2, top - 0.2, (z0 + z1) / 2),
		Material = material,
		Color = color,
	})
end

-- Tömör talajtömb (x0, z0)-(x1, z1) között a "bottom" és "top" magasság között (dombok, teraszok, rakpartok).
function Kit.mound(
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	bottom: number,
	top: number,
	material: Enum.Material,
	color: Color3
): BasePart
	-- A teteje felszín (ott a talaj "top" magasan van), a széle foglalt.
	table.insert(
		Common.surfaces,
		{ rect = Common.rect((x0 + x1) / 2, (z0 + z1) / 2, math.abs(x1 - x0) / 2, math.abs(z1 - z0) / 2), top = top }
	)
	return Kit.block({
		Name = name,
		Size = Vector3.new(math.abs(x1 - x0), top - bottom, math.abs(z1 - z0)),
		Position = Vector3.new((x0 + x1) / 2, (bottom + top) / 2, (z0 + z1) / 2),
		Material = material,
		Color = color,
	})
end

-- Burkolt tér: talajlap, amely foglaltnak is számít (a kitöltés nem tesz rá semmit).
function Kit.plaza(
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	top: number,
	material: Enum.Material,
	color: Color3
): BasePart
	Common.occupy(Common.rect((x0 + x1) / 2, (z0 + z1) / 2, math.abs(x1 - x0) / 2, math.abs(z1 - z0) / 2))
	return Kit.ground(name, x0, z0, x1, z1, top, material, color)
end

-- Kanyargó utca pontok mentén: egyenes darabok, a töréspontokban kerek csatlakozással.
-- A pontok magassága (Y) az utca felszíne. margin: ekkora sáv számít foglaltnak az utca két szélén (járda).
local pathIndex = 0
function Kit.path(
	name: string,
	points: { Vector3 },
	width: number,
	material: Enum.Material,
	color: Color3,
	margin: number?
)
	pathIndex += 1
	local lift = (pathIndex % 7) * 0.003 -- az egymást keresztező utcák ne villogjanak
	local m = margin or 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		local mid = (a + b) / 2
		local top = mid.Y + lift
		Kit.block({
			Name = name,
			Size = Vector3.new(width, 0.4, length),
			CFrame = CFrame.lookAt(Vector3.new(mid.X, top - 0.2, mid.Z), Vector3.new(mid.X, top - 0.2, mid.Z) + flat),
			Material = material,
			Color = color,
		})
		local rot = math.deg(math.atan2(flat.X, flat.Z))
		Common.occupy(Common.rect(mid.X, mid.Z, width / 2 + m, length / 2 + width / 2, rot))
	end
	for i = 2, #points - 1 do
		local p = points[i]
		Kit.block({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, width, width),
			CFrame = CFrame.new(p.X, p.Y + lift - 0.21, p.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Material = material,
			Color = color,
		})
	end
end

-- Házsor egy utca mentén (a pontok ugyanazok, mint a Kit.path-nál). A házak a homlokzattal az utca felé néznek,
-- szélességük, mélységük, emeletszámuk és stílusuk a megadott tartományokból sorsolódik (fix maggal), és csak oda
-- kerülnek, ahol szabad a hely. opts:
--   side = "both" | "left" | "right", street = az utca szélessége, setback = távolság az utca szélétől (legalább 4),
--   widths = {min, max}, depths = {min, max}, floors = {min, max}, gaps = {min, max}, margin = kihagyás a sarkoknál,
--   shops = esély üzletre, chimney = esély kéményre, materials = {...}, windows = {...}, balconies = esély
function Kit.streetRow(points: { Vector3 }, opts: { [string]: any })
	local rng = Common.rng
	local sides = if opts.side == "left" then { 1 } elseif opts.side == "right" then { -1 } else { 1, -1 }
	local street = opts.street or 10
	-- Az utca foglalt sávja (a járda) 2 stud, a ház előtti ráhagyás 1.8: ennél kisebb előkertnél nem férne el.
	local setback = math.max(opts.setback or 4, 4)
	local margin = opts.margin or 8
	local function range(r: { number }): number
		return rng:NextInteger(r[1], r[2])
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		local dir = flat.Unit
		local normal = Vector3.new(-dir.Z, 0, dir.X)
		for _, side in sides do
			local t = margin
			while true do
				local width = range(opts.widths or { 9, 15 })
				local depth = range(opts.depths or { 10, 13 })
				if t + width > length - margin then
					break
				end
				local out = normal * side
				local pos = a + dir * (t + width / 2) + out * (street / 2 + setback + depth / 2)
				local rot = math.deg(math.atan2(out.X, out.Z))
				local ground = Common.groundAt(pos.X, pos.Z, math.max(width, depth) / 2 + 1)
				local rect = Common.rect(pos.X, pos.Z, width / 2 + 0.5, depth / 2 + 1.8, rot)
				if ground and Common.isFree(rect) then
					local floors = range(opts.floors or { 2, 2 })
					local shop = rng:NextNumber() < (opts.shops or 0)
					Kit.building({
						at = Vector3.new(pos.X, ground, pos.Z),
						size = Vector2.new(width, depth),
						floors = floors,
						rot = rot,
						shop = shop,
						ridge = if rng:NextNumber() < 0.7 then "x" else "z",
						roof = if floors <= 2 or rng:NextNumber() < 0.4 then "gable" else "flat",
						chimney = rng:NextNumber() < (opts.chimney or 0.5),
						material = Common.pick(opts.materials or { "plaster", "plaster", "brick", "wood" }),
						windows = if shop then "plain" else Common.pick(opts.windows or { "plain", "shutters" }),
						balconies = if floors >= 3 and rng:NextNumber() < (opts.balconies or 0.3)
							then { face = "front" }
							else nil,
						corners = rng:NextNumber() < 0.25,
					})
					t += width + range(opts.gaps or { 2, 6 })
				else
					t += 3
				end
			end
		end
	end
end

-- Kitöltés: a (x0, z0)-(x1, z1) területet "cell" méretű cellákra, a cellákat 3×3-as telkekre osztja, és minden
-- szabad cellába tesz valamit. Egy telken belül egy téma van (pl. gyümölcsös, veteményeskert, rét, liget), így a
-- kitöltés természetesebb, nem cellánként véletlenszerű. A fészer és a kút ritka, és távol kerülnek egymástól.
-- zone(x, z) mondja meg a hely jellegét: "garden", "park", "farm", "yard", vagy nil (üresen marad).
local THEMES = {
	garden = { { "orchard", 3 }, { "veggies", 3 }, { "meadow", 2 }, { "grove", 2 } },
	park = { { "grove", 4 }, { "meadow", 3 }, { "flowers", 2 } },
	farm = { { "field", 5 }, { "orchard", 2 }, { "meadow", 1 } },
	yard = { { "yard", 1 } },
}

local function pickTheme(rng: Random, kind: string): string
	local list = THEMES[kind]
	local total = 0
	for _, t in list do
		total += t[2]
	end
	local roll = rng:NextNumber() * total
	for _, t in list do
		roll -= t[2]
		if roll <= 0 then
			return t[1]
		end
	end
	return list[1][1]
end

function Kit.fill(x0: number, z0: number, x1: number, z1: number, cell: number, zone: (number, number) -> string?)
	local rng = Common.rng
	local half = cell / 2
	local specials: { { pos: Vector3, kind: string } } = {} -- fészrek és kutak, a ritkításhoz
	local function farFrom(kind: string, pos: Vector3, distance: number): boolean
		for _, sp in specials do
			if sp.kind == kind and (sp.pos - pos).Magnitude < distance then
				return false
			end
		end
		return true
	end

	local plot = cell * 3
	for px = x0, x1 - cell, plot do
		for pz = z0, z1 - cell, plot do
			local themeByKind: { [string]: string } = {}
			local plotRot = rng:NextInteger(0, 3) * 90 + rng:NextNumber(-10, 10)
			local shedDone = false
			for cx = 0, 2 do
				for cz = 0, 2 do
					local x = px + cx * cell + half
					local z = pz + cz * cell + half
					if x > x1 - half or z > z1 - half then
						continue
					end
					local kind = zone(x, z)
					local rect = Common.rect(x, z, half - 0.5, half - 0.5)
					local ground = Common.groundAt(x, z, half)
					if not (kind and ground and Common.isFree(rect)) then
						continue
					end
					Common.occupy(rect)
					local theme = themeByKind[kind] or pickTheme(rng, kind)
					themeByKind[kind] = theme
					local center = Vector3.new(x, ground, z)
					local jitter = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * half * 0.35
					local at = center + jitter
					local roll = rng:NextNumber()

					if theme == "orchard" then
						-- Gyümölcsfák közel szabályos sorban, a fák alatt néha egy bokor
						Props.fruitTree(center + jitter * 0.3)
					elseif theme == "veggies" then
						if not shedDone and roll < 0.12 and farFrom("shed", center, 60) then
							Props.shed(center, plotRot)
							table.insert(specials, { pos = center, kind = "shed" })
							shedDone = true
						else
							Props.vegetablePatch(center, plotRot, cell - 2.5)
						end
					elseif theme == "meadow" then
						Props.wildflowers(at)
						if roll < 0.35 then
							Props.bush(center - jitter, rng:NextNumber(0.7, 1.1))
						end
					elseif theme == "grove" then
						if roll < 0.75 then
							Props.tree(at, rng:NextNumber(0.8, 1.2))
						else
							Props.bush(at, rng:NextNumber(0.9, 1.3))
						end
					elseif theme == "flowers" then
						if roll < 0.5 then
							Props.flowerBed(at, rng:NextNumber(2.5, half - 1.5))
						else
							Props.wildflowers(at)
						end
					elseif theme == "field" then
						if roll < 0.08 then
							Props.haystack(at)
						else
							Props.vegetablePatch(center, plotRot, cell - 0.5)
						end
					elseif theme == "yard" then
						if roll < 0.1 and farFrom("well", center, 90) then
							Props.well(center)
							table.insert(specials, { pos = center, kind = "well" })
						elseif roll < 0.4 then
							Props.tree(at, 0.8)
						elseif roll < 0.6 then
							Props.planter(at, plotRot, 4)
						elseif roll < 0.75 then
							Props.crates(at, plotRot)
						else
							Props.bush(at, 1)
						end
					end
				end
			end
		end
	end
end

-- Városfal a pálya szélén: négyzet alakú, lőréses kőfal tornyokkal (a tornyok festhetők), a kijáratoknál bezárt
-- kapukkal, és egy láthatatlan magas fallal, hogy ne lehessen kiugrani. half: a fal középvonala ennyire van a
-- középponttól. gates: a kapuk helye {side = "north"|"south"|"east"|"west", at = a fal menti koordináta}.
function Kit.townWall(half: number, gates: { { side: string, at: number } })
	local stone = Color3.fromRGB(168, 156, 136)
	local height, thick = 16, 4
	local sides = {
		north = { center = Vector3.new(0, 0, -half), along = Vector3.xAxis },
		south = { center = Vector3.new(0, 0, half), along = Vector3.xAxis },
		west = { center = Vector3.new(-half, 0, 0), along = Vector3.zAxis },
		east = { center = Vector3.new(half, 0, 0), along = Vector3.zAxis },
	}
	for name, sideInfo in sides do
		local c, along = sideInfo.center, sideInfo.along
		local len = half * 2 + thick
		local size = if along.X ~= 0
			then Vector3.new(len, height + 3.2, thick)
			else Vector3.new(thick, height + 3.2, len)
		Kit.block({
			Name = "TownWall",
			Size = size,
			Position = c + Vector3.new(0, (height - 3.2) / 2, 0),
			Material = Enum.Material.Cobblestone,
			Color = stone,
		})
		-- Lőrések (pártázat) a fal tetején
		for t = -half, half, 6 do
			local p = c + along * t + Vector3.new(0, height + 1.2, 0)
			Kit.block({
				Name = "Merlon",
				Size = Vector3.new(2.6, 2.4, 2.6),
				Position = p,
				Material = Enum.Material.Cobblestone,
				Color = stone,
			})
		end
		-- Láthatatlan akadály a fal fölött
		local barrier = if along.X ~= 0 then Vector3.new(len, 200, thick) else Vector3.new(thick, 200, len)
		Kit.block({
			Name = "Barrier",
			Size = barrier,
			Position = c + Vector3.new(0, 100, 0),
			Transparency = 1,
			CastShadow = false,
		})
		local wallRect = if along.X ~= 0
			then Common.rect(c.X, c.Z, len / 2, thick / 2 + 3)
			else Common.rect(c.X, c.Z, thick / 2 + 3, len / 2)
		Common.occupy(wallRect)
		-- Tornyok: a sarkokban (a nyugati és keleti oldalon) és félúton
		local towerAt = { 0 }
		if name == "west" or name == "east" then
			towerAt = { -half, 0, half }
		end
		for _, t in towerAt do
			local isGate = false
			for _, g in gates do
				if g.side == name and math.abs(g.at - t) < 16 then
					isGate = true
				end
			end
			if not isGate then
				local p = c + along * t
				Kit.building({
					at = Vector3.new(p.X, 0, p.Z),
					size = Vector2.new(12, 12),
					floors = 4,
					roof = "cross",
					door = false,
					windows = "none",
					material = "stone",
					corners = true,
				})
			end
		end
	end
	-- Kapuk: kaputorony (festhető), előtte bezárt kétszárnyú fakapu
	for _, g in gates do
		local info = sides[g.side]
		local p = info.center + info.along * g.at
		local inward = -info.center.Unit
		local rot = math.deg(math.atan2(inward.X, inward.Z))
		Kit.building({
			at = Vector3.new(p.X, 0, p.Z),
			size = Vector2.new(18, 10),
			floors = 3,
			rot = rot,
			roof = "gable",
			ridge = "x",
			door = false,
			windows = "none",
			material = "stone",
			corners = true,
		})
		local gateCf = CFrame.lookAt(p + inward * 5.2 + Vector3.new(0, 4, 0), p + inward * 10 + Vector3.new(0, 4, 0))
		for _, x in { -1.6, 1.6 } do
			Kit.block({
				Name = "Gate",
				Size = Vector3.new(3.1, 8, 0.6),
				CFrame = gateCf * CFrame.new(x, 0, 0),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(110, 76, 50),
			})
		end
		Kit.block({
			Name = "GateArch",
			Size = Vector3.new(8, 1, 0.8),
			CFrame = gateCf * CFrame.new(0, 4.5, 0.1),
			Material = Enum.Material.Cobblestone,
			Color = Common.darker(stone, 0.2),
		})
	end
end

-- Erdő a városfalon kívül (díszlet): fák egy gyűrűben a fal és a pálya széle között.
function Kit.forest(inner: number, outer: number, spacing: number)
	local rng = Common.rng
	for x = -outer, outer, spacing do
		for z = -outer, outer, spacing do
			if math.max(math.abs(x), math.abs(z)) > inner then
				local p = Vector3.new(
					x + rng:NextNumber(-spacing, spacing) * 0.4,
					0,
					z + rng:NextNumber(-spacing, spacing) * 0.4
				)
				Props.forestTree(Common.folders.world, p, rng:NextNumber(1, 1.6))
			end
		end
	end
end

-- A fokok tömörek (a talajig érnek), 1 stud magasak és 2 stud mélyek.
function Kit.stairs(from: Vector3, dir: Vector3, width: number, rise: number, material: Enum.Material?, color: Color3?)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local steps = math.ceil(rise)
	local run = 2
	local mid = from + dir * (steps * run / 2)
	Common.occupy(Common.rect(mid.X, mid.Z, width / 2 + 1, steps * run / 2 + 2, math.deg(math.atan2(dir.X, dir.Z))))
	for i = 1, steps do
		local height = math.min(i, rise)
		local center = from + dir * (run * (i - 0.5)) + Vector3.new(0, height / 2, 0)
		Kit.block({
			Name = "Step",
			Size = Vector3.new(width, height, run),
			CFrame = CFrame.lookAt(center, center + dir),
			Material = material or Enum.Material.Concrete,
			Color = color or Color3.fromRGB(160, 158, 152),
		})
	end
end

-- Vízfelszín (x0, z0)-(x1, z1) között "top" magasságban. Át lehet rajta esni (a meder alatta van).
function Kit.water(name: string, x0: number, z0: number, x1: number, z1: number, top: number): BasePart
	Common.occupy(Common.rect((x0 + x1) / 2, (z0 + z1) / 2, math.abs(x1 - x0) / 2 + 3, math.abs(z1 - z0) / 2))
	return Kit.block({
		Name = name,
		Size = Vector3.new(math.abs(x1 - x0), 0.4, math.abs(z1 - z0)),
		Position = Vector3.new((x0 + x1) / 2, top - 0.2, (z0 + z1) / 2),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(78, 150, 200),
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
	})
end

-- Kőhíd "from"-tól "to"-ig (a két hídfő a talajon), korláttal. A korlát festhető kerítés.
function Kit.bridge(from: Vector3, to: Vector3, width: number, archHeight: number?)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	Common.occupy(Common.rect(mid.X, mid.Z, width / 2 + 1, length / 2 + 2, math.deg(math.atan2(dir.X, dir.Z))))
	local deck = CFrame.lookAt(mid, mid + dir)
	local stone = Color3.fromRGB(176, 166, 150)
	Kit.block({
		Name = "BridgeDeck",
		Size = Vector3.new(width, 1, length),
		CFrame = deck * CFrame.new(0, -0.5, 0),
		Material = Enum.Material.Cobblestone,
		Color = stone,
	})
	-- Ív alatta (csak látvány): két ferde lap
	local rise = archHeight or 3
	for _, sign in { -1, 1 } do
		local half = length / 2
		local slant = math.sqrt(half * half + rise * rise)
		local angle = math.atan2(rise, half)
		Kit.block({
			Name = "BridgeArch",
			Size = Vector3.new(width - 0.4, 0.8, slant),
			CFrame = deck * CFrame.new(0, -1 - rise / 2, sign * half / 2) * CFrame.Angles(sign * angle, 0, 0),
			Material = Enum.Material.Cobblestone,
			Color = Common.darker(stone, 0.1),
			CanCollide = false,
		})
	end
	local side = deck.RightVector * (width / 2 - 0.3)
	Props.fence(from + side, to + side)
	Props.fence(from - side, to - side)
end

---------------------------------------------------------------------------------------------------
-- Játékelemek

function Kit.spawn(at: Vector3, rot: number?)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(rot or 0), 0)
	spawn.Color = Color3.fromRGB(240, 240, 240)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0 -- nincs védőpajzs a születéskor
	spawn.Parent = Common.folders.world
end

return Kit
