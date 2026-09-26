-- MVP-szobor: a főtéri szobor talapzatán a legutóbbi meccs legjobb festőjének (a legtöbb saját pont)
-- Roblox-avatarja áll győzelmi pózban, alatta arany plakett a nevével és a pontjával.
-- Amíg nincs MVP, az eredeti bronzalak áll ott, a plaketten biztatás.
-- A szobor a pálya egy Statue tárgya (Kit.statue), az "MvpTop" attribútumú első; az avatar nem festhető
-- (nem a Props mappában van).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StatueService = {}

local FIGURE_HEIGHT = 5.6 -- ilyen magas legyen az avatar a talapzaton (stud)

local statue: Model? = nil
local figureParts: { BasePart } = {}
local plaqueNames: { TextLabel } = {} -- a két plakett (elöl, hátul) feliratai
local plaqueInfos: { TextLabel } = {}
local current: Model? = nil
local folder: Folder? = nil
local requestId = 0

local function makePlaque(model: Model)
	local top: Vector3 = model:GetAttribute("MvpTop")
	local rot: number = model:GetAttribute("MvpRot") or 0
	local base = CFrame.new(top - Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, math.rad(rot), 0)
	for _, side in { 0, 180 } do
		local plaque = Instance.new("Part")
		plaque.Name = "MvpPlaque"
		plaque.Anchored = true
		plaque.CanCollide = false
		plaque.CanQuery = false
		plaque.CanTouch = false
		plaque.Material = Enum.Material.Metal
		plaque.Color = Color3.fromRGB(214, 172, 70)
		plaque.Reflectance = 0.15
		plaque.Size = Vector3.new(3.2, 1.9, 0.12)
		plaque.CFrame = base * CFrame.Angles(0, math.rad(side), 0) * CFrame.new(0, 1.6, -2.06)
		plaque.Parent = folder
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 1
		gui.Parent = plaque
		local function text(y: number, height: number, content: string): TextLabel
			local l = Instance.new("TextLabel")
			l.Position = UDim2.fromScale(0.06, y)
			l.Size = UDim2.fromScale(0.88, height)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextColor3 = Color3.fromRGB(70, 48, 16)
			l.Text = content
			l.Parent = gui
			return l
		end
		text(0.06, 0.24, "MVP")
		table.insert(plaqueNames, text(0.32, 0.36, "Your name here?"))
		table.insert(plaqueInfos, text(0.72, 0.2, "Top painter of the match"))
	end
end

local function showOriginal(visible: boolean)
	for _, part in figureParts do
		part.Transparency = if visible then 0 else 1
		part.CanCollide = visible
		part.CanQuery = visible -- elrejtve ne lehessen "befesteni"
	end
end

-- Az avatar leírása: a karakteréből (a Studio tesztjátékosainál is működik), különben a fiókjából.
local function descriptionOf(player: Player): HumanoidDescription
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ok, description = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if ok and description then
			return description
		end
	end
	if player.UserId > 0 then
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok and description then
			return description
		end
	end
	return Instance.new("HumanoidDescription")
end

-- Győzelmi póz: mindkét kar ferdén a magasba (V), a fej kicsit felfelé néz.
-- Az ízületek átállítása a szerveren nem mozgatja a végtagokat, ezért a már rögzített (Anchored) részeket
-- közvetlenül forgatjuk el: egy végtag minden részét (és a rá erősített kiegészítőket) a csukló/váll
-- pontja körül, a törzs saját tengelyei szerint.
local function pose(model: Model)
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	if not torso then
		return
	end
	-- Melyik kiegészítő melyik testrészhez van erősítve
	local attachedTo: { [BasePart]: { BasePart } } = {}
	for _, weld in model:GetDescendants() do
		if weld:IsA("JointInstance") and weld.Part0 and weld.Part1 then
			local handle = if weld.Part0.Name == "Handle" then weld.Part0 else weld.Part1
			local body = if handle == weld.Part0 then weld.Part1 else weld.Part0
			if handle.Name == "Handle" and body then
				attachedTo[body] = attachedTo[body] or {}
				table.insert(attachedTo[body] :: { BasePart }, handle)
			end
		end
	end
	local function rotate(partNames: { string }, jointPart: string, jointName: string, rotation: CFrame)
		local first = model:FindFirstChild(jointPart)
		local joint = first and first:FindFirstChild(jointName)
		if not joint or not joint:IsA("Motor6D") or not joint.Part0 then
			return
		end
		-- A forgáspont: az ízület helye, a törzs irányában
		local pivotPosition = (joint.Part0.CFrame * joint.C0).Position
		local pivot = CFrame.new(pivotPosition) * torso.CFrame.Rotation
		local transform = pivot * rotation * pivot:Inverse()
		for _, name in partNames do
			local part = model:FindFirstChild(name) :: BasePart?
			if part then
				part.CFrame = transform * part.CFrame
				for _, handle in attachedTo[part] or {} do
					handle.CFrame = transform * handle.CFrame
				end
			end
		end
	end
	rotate(
		{ "RightUpperArm", "RightLowerArm", "RightHand" },
		"RightUpperArm",
		"RightShoulder",
		CFrame.Angles(0, 0, math.rad(150))
	)
	rotate(
		{ "LeftUpperArm", "LeftLowerArm", "LeftHand" },
		"LeftUpperArm",
		"LeftShoulder",
		CFrame.Angles(0, 0, math.rad(-150))
	)
	rotate({ "Head" }, "Head", "Neck", CFrame.Angles(math.rad(12), 0, 0))
end

local function buildFigure(player: Player): Model?
	local description = descriptionOf(player)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Paint Pop] MVP statue: could not build avatar:", model)
		return nil
	end
	model.Name = "MvpFigure"
	for _, item in model:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = false
			item.CanTouch = false
			item.CanQuery = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true -- a gyökér rögzített, a végtagokat az ízületek tartják (így a póz megmarad)
	end
	return model
end

-- A figura ráállítása a talapzatra: méretezés, irány, és az alja pontosan a talapzat tetejére.
local function place(model: Model)
	local s = statue :: Model
	local top: Vector3 = s:GetAttribute("MvpTop")
	local rot: number = s:GetAttribute("MvpRot") or 0
	model.Parent = folder -- a méretezéshez és a befoglaló dobozhoz a világban kell lennie
	local height = model:GetExtentsSize().Y
	if height > 0 then
		pcall(function()
			model:ScaleTo(model:GetScale() * FIGURE_HEIGHT / height)
		end)
	end
	model:PivotTo(CFrame.new(top) * CFrame.Angles(0, math.rad(rot), 0))
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, top.Y - bottom + 0.05, 0))

	-- Egy-két fizikai lépés, amíg a végtagok a helyükre kerülnek; utána minden részt rögzítünk (így az
	-- ízületek már nem mozgatják őket), és a pózt a részek elforgatásával állítjuk be.
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	pose(model)

	-- Aranyló csillogás körülötte
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 224, 120))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(1, 1.6)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = root
	end
end

-- A pálya betöltése után: megkeresi a szobrot, és felteszi a plakettet.
function StatueService.setup(props: Folder)
	for _, model in props:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("MvpTop") then
			statue = model
			break
		end
	end
	if not statue then
		return
	end
	for _, part in (statue :: Model):GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("StatueFigure") then
			table.insert(figureParts, part)
		end
	end
	local f = Instance.new("Folder")
	f.Name = "MvpStatue"
	f.Parent = (statue :: Model).Parent and (statue :: Model).Parent.Parent or workspace -- a Level mappába
	folder = f
	makePlaque(statue :: Model)
end

-- Az új MVP a szoborra kerül (az előző helyére). Aszinkron: az avatar betöltése eltarthat egy ideig.
function StatueService.setMvp(player: Player, score: number)
	if not statue then
		return
	end
	requestId += 1
	local id = requestId
	local name = player.DisplayName
	task.spawn(function()
		local model = buildFigure(player)
		if id ~= requestId then
			if model then
				model:Destroy()
			end
			return
		end
		if current then
			current:Destroy()
			current = nil
		end
		if model then
			place(model)
			current = model
			showOriginal(false)
		else
			showOriginal(true)
		end
		for _, label in plaqueNames do
			label.Text = name
		end
		for _, label in plaqueInfos do
			label.Text = `Top painter: {score} points`
		end
	end)
end

return StatueService
