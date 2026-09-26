-- Épületek a Kithez. Egy épület teste (Body) a Buildings mappába kerül; ezt festi be a játékos.
-- A részletek a test leszármazottai; mindegyiknek van szerepe (Role) és festetlen színe (BaseColor),
-- a fix színűeknek festett színe is (PaintedColor). A PaintService ez alapján színezi át őket.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Common = require(script.Parent.Common)

local darker, lighter, pick = Common.darker, Common.lighter, Common.pick
local newPart, faceWidth, onFace, faceSize = Common.newPart, Common.faceWidth, Common.onFace, Common.faceSize
local FACES = Common.FACES

local Buildings = {}

-- Az ablakok a pálya végén kerülnek fel (Buildings.finish), hogy ahol egy másik ház közvetlenül előttük áll,
-- oda ne kerüljön ablak (kevesebb alkatrész, gyorsabb játék).
local bodies: { BasePart } = {}
local pendingWindows: { { any } } = {}

function Buildings.reset()
	bodies = {}
	pendingWindows = {}
end

-- Anyag név szerint; ha a Roblox-verzióban még nincs ilyen, a tartalék.
local function material(name: string, fallback: Enum.Material): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else fallback
end

local WALL_MATERIALS = {
	plaster = material("Plaster", Enum.Material.SmoothPlastic),
	brick = Enum.Material.Brick,
	wood = Enum.Material.WoodPlanks,
	stone = Enum.Material.Slate,
}
local ROOF_MATERIAL = material("ClayRoofTiles", Enum.Material.SmoothPlastic)
local DARK_GLASS = Color3.fromRGB(70, 82, 102)
local SHOP_NAMES =
	{ "BAKERY", "CAFE", "BOOKS", "FLOWERS", "TOYS", "CANDY", "SHOES", "TAILOR", "PHARMACY", "BUTCHER", "HATS", "TEA" }

-- Egy helyi irányhoz tartozó oldal (NormalId).
local function normalOf(dir: Vector3): Enum.NormalId
	for _, face in FACES do
		if face.dir == dir then
			return face.normal
		end
	end
	return Enum.NormalId.Front
end

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

-- Díszítő részlet: nem ütközik, nem kell vele számolni a festésnél és az árnyékoknál.
local function trimDetail(
	parent: BasePart,
	role: string,
	props: { [string]: any },
	baseColor: Color3,
	paintedColor: Color3?
): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return detail(parent, role, props, baseColor, paintedColor)
end

---------------------------------------------------------------------------------------------------
-- Ablakok és ajtók

-- Egy ablak. Ha fel vannak töltve az ablakképek (Config.BUILDINGS.FACADE), egy láthatatlan lap a képpel
-- (keret, üveg, párkány a képen); különben keret, üveg és párkány alkatrészekből. "shutters" stílusban
-- zsalugáterek is kerülnek mellé.
local function addWindow(
	body: BasePart,
	part: BasePart,
	dir: Vector3,
	normal: Enum.NormalId,
	shift: number,
	y: number,
	bayWidth: number,
	style: string
)
	local b = Config.BUILDINGS
	local w = math.min(bayWidth * 0.5, 2.6)
	local h = if style == "tall" then 4.4 else 2.8
	-- Melyik ablakkép: magas (templom, városháza), vagy az épületre sorsolt változat (klasszikus / függönyös).
	local variant = if style == "tall" then "tall" else body:GetAttribute("WindowVariant") or "classic"
	local images = b.WINDOWS[variant]
	local grey = if images and images.grey ~= "" then images.grey else b.FACADE.GREY
	local lit = if images and images.lit ~= "" then images.lit else b.FACADE.LIT
	local shutterDecal = style == "shutters" and b.SHUTTERS ~= ""
	if b.WINDOW_MODE == "decal" and grey ~= "" and lit ~= "" then
		-- Egy láthatatlan lap a képpel. A képen az ablak a lap szélességének felét foglalja el (a két szélén
		-- a zsalugáterek helye); a lap magassága a kép arányát követi, hogy ne torzuljon.
		local width = w / 0.5
		local height = width * (if variant == "tall" then 1.5 else 1)
		local panel = trimDetail(body, "WindowPanel", {
			Size = faceSize(dir, width, height, 0.2),
			CFrame = onFace(part, dir, 0.1, shift, y - height * 0.085),
			Transparency = 1,
		}, body.Color)
		local decal = Instance.new("Decal")
		decal.Texture = grey
		decal.Face = normal
		decal:SetAttribute("Role", "Facade")
		decal:SetAttribute("Grey", grey)
		decal:SetAttribute("Lit", lit)
		decal.Parent = panel
		if shutterDecal then
			-- Zsalugáter: fehér kép ugyanazon a lapon, a színét a Color3 adja (befestve a festék sötétebb árnyalata)
			local shutters = Instance.new("Decal")
			shutters.Texture = b.SHUTTERS
			shutters.Face = normal
			shutters.Color3 = darker(body.Color, 0.25)
			shutters:SetAttribute("Role", "Shutter")
			shutters:SetAttribute("BaseColor", shutters.Color3)
			shutters.Parent = panel
		end
	else
		local frameColor = lighter(body.Color, 0.3)
		trimDetail(
			body,
			"WindowFrame",
			{ Size = faceSize(dir, w + 0.6, h + 0.6, 0.3), CFrame = onFace(part, dir, 0.05, shift, y) },
			frameColor
		)
		trimDetail(
			body,
			"Window",
			{ Size = faceSize(dir, w, h, 0.3), CFrame = onFace(part, dir, 0.12, shift, y) },
			DARK_GLASS
		)
		trimDetail(
			body,
			"Trim",
			{ Size = faceSize(dir, w + 1, 0.3, 0.7), CFrame = onFace(part, dir, 0.3, shift, y - h / 2 - 0.35) },
			frameColor
		)
	end
	if style == "shutters" and not shutterDecal then
		for _, side in { -1, 1 } do
			trimDetail(body, "Shutter", {
				Size = faceSize(dir, w * 0.5, h + 0.3, 0.2),
				CFrame = onFace(part, dir, 0.1, shift + side * (w * 0.75 + 0.35), y),
			}, darker(body.Color, 0.25))
		end
	end
end

-- Ablakok egy tömb négy oldalán, emeletenként. skip(dir, floor, shift) igaz = oda nem kerül ablak.
local function addWindows(
	body: BasePart,
	part: BasePart,
	floors: number,
	style: string,
	skip: ((Vector3, number, number) -> boolean)?
)
	if style == "none" then
		return
	end
	local b = Config.BUILDINGS
	if b.WINDOW_MODE == "texture" and b.FACADE.GREY ~= "" and b.FACADE.LIT ~= "" then
		-- Falra feszített kép; befestéskor a PaintService cseréli a kivilágított változatra.
		for _, face in FACES do
			local width = faceWidth(part.Size, face.dir)
			local texture = Instance.new("Texture")
			texture.Texture = b.FACADE.GREY
			texture.Face = face.normal
			texture.StudsPerTileU = width / math.max(1, math.round(width / b.BAY_WIDTH))
			texture.StudsPerTileV = b.FLOOR_HEIGHT
			texture:SetAttribute("Role", "Facade")
			texture.Parent = part
		end
		return
	end
	for _, face in FACES do
		local width = faceWidth(part.Size, face.dir)
		-- Az oldalfalakon (helyi X irány) ritkábbak az ablakok, mint elöl és hátul.
		local bayWidth0 = if face.dir.X ~= 0 then b.BAY_WIDTH * b.SIDE_BAY_FACTOR else b.BAY_WIDTH
		local bays = math.max(1, math.round(width / bayWidth0))
		local bayWidth = width / bays
		for floor = 1, floors do
			local y = (floor - 1) * b.FLOOR_HEIGHT + b.FLOOR_HEIGHT * (if style == "tall" then 0.5 else 0.55)
			for i = 1, bays do
				local shift = (i - 0.5) * bayWidth - width / 2
				if not (skip and skip(face.dir, floor, shift)) then
					table.insert(pendingWindows, { body, part, face.dir, face.normal, shift, y, bayWidth, style })
				end
			end
		end
	end
end

-- Ajtó kerettel, előtetővel és lépcsővel.
-- canopy = false: nincs előtető (a boltnál a napellenző takarja az ajtót). Földszintes háznál sincs,
-- mert ott az eresz lóg az ajtó fölé, és az előtető belelógna a tetőbe.
local function addDoor(body: BasePart, dir: Vector3, shift: number, canopy: boolean?)
	local b = Config.BUILDINGS
	local dw, dh = b.DOOR_SIZE.X, b.DOOR_SIZE.Y
	trimDetail(
		body,
		"WindowFrame",
		{ Size = faceSize(dir, dw + 0.8, dh + 0.4, 0.3), CFrame = onFace(body, dir, 0.05, shift, dh / 2 + 0.2) },
		lighter(body.Color, 0.3)
	)
	detail(
		body,
		"Door",
		{ Size = faceSize(dir, dw, dh, 0.3), CFrame = onFace(body, dir, 0.15, shift, dh / 2) },
		darker(body.Color, 0.45),
		pick(b.DOOR_COLORS)
	)
	if canopy ~= false and body.Size.Y >= b.FLOOR_HEIGHT * 1.5 then
		detail(
			body,
			"Canopy",
			{ Size = faceSize(dir, dw + 1.6, 0.35, 1.6), CFrame = onFace(body, dir, 0.8, shift, dh + 0.8) },
			darker(body.Color, 0.15)
		)
	end
	detail(
		body,
		"Step",
		{ Size = faceSize(dir, dw + 1.4, 0.4, 1.4), CFrame = onFace(body, dir, 0.7, shift, 0.2) },
		Color3.fromRGB(170, 166, 158),
		Color3.fromRGB(196, 188, 174)
	)
end

---------------------------------------------------------------------------------------------------
-- Tetők

-- Nyeregtető 45 fokos lejtéssel: az oromfalat egy 45 fokkal elforgatott hasáb adja (az alsó fele a házban van,
-- a vége pontosan a falsíkban), rajta két tetősík ereszcsatornával és egy gerinccserép.
-- alongX: a gerinc a tömb helyi X tengelyével párhuzamos. Visszaadja a tető magasságát.
local function addGable(body: BasePart, onPart: BasePart, alongX: boolean, roofColor: Color3): number
	local s = onPart.Size
	local frame = onPart.CFrame
		* CFrame.new(0, s.Y / 2, 0)
		* (if alongX then CFrame.identity else CFrame.Angles(0, math.rad(90), 0))
	local length = if alongX then s.X else s.Z
	local span = if alongX then s.Z else s.X
	local half = span / 2

	-- Oromfal: két ék (WedgePart) háttal egymásnak. Az ék függőleges hátlapja a helyi +Z, a lejtője a -Z felé
	-- ereszkedik. Nincsenek elforgatva, így a fal anyagának mintája (tégla, deszka) vízszintes marad.
	for _, sign in { -1, 1 } do
		detail(body, "Gable", {
			ClassName = "WedgePart",
			Size = Vector3.new(length, half, half),
			CFrame = frame * CFrame.new(0, half / 2, sign * half / 2) * (if sign > 0
				then CFrame.Angles(0, math.pi, 0)
				else CFrame.identity),
			Material = body.Material,
		}, onPart.Color)
	end

	local overhang, endOverhang, thickness = 0.9, 0.7, 0.5
	local slope = (half + overhang) * math.sqrt(2)
	local greyRoof = darker(body.Color, 0.25)
	for _, sign in { 1, -1 } do
		local cf = frame
			* CFrame.new(0, (half - overhang) / 2, sign * (half + overhang) / 2)
			* CFrame.Angles(sign * math.rad(45), 0, 0)
			* CFrame.new(0, thickness / 2, 0)
		detail(
			body,
			"Roof",
			{ Size = Vector3.new(length + 2 * endOverhang, thickness, slope), CFrame = cf, Material = ROOF_MATERIAL },
			greyRoof,
			roofColor
		)
		-- Ereszcsatorna a tetősík alsó szélén
		trimDetail(body, "Metal", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length + 2 * endOverhang, 0.45, 0.45),
			CFrame = frame * CFrame.new(0, -overhang - 0.15, sign * (half + overhang + 0.1)),
		}, darker(body.Color, 0.35), Config.BUILDINGS.METAL_COLOR)
	end
	detail(body, "RoofRidge", {
		Size = Vector3.new(length + 2 * endOverhang + 0.2, 0.7, 0.7),
		CFrame = frame * CFrame.new(0, half + thickness * 0.9, 0) * CFrame.Angles(math.rad(45), 0, 0),
	}, darker(greyRoof, 0.2), darker(roofColor, 0.25))
	return half
end

local function addChimney(body: BasePart, onPart: BasePart, alongX: boolean, roofHeight: number)
	local s = onPart.Size
	local span = if alongX then s.Z else s.X
	local out = span * 0.22 -- ennyire van a gerinctől; a tető ott (45 fok) ennyivel alacsonyabb
	local offset = if alongX then Vector3.new(s.X * 0.28, 0, out) else Vector3.new(out, 0, s.Z * 0.28)
	local height = 4.5
	local chimney = detail(body, "Chimney", {
		Size = Vector3.new(1.6, height, 1.6),
		CFrame = onPart.CFrame * CFrame.new(offset + Vector3.new(0, s.Y / 2 + roofHeight - out + height / 2 - 1, 0)),
		Material = Enum.Material.Brick,
	}, darker(body.Color, 0.2), Config.BUILDINGS.CHIMNEY_COLOR)
	detail(body, "Chimney", {
		Size = Vector3.new(2, 0.4, 2),
		CFrame = chimney.CFrame * CFrame.new(0, height / 2, 0),
	}, darker(body.Color, 0.3), darker(Config.BUILDINGS.CHIMNEY_COLOR, 0.2))
end

-- Lapos tető: párkány (mellvéd) körben.
local function addParapet(body: BasePart, onPart: BasePart, height: number)
	local s = onPart.Size
	detail(body, "Trim", {
		Size = Vector3.new(s.X + 0.8, height, s.Z + 0.8),
		CFrame = onPart.CFrame * CFrame.new(0, s.Y / 2 + height / 2 - 0.4, 0),
	}, lighter(body.Color, 0.25))
end

-- Lapos tetőre: lépcsőház-kijáró és klímadobozok, hogy ne legyen üres.
local function addRoofClutter(body: BasePart, onPart: BasePart)
	local s = onPart.Size
	local rng = Common.rng
	local metal = Config.BUILDINGS.METAL_COLOR
	if s.X >= 8 and s.Z >= 8 then
		local hut = Vector3.new(s.X * rng:NextNumber(-0.25, 0.25), s.Y / 2 + 1.5, s.Z * rng:NextNumber(-0.25, 0.25))
		detail(
			body,
			"Trim",
			{ Size = Vector3.new(4, 3, 3.5), CFrame = onPart.CFrame * CFrame.new(hut) },
			lighter(body.Color, 0.15)
		)
		detail(body, "Door", {
			Size = Vector3.new(1.6, 2.4, 0.2),
			CFrame = onPart.CFrame * CFrame.new(hut + Vector3.new(0, -0.3, -1.8)),
		}, darker(body.Color, 0.45), pick(Config.BUILDINGS.DOOR_COLORS))
	end
	for _ = 1, rng:NextInteger(1, 2) do
		local offset = Vector3.new(s.X * rng:NextNumber(-0.3, 0.3), s.Y / 2 + 0.6, s.Z * rng:NextNumber(-0.3, 0.3))
		detail(
			body,
			"Metal",
			{ Size = Vector3.new(2.2, 1.2, 1.8), CFrame = onPart.CFrame * CFrame.new(offset) },
			darker(body.Color, 0.1),
			metal
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Egyéb részletek

local function addPlinth(body: BasePart)
	local s = body.Size
	detail(body, "Plinth", {
		Size = Vector3.new(s.X + 0.4, 1.2, s.Z + 0.4),
		CFrame = body.CFrame * CFrame.new(0, -s.Y / 2 + 0.6, 0),
		Material = Enum.Material.Slate,
	}, darker(body.Color, 0.3))
end

-- Díszsáv az emeletek között.
local function addBands(body: BasePart, floors: number)
	local s = body.Size
	for floor = 2, floors do
		trimDetail(body, "Band", {
			Size = Vector3.new(s.X + 0.3, 0.4, s.Z + 0.3),
			CFrame = body.CFrame * CFrame.new(0, -s.Y / 2 + (floor - 1) * Config.BUILDINGS.FLOOR_HEIGHT, 0),
		}, lighter(body.Color, 0.2))
	end
end

-- Sarokpillérek.
local function addCorners(body: BasePart)
	local s = body.Size
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			trimDetail(body, "Corner", {
				Size = Vector3.new(1, s.Y, 1),
				CFrame = body.CFrame * CFrame.new(x * s.X / 2, 0, z * s.Z / 2),
			}, lighter(body.Color, 0.2))
		end
	end
end

-- Kirakat kerettel, csíkos napellenző, cégtábla; az ajtó a kirakat mellé kerül.
local function addShopfront(body: BasePart, dir: Vector3): number
	local width = faceWidth(body.Size, dir)
	local doorSide = if Common.rng:NextNumber() < 0.5 then -1 else 1
	local doorShift = doorSide * width * 0.3
	addDoor(body, dir, doorShift, false)

	local windowWidth = width * 0.5
	local windowShift = -doorSide * width * 0.18
	trimDetail(
		body,
		"WindowFrame",
		{ Size = faceSize(dir, windowWidth + 0.8, 4, 0.3), CFrame = onFace(body, dir, 0.05, windowShift, 2.9) },
		lighter(body.Color, 0.3)
	)
	detail(body, "ShopWindow", {
		Size = faceSize(dir, windowWidth, 3.4, 0.3),
		CFrame = onFace(body, dir, 0.15, windowShift, 2.9),
		Material = Enum.Material.Glass,
		Reflectance = 0.15,
	}, DARK_GLASS)
	-- Osztók: két függőleges és egy vízszintes léc
	for _, k in { -1, 1 } do
		trimDetail(body, "WindowFrame", {
			Size = faceSize(dir, 0.25, 3.4, 0.3),
			CFrame = onFace(body, dir, 0.25, windowShift + k * windowWidth / 6, 2.9),
		}, lighter(body.Color, 0.3))
	end
	trimDetail(body, "WindowFrame", {
		Size = faceSize(dir, windowWidth, 0.25, 0.3),
		CFrame = onFace(body, dir, 0.25, windowShift, 3.9),
	}, lighter(body.Color, 0.3))

	-- Napellenző: lefelé lejtő lap csíkokból. A lap síkjának normálisa a függőlegestől kifelé dől.
	local stripes = 7
	local awningWidth = width * 0.92
	local depth = 2.4
	local tilt = math.rad(22)
	local along = Common.alongFace(dir)
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
	-- Cégtábla felirattal (a felirat felület-GUI, nem alkatrész)
	local sign = trimDetail(body, "Sign", {
		Size = faceSize(dir, width * 0.5, 1.4, 0.3),
		CFrame = onFace(body, dir, 0.1, 0, 6.5),
	}, lighter(body.Color, 0.35))
	local gui = Instance.new("SurfaceGui")
	gui.Face = normalOf(dir)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(50, 44, 40)
	text.Text = pick(SHOP_NAMES)
	text.Parent = gui
	gui.Parent = sign
	return doorShift
end

-- Erkélyek egy oszlopban (firstFloor emelettől felfelé): padló + korlát.
local function addBalconies(body: BasePart, dir: Vector3, floors: number, shift: number, firstFloor: number)
	local b = Config.BUILDINGS
	local width = math.min(faceWidth(body.Size, dir) * 0.45, 7)
	for floor = firstFloor, floors do
		local y = (floor - 1) * b.FLOOR_HEIGHT
		detail(
			body,
			"Balcony",
			{ Size = faceSize(dir, width, 0.3, 1.8), CFrame = onFace(body, dir, 0.9, shift, y + 0.15) },
			lighter(body.Color, 0.25)
		)
		detail(
			body,
			"Railing",
			{ Size = faceSize(dir, width, 1.2, 0.2), CFrame = onFace(body, dir, 1.7, shift, y + 0.9) },
			darker(body.Color, 0.4),
			b.RAILING_COLOR
		)
		for _, side in { -1, 1 } do
			detail(body, "Railing", {
				Size = faceSize(dir, 0.2, 1.2, 1.8),
				CFrame = onFace(body, dir, 0.9, shift + side * (width / 2 - 0.1), y + 0.9),
			}, darker(body.Color, 0.4), b.RAILING_COLOR)
		end
	end
end

-- Óra a torony egyik oldalán.
local function addClock(body: BasePart, onPart: BasePart, dir: Vector3, y: number)
	-- Ne lógjon bele a tetőbe: a tömb magasságának legfeljebb kb. kétharmada
	local diameter = math.min(faceWidth(onPart.Size, dir) * 0.7, 6, onPart.Size.Y * 0.6)
	local center = onFace(onPart, dir, 0.2, 0, y)
	-- A henger tengelye (helyi X) nézzen kifelé.
	local facing = CFrame.fromMatrix(center.Position, (center.Rotation * dir).Unit, Vector3.yAxis)
	detail(
		body,
		"Clock",
		{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, diameter + 0.8, diameter + 0.8), CFrame = facing },
		lighter(body.Color, 0.1),
		Color3.fromRGB(196, 160, 70)
	)
	detail(body, "Clock", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, diameter, diameter),
		CFrame = facing * CFrame.new(0.1, 0, 0),
	}, lighter(body.Color, 0.3), Color3.fromRGB(250, 246, 232))
	local hand = Color3.fromRGB(40, 40, 50)
	trimDetail(
		body,
		"Metal",
		{ Size = Vector3.new(0.2, diameter * 0.38, 0.35), CFrame = facing * CFrame.new(0.3, diameter * 0.17, 0) },
		darker(body.Color, 0.5),
		hand
	)
	trimDetail(
		body,
		"Metal",
		{ Size = Vector3.new(0.2, 0.3, diameter * 0.28), CFrame = facing * CFrame.new(0.35, 0, diameter * 0.12) },
		darker(body.Color, 0.5),
		hand
	)
end

-- Kerek ablak (rózsaablak): az oromzatban, vagy ha ott nincs hely, a fal tetején.
local function addRoseWindow(body: BasePart, dir: Vector3, y: number, diameter: number)
	local center = onFace(body, dir, 0.15, 0, y)
	local facing = CFrame.fromMatrix(center.Position, (center.Rotation * dir).Unit, Vector3.yAxis)
	trimDetail(
		body,
		"WindowFrame",
		{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, diameter + 1, diameter + 1), CFrame = facing },
		lighter(body.Color, 0.3)
	)
	trimDetail(body, "Window", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, diameter, diameter),
		CFrame = facing * CFrame.new(0.1, 0, 0),
	}, DARK_GLASS)
end

---------------------------------------------------------------------------------------------------

--[[
Egy épület. A spec mezői (csak az "at" és a "size" kötelező):
  at        Vector3   a talajpont a ház közepén (a magassága a talaj felszíne)
  size      Vector2   homlokzat szélessége (helyi X) × mélység (helyi Z)
  floors    number    emeletek száma (alapból 2)
  rot       number    elforgatás fokban: 0 = a homlokzat északra (-Z) néz, 180 = délre, 90 = nyugatra, -90 = keletre
  material  string    "plaster" (vakolat, alap), "brick" (tégla), "wood" (deszka), "stone" (kő)
  windows   string    "plain" (alap), "shutters" (zsalugáteres), "tall" (magas), "none"
  bands     boolean   díszsáv az emeletek között (alapból 3 emelettől)
  corners   boolean   sarokpillérek
  roof      string    "gable" (nyeregtető), "flat" (lapos, mellvéddel), "cross" (kereszt-nyeregtető);
                      alapból 2 emeletig nyeregtető, fölötte lapos
  ridge     string    nyeregtetőnél a gerinc iránya: "x" (a homlokzattal párhuzamos) vagy "z" (merőleges)
  roofColor Color3    fix tetőszín (alapból véletlen a Config.BUILDINGS.ROOF_COLORS-ból)
  chimney   boolean   kémény a nyeregtetőn
  door      table|false  { face = "front", shift = 0 } — az ajtó oldala és eltolása; false = nincs ajtó
  shop      boolean   kirakat, napellenző és cégtábla az ajtós oldalon
  balconies table     { face = "front", shift = 0 } — erkélyek a második emelettől
  tier      table     { floors = 1, scale = 0.65, roof = "flat" } — kisebb felső emelet (tornyok)
  clock     string    óra ezen az oldalon (a felső emeleten, ha van)
  rose      string    kerek ablak ezen az oldalon, fent (templomok)
  windowVariant string "classic" vagy "curtain" (függönyös, virágládás); alapból sorsolt
  paintCost number    festékár (alapból a szintek szerint: Config.PAINT_COST)
]]
function Buildings.building(spec: { [string]: any }): BasePart
	local b = Config.BUILDINGS
	-- A bolt kirakata, napellenzője és cégtáblája egy emeletnyi falon nem fér el a tetőeresz alatt
	local floors = if spec.shop then math.max(spec.floors or 2, 2) else spec.floors or 2
	local height = floors * b.FLOOR_HEIGHT
	local grey = Common.greyShade()
	local body = newPart({
		Name = "Building",
		Size = Vector3.new(spec.size.X, height, spec.size.Y),
		CFrame = CFrame.new(spec.at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(spec.rot or 0), 0),
		Color = grey,
		Material = WALL_MATERIALS[spec.material or "plaster"] or WALL_MATERIALS.plaster,
	})
	body:SetAttribute("BaseColor", grey) -- ide áll vissza a pálya újrakezdésekor
	body:SetAttribute("ColorName", "") -- "" = még festetlen
	body:SetAttribute(
		"WindowVariant",
		spec.windowVariant or (if Common.rng:NextNumber() < 0.3 then "curtain" else "classic")
	)
	-- Festékár a szintek száma szerint: földszintes kicsi, kétszintes közepes, három- vagy többszintes nagy
	local cost = Config.PAINT_COST
	body:SetAttribute(
		"PaintCost",
		spec.paintCost or (if floors >= 3 then cost.LARGE elseif floors == 2 then cost.MEDIUM else cost.SMALL)
	)

	addPlinth(body)
	if spec.bands or (spec.bands == nil and floors >= 3) then
		addBands(body, floors)
	end
	if spec.corners then
		addCorners(body)
	end

	-- Földszint: ajtó (vagy kirakat); ahol ezek vannak, oda nem kerül ablak.
	local door = if spec.door == nil then { face = "front", shift = 0 } else spec.door
	local doorDir: Vector3? = nil
	local doorShift = 0
	if door then
		doorDir = FACES[door.face or "front"].dir
		if spec.shop then
			doorShift = addShopfront(body, doorDir :: Vector3)
		else
			doorShift = door.shift or 0
			addDoor(body, doorDir :: Vector3, doorShift)
		end
	end
	-- A tető típusa és a gerinc iránya (a rózsaablak helyéhez már itt kell)
	local roof = (spec.tier and spec.tier.roof) or spec.roof or (if floors <= 2 then "gable" else "flat")
	local alongX = if spec.ridge then spec.ridge == "x" else body.Size.X >= body.Size.Z
	local roseDir = spec.rose and FACES[spec.rose].dir
	-- Oromzat van ezen az oldalon, ha nyeregtető van, és a gerinc merőleges az oldalra
	local roseInGable = roseDir ~= nil and roof == "gable" and not spec.tier and ((roseDir.X ~= 0) == alongX)
	local roseDiameter = if roseDir then math.min(faceWidth(body.Size, roseDir) * 0.35, 6) else 0

	local balconyDir = spec.balconies and FACES[spec.balconies.face or "front"].dir
	local balconyShift = spec.balconies and (spec.balconies.shift or 0) or 0
	-- A bolt cégtáblája a 2. emelet aljáig ér: ugyanazon az oldalon az erkélyek csak a 3. emelettől kezdődnek
	local balconyFrom = if spec.shop and balconyDir == doorDir then 3 else 2
	local style = spec.windows or "plain"
	addWindows(body, body, floors, style, function(dir, floor, shift)
		if floor == 1 and dir == doorDir then
			return spec.shop or math.abs(shift - doorShift) < b.BAY_WIDTH * 0.7
		end
		-- A fal tetején lévő rózsaablak alatt nincs ablak
		if
			roseDir
			and not roseInGable
			and dir == roseDir
			and floor == floors
			and math.abs(shift) < roseDiameter / 2 + 2
		then
			return true
		end
		-- Az erkély mögött nincs ablak (ott erkélyajtó lenne)
		return floor >= balconyFrom and dir == balconyDir and math.abs(shift - balconyShift) < b.BAY_WIDTH * 0.6
	end)
	if balconyDir then
		addBalconies(body, balconyDir, floors, balconyShift, balconyFrom)
	end

	-- A tető a legfelső tömbre kerül: a felső emeletre, ha van, különben a testre.
	local top = body
	if spec.tier then
		local tierFloors = spec.tier.floors or 1
		local scale = spec.tier.scale or 0.65
		local tierHeight = tierFloors * b.FLOOR_HEIGHT
		addParapet(body, body, 1)
		top = detail(body, "Tier", {
			Size = Vector3.new(body.Size.X * scale, tierHeight, body.Size.Z * scale),
			CFrame = body.CFrame * CFrame.new(0, height / 2 + 0.6 + tierHeight / 2, 0),
			Material = body.Material,
		}, grey)
		if not spec.clock then
			addWindows(body, top, tierFloors, style)
		end
	end

	local roofColor = spec.roofColor or pick(b.ROOF_COLORS)
	local roofHeight = 0
	if roof == "gable" then
		if top ~= body then
			alongX = if spec.ridge then spec.ridge == "x" else top.Size.X >= top.Size.Z
		end
		roofHeight = addGable(body, top, alongX, roofColor)
		if spec.chimney and top == body then
			addChimney(body, top, alongX, roofHeight)
		end
	elseif roof == "cross" then
		addGable(body, top, true, roofColor)
		addGable(body, top, false, roofColor)
	else
		addParapet(body, top, if floors >= 3 then 1.4 else 1)
		addRoofClutter(body, top)
	end

	if spec.clock then
		addClock(body, top, FACES[spec.clock].dir, top.Size.Y * 0.45)
	end
	if roseDir then
		if roseInGable then
			-- Az oromzat háromszögében, a tető alatt
			local d = math.min(roseDiameter, roofHeight * 0.8)
			addRoseWindow(body, roseDir, height + roofHeight * 0.4, d)
		else
			addRoseWindow(body, roseDir, height - roseDiameter / 2 - 1, roseDiameter)
		end
	end

	body.Parent = Common.folders.buildings
	table.insert(bodies, body)
	-- Alaprajz a foglaltsági térképbe (elöl-hátul nagyobb ráhagyással az ajtó, lépcső, erkély miatt)
	local pos = body.Position
	Common.occupy(Common.rect(pos.X, pos.Z, body.Size.X / 2 + 0.5, body.Size.Z / 2 + 1.8, spec.rot or 0))
	return body
end

-- Takarja-e egy másik épület teste a pontot.
local function insideOtherBuilding(point: Vector3, own: BasePart): boolean
	for _, other in bodies do
		if other ~= own then
			local localPoint = other.CFrame:PointToObjectSpace(point)
			local half = other.Size / 2 + Vector3.new(0.5, 0, 0.5)
			if
				math.abs(localPoint.X) < half.X
				and math.abs(localPoint.Y) < half.Y
				and math.abs(localPoint.Z) < half.Z
			then
				return true
			end
		end
	end
	return false
end

-- A pálya végén: az ablakok felrakása, kivéve ahol közvetlenül egy másik ház áll előttük.
function Buildings.finish()
	for _, w in pendingWindows do
		local body, part, dir, normal, shift, y = w[1], w[2], w[3], w[4], w[5], w[6]
		local inFront = onFace(part, dir, 2.5, shift, y).Position
		if not insideOtherBuilding(inFront, body) then
			addWindow(body, part, dir, normal, shift, y, w[7], w[8])
		end
	end
	pendingWindows = {}
end

return Buildings
