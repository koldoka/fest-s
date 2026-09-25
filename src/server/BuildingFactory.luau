-- Egy épület felépítése egy telekre. Négy típus, rajzfilmes, de "igazi" házakra emlékeztető részletekkel:
--   House      kétszintes családi ház nyeregtetővel és kéménnyel
--   Shop       üzlet kirakattal és csíkos napellenzővel
--   Apartment  lakóház erkélyekkel, a tetőn klímadobozokkal
--   Tower      toronyház, a tetején kisebb emelettel és antennával
-- Az épület "teste" (Body) a Buildings mappába kerül; ezt festi be a játékos. A részletek a test gyerekei,
-- mindegyiknek van szerepe (Role), és a PaintService ez alapján színezi át őket befestéskor.
-- Az ablakok a falra feszített textúrák (Config.CITY.FACADE); amíg nincsenek feltöltve, ablaksávok helyettesítik őket.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BuildingFactory = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Oldalak: kifelé mutató irány és a hozzá tartozó NormalId (a textúrákhoz).
local FACES = {
	{ dir = Vector3.xAxis, normal = Enum.NormalId.Right },
	{ dir = -Vector3.xAxis, normal = Enum.NormalId.Left },
	{ dir = Vector3.zAxis, normal = Enum.NormalId.Back },
	{ dir = -Vector3.zAxis, normal = Enum.NormalId.Front },
}

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(BLACK, amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(WHITE, amount)
end

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function newPart(props: { [string]: any }): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	props.ClassName = nil
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Részlet a testen. baseColor: festetlen szín; paintedColor: fix szín befestve (ha nincs, a szerep dönt).
local function detail(body: BasePart, role: string, props: { [string]: any }, baseColor: Color3, paintedColor: Color3?)
	props.Name = role
	props.Color = baseColor
	local part = newPart(props)
	part:SetAttribute("Role", role)
	part:SetAttribute("BaseColor", baseColor)
	if paintedColor then
		part:SetAttribute("PaintedColor", paintedColor)
	end
	part.Parent = body
	return part
end

-- Egy oldal szélessége (a fal vízszintes mérete az adott irányban nézve).
local function faceWidth(size: Vector3, dir: Vector3): number
	return if dir.X ~= 0 then size.Z else size.X
end

-- A fal mentén vízszintes irány (jobbra, kívülről nézve mindegy, a részletek szimmetrikusak).
local function alongFace(dir: Vector3): Vector3
	return dir:Cross(Vector3.yAxis).Unit
end

-- Ablakok egy tömb négy oldalán: textúra, vagy ha nincs feltöltve, emeletenként egy ablaksáv.
local function addWindows(part: BasePart, floors: number, skipGroundFloor: boolean)
	local c = Config.CITY
	if c.FACADE.GREY ~= "" and c.FACADE.LIT ~= "" then
		for _, face in FACES do
			local width = faceWidth(part.Size, face.dir)
			local bays = math.max(1, math.round(width / c.BAY_WIDTH))
			local texture = Instance.new("Texture")
			texture.Texture = c.FACADE.GREY
			texture.Face = face.normal
			texture.StudsPerTileU = width / bays
			texture.StudsPerTileV = c.FLOOR_HEIGHT
			texture:SetAttribute("Role", "Facade")
			texture.Parent = part
		end
		return
	end
	-- Tartalék: ablaksávok
	local half = part.Size / 2
	for floor = if skipGroundFloor then 2 else 1, floors do
		local y = -half.Y + (floor - 0.5) * c.FLOOR_HEIGHT + 0.5
		for _, face in FACES do
			local width = faceWidth(part.Size, face.dir) - 2
			local size = if face.dir.X ~= 0 then Vector3.new(0.2, 2.5, width) else Vector3.new(width, 2.5, 0.2)
			local offset = face.dir * (math.abs(face.dir:Dot(half)) + 0.1) + Vector3.new(0, y, 0)
			detail(part, "Window", {
				Size = size,
				CFrame = part.CFrame * CFrame.new(offset),
				CanCollide = false,
			}, darker(part.Color, 0.3))
		end
	end
end

-- Az épület teste: egy tömb a járdán.
local function makeBody(center: Vector3, width: number, depth: number, floors: number, grey: Color3, kind: string)
	local height = floors * Config.CITY.FLOOR_HEIGHT
	local body = newPart({
		Name = "Building",
		Size = Vector3.new(width, height, depth),
		Position = center + Vector3.new(0, height / 2, 0),
		Color = grey,
	})
	body:SetAttribute("BaseColor", grey) -- ide áll vissza a város újrakezdésekor
	body:SetAttribute("ColorName", "") -- "" = még festetlen
	body:SetAttribute("Kind", kind)
	return body
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

-- Ajtó a megadott oldalon, a fal mentén "shift" studdal eltolva.
local function addDoor(body: BasePart, rng: Random, dir: Vector3, shift: number)
	local c = Config.CITY
	local half = body.Size / 2
	local along = alongFace(dir)
	local size = if dir.X ~= 0
		then Vector3.new(0.3, c.DOOR_SIZE.Y, c.DOOR_SIZE.X)
		else Vector3.new(c.DOOR_SIZE.X, c.DOOR_SIZE.Y, 0.3)
	local offset = dir * (math.abs(dir:Dot(half)) + 0.15)
		+ along * shift
		+ Vector3.new(0, -half.Y + c.DOOR_SIZE.Y / 2, 0)
	detail(
		body,
		"Door",
		{ Size = size, CFrame = body.CFrame * CFrame.new(offset) },
		darker(body.Color, 0.45),
		pick(rng, c.DOOR_COLORS)
	)
end

local function house(body: BasePart, rng: Random, doorDir: Vector3)
	local c = Config.CITY
	local s = body.Size
	addPlinth(body)
	addWindows(body, 2, false)
	addDoor(body, rng, doorDir, rng:NextNumber(-1, 1) * (faceWidth(s, doorDir) / 2 - 2.5))

	-- Nyeregtető: egy 45 fokkal elforgatott hasáb; az alsó fele a házban van, a felső fele a tető.
	-- A gerinc a hosszabbik oldallal párhuzamos.
	local alongX = s.X >= s.Z
	local span = if alongX then s.Z else s.X
	local diagonal = span + 1.2 -- kis eresz
	local side = diagonal / math.sqrt(2)
	local length = (if alongX then s.X else s.Z) + 1
	local top = body.CFrame * CFrame.new(0, s.Y / 2, 0)
	local rotation = if alongX then CFrame.Angles(math.rad(45), 0, 0) else CFrame.Angles(0, 0, math.rad(45))
	local roofSize = if alongX then Vector3.new(length, side, side) else Vector3.new(side, side, length)
	detail(
		body,
		"Roof",
		{ Size = roofSize, CFrame = top * rotation },
		darker(body.Color, 0.25),
		pick(rng, c.ROOF_COLORS)
	)

	-- Kémény az egyik tetőfelületen: a tető ott (45 fok) annyival alacsonyabb, amennyire kint van a gerinctől.
	local out = span * 0.22
	local roofHere = diagonal / 2 - out
	local offset = if alongX then Vector3.new(s.X * 0.25, 0, out) else Vector3.new(out, 0, s.Z * 0.25)
	detail(body, "Chimney", {
		Size = Vector3.new(1.4, 4, 1.4),
		CFrame = top * CFrame.new(offset + Vector3.new(0, roofHere + 1, 0)),
	}, darker(body.Color, 0.2), c.CHIMNEY_COLOR)
end

local function shop(body: BasePart, rng: Random, doorDir: Vector3, floors: number)
	local s = body.Size
	local half = s / 2
	local width = faceWidth(s, doorDir)
	local along = alongFace(doorDir)
	local outward = math.abs(doorDir:Dot(half))
	local doorSide = if rng:NextNumber() < 0.5 then -1 else 1

	addPlinth(body)
	addWindows(body, floors, false)
	addTrim(body, body, 1)
	addDoor(body, rng, doorDir, doorSide * width * 0.3)

	-- Kirakat a bejárat mellett
	local windowWidth = width * 0.5
	local windowSize = if doorDir.X ~= 0 then Vector3.new(0.3, 3.4, windowWidth) else Vector3.new(windowWidth, 3.4, 0.3)
	detail(body, "ShopWindow", {
		Size = windowSize,
		CFrame = body.CFrame * CFrame.new(
			doorDir * (outward + 0.15) - along * doorSide * width * 0.18 + Vector3.new(0, -half.Y + 2.9, 0)
		),
		Material = Enum.Material.Glass,
		Reflectance = 0.15,
	}, Color3.fromRGB(82, 96, 118))

	-- Csíkos napellenző: lefelé lejtő lap csíkokból, a kirakat és az ajtó fölött.
	local stripes = 7
	local awningWidth = width * 0.92
	local depth = 2.4
	local tilt = math.rad(22)
	local normal = Vector3.yAxis * math.cos(tilt) + doorDir * math.sin(tilt) -- a lap síkjának normálisa
	local topY = -half.Y + 5.6
	for i = 1, stripes do
		local lateral = ((i - 0.5) / stripes - 0.5) * awningWidth
		local center = doorDir * (outward + depth / 2 * math.cos(tilt))
			+ along * lateral
			+ Vector3.new(0, topY - depth / 2 * math.sin(tilt), 0)
		local role = if i % 2 == 1 then "AwningA" else "AwningB"
		local base = if i % 2 == 1 then darker(body.Color, 0.2) else lighter(body.Color, 0.3)
		detail(body, role, {
			Size = Vector3.new(awningWidth / stripes, 0.25, depth),
			CFrame = CFrame.fromMatrix(body.Position + center, along, normal),
		}, base)
	end
end

local function apartment(body: BasePart, rng: Random, doorDir: Vector3, floors: number)
	local c = Config.CITY
	local s = body.Size
	local half = s / 2
	addPlinth(body)
	addWindows(body, floors, false)
	addTrim(body, body, 1.4)
	addDoor(body, rng, doorDir, 0)

	-- Erkélyek a második emelettől: padló + korlát, egy oszlopban az ajtós oldalon.
	local width = faceWidth(s, doorDir)
	local along = alongFace(doorDir)
	local outward = math.abs(doorDir:Dot(half))
	local balconyWidth = math.min(width * 0.45, 7)
	local shift = (if rng:NextNumber() < 0.5 then -1 else 1) * width * 0.22
	for floor = 2, floors do
		local y = -half.Y + (floor - 1) * c.FLOOR_HEIGHT
		local slabSize = if doorDir.X ~= 0
			then Vector3.new(1.8, 0.3, balconyWidth)
			else Vector3.new(balconyWidth, 0.3, 1.8)
		detail(body, "Balcony", {
			Size = slabSize,
			CFrame = body.CFrame * CFrame.new(doorDir * (outward + 0.9) + along * shift + Vector3.new(0, y + 0.15, 0)),
		}, lighter(body.Color, 0.25))
		local railSize = if doorDir.X ~= 0
			then Vector3.new(0.2, 1.2, balconyWidth)
			else Vector3.new(balconyWidth, 1.2, 0.2)
		detail(body, "Railing", {
			Size = railSize,
			CFrame = body.CFrame * CFrame.new(doorDir * (outward + 1.7) + along * shift + Vector3.new(0, y + 0.9, 0)),
		}, darker(body.Color, 0.4), c.RAILING_COLOR)
	end

	-- Klímadobozok a tetőn
	for _ = 1, rng:NextInteger(1, 3) do
		local offset = Vector3.new(rng:NextNumber(-0.3, 0.3) * s.X, half.Y + 0.7, rng:NextNumber(-0.3, 0.3) * s.Z)
		detail(body, "Metal", {
			Size = Vector3.new(2.2, 1.4, 2.2),
			CFrame = body.CFrame * CFrame.new(offset),
		}, c.METAL_COLOR, c.METAL_COLOR)
	end
end

local function tower(body: BasePart, rng: Random, doorDir: Vector3, floors: number)
	local c = Config.CITY
	local s = body.Size
	addPlinth(body)
	addWindows(body, floors, false)
	addTrim(body, body, 1)
	addDoor(body, rng, doorDir, 0)

	-- Kisebb felső emelet(ek), ugyanolyan színű, mint a test
	local tierFloors = rng:NextInteger(1, 2)
	local tierHeight = tierFloors * c.FLOOR_HEIGHT
	local tier = detail(body, "Tier", {
		Size = Vector3.new(s.X * 0.65, tierHeight, s.Z * 0.65),
		CFrame = body.CFrame * CFrame.new(0, s.Y / 2 + 0.5 + tierHeight / 2, 0),
	}, body.Color)
	addWindows(tier, tierFloors, false)
	addTrim(body, tier, 0.8)

	-- Antenna
	detail(body, "Metal", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 0.35, 0.35),
		CFrame = tier.CFrame * CFrame.new(s.X * 0.1, tierHeight / 2 + 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
	}, c.METAL_COLOR, c.METAL_COLOR)
end

-- Felépít egy épületet. center: a telek közepe a járda szintjén; doorDirs: az utca felé néző oldalak.
function BuildingFactory.build(
	kind: string,
	center: Vector3,
	lotWidth: number,
	grey: Color3,
	rng: Random,
	doorDirs: { Vector3 }
): BasePart
	local c = Config.CITY
	local info = c.BUILDING_TYPES[kind]
	local floors = rng:NextInteger(info.floors[1], info.floors[2])
	local width, depth = lotWidth, lotWidth
	if kind == "House" then
		-- A családi ház kisebb, körülötte marad egy kis udvar.
		width = lotWidth * rng:NextNumber(0.72, 0.85)
		depth = lotWidth * rng:NextNumber(0.72, 0.85)
	end
	local body = makeBody(center, width, depth, floors, grey, kind)
	local doorDir = pick(rng, doorDirs)

	if kind == "House" then
		house(body, rng, doorDir)
	elseif kind == "Shop" then
		shop(body, rng, doorDir, floors)
	elseif kind == "Apartment" then
		apartment(body, rng, doorDir, floors)
	else
		tower(body, rng, doorDir, floors)
	end
	return body
end

return BuildingFactory
