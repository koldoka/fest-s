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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Common = require(script.Common)
local Buildings = require(script.Buildings)
local Props = require(script.Props)

local newPart = Common.newPart

local Kit = {}

-- Pálya eleje: a LevelLoader hívja.
function Kit.begin(levelFolders: { world: Folder, buildings: Folder, props: Folder, tanks: Folder }, seed: number)
	Common.folders = levelFolders
	Common.rng = Random.new(seed) -- fix mag: a pálya minden indításkor ugyanúgy néz ki
	Buildings.reset()
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
	return Kit.block({
		Name = name,
		Size = Vector3.new(math.abs(x1 - x0), top - bottom, math.abs(z1 - z0)),
		Position = Vector3.new((x0 + x1) / 2, (bottom + top) / 2, (z0 + z1) / 2),
		Material = material,
		Color = color,
	})
end

-- Lépcső: "from" az első fok eleje a talajon (középen), "dir" merre megy fel, "rise" a teljes magasság.
-- A fokok tömörek (a talajig érnek), 1 stud magasak és 2 stud mélyek.
function Kit.stairs(from: Vector3, dir: Vector3, width: number, rise: number, material: Enum.Material?, color: Color3?)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local steps = math.ceil(rise)
	local run = 2
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

function Kit.paintTank(at: Vector3, colorName: string)
	local color = Config.PAINT_COLOR_BY_NAME[colorName]
	assert(color, `Unknown paint color: {colorName}`)
	-- Álló henger: a Roblox hengerének tengelye az X, ezért 90 fokkal elforgatjuk.
	local tank = newPart({
		Name = colorName .. "Tank",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 6, 6),
		CFrame = CFrame.new(at + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		CanCollide = false, -- bele lehet ugrani
	})
	tank:SetAttribute("ColorName", colorName)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 2
	light.Parent = tank
	tank.Parent = Common.folders.tanks
end

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
