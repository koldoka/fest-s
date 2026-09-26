-- A kerületek a pályán (csak látvány, a kliensen; az állapot a ReplicatedStorage.Districts mappából jön):
--   Minden kerület fölött egy lebegő tábla: a kerület neve, a csapatok házai egy sávban, a gazda színe,
--   lezárva a hátralévő idő.
--   Lezárt kerület: a határán csillogó, csapatszínű erőtér-fal áll, amíg a lezárás tart.
--   Teljes elfoglaláskor a kerület házaiból színes konfetti pattan ki, és fanfár szól; feloldáskor csengő.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)

local Districts = {}

local BANNER_HEIGHT = 62 -- a tábla ilyen magasan lebeg (a legmagasabb torony, ~52, fölött)
local WALL_HEIGHT = 30

type View = {
	folder: Instance,
	anchor: BasePart,
	name: TextLabel,
	status: TextLabel,
	stroke: UIStroke,
	segments: { [string]: Frame },
	walls: { BasePart },
	locked: boolean,
}

local views: { View } = {}
local connections: { RBXScriptConnection } = {}
local effectsFolder: Folder

local function rectsOf(folder: Instance): { { lo: Vector2, hi: Vector2 } }
	local list = {}
	for _, rect in folder:GetChildren() do
		local lo, hi = rect:GetAttribute("Min"), rect:GetAttribute("Max")
		if typeof(lo) == "Vector2" and typeof(hi) == "Vector2" then
			table.insert(list, { lo = lo, hi = hi })
		end
	end
	return list
end

-- Lebegő tábla a kerület legnagyobb téglalapjának közepe fölött.
local function makeBanner(folder: Instance): View?
	local rects = rectsOf(folder)
	local best, bestArea = nil, -1
	for _, r in rects do
		local area = (r.hi.X - r.lo.X) * (r.hi.Y - r.lo.Y)
		if area > bestArea then
			best, bestArea = r, area
		end
	end
	if not best then
		return nil
	end
	local center = (best.lo + best.hi) / 2

	local anchor = Instance.new("Part")
	anchor.Name = "DistrictBanner"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = Vector3.new(center.X, BANNER_HEIGHT, center.Y)
	anchor.Parent = effectsFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(26, 7) -- studban: messziről kisebb, közelről nagyobb
	gui.LightInfluence = 0
	gui.MaxDistance = 450
	gui.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	frame.BackgroundTransparency = 0.3
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = frame

	local function text(y: number, height: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, height)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.4
		l.Parent = frame
		return l
	end
	local name = text(0.06, 0.42)
	name.Text = folder.Name
	local status = text(0.52, 0.4)
	status.ZIndex = 3

	-- A csapatok házai egy sávban (a státusz felirat alatt)
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0.05, 0.52)
	bar.Size = UDim2.fromScale(0.9, 0.4)
	bar.BackgroundColor3 = Config.BUILDINGS.GREY
	bar.ClipsDescendants = true
	bar.Parent = frame
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.3, 0)
	barCorner.Parent = bar
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar
	local segments = {}
	for index, team in Config.TEAMS do
		local seg = Instance.new("Frame")
		seg.LayoutOrder = index
		seg.BorderSizePixel = 0
		seg.BackgroundColor3 = Config.PAINT_COLOR_BY_NAME[team.name]
		seg.Size = UDim2.fromScale(0, 1)
		seg.Parent = bar
		segments[team.name] = seg
	end

	return {
		folder = folder,
		anchor = anchor,
		name = name,
		status = status,
		stroke = stroke,
		segments = segments,
		walls = {},
		locked = false,
	}
end

-- Csillogó fal a kerület határán (a téglalapok élei mentén).
local function buildWalls(view: View, color: Color3)
	for _, r in rectsOf(view.folder) do
		local lo, hi = r.lo, r.hi
		local edges = {
			{ Vector2.new(lo.X, lo.Y), Vector2.new(hi.X, lo.Y) },
			{ Vector2.new(hi.X, lo.Y), Vector2.new(hi.X, hi.Y) },
			{ Vector2.new(hi.X, hi.Y), Vector2.new(lo.X, hi.Y) },
			{ Vector2.new(lo.X, hi.Y), Vector2.new(lo.X, lo.Y) },
		}
		for _, edge in edges do
			local a, b = edge[1], edge[2]
			local length = (b - a).Magnitude
			local mid = (a + b) / 2
			local wall = Instance.new("Part")
			wall.Name = "DistrictWall"
			wall.Anchored = true
			wall.CanCollide = false
			wall.CanQuery = false
			wall.CanTouch = false
			wall.CastShadow = false
			wall.Material = Enum.Material.ForceField
			wall.Color = color
			wall.Transparency = 1
			wall.Size = Vector3.new(length, WALL_HEIGHT, 0.4)
			wall.CFrame = CFrame.lookAt(
				Vector3.new(mid.X, WALL_HEIGHT / 2 - 2, mid.Y),
				Vector3.new(mid.X, WALL_HEIGHT / 2 - 2, mid.Y) + Vector3.new(-(b - a).Y, 0, (b - a).X)
			)
			wall.Parent = effectsFolder
			TweenService:Create(wall, TweenInfo.new(0.6), { Transparency = 0 }):Play()
			table.insert(view.walls, wall)
		end
	end
end

local function removeWalls(view: View)
	for _, wall in view.walls do
		TweenService:Create(wall, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		Debris:AddItem(wall, 0.7)
	end
	view.walls = {}
end

-- Konfetti a kerület minden házának tetejéről.
local function confetti(districtName: string, color: Color3)
	local level = workspace:FindFirstChild("Level")
	local buildings = level and level:FindFirstChild("Buildings")
	if not buildings then
		return
	end
	for _, building in buildings:GetChildren() do
		if not building:IsA("BasePart") or building:GetAttribute("District") ~= districtName then
			continue
		end
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, building.Size.Y / 2 + 1, 0)
		attachment.Parent = building
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.6, color:Lerp(Color3.new(1, 1, 1), 0.5)),
			ColorSequenceKeypoint.new(1, color),
		})
		emitter.Size = NumberSequence.new(0.6)
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.Speed = NumberRange.new(20, 32)
		emitter.SpreadAngle = Vector2.new(30, 30)
		emitter.Acceleration = Vector3.new(0, -35, 0)
		emitter.Drag = 1.5
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-200, 200)
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.LightEmission = 0.3
		emitter.Enabled = false
		emitter.Parent = attachment
		emitter:Emit(25)
		Debris:AddItem(attachment, 2.5)
	end
end

local function update(view: View, announce: boolean)
	local d = view.folder
	local owner = d:GetAttribute("Owner") or ""
	local ownerColor = Config.PAINT_COLOR_BY_NAME[owner]
	local total = d:GetAttribute("Total") or 0
	local lockedFor = math.ceil((d:GetAttribute("LockedUntil") or 0) - workspace:GetServerTimeNow())
	local locked = lockedFor > 0

	view.stroke.Color = ownerColor or Color3.new(1, 1, 1)
	for _, team in Config.TEAMS do
		local count = d:GetAttribute("Count_" .. team.name) or 0
		view.segments[team.name].Size = UDim2.fromScale(if total > 0 then count / total else 0, 1)
	end
	if locked then
		view.status.Text = `LOCKED {lockedFor}s`
	else
		local counts = {}
		for _, team in Config.TEAMS do
			table.insert(counts, tostring(d:GetAttribute("Count_" .. team.name) or 0))
		end
		view.status.Text = `{table.concat(counts, " : ")} / {total}`
	end

	if locked ~= view.locked then
		view.locked = locked
		if locked then
			buildWalls(view, ownerColor or Color3.new(1, 1, 1))
			if announce then
				confetti(d.Name, ownerColor or Color3.new(1, 1, 1))
				Sounds.play("Capture")
			end
		else
			removeWalls(view)
			if announce then
				Sounds.play("Unlock")
			end
		end
	end
end

local function setup(root: Instance)
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, view in views do
		view.anchor:Destroy()
		removeWalls(view)
	end
	views, connections = {}, {}
	for _, folder in root:GetChildren() do
		local view = makeBanner(folder)
		if view then
			table.insert(views, view)
			update(view, false) -- belépéskor ne szóljon a fanfár
			table.insert(
				connections,
				folder.AttributeChanged:Connect(function()
					update(view, true)
				end)
			)
		end
	end
end

function Districts.start()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "DistrictEffects"
	effectsFolder.Parent = workspace

	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "Districts" then
			task.wait(0.5) -- a kerületmappák és attribútumaik megérkezése
			setup(child)
		end
	end)
	local existing = ReplicatedStorage:FindFirstChild("Districts")
	if existing then
		setup(existing)
	end

	-- A lezárás visszaszámlálása a táblán (és a feloldás, ha az attribútum még nem változott)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		for _, view in views do
			if view.locked then
				update(view, true)
			end
		end
	end)
end

return Districts
