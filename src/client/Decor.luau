-- Díszek és mozgó részletek (csak látvány, a kliensen):
--   Szélmalom: a lapátok forognak ("Spin" jelölésű részek a SpinHub tengely körül); befestve gyorsabban.
--   Virágládák: a befestett házak néhány ablaka alá virágláda kerül virágokkal; visszaszürküléskor eltűnnek.
--   Cégér: a befestett boltok falán kiálló vastartón lengő tábla a bolt nevével, a festék színében.
--   Hogy melyik ablak kap ládát, a ház helyéből sorsolódik, így minden játékosnál ugyanaz.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local LevelReady = require(script.Parent.LevelReady)

local Decor = {}

local MAX_BOXES = 3 -- házanként legfeljebb ennyi virágláda
local WOOD = Color3.fromRGB(116, 76, 46)
local LEAVES = Color3.fromRGB(74, 150, 70)
local BLOSSOMS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 214, 80),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(190, 120, 240),
	Color3.fromRGB(255, 150, 70),
}

local folder: Folder

-- Lengő cégértáblák: a felfüggesztési pont, és a tábla helye ahhoz képest.
type Swinger = { plate: BasePart, pivot: CFrame, offset: CFrame, phase: number }
local swingers: { [BasePart]: Swinger } = {}

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

---------------------------------------------------------------------------------------------------
-- Szélmalom

type Spinner = { model: Model, hub: CFrame, parts: { { part: BasePart, offset: CFrame } }, angle: number }
local spinners: { Spinner } = {}

local function addSpinner(model: Model)
	local hub = model:GetAttribute("SpinHub")
	if typeof(hub) ~= "CFrame" then
		return
	end
	local list = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Spin") then
			table.insert(list, { part = p, offset = hub:ToObjectSpace(p.CFrame) })
		end
	end
	table.insert(spinners, { model = model, hub = hub, parts = list, angle = 0 })
end

local function spin(dt: number)
	-- Cégérek lengése (kis szögben, a felfüggesztési pont körül)
	local t = os.clock()
	for _, s in swingers do
		s.plate.CFrame = s.pivot * CFrame.Angles(math.sin(t * 1.4 + s.phase) * math.rad(5), 0, 0) * s.offset
	end
	for _, s in spinners do
		if s.model.Parent == nil then
			continue
		end
		local painted = (s.model:GetAttribute("ColorName") or "") ~= ""
		s.angle = (s.angle + dt * (if painted then 1.3 else 0.35)) % (math.pi * 2)
		local frame = s.hub * CFrame.Angles(0, 0, s.angle)
		for _, entry in s.parts do
			entry.part.CFrame = frame * entry.offset
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Virágládák

local boxes: { [BasePart]: Model } = {}

-- Az ablaklapok, amelyek alá láda kerülhet (a magas templomablakok és a függönyös, virágládás képek nem).
local function windowSpots(building: BasePart): { { cf: CFrame, width: number } }
	if building:GetAttribute("WindowVariant") == "curtain" then
		return {}
	end
	local spots = {}
	for _, panel in building:GetDescendants() do
		if not panel:IsA("BasePart") or panel.Name ~= "WindowPanel" then
			continue
		end
		local decal = panel:FindFirstChildOfClass("Decal")
		if not decal then
			continue
		end
		local localNormal = Vector3.FromNormalId(decal.Face)
		local width = if localNormal.X ~= 0 then panel.Size.Z else panel.Size.X
		if panel.Size.Y > width * 1.2 then
			continue -- magas ablak
		end
		local normal = panel.CFrame:VectorToWorldSpace(localNormal)
		-- A kép alsó harmadában van az ablakpárkány; a láda közvetlenül alá, a falhoz simulva
		local sill = panel.Position - Vector3.new(0, panel.Size.Y * 0.36, 0)
		local center = sill + normal * 0.45 - Vector3.new(0, 0.3, 0)
		table.insert(spots, { cf = CFrame.lookAt(center, center + normal), width = width * 0.55 })
	end
	return spots
end

---------------------------------------------------------------------------------------------------
-- Cégér

local function addHangingSign(building: BasePart, model: Model)
	local sign: BasePart? = nil
	for _, d in building:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Role") == "Sign" then
			sign = d
			break
		end
	end
	if not sign then
		return
	end
	local label = sign:FindFirstChildWhichIsA("TextLabel", true)
	local name = if label then label.Text else "SHOP"

	-- A cégtábla melyik oldalon van: a ház közepétől a tábla felé eső tengely
	local localPos = building.CFrame:PointToObjectSpace(sign.Position)
	local half = building.Size / 2
	local axis = if math.abs(localPos.X) / half.X > math.abs(localPos.Z) / half.Z
		then Vector3.xAxis * math.sign(localPos.X)
		else Vector3.zAxis * math.sign(localPos.Z)
	local normal = building.CFrame:VectorToWorldSpace(axis)
	local along = Vector3.yAxis:Cross(normal).Unit
	local faceWidth = math.abs(building.CFrame:VectorToWorldSpace(Vector3.new(half.X, 0, half.Z) * 2):Dot(along))
	-- Az ajtóval ellentétes sarok felé
	local side = 1
	for _, d in building:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Door" and d.Position.Y < sign.Position.Y then
			side = if (d.Position - sign.Position):Dot(along) > 0 then -1 else 1
			break
		end
	end
	local wall = sign.Position - normal * 0.1 -- a fal síkja (a cégtábla 0,1 studdal előtte áll)
	local anchor = Vector3.new(wall.X, sign.Position.Y + 2.6, wall.Z) + along * side * (faceWidth / 2 - 1.4)
	local frame = CFrame.fromMatrix(anchor, normal, Vector3.yAxis) -- X: kifelé a faltól

	local iron = Color3.fromRGB(46, 44, 48)
	local bar = part({ Size = Vector3.new(2.6, 0.18, 0.18), CFrame = frame * CFrame.new(1.3, 0, 0), Color = iron })
	bar.Parent = model
	local brace = part({
		Size = Vector3.new(1.7, 0.14, 0.14),
		CFrame = frame * CFrame.new(0.6, -0.6, 0) * CFrame.Angles(0, 0, math.rad(40)),
		Color = iron,
	})
	brace.Parent = model
	local paint = building.Color
	-- A tábla a rúd végéhez közel lóg; a felfüggesztési pont körül leng
	local pivot = frame * CFrame.new(1.6, -0.1, 0)
	local offset = CFrame.new(0, -1.05, 0)
	local plate = part({
		Size = Vector3.new(1.9, 1.6, 0.16),
		CFrame = pivot * offset,
		Color = paint,
	})
	plate.Parent = model
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 1
		gui.Parent = plate
		local inner = Instance.new("Frame")
		inner.Position = UDim2.fromScale(0.08, 0.1)
		inner.Size = UDim2.fromScale(0.84, 0.8)
		inner.BackgroundColor3 = Color3.fromRGB(250, 244, 226)
		inner.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = inner
		local text = Instance.new("TextLabel")
		text.Position = UDim2.fromScale(0.06, 0.1)
		text.Size = UDim2.fromScale(0.88, 0.8)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = paint:Lerp(Color3.new(0, 0, 0), 0.45)
		text.Text = name
		text.Parent = inner
	end
	swingers[plate] = { plate = plate, pivot = pivot, offset = offset, phase = math.random() * 6 }
end

local function addBoxes(building: BasePart)
	if boxes[building] then
		return
	end
	local spots = windowSpots(building)
	-- A ház helyéből sorsolva, hogy minden kliensnél ugyanaz legyen
	local p = building.Position
	local rng = Random.new(math.floor(p.X * 7.3 + p.Z * 13.1 + p.Y * 3.7))
	for i = #spots, 2, -1 do
		local j = rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	local model = Instance.new("Model")
	model.Name = "Decor"
	addHangingSign(building, model)
	for i = 1, math.min(MAX_BOXES, #spots) do
		local spot = spots[i]
		local w = spot.width
		local box = part({
			Size = Vector3.new(w, 0.55, 0.7),
			CFrame = spot.cf,
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
		})
		box.Parent = model
		local leaves = part({
			Size = Vector3.new(w * 0.95, 0.35, 0.55),
			CFrame = spot.cf * CFrame.new(0, 0.42, 0),
			Color = LEAVES,
			Material = Enum.Material.Grass,
			CastShadow = false,
		})
		leaves.Parent = model
		for k = -1, 1 do
			local blossom = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(0.4, 0.55),
				CFrame = spot.cf * CFrame.new(k * w / 3 + rng:NextNumber(-0.15, 0.15), 0.7, rng:NextNumber(-0.1, 0.1)),
				Color = BLOSSOMS[rng:NextInteger(1, #BLOSSOMS)],
				CastShadow = false,
			})
			blossom.Parent = model
		end
	end
	-- Kis késéssel és "kinövéssel" jelennek meg (a festés fröccsenése után)
	for _, item in model:GetChildren() do
		local target = (item :: BasePart).Size;
		(item :: BasePart).Size = target * 0.1
		TweenService:Create(
			item,
			TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.3),
			{ Size = target }
		):Play()
	end
	model.Parent = folder
	boxes[building] = model
end

local function removeBoxes(building: BasePart)
	local model = boxes[building]
	if model then
		for _, item in model:GetChildren() do
			swingers[item :: BasePart] = nil
		end
		model:Destroy()
		boxes[building] = nil
	end
end

local function watchBuilding(building: Instance)
	if not building:IsA("BasePart") then
		return
	end
	local function update()
		if (building:GetAttribute("ColorName") or "") ~= "" then
			addBoxes(building)
		else
			removeBoxes(building)
		end
	end
	building:GetAttributeChangedSignal("ColorName"):Connect(update)
	update()
end

function Decor.start()
	folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = workspace
	if not Config.DECOR_FLOWER_BOXES then
		MAX_BOXES = 0
	end

	task.spawn(function()
		local level = LevelReady.wait()
		local props = level:WaitForChild("Props")
		local buildings = level:WaitForChild("Buildings")
		local function onProp(model: Instance)
			if model:IsA("Model") and model:GetAttribute("SpinHub") then
				task.wait() -- a részei is megérkezzenek
				addSpinner(model)
			end
		end
		for _, model in props:GetChildren() do
			task.spawn(onProp, model)
		end
		props.ChildAdded:Connect(onProp)
		if MAX_BOXES > 0 then
			for _, building in buildings:GetChildren() do
				watchBuilding(building)
			end
			buildings.ChildAdded:Connect(watchBuilding)
		end
	end)

	RunService.RenderStepped:Connect(spin)
end

return Decor
