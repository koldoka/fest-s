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
--   épületek (Buildings mappa): a játékos befesti a saját színével, pontot kap érte;
--   tárgyak (Props mappa): érintésre visszakapják a természetes színüket, ez festéket nem fogyaszt.
-- Minden részletnek van szerepe (Role) és alapszíne (BaseColor); a tárgyaknak fix színük is (PaintedColor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Kit = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local folders: { world: Folder, buildings: Folder, props: Folder, tanks: Folder }
local rng = Random.new(1)

-- Oldalak helyi irányai és a hozzájuk tartozó NormalId (a textúrákhoz).
local FACES = {
	front = { dir = -Vector3.zAxis, normal = Enum.NormalId.Front },
	back = { dir = Vector3.zAxis, normal = Enum.NormalId.Back },
	left = { dir = -Vector3.xAxis, normal = Enum.NormalId.Left },
	right = { dir = Vector3.xAxis, normal = Enum.NormalId.Right },
}

---------------------------------------------------------------------------------------------------
-- Segédek

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(BLACK, amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(WHITE, amount)
end

-- Egy szín szürke változata (a festetlen világhoz): a világossága marad, a színe eltűnik.
local function toGrey(color: Color3): Color3
	local l = 0.3 * color.R + 0.59 * color.G + 0.11 * color.B
	return Color3.new(l, l, l):Lerp(Config.BUILDINGS.GREY, 0.35)
end

local function greyShade(): Color3
	local b = Config.BUILDINGS
	local offset = rng:NextInteger(-b.GREY_VARIANCE, b.GREY_VARIANCE) / 255
	return Color3.new(
		math.clamp(b.GREY.R + offset, 0, 1),
		math.clamp(b.GREY.G + offset, 0, 1),
		math.clamp(b.GREY.B + offset, 0, 1)
	)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function newPart(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	return part
end

local function faceWidth(size: Vector3, dir: Vector3): number
	return if dir.X ~= 0 then size.Z else size.X
end

-- Vízszintes irány a fal mentén (a részletek szimmetrikusak, az előjel mindegy).
local function alongFace(dir: Vector3): Vector3
	return dir:Cross(Vector3.yAxis).Unit
end

-- Helyi eltolás egy oldal elé: kifelé "out" studdal, a fal mentén "shift"-tel, "y" magasan (a tömb aljától).
local function onFace(part: BasePart, dir: Vector3, out: number, shift: number, y: number): CFrame
	local half = part.Size / 2
	local offset = dir * (math.abs(dir:Dot(half)) + out) + alongFace(dir) * shift + Vector3.new(0, -half.Y + y, 0)
	return part.CFrame * CFrame.new(offset)
end

---------------------------------------------------------------------------------------------------
-- Pálya eleje: a LevelLoader hívja

function Kit.begin(levelFolders: { world: Folder, buildings: Folder, props: Folder, tanks: Folder }, seed: number)
	folders = levelFolders
	rng = Random.new(seed) -- fix mag: a pálya minden indításkor ugyanúgy néz ki
end

function Kit.random(): Random
	return rng
end

---------------------------------------------------------------------------------------------------
-- Világ: talaj, falak, lépcsők (nem festhetők)

function Kit.block(props: { [string]: any }): BasePart
	local part = newPart(props)
	part.Parent = folders.world
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

---------------------------------------------------------------------------------------------------
-- Épületek

-- Részlet az épületen. baseColor: festetlen szín; paintedColor: fix szín befestve (ha nincs, a szerep dönt).
local function detail(
	parent: BasePart,
	role: string,
	props: { [string]: any },
	baseColor: Color3,
	paintedColor: Color3?
): BasePart
	props.Name = role
	props.Color = baseColor
	local part = newPart(props)
	part:SetAttribute("Role", role)
	part:SetAttribute("BaseColor", baseColor)
	if paintedColor then
		part:SetAttribute("PaintedColor", paintedColor)
	end
	part.Parent = parent
	return part
end

-- Ablakok egy tömb négy oldalán: textúra, vagy ha nincs feltöltve, emeletenként egy ablaksáv.
local function addWindows(part: BasePart, floors: number)
	local b = Config.BUILDINGS
	if b.FACADE.GREY ~= "" and b.FACADE.LIT ~= "" then
		for _, face in FACES do
			local width = faceWidth(part.Size, face.dir)
			local bays = math.max(1, math.round(width / b.BAY_WIDTH))
			local texture = Instance.new("Texture")
			texture.Texture = b.FACADE.GREY
			texture.Face = face.normal
			texture.StudsPerTileU = width / bays
			texture.StudsPerTileV = b.FLOOR_HEIGHT
			texture:SetAttribute("Role", "Facade")
			texture.Parent = part
		end
		return
	end
	-- Tartalék: ablaksávok
	for floor = 1, floors do
		local y = (floor - 0.5) * b.FLOOR_HEIGHT + 0.5
		for _, face in FACES do
			local width = faceWidth(part.Size, face.dir) - 2
			local size = if face.dir.X ~= 0 then Vector3.new(0.2, 2.5, width) else Vector3.new(width, 2.5, 0.2)
			detail(
				part,
				"Window",
				{ Size = size, CFrame = onFace(part, face.dir, 0.1, 0, y), CanCollide = false },
				darker(part.Color, 0.3)
			)
		end
	end
end

local function addPlinth(body: BasePart)
	local s = body.Size
	detail(body, "Plinth", {
		Size = Vector3.new(s.X + 0.4, 1, s.Z + 0.4),
		CFrame = body.CFrame * CFrame.new(0, -s.Y / 2 + 0.5, 0),
	}, darker(body.Color, 0.3))
end

-- Tetőperem (párkány) egy tömb tetején.
local function addTrim(body: BasePart, onPart: BasePart, height: number)
	local s = onPart.Size
	detail(body, "Trim", {
		Size = Vector3.new(s.X + 0.6, height, s.Z + 0.6),
		CFrame = onPart.CFrame * CFrame.new(0, s.Y / 2 + height / 2 - 0.3, 0),
	}, lighter(body.Color, 0.25))
end

-- Nyeregtető: egy 45 fokkal elforgatott hasáb; az alsó fele a tömbben van, a felső fele a tető.
-- ridge = "x" vagy "z": a gerinc iránya (alapból a hosszabbik oldallal párhuzamos).
-- Visszaadja a tető magasságát a tömb teteje fölött.
local function addGable(body: BasePart, onPart: BasePart, ridge: string?, roofColor: Color3?): (number, boolean, number)
	local s = onPart.Size
	local alongX = if ridge then ridge == "x" else s.X >= s.Z
	local span = if alongX then s.Z else s.X
	local diagonal = span + 1.2 -- kis eresz
	local side = diagonal / math.sqrt(2)
	local length = (if alongX then s.X else s.Z) + 1
	local top = onPart.CFrame * CFrame.new(0, s.Y / 2, 0)
	local rotation = if alongX then CFrame.Angles(math.rad(45), 0, 0) else CFrame.Angles(0, 0, math.rad(45))
	local size = if alongX then Vector3.new(length, side, side) else Vector3.new(side, side, length)
	detail(
		body,
		"Roof",
		{ Size = size, CFrame = top * rotation },
		darker(body.Color, 0.25),
		roofColor or pick(Config.BUILDINGS.ROOF_COLORS)
	)
	return diagonal / 2, alongX, span
end

-- Kereszt-nyeregtető tornyokra: két, egymásra merőleges nyeregtető.
local function addCrossRoof(body: BasePart, onPart: BasePart, roofColor: Color3?)
	local color = roofColor or pick(Config.BUILDINGS.ROOF_COLORS)
	addGable(body, onPart, "x", color)
	addGable(body, onPart, "z", color)
end

local function addChimney(body: BasePart, roofHeight: number, alongX: boolean, span: number)
	local s = body.Size
	local out = span * 0.22 -- ennyire van a gerinctől; a tető ott (45 fok) ennyivel alacsonyabb
	local roofHere = roofHeight - out
	local offset = if alongX then Vector3.new(s.X * 0.25, 0, out) else Vector3.new(out, 0, s.Z * 0.25)
	detail(body, "Chimney", {
		Size = Vector3.new(1.4, 4, 1.4),
		CFrame = body.CFrame * CFrame.new(offset + Vector3.new(0, s.Y / 2 + roofHere + 1, 0)),
	}, darker(body.Color, 0.2), Config.BUILDINGS.CHIMNEY_COLOR)
end

local function addDoor(body: BasePart, dir: Vector3, shift: number, doorColor: Color3?)
	local b = Config.BUILDINGS
	local size = if dir.X ~= 0
		then Vector3.new(0.3, b.DOOR_SIZE.Y, b.DOOR_SIZE.X)
		else Vector3.new(b.DOOR_SIZE.X, b.DOOR_SIZE.Y, 0.3)
	detail(
		body,
		"Door",
		{ Size = size, CFrame = onFace(body, dir, 0.15, shift, b.DOOR_SIZE.Y / 2) },
		darker(body.Color, 0.45),
		doorColor or pick(b.DOOR_COLORS)
	)
end

-- Kirakat és csíkos napellenző a földszinten; az ajtó a kirakat mellé kerül.
local function addShopfront(body: BasePart, dir: Vector3)
	local width = faceWidth(body.Size, dir)
	local doorSide = if rng:NextNumber() < 0.5 then -1 else 1
	addDoor(body, dir, doorSide * width * 0.3)

	local windowWidth = width * 0.5
	local windowSize = if dir.X ~= 0 then Vector3.new(0.3, 3.4, windowWidth) else Vector3.new(windowWidth, 3.4, 0.3)
	detail(body, "ShopWindow", {
		Size = windowSize,
		CFrame = onFace(body, dir, 0.15, -doorSide * width * 0.18, 2.9),
		Material = Enum.Material.Glass,
		Reflectance = 0.15,
	}, Color3.fromRGB(82, 96, 118))

	-- Napellenző: lefelé lejtő lap csíkokból. A lap síkjának normálisa a függőlegestől kifelé dől.
	local stripes = 7
	local awningWidth = width * 0.92
	local depth = 2.4
	local tilt = math.rad(22)
	local along = alongFace(dir)
	local normal = Vector3.yAxis * math.cos(tilt) + dir * math.sin(tilt)
	local half = body.Size / 2
	local outward = math.abs(dir:Dot(half))
	local topY = -half.Y + 5.6
	for i = 1, stripes do
		local lateral = ((i - 0.5) / stripes - 0.5) * awningWidth
		local center = dir * (outward + depth / 2 * math.cos(tilt))
			+ along * lateral
			+ Vector3.new(0, topY - depth / 2 * math.sin(tilt), 0)
		local role = if i % 2 == 1 then "AwningA" else "AwningB"
		local base = if i % 2 == 1 then darker(body.Color, 0.2) else lighter(body.Color, 0.3)
		detail(body, role, {
			Size = Vector3.new(awningWidth / stripes, 0.25, depth),
			CFrame = body.CFrame * CFrame.fromMatrix(center, along, normal),
		}, base)
	end
end

-- Erkélyek a második emelettől egy oszlopban: padló + korlát.
local function addBalconies(body: BasePart, dir: Vector3, floors: number, shift: number)
	local b = Config.BUILDINGS
	local width = math.min(faceWidth(body.Size, dir) * 0.45, 7)
	for floor = 2, floors do
		local y = (floor - 1) * b.FLOOR_HEIGHT
		local slab = if dir.X ~= 0 then Vector3.new(1.8, 0.3, width) else Vector3.new(width, 0.3, 1.8)
		detail(
			body,
			"Balcony",
			{ Size = slab, CFrame = onFace(body, dir, 0.9, shift, y + 0.15) },
			lighter(body.Color, 0.25)
		)
		local rail = if dir.X ~= 0 then Vector3.new(0.2, 1.2, width) else Vector3.new(width, 1.2, 0.2)
		detail(
			body,
			"Railing",
			{ Size = rail, CFrame = onFace(body, dir, 1.7, shift, y + 0.9) },
			darker(body.Color, 0.4),
			b.RAILING_COLOR
		)
	end
end

-- Óra a torony egyik oldalán.
local function addClock(body: BasePart, onPart: BasePart, dir: Vector3, y: number)
	local diameter = math.min(faceWidth(onPart.Size, dir) * 0.7, 6)
	local center = onFace(onPart, dir, 0.2, 0, y)
	-- A henger tengelye (helyi X) nézzen kifelé.
	local facing = CFrame.fromMatrix(center.Position, (center.Rotation * dir).Unit, Vector3.yAxis)
	detail(
		body,
		"Clock",
		{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, diameter, diameter), CFrame = facing },
		lighter(body.Color, 0.3),
		Color3.fromRGB(250, 246, 232)
	)
	local hand = Color3.fromRGB(40, 40, 50)
	detail(body, "Metal", {
		Size = Vector3.new(0.2, diameter * 0.38, 0.35),
		CFrame = facing * CFrame.new(0.2, diameter * 0.17, 0),
		CanCollide = false,
	}, darker(body.Color, 0.5), hand)
	detail(body, "Metal", {
		Size = Vector3.new(0.2, 0.3, diameter * 0.28),
		CFrame = facing * CFrame.new(0.25, 0, diameter * 0.12),
		CanCollide = false,
	}, darker(body.Color, 0.5), hand)
end

--[[
Egy épület. A spec mezői:
  at        Vector3   a talajpont a ház közepén (a magassága a talaj felszíne)
  size      Vector2   homlokzat szélessége (helyi X) × mélység (helyi Z)
  floors    number    emeletek száma (alapból 2)
  rot       number    elforgatás fokban (lásd a fájl elején)
  roof      string    "gable" (nyeregtető), "flat" (lapos, párkánnyal), "cross" (kereszt-nyeregtető); alapból
                      2 emeletig nyeregtető, fölötte lapos
  ridge     string    nyeregtetőnél a gerinc iránya: "x" (a homlokzattal párhuzamos) vagy "z"
  roofColor Color3    fix tetőszín (alapból véletlen a Config.BUILDINGS.ROOF_COLORS-ból)
  chimney   boolean   kémény a nyeregtetőn
  door      table|false  { face = "front", shift = 0 } — az ajtó oldala és eltolása; false = nincs ajtó
  shop      boolean   kirakat és napellenző az ajtós oldalon
  balconies table     { face = "front", shift = 0 } — erkélyek a második emelettől
  tier      table     { floors = 1, scale = 0.65, roof = "flat" } — kisebb felső emelet (toronyházak, tornyok)
  clock     string    óra ezen az oldalon (a felső emeleten, ha van)
]]
function Kit.building(spec: { [string]: any }): BasePart
	local b = Config.BUILDINGS
	local floors = spec.floors or 2
	local height = floors * b.FLOOR_HEIGHT
	local grey = greyShade()
	local body = newPart({
		Name = "Building",
		Size = Vector3.new(spec.size.X, height, spec.size.Y),
		CFrame = CFrame.new(spec.at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(spec.rot or 0), 0),
		Color = grey,
	})
	body:SetAttribute("BaseColor", grey) -- ide áll vissza a pálya újrakezdésekor
	body:SetAttribute("ColorName", "") -- "" = még festetlen

	addPlinth(body)
	addWindows(body, floors)

	local door = if spec.door == nil then { face = "front", shift = 0 } else spec.door
	if spec.shop then
		addShopfront(body, FACES[(door and door.face) or "front"].dir)
	elseif door then
		addDoor(body, FACES[door.face or "front"].dir, door.shift or 0)
	end
	if spec.balconies then
		addBalconies(body, FACES[spec.balconies.face or "front"].dir, floors, spec.balconies.shift or 0)
	end

	-- A tető a legfelső tömbre kerül: a felső emeletre, ha van, különben a testre.
	local top = body
	if spec.tier then
		local tierFloors = spec.tier.floors or 1
		local scale = spec.tier.scale or 0.65
		local tierHeight = tierFloors * b.FLOOR_HEIGHT
		addTrim(body, body, 1)
		top = detail(body, "Tier", {
			Size = Vector3.new(body.Size.X * scale, tierHeight, body.Size.Z * scale),
			CFrame = body.CFrame * CFrame.new(0, height / 2 + 0.5 + tierHeight / 2, 0),
		}, grey)
		addWindows(top, tierFloors)
	end

	local roof = (spec.tier and spec.tier.roof) or spec.roof or (if floors <= 2 then "gable" else "flat")
	if roof == "gable" then
		local roofHeight, alongX, span = addGable(body, top, spec.ridge, spec.roofColor)
		if spec.chimney and top == body then
			addChimney(body, roofHeight, alongX, span)
		end
	elseif roof == "cross" then
		addCrossRoof(body, top, spec.roofColor)
	else
		addTrim(body, top, if floors >= 3 then 1.4 else 1)
	end

	if spec.clock then
		addClock(body, top, FACES[spec.clock].dir, top.Size.Y * 0.55)
	end

	body.Parent = folders.buildings
	return body
end

---------------------------------------------------------------------------------------------------
-- Tárgyak: érintésre visszakapják a színüket

local function newProp(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folders.props
	return model
end

-- A tárgy egy része: a természetes színe "color", festetlenül ennek szürke változata.
local function propPart(model: Model, color: Color3, props: { [string]: any }): BasePart
	local grey = toGrey(color)
	props.Color = grey
	local part = newPart(props)
	part:SetAttribute("BaseColor", grey)
	part:SetAttribute("PaintedColor", color)
	part.Parent = model
	if not model.PrimaryPart then
		model.PrimaryPart = part
	end
	return part
end

local function cylinderUp(center: Vector3, height: number, diameter: number): { [string]: any }
	return {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
	}
end

function Kit.tree(at: Vector3, scale: number?)
	local s = (scale or 1) * rng:NextNumber(0.85, 1.15)
	local model = newProp("Tree")
	local trunk = cylinderUp(at + Vector3.new(0, 3 * s, 0), 6 * s, 1.2 * s)
	propPart(model, Color3.fromRGB(120, 84, 56), trunk)
	local greens = { Color3.fromRGB(86, 160, 72), Color3.fromRGB(104, 176, 80), Color3.fromRGB(74, 144, 70) }
	for i, offset in { Vector3.new(0, 7.5, 0), Vector3.new(1.6, 6.2, 0.8), Vector3.new(-1.4, 6.4, -1) } do
		local size = (if i == 1 then 6 else 4.2) * s
		propPart(model, greens[i], {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = at + offset * s,
		})
	end
end

-- Pad: ülőlap, háttámla, két láb. rot: merre néz az ülő (mint az épületeknél).
function Kit.bench(at: Vector3, rot: number)
	local model = newProp("Bench")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	local wood = Color3.fromRGB(150, 98, 58)
	local iron = Color3.fromRGB(46, 62, 52)
	propPart(model, wood, { Size = Vector3.new(5, 0.3, 1.4), CFrame = base * CFrame.new(0, 1.3, 0) })
	propPart(model, wood, { Size = Vector3.new(5, 1.2, 0.25), CFrame = base * CFrame.new(0, 2.1, 0.65) })
	for _, x in { -2, 2 } do
		propPart(model, iron, { Size = Vector3.new(0.3, 1.2, 1.3), CFrame = base * CFrame.new(x, 0.6, 0) })
	end
end

function Kit.lamp(at: Vector3)
	local model = newProp("Lamp")
	local iron = Color3.fromRGB(40, 58, 50)
	propPart(model, iron, cylinderUp(at + Vector3.new(0, 4, 0), 8, 0.45))
	propPart(model, iron, cylinderUp(at + Vector3.new(0, 0.3, 0), 0.6, 1.2))
	propPart(
		model,
		Color3.fromRGB(255, 232, 160),
		{ Size = Vector3.new(1.3, 1.6, 1.3), Position = at + Vector3.new(0, 8.6, 0) }
	)
	propPart(model, iron, { Size = Vector3.new(1.7, 0.3, 1.7), Position = at + Vector3.new(0, 9.55, 0) })
end

-- Virágláda: doboz, benne színes virágok.
function Kit.planter(at: Vector3, rot: number, length: number?)
	local len = length or 4
	local model = newProp("Planter")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	propPart(
		model,
		Color3.fromRGB(176, 112, 76),
		{ Size = Vector3.new(len, 1.2, 1.4), CFrame = base * CFrame.new(0, 0.6, 0) }
	)
	local flowers = {
		Color3.fromRGB(236, 84, 120),
		Color3.fromRGB(252, 206, 70),
		Color3.fromRGB(240, 120, 60),
		Color3.fromRGB(180, 100, 220),
	}
	local count = math.max(2, math.floor(len / 1.1))
	for i = 1, count do
		local x = (i - 0.5) / count * len - len / 2
		propPart(
			model,
			pick(flowers),
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = base * CFrame.new(x, 1.5, 0) }
		)
	end
end

-- Kávézóasztal napernyővel.
function Kit.cafeTable(at: Vector3)
	local model = newProp("CafeTable")
	local umbrellas = {
		Color3.fromRGB(226, 76, 70),
		Color3.fromRGB(64, 138, 200),
		Color3.fromRGB(246, 196, 60),
		Color3.fromRGB(90, 170, 110),
	}
	propPart(model, Color3.fromRGB(240, 238, 230), cylinderUp(at + Vector3.new(0, 2.2, 0), 0.25, 3))
	propPart(model, Color3.fromRGB(60, 60, 66), cylinderUp(at + Vector3.new(0, 3.2, 0), 6.4, 0.25))
	propPart(model, pick(umbrellas), cylinderUp(at + Vector3.new(0, 6.3, 0), 0.4, 6.5))
	for _, offset in { Vector3.new(2, 0, 0), Vector3.new(-2, 0, 0) } do
		propPart(
			model,
			Color3.fromRGB(120, 80, 52),
			{ Size = Vector3.new(1.1, 1.3, 1.1), Position = at + offset + Vector3.new(0, 0.65, 0) }
		)
	end
end

-- Piaci stand: pult, négy oszlop, lejtős ponyvatető.
function Kit.stall(at: Vector3, rot: number)
	local model = newProp("Stall")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	local wood = Color3.fromRGB(160, 110, 66)
	local cloths = {
		Color3.fromRGB(214, 70, 64),
		Color3.fromRGB(70, 130, 200),
		Color3.fromRGB(236, 178, 50),
		Color3.fromRGB(80, 160, 100),
	}
	propPart(model, wood, { Size = Vector3.new(6, 2.4, 2.2), CFrame = base * CFrame.new(0, 1.2, -0.8) })
	for _, p in
		{ Vector3.new(-2.8, 0, -1.8), Vector3.new(2.8, 0, -1.8), Vector3.new(-2.8, 0, 1.6), Vector3.new(2.8, 0, 1.6) }
	do
		propPart(
			model,
			wood,
			{ Size = Vector3.new(0.35, 5.6, 0.35), CFrame = base * CFrame.new(p + Vector3.new(0, 2.8, 0)) }
		)
	end
	propPart(model, pick(cloths), {
		Size = Vector3.new(6.8, 0.25, 4.6),
		CFrame = base * CFrame.new(0, 5.8, -0.1) * CFrame.Angles(math.rad(-12), 0, 0),
	})
	-- Áru a pulton
	local goods = { Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 170, 40), Color3.fromRGB(120, 190, 70) }
	for i = -2, 2 do
		propPart(
			model,
			pick(goods),
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = base * CFrame.new(i * 1.1, 2.8, -0.9) }
		)
	end
end

-- Szökőkút: kerek medence vízzel, középen oszlop és felső tál.
function Kit.fountain(at: Vector3, radius: number)
	local model = newProp("Fountain")
	local stone = Color3.fromRGB(214, 200, 176)
	local water = Color3.fromRGB(80, 170, 230)
	propPart(model, stone, cylinderUp(at + Vector3.new(0, 0.8, 0), 1.6, radius * 2))
	local pool = propPart(model, water, cylinderUp(at + Vector3.new(0, 1.2, 0), 1.0, radius * 2 - 1.6))
	pool.Material = Enum.Material.Glass
	pool.Transparency = 0.15
	propPart(model, stone, cylinderUp(at + Vector3.new(0, 3.2, 0), 4.2, 2.4))
	propPart(model, stone, cylinderUp(at + Vector3.new(0, 5.4, 0), 0.8, radius * 0.8))
	local top = propPart(model, water, cylinderUp(at + Vector3.new(0, 5.75, 0), 0.2, radius * 0.8 - 0.8))
	top.Material = Enum.Material.Glass
	propPart(
		model,
		stone,
		{ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Position = at + Vector3.new(0, 6.6, 0) }
	)
end

-- Tavacska: lapos víztükör kőszegéllyel.
function Kit.pond(at: Vector3, size: Vector2)
	local model = newProp("Pond")
	propPart(
		model,
		Color3.fromRGB(190, 180, 160),
		{ Size = Vector3.new(size.X + 1.6, 0.5, size.Y + 1.6), Position = at + Vector3.new(0, 0.25, 0) }
	)
	local water = propPart(
		model,
		Color3.fromRGB(70, 160, 220),
		{ Size = Vector3.new(size.X, 0.5, size.Y), Position = at + Vector3.new(0, 0.3, 0) }
	)
	water.Material = Enum.Material.Glass
end

-- Sövény két pont között.
function Kit.hedge(from: Vector3, to: Vector3, height: number?)
	local h = height or 2.2
	local model = newProp("Hedge")
	local mid = (from + to) / 2 + Vector3.new(0, h / 2, 0)
	local length = (to - from).Magnitude
	local part = propPart(
		model,
		Color3.fromRGB(78, 148, 74),
		{ Size = Vector3.new(1.6, h, length), CFrame = CFrame.lookAt(mid, mid + (to - from)) }
	)
	part.Material = Enum.Material.Grass
end

-- Léckerítés két pont között: oszlopok és két léc.
function Kit.fence(from: Vector3, to: Vector3)
	local model = newProp("Fence")
	local white = Color3.fromRGB(246, 244, 236)
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	local posts = math.max(2, math.floor(length / 2.5) + 1)
	for i = 0, posts - 1 do
		local p = from + dir * (length * i / (posts - 1))
		propPart(model, white, { Size = Vector3.new(0.35, 2.4, 0.35), Position = p + Vector3.new(0, 1.2, 0) })
	end
	for _, y in { 0.9, 1.8 } do
		local mid = (from + to) / 2 + Vector3.new(0, y, 0)
		propPart(model, white, { Size = Vector3.new(0.2, 0.3, length), CFrame = CFrame.lookAt(mid, mid + dir) })
	end
end

-- Kőív két oszloppal (pl. városkapu, átjáró).
function Kit.arch(at: Vector3, rot: number, width: number, height: number)
	local model = newProp("Arch")
	local stone = Color3.fromRGB(206, 190, 160)
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	for _, x in { -1, 1 } do
		propPart(
			model,
			stone,
			{ Size = Vector3.new(2.4, height, 2.4), CFrame = base * CFrame.new(x * (width / 2 + 1.2), height / 2, 0) }
		)
	end
	propPart(
		model,
		stone,
		{ Size = Vector3.new(width + 4.8, 2.4, 2.8), CFrame = base * CFrame.new(0, height + 1.2, 0) }
	)
	propPart(
		model,
		Color3.fromRGB(180, 70, 60),
		{ Size = Vector3.new(width + 5.4, 0.6, 3.4), CFrame = base * CFrame.new(0, height + 2.7, 0) }
	)
end

-- Kerti pavilon: padló, oszlopok, kereszt-nyeregtető.
function Kit.gazebo(at: Vector3, size: number)
	local model = newProp("Gazebo")
	local white = Color3.fromRGB(246, 244, 236)
	propPart(
		model,
		Color3.fromRGB(170, 130, 90),
		{ Size = Vector3.new(size, 0.6, size), Position = at + Vector3.new(0, 0.3, 0) }
	)
	local h = 7
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			propPart(
				model,
				white,
				cylinderUp(at + Vector3.new(x * (size / 2 - 0.6), h / 2, z * (size / 2 - 0.6)), h, 0.6)
			)
		end
	end
	local side = (size + 1.2) / math.sqrt(2)
	local roofColor = Color3.fromRGB(64, 120, 110)
	local roofs = {
		{ Vector3.new(size + 1, side, side), CFrame.Angles(math.rad(45), 0, 0) },
		{ Vector3.new(side, side, size + 1), CFrame.Angles(0, 0, math.rad(45)) },
	}
	for _, roof in roofs do
		propPart(model, roofColor, { Size = roof[1], CFrame = CFrame.new(at + Vector3.new(0, h, 0)) * roof[2] })
	end
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
	tank.Parent = folders.tanks
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
	spawn.Parent = folders.world
end

return Kit
