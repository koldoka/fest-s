-- Tárgyak a Kithez: fák, padok, lámpák, kerítések… Mind a Props mappába kerül, Modelként.
-- Festetlenül szürkék. Ha egy festékes paca hozzáér, színesek lesznek: a "festhető" részeik a festék
-- színét kapják (lomb, ülőke, lámpaoszlop, napernyő…), a többi a természetes színét (törzs, vasláb, víz).
-- Más színnel át is festhetők. Ez festéket nem fogyaszt, és pont sem jár érte.
--
-- Egy rész festési módja (PaintRole attribútum):
--   nincs  -> a természetes színe (PaintedColor)
--   "paint" -> a festék színe;  "light" -> világosabb;  "dark" -> sötétebb

local Common = require(script.Parent.Common)

local pick = Common.pick

local Props = {}

-- A tárgy alaprajzának feljegyzése a foglaltsági térképbe (hogy a kitöltés ne tegyen rá semmit).
local function occupy(at: Vector3, hx: number, hz: number, rot: number?)
	Common.occupy(Common.rect(at.X, at.Z, hx, hz, rot))
end

local function newProp(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("ColorName", "")
	model.Parent = Common.folders.props
	return model
end

-- A tárgy egy része. color: a természetes színe (a festhető részeknél csak a szürke árnyalathoz kell).
local function propPart(model: Model, color: Color3, props: { [string]: any }, paintRole: string?): BasePart
	local grey = Common.toGrey(color)
	props.Color = grey
	local part = Common.newPart(props)
	part:SetAttribute("BaseColor", grey)
	part:SetAttribute("PaintedColor", color)
	if paintRole then
		part:SetAttribute("PaintRole", paintRole)
	end
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

local WOOD = Color3.fromRGB(150, 98, 58)
local IRON = Color3.fromRGB(46, 52, 58)
local LEAF = Color3.fromRGB(96, 164, 76)
local STONE = Color3.fromRGB(214, 200, 176)

-- Fa: törzs és több gömbből álló lombkorona. A lomb a festék színét kapja, árnyalatokkal.
function Props.tree(at: Vector3, scale: number?)
	occupy(at, 3, 3)
	local rng = Common.rng
	local s = (scale or 1) * rng:NextNumber(0.85, 1.15)
	local model = newProp("Tree")
	propPart(model, Color3.fromRGB(120, 84, 56), cylinderUp(at + Vector3.new(0, 3.2 * s, 0), 6.4 * s, 1.2 * s))
	propPart(model, Color3.fromRGB(120, 84, 56), cylinderUp(at + Vector3.new(0, 0.4 * s, 0), 0.8 * s, 1.8 * s))
	local crowns = {
		{ Vector3.new(0, 8, 0), 6, "paint" },
		{ Vector3.new(1.8, 6.6, 0.9), 4.4, "dark" },
		{ Vector3.new(-1.7, 6.8, -1.1), 4.4, "light" },
		{ Vector3.new(-0.6, 6.4, 1.9), 3.8, "paint" },
		{ Vector3.new(0.8, 10, -0.4), 3.6, "light" },
	}
	for _, c in crowns do
		local jitter = Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
		propPart(
			model,
			LEAF,
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * c[2] * s, Position = at + (c[1] + jitter) * s },
			c[3]
		)
	end
end

-- Bokor: pár gömb a földön.
function Props.bush(at: Vector3, scale: number?)
	occupy(at, 2, 2)
	local s = scale or 1
	local model = newProp("Bush")
	for _, c in
		{
			{ Vector3.new(0, 1.2, 0), 2.8, "paint" },
			{ Vector3.new(1.3, 0.9, 0.4), 2, "dark" },
			{ Vector3.new(-1.2, 0.9, -0.3), 2.1, "light" },
		}
	do
		propPart(
			model,
			LEAF,
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * c[2] * s, Position = at + c[1] * s },
			c[3]
		)
	end
end

-- Pad: ülőlap, háttámla, két vasláb. rot: merre néz az ülő (mint az épületeknél).
function Props.bench(at: Vector3, rot: number)
	occupy(at, 3, 1.5, rot)
	local model = newProp("Bench")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	propPart(model, WOOD, { Size = Vector3.new(5, 0.3, 1.5), CFrame = base * CFrame.new(0, 1.3, 0) }, "paint")
	propPart(model, WOOD, {
		Size = Vector3.new(5, 1.2, 0.25),
		-- Hátradőlő támla: a teteje az ülőtől elfelé (+Z) hajlik
		CFrame = base * CFrame.new(0, 2.2, 0.75) * CFrame.Angles(math.rad(12), 0, 0),
	}, "paint")
	for _, x in { -2, 2 } do
		propPart(model, IRON, { Size = Vector3.new(0.3, 1.2, 1.4), CFrame = base * CFrame.new(x, 0.6, 0) })
		propPart(model, IRON, { Size = Vector3.new(0.3, 0.8, 0.3), CFrame = base * CFrame.new(x, 1.8, 0.65) })
	end
end

-- Utcai lámpa: talapzat, oszlop, lámpafej üveggel és tetővel. Az oszlop a festék sötétebb árnyalatát kapja.
function Props.lamp(at: Vector3)
	occupy(at, 1, 1)
	local model = newProp("Lamp")
	propPart(model, IRON, cylinderUp(at + Vector3.new(0, 0.5, 0), 1, 1.3), "dark")
	propPart(model, IRON, cylinderUp(at + Vector3.new(0, 4.5, 0), 8, 0.45), "dark")
	propPart(model, IRON, cylinderUp(at + Vector3.new(0, 8.5, 0), 0.3, 1.1), "dark")
	propPart(
		model,
		Color3.fromRGB(255, 232, 160),
		{ Size = Vector3.new(1.3, 1.6, 1.3), Position = at + Vector3.new(0, 9.45, 0), Material = Enum.Material.Neon }
	)
	propPart(model, IRON, { Size = Vector3.new(1.8, 0.3, 1.8), Position = at + Vector3.new(0, 10.4, 0) }, "dark")
	propPart(
		model,
		IRON,
		{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Position = at + Vector3.new(0, 10.75, 0) },
		"dark"
	)
end

-- Virágláda: a láda a festék színét kapja, a virágok tarkák.
function Props.planter(at: Vector3, rot: number, length: number?)
	occupy(at, (length or 4) / 2 + 0.5, 1, rot)
	local len = length or 4
	local model = newProp("Planter")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	propPart(
		model,
		Color3.fromRGB(176, 112, 76),
		{ Size = Vector3.new(len, 1.2, 1.4), CFrame = base * CFrame.new(0, 0.6, 0) },
		"paint"
	)
	propPart(model, LEAF, {
		Size = Vector3.new(len - 0.3, 0.4, 1.1),
		CFrame = base * CFrame.new(0, 1.3, 0),
		Material = Enum.Material.Grass,
	})
	local flowers = {
		Color3.fromRGB(236, 84, 120),
		Color3.fromRGB(252, 206, 70),
		Color3.fromRGB(240, 120, 60),
		Color3.fromRGB(180, 100, 220),
		Color3.fromRGB(250, 250, 250),
	}
	local count = math.max(2, math.floor(len / 0.9))
	for i = 1, count do
		local x = (i - 0.5) / count * len - len / 2
		local z = if i % 2 == 0 then 0.25 else -0.25
		propPart(
			model,
			pick(flowers),
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = base * CFrame.new(x, 1.8, z) }
		)
	end
end

-- Kávézóasztal napernyővel és két székkel.
function Props.cafeTable(at: Vector3)
	occupy(at, 3.5, 3.5)
	local model = newProp("CafeTable")
	propPart(model, Color3.fromRGB(240, 238, 230), cylinderUp(at + Vector3.new(0, 2.2, 0), 0.25, 3))
	propPart(model, IRON, cylinderUp(at + Vector3.new(0, 1.1, 0), 2.2, 0.35))
	propPart(model, IRON, cylinderUp(at + Vector3.new(0, 4.3, 0), 4.2, 0.25))
	propPart(model, Color3.fromRGB(226, 76, 70), cylinderUp(at + Vector3.new(0, 6.3, 0), 0.4, 6.5), "paint")
	propPart(model, Color3.fromRGB(226, 76, 70), cylinderUp(at + Vector3.new(0, 6.6, 0), 0.3, 3.5), "light")
	for _, x in { -2.1, 2.1 } do
		propPart(model, WOOD, { Size = Vector3.new(1.2, 0.25, 1.2), Position = at + Vector3.new(x, 1.3, 0) }, "dark")
		propPart(
			model,
			WOOD,
			{ Size = Vector3.new(0.25, 1.3, 1.2), Position = at + Vector3.new(x + (if x > 0 then 0.5 else -0.5), 2, 0) },
			"dark"
		)
		-- Négy vékony vasláb az ülőke sarkainál
		for _, lx in { -0.45, 0.45 } do
			for _, lz in { -0.45, 0.45 } do
				propPart(
					model,
					IRON,
					{ Size = Vector3.new(0.18, 1.2, 0.18), Position = at + Vector3.new(x + lx, 0.6, lz) }
				)
			end
		end
	end
end

-- Piaci stand: pult, négy oszlop, lejtős ponyvatető, áru a pulton.
function Props.stall(at: Vector3, rot: number)
	occupy(at, 4, 3, rot)
	local model = newProp("Stall")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	propPart(model, WOOD, { Size = Vector3.new(6, 2.4, 2.2), CFrame = base * CFrame.new(0, 1.2, -0.8) }, "dark")
	for _, p in
		{ Vector3.new(-2.8, 0, -1.8), Vector3.new(2.8, 0, -1.8), Vector3.new(-2.8, 0, 1.6), Vector3.new(2.8, 0, 1.6) }
	do
		propPart(
			model,
			WOOD,
			{ Size = Vector3.new(0.35, 5.6, 0.35), CFrame = base * CFrame.new(p + Vector3.new(0, 2.8, 0)) }
		)
	end
	local roofCf = base * CFrame.new(0, 5.8, -0.1) * CFrame.Angles(math.rad(-12), 0, 0)
	for i = 0, 5 do
		propPart(model, Color3.fromRGB(214, 70, 64), {
			Size = Vector3.new(6.8 / 6, 0.25, 4.6),
			CFrame = roofCf * CFrame.new((i + 0.5) * 6.8 / 6 - 3.4, 0, 0),
		}, if i % 2 == 0 then "paint" else nil)
	end
	local goods = { Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 170, 40), Color3.fromRGB(120, 190, 70) }
	for i = -2, 2 do
		propPart(
			model,
			pick(goods),
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = base * CFrame.new(i * 1.1, 2.8, -0.9) }
		)
	end
end

-- Szökőkút: kerek medence vízzel, középen oszlop és felső tál. A kőszegélyek a festék világos árnyalatát kapják.
function Props.fountain(at: Vector3, radius: number)
	occupy(at, radius + 1, radius + 1)
	local model = newProp("Fountain")
	local water = Color3.fromRGB(80, 170, 230)
	propPart(model, STONE, cylinderUp(at + Vector3.new(0, 0.8, 0), 1.6, radius * 2), "light")
	local pool = propPart(model, water, cylinderUp(at + Vector3.new(0, 1.2, 0), 1.0, radius * 2 - 1.6))
	pool.Material = Enum.Material.Glass
	pool.Transparency = 0.15
	pool:SetAttribute("Water", true)
	propPart(model, STONE, cylinderUp(at + Vector3.new(0, 3.2, 0), 4.2, 2.4))
	propPart(model, STONE, cylinderUp(at + Vector3.new(0, 5.4, 0), 0.8, radius * 0.8), "light")
	local top = propPart(model, water, cylinderUp(at + Vector3.new(0, 5.75, 0), 0.2, radius * 0.8 - 0.8))
	top.Material = Enum.Material.Glass
	propPart(
		model,
		STONE,
		{ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Position = at + Vector3.new(0, 6.6, 0) },
		"paint"
	)
end

-- Tavacska: lapos víztükör kőszegéllyel.
function Props.pond(at: Vector3, size: Vector2)
	occupy(at, size.X / 2 + 1.5, size.Y / 2 + 1.5)
	local model = newProp("Pond")
	propPart(
		model,
		STONE,
		{ Size = Vector3.new(size.X + 1.6, 0.5, size.Y + 1.6), Position = at + Vector3.new(0, 0.25, 0) },
		"light"
	)
	local water = propPart(
		model,
		Color3.fromRGB(70, 160, 220),
		{ Size = Vector3.new(size.X, 0.5, size.Y), Position = at + Vector3.new(0, 0.3, 0) }
	)
	water.Material = Enum.Material.Glass
	water:SetAttribute("Water", true)
end

-- Sövény két pont között.
function Props.hedge(from: Vector3, to: Vector3, height: number?)
	local h = height or 2.2
	local mid0 = (from + to) / 2
	Common.occupy(
		Common.rect(mid0.X, mid0.Z, 1, (to - from).Magnitude / 2, math.deg(math.atan2(to.X - from.X, to.Z - from.Z)))
	)
	local model = newProp("Hedge")
	local mid = (from + to) / 2 + Vector3.new(0, h / 2, 0)
	local length = (to - from).Magnitude
	local part = propPart(
		model,
		LEAF,
		{ Size = Vector3.new(1.6, h, length), CFrame = CFrame.lookAt(mid, mid + (to - from)) },
		"dark"
	)
	part.Material = Enum.Material.Grass
end

-- Léckerítés két pont között: oszlopok gombbal, két léc. A festék világos árnyalatát kapja.
function Props.fence(from: Vector3, to: Vector3)
	local mid0 = (from + to) / 2
	Common.occupy(
		Common.rect(mid0.X, mid0.Z, 0.5, (to - from).Magnitude / 2, math.deg(math.atan2(to.X - from.X, to.Z - from.Z)))
	)
	local model = newProp("Fence")
	local white = Color3.fromRGB(246, 244, 236)
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	local posts = math.max(2, math.floor(length / 2.5) + 1)
	for i = 0, posts - 1 do
		local p = from + dir * (length * i / (posts - 1))
		propPart(model, white, { Size = Vector3.new(0.4, 2.4, 0.4), Position = p + Vector3.new(0, 1.2, 0) }, "light")
		propPart(
			model,
			white,
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Position = p + Vector3.new(0, 2.5, 0) },
			"paint"
		)
	end
	for _, y in { 0.9, 1.8 } do
		local mid = (from + to) / 2 + Vector3.new(0, y, 0)
		propPart(
			model,
			white,
			{ Size = Vector3.new(0.2, 0.3, length), CFrame = CFrame.lookAt(mid, mid + dir) },
			"light"
		)
	end
end

-- Kőív két oszloppal (városkapu, átjáró); a tetején festhető sáv.
function Props.arch(at: Vector3, rot: number, width: number, height: number)
	occupy(at, width / 2 + 3, 2, rot)
	local model = newProp("Arch")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	for _, x in { -1, 1 } do
		propPart(
			model,
			STONE,
			{ Size = Vector3.new(2.4, height, 2.4), CFrame = base * CFrame.new(x * (width / 2 + 1.2), height / 2, 0) }
		)
	end
	propPart(
		model,
		STONE,
		{ Size = Vector3.new(width + 4.8, 2.4, 2.8), CFrame = base * CFrame.new(0, height + 1.2, 0) }
	)
	propPart(
		model,
		Color3.fromRGB(180, 70, 60),
		{ Size = Vector3.new(width + 5.4, 0.6, 3.4), CFrame = base * CFrame.new(0, height + 2.7, 0) },
		"paint"
	)
end

-- Kerti pavilon: padló, oszlopok, kereszt-nyeregtető a festék színében.
function Props.gazebo(at: Vector3, size: number)
	occupy(at, size / 2 + 1, size / 2 + 1)
	local model = newProp("Gazebo")
	local white = Color3.fromRGB(246, 244, 236)
	propPart(model, WOOD, { Size = Vector3.new(size, 0.6, size), Position = at + Vector3.new(0, 0.3, 0) })
	local h = 7
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			propPart(
				model,
				white,
				cylinderUp(at + Vector3.new(x * (size / 2 - 0.6), h / 2, z * (size / 2 - 0.6)), h, 0.6),
				"light"
			)
		end
	end
	local side = (size + 1.2) / math.sqrt(2)
	local roofs = {
		{ Vector3.new(size + 1, side, side), CFrame.Angles(math.rad(45), 0, 0) },
		{ Vector3.new(side, side, size + 1), CFrame.Angles(0, 0, math.rad(45)) },
	}
	for _, roof in roofs do
		propPart(
			model,
			Color3.fromRGB(64, 120, 110),
			{ Size = roof[1], CFrame = CFrame.new(at + Vector3.new(0, h, 0)) * roof[2] },
			"paint"
		)
	end
end

-- Kikötőbak / terelőoszlop.
function Props.bollard(at: Vector3)
	occupy(at, 0.6, 0.6)
	local model = newProp("Bollard")
	propPart(model, IRON, cylinderUp(at + Vector3.new(0, 0.9, 0), 1.8, 0.7), "dark")
	propPart(
		model,
		IRON,
		{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Position = at + Vector3.new(0, 1.9, 0) },
		"paint"
	)
end

-- Szélmalom lapátjai: agy és négy lapát egy függőleges síkban. hub: az agy közepe, facing: merre néz.
-- axle: a tengely hossza az agytól vissza (a fal előtti távolság + egy kicsi a falba).
function Props.windmillBlades(hub: Vector3, facing: Vector3, axle: number?)
	local axleLength = axle or 3
	local model = newProp("WindmillBlades")
	local base = CFrame.lookAt(hub, hub + facing)
	-- A lapátokat a kliens forgatja (Decor): a forgó részeket "Spin" jelöli, a tengely a SpinHub CFrame Z-je
	model:SetAttribute("SpinHub", base)
	local hubPart =
		propPart(model, WOOD, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = base }, "dark")
	hubPart:SetAttribute("Spin", true)
	-- Tengely az agytól vissza a toronyba (a hátsó fele a falban van)
	propPart(model, IRON, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(axleLength, 0.7, 0.7),
		CFrame = base * CFrame.new(0, 0, axleLength / 2) * CFrame.Angles(0, math.rad(90), 0),
	})
	-- Tartókonzol a falon: egy kis kőlap, amibe a tengely befut
	propPart(model, Color3.fromRGB(190, 180, 164), {
		Size = Vector3.new(2.2, 2.2, 0.6),
		CFrame = base * CFrame.new(0, 0, axleLength - 0.6),
	}, "light")
	for i = 0, 3 do
		local arm = base * CFrame.Angles(0, 0, math.rad(45 + i * 90))
		local spar =
			propPart(model, WOOD, { Size = Vector3.new(0.4, 10, 0.4), CFrame = arm * CFrame.new(0, 5.2, -0.3) }, "dark")
		local sail = propPart(
			model,
			Color3.fromRGB(240, 232, 214),
			{ Size = Vector3.new(2, 8, 0.2), CFrame = arm * CFrame.new(1.1, 6, -0.2) },
			"light"
		)
		spar:SetAttribute("Spin", true)
		sail:SetAttribute("Spin", true)
	end
end

-- Szobor talapzaton: a talapzat kő, a figura a festék színét kapja.
function Props.statue(at: Vector3, rot: number)
	occupy(at, 3, 3, rot)
	local model = newProp("Statue")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	-- Az MVP-szobor (StatueService): a talapzat teteje és iránya; az alak részeit "StatueFigure" jelöli,
	-- ezeket a legutóbbi meccs legjobb játékosának avatarja váltja fel.
	model:SetAttribute("MvpTop", (base * CFrame.new(0, 3.5, 0)).Position)
	model:SetAttribute("MvpRot", rot)
	propPart(model, STONE, { Size = Vector3.new(4, 3, 4), CFrame = base * CFrame.new(0, 1.5, 0) })
	propPart(model, STONE, { Size = Vector3.new(4.6, 0.5, 4.6), CFrame = base * CFrame.new(0, 3.25, 0) }, "light")
	local bronze = Color3.fromRGB(150, 120, 80)
	local figure = {
		propPart(model, bronze, { Size = Vector3.new(1.8, 3.2, 1.2), CFrame = base * CFrame.new(0, 5.1, 0) }, "paint"),
		propPart(
			model,
			bronze,
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.5, CFrame = base * CFrame.new(0, 7.4, 0) },
			"paint"
		),
		propPart(model, bronze, {
			Size = Vector3.new(0.5, 2.6, 0.5),
			CFrame = base * CFrame.new(1.2, 6.9, 0) * CFrame.Angles(0, 0, math.rad(-25)),
		}, "paint"),
		propPart(
			model,
			bronze,
			{ Size = Vector3.new(0.5, 2.2, 0.5), CFrame = base * CFrame.new(-1.15, 4.9, 0) },
			"paint"
		),
	}
	for _, part in figure do
		part:SetAttribute("StatueFigure", true)
	end
end

---------------------------------------------------------------------------------------------------
-- Kitöltő tárgyak (a Kit.fill teszi le őket az üres helyekre). A foglaltságot a Kit.fill jegyzi fel.

local SOIL = Color3.fromRGB(120, 86, 60)

-- Veteményes: földágyás növénysorokkal, néha madárijesztővel. A növények a festék színét kapják.
function Props.vegetablePatch(at: Vector3, rot: number, size: number)
	local model = newProp("VegetablePatch")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	propPart(
		model,
		SOIL,
		{ Size = Vector3.new(size, 0.5, size), CFrame = base * CFrame.new(0, 0.25, 0), Material = Enum.Material.Ground }
	)
	local rows = 3
	for i = 1, rows do
		local x = ((i - 0.5) / rows - 0.5) * size * 0.8
		propPart(model, LEAF, {
			Size = Vector3.new(size * 0.18, 0.9, size * 0.85),
			CFrame = base * CFrame.new(x, 0.9, 0),
			Material = Enum.Material.Grass,
		}, if i == 2 then "light" else "paint")
	end
	if Common.rng:NextNumber() < 0.3 then
		propPart(
			model,
			WOOD,
			{ Size = Vector3.new(0.3, 4, 0.3), CFrame = base * CFrame.new(size * 0.4, 2, size * 0.4) }
		)
		propPart(
			model,
			Color3.fromRGB(200, 60, 50),
			{ Size = Vector3.new(2.4, 0.3, 0.3), CFrame = base * CFrame.new(size * 0.4, 3, size * 0.4) },
			"paint"
		)
		propPart(model, Color3.fromRGB(220, 190, 120), {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1,
			CFrame = base * CFrame.new(size * 0.4, 4.2, size * 0.4),
		})
	end
end

-- Virágágyás: kerek földágyás tarka virágokkal.
function Props.flowerBed(at: Vector3, radius: number)
	local model = newProp("FlowerBed")
	propPart(model, STONE, cylinderUp(at + Vector3.new(0, 0.3, 0), 0.6, radius * 2), "light")
	propPart(model, LEAF, cylinderUp(at + Vector3.new(0, 0.5, 0), 0.5, radius * 2 - 0.8))
	local flowers = {
		Color3.fromRGB(236, 84, 120),
		Color3.fromRGB(252, 206, 70),
		Color3.fromRGB(240, 120, 60),
		Color3.fromRGB(250, 250, 250),
	}
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local r = radius * 0.5
		propPart(model, flowers[i % #flowers + 1], {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.2,
			Position = at + Vector3.new(math.cos(a) * r, 1.1, math.sin(a) * r),
		}, if i % 2 == 0 then "paint" else nil)
	end
end

-- Gyümölcsfa: kisebb fa, a lombban gyümölcsökkel.
function Props.fruitTree(at: Vector3)
	local model = newProp("FruitTree")
	propPart(model, Color3.fromRGB(120, 84, 56), cylinderUp(at + Vector3.new(0, 2, 0), 4, 0.9))
	propPart(
		model,
		LEAF,
		{ Shape = Enum.PartType.Ball, Size = Vector3.one * 5.5, Position = at + Vector3.new(0, 5.5, 0) },
		"paint"
	)
	propPart(
		model,
		LEAF,
		{ Shape = Enum.PartType.Ball, Size = Vector3.one * 3.5, Position = at + Vector3.new(1.3, 4.6, 0.8) },
		"dark"
	)
	local fruit = pick({ Color3.fromRGB(220, 50, 50), Color3.fromRGB(250, 170, 40), Color3.fromRGB(240, 220, 70) })
	for _, o in { Vector3.new(2.2, 5, -1), Vector3.new(-1.8, 6, 1.4), Vector3.new(0.4, 4.2, 2.4) } do
		propPart(model, fruit, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Position = at + o })
	end
end

-- Ládarakás (udvarra, piacra).
function Props.crates(at: Vector3, rot: number)
	local model = newProp("Crates")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	propPart(model, WOOD, { Size = Vector3.new(2, 2, 2), CFrame = base * CFrame.new(-1.1, 1, 0) }, "paint")
	propPart(model, WOOD, { Size = Vector3.new(2, 2, 2), CFrame = base * CFrame.new(1.1, 1, 0.3) }, "dark")
	propPart(
		model,
		WOOD,
		{ Size = Vector3.new(1.8, 1.8, 1.8), CFrame = base * CFrame.new(0, 2.9, 0.1) * CFrame.Angles(0, 0.3, 0) },
		"light"
	)
end

-- Kút: kerek kőkáva, két oszlop, kis tető.
function Props.well(at: Vector3)
	local model = newProp("Well")
	propPart(model, STONE, cylinderUp(at + Vector3.new(0, 1, 0), 2, 4))
	propPart(model, Color3.fromRGB(60, 110, 160), cylinderUp(at + Vector3.new(0, 1.9, 0), 0.3, 3))
	for _, x in { -1.7, 1.7 } do
		propPart(model, WOOD, { Size = Vector3.new(0.4, 3.4, 0.4), Position = at + Vector3.new(x, 3.4, 0) })
	end
	propPart(
		model,
		Color3.fromRGB(180, 70, 60),
		{ Size = Vector3.new(4.6, 0.4, 3), Position = at + Vector3.new(0, 5.2, 0) },
		"paint"
	)
end

-- Kerti fészer: deszkafal, nyeregtető, ajtó. A fal és a tető a festék árnyalatait kapja.
function Props.shed(at: Vector3, rot: number)
	local model = newProp("Shed")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	local w, d, h = 6, 5, 4
	local walls =
		propPart(model, WOOD, { Size = Vector3.new(w, h, d), CFrame = base * CFrame.new(0, h / 2, 0) }, "paint")
	walls.Material = Enum.Material.WoodPlanks
	-- Oromfal: két ék háttal egymásnak (nincs elforgatva, így a deszkaminta vízszintes marad)
	for _, sign in { -1, 1 } do
		propPart(model, WOOD, {
			ClassName = "WedgePart",
			Size = Vector3.new(w, d / 2, d / 2),
			CFrame = base * CFrame.new(0, h + d / 4, sign * d / 4) * (if sign > 0
				then CFrame.Angles(0, math.pi, 0)
				else CFrame.identity),
			Material = Enum.Material.WoodPlanks,
		}, "paint")
	end
	for _, sign in { 1, -1 } do
		local half = d / 2 + 0.5
		propPart(model, Color3.fromRGB(150, 70, 56), {
			Size = Vector3.new(w + 0.8, 0.3, half * math.sqrt(2)),
			CFrame = base
				* CFrame.new(0, h + (d / 2 - 0.5) / 2, sign * half / 2)
				* CFrame.Angles(sign * math.rad(45), 0, 0)
				* CFrame.new(0, 0.15, 0),
		}, "dark")
	end
	propPart(
		model,
		Color3.fromRGB(90, 62, 44),
		{ Size = Vector3.new(1.8, 3, 0.2), CFrame = base * CFrame.new(0, 1.5, -d / 2 - 0.1) }
	)
end

-- Vadvirágok: pár apró, tarka virág a fűben (rétekre).
function Props.wildflowers(at: Vector3)
	local model = newProp("Wildflowers")
	local rng = Common.rng
	local flowers = {
		Color3.fromRGB(236, 84, 120),
		Color3.fromRGB(252, 206, 70),
		Color3.fromRGB(250, 250, 250),
		Color3.fromRGB(180, 100, 220),
	}
	for i = 1, 4 do
		local o = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		propPart(model, LEAF, { Size = Vector3.new(0.25, 1, 0.25), Position = at + o + Vector3.new(0, 0.5, 0) }, "dark")
		propPart(
			model,
			flowers[i],
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Position = at + o + Vector3.new(0, 1.1, 0) },
			if i == 1 then "paint" else nil
		)
	end
end

-- Szénaboglya.
function Props.haystack(at: Vector3)
	local model = newProp("Haystack")
	local hay = Color3.fromRGB(226, 192, 100)
	propPart(model, hay, cylinderUp(at + Vector3.new(0, 1.2, 0), 2.4, 4.4), "light")
	propPart(
		model,
		hay,
		{ Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 4.4, 4.4), Position = at + Vector3.new(0, 2.4, 0) },
		"light"
	)
end

-- Egyszerű erdei fa a városfalon kívülre (csak díszlet: nem festhető, nem kerül a Props mappába).
function Props.forestTree(parent: Instance, at: Vector3, scale: number)
	local trunk = Common.newPart(cylinderUp(at + Vector3.new(0, 4 * scale, 0), 8 * scale, 1.4 * scale))
	trunk.Color = Color3.fromRGB(96, 80, 66)
	trunk.Parent = parent
	for i, o in { Vector3.new(0, 10, 0), Vector3.new(1.5, 7.5, 1) } do
		local crown = Common.newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (if i == 1 then 8 else 6) * scale,
			Position = at + o * scale,
		})
		crown.Color = Color3.fromRGB(84, 108, 84)
		crown.Material = Enum.Material.Grass
		crown.Parent = parent
	end
end

return Props
