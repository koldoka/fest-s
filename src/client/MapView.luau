-- Térkép: az M gombra (telefonon a "Map" gombra, kontrolleren a Select gombra) felülnézeti térkép nyílik.
-- Látszanak rajta a házak a mostani színükkel (a festetlenek szürkék), az utcák, terek, a folyó, a városfal,
-- a festéktartályok és a játékosok (az avatarjuk arcképével). A játékosok helyzete képkockánként frissül,
-- a házak színe és a tartályok félmásodpercenként.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapView = {}

local WORLD_STYLE: { [string]: Color3 } = {
	Street = Color3.fromRGB(150, 146, 140),
	Lane = Color3.fromRGB(176, 164, 140),
	Alley = Color3.fromRGB(160, 156, 150),
	Promenade = Color3.fromRGB(160, 156, 150),
	Square = Color3.fromRGB(196, 190, 180),
	TerracePlaza = Color3.fromRGB(196, 190, 180),
	Terrace = Color3.fromRGB(150, 140, 126),
	Hill = Color3.fromRGB(110, 132, 100),
	River = Color3.fromRGB(80, 150, 205),
	BridgeDeck = Color3.fromRGB(190, 180, 164),
	TownWall = Color3.fromRGB(120, 110, 96),
}

local gui: ScreenGui
local canvas: Frame
local buildingFrames: { [BasePart]: Frame } = {}
local dynamic: Frame -- tartályok és játékosok (minden frissítéskor újra)
local open = false
local mapMin, mapMax = Vector2.new(-250, -250), Vector2.new(250, 250)

-- Világkoordináta -> a térkép 0..1 skálája
local function toMap(x: number, z: number): UDim2
	local size = mapMax - mapMin
	return UDim2.fromScale((x - mapMin.X) / size.X, (z - mapMin.Y) / size.Y)
end

-- Egy (elforgatott) alkatrész téglalapja a térképen
local function rectFrame(part: BasePart, color: Color3, z: number): Frame
	local size = mapMax - mapMin
	local _, ry = part.CFrame:ToOrientation()
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = toMap(part.Position.X, part.Position.Z)
	frame.Size = UDim2.fromScale(part.Size.X / size.X, part.Size.Z / size.Y)
	-- A helyi X tengely a térképen (x, z) = (cos ry, -sin ry): ez -ry fokos elforgatás (az y lefelé nő)
	frame.Rotation = -math.deg(ry)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = canvas
	return frame
end

local function dot(position: Vector3, color: Color3, pixels: number, z: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = toMap(position.X, position.Z)
	frame.Size = UDim2.fromOffset(pixels, pixels)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	frame.Parent = dynamic
	return frame
end

-- Az állandó rész: talaj, utcák, víz, fal, házak (egyszer, a térkép első megnyitásakor)
local function build(level: Instance)
	local world = level:FindFirstChild("World")
	if world then
		for _, part in world:GetChildren() do
			local color = WORLD_STYLE[part.Name]
			if color and part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
				-- Kerek utcacsatlakozás: kör a térképen
				local size = mapMax - mapMin
				local circle = Instance.new("Frame")
				circle.AnchorPoint = Vector2.new(0.5, 0.5)
				circle.Position = toMap(part.Position.X, part.Position.Z)
				circle.Size = UDim2.fromScale(part.Size.Y / size.X, part.Size.Y / size.Y)
				circle.BackgroundColor3 = color
				circle.BorderSizePixel = 0
				circle.ZIndex = 2
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(1, 0)
				round.Parent = circle
				circle.Parent = canvas
			elseif color and part:IsA("BasePart") then
				rectFrame(part, color, if part.Name == "River" or part.Name == "TownWall" then 3 else 2)
			end
		end
	end
	local buildings = level:FindFirstChild("Buildings")
	if buildings then
		for _, building in buildings:GetChildren() do
			if building:IsA("BasePart") then
				local frame = rectFrame(building, building.Color, 5)
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(40, 40, 48)
				stroke.Thickness = 1
				stroke.Parent = frame
				buildingFrames[building] = frame
			end
		end
	end
end

-- A változó rész: a házak színe és a tartályok (a játékosokat az updatePlayers mozgatja képkockánként)
local function refresh()
	for building, frame in buildingFrames do
		frame.BackgroundColor3 = building.Color
	end
	dynamic:ClearAllChildren()
	local level = workspace:FindFirstChild("Level")
	local tanks = level and level:FindFirstChild("PaintTanks")
	if tanks then
		for _, tank in tanks:GetChildren() do
			if tank:IsA("BasePart") and not tank:GetAttribute("Used") then
				local d = dot(tank.Position, tank.Color, 9, 8)
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.new(1, 1, 1)
				stroke.Thickness = 1.5
				stroke.Parent = d
			end
		end
	end
end

-- Játékosikonok: a Roblox-avatar arcképe kör alakban, a festék színével szegélyezve.
local icons: { [Player]: { frame: Frame, stroke: UIStroke, arrow: Frame? } } = {}
local thumbnails: { [number]: string } = {}

local function thumbnail(player: Player): string
	local cached = thumbnails[player.UserId]
	if cached then
		return cached
	end
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
	end)
	local image = if ok then content else ""
	thumbnails[player.UserId] = image
	return image
end

local function iconFor(player: Player)
	local icon = icons[player]
	if icon then
		return icon
	end
	local isMe = player == Players.LocalPlayer
	local size = if isMe then 34 else 28
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = Color3.fromRGB(230, 230, 236)
	frame.BorderSizePixel = 0
	frame.ZIndex = if isMe then 13 else 12
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if isMe then 4 else 3
	stroke.Parent = frame
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ZIndex = frame.ZIndex
	image.Parent = frame
	local imageCorner = Instance.new("UICorner")
	imageCorner.CornerRadius = UDim.new(1, 0)
	imageCorner.Parent = image
	task.spawn(function()
		image.Image = thumbnail(player)
	end)
	local arrow: Frame? = nil
	if isMe then
		-- Irányjelző: kis pálcika az ikon előtt, a nézési irányba
		local a = Instance.new("Frame")
		a.AnchorPoint = Vector2.new(0.5, 0.5)
		a.Size = UDim2.fromOffset(5, 14)
		a.BackgroundColor3 = Color3.new(1, 1, 1)
		a.BorderSizePixel = 0
		a.ZIndex = 12
		a.Parent = canvas
		arrow = a
	end
	frame.Parent = canvas
	icon = { frame = frame, stroke = stroke, arrow = arrow }
	icons[player] = icon
	return icon
end

-- A játékosok helyzete: minden képkockán, amíg a térkép nyitva van.
local function updatePlayers()
	for player, icon in icons do
		if player.Parent == nil then
			icon.frame:Destroy()
			if icon.arrow then
				icon.arrow:Destroy()
			end
			icons[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local icon = iconFor(player)
		icon.frame.Visible = root ~= nil
		if root then
			local p = root.Position
			icon.frame.Position = toMap(p.X, p.Z)
			icon.stroke.Color = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("PaintColor")] or Color3.new(1, 1, 1)
			if icon.arrow then
				local look = root.CFrame.LookVector
				icon.arrow.Visible = true
				icon.arrow.Position =
					UDim2.new(icon.frame.Position.X.Scale, look.X * 26, icon.frame.Position.Y.Scale, look.Z * 26)
				icon.arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
			end
		elseif icon.arrow then
			icon.arrow.Visible = false
		end
	end
end

local function setOpen(value: boolean)
	open = value
	gui.Enabled = value
	if value then
		local level = workspace:FindFirstChild("Level")
		if level and next(buildingFrames) == nil then
			mapMin = workspace:GetAttribute("MapMin") or mapMin
			mapMax = workspace:GetAttribute("MapMax") or mapMax
			build(level)
		end
		refresh()
		updatePlayers()
		task.spawn(function()
			while open do
				task.wait(0.5)
				if open then
					refresh()
				end
			end
		end)
	end
end

function MapView.start()
	game:GetService("RunService").RenderStepped:Connect(function()
		if open then
			updatePlayers()
		end
	end)
	gui = Instance.new("ScreenGui")
	gui.Name = "Map"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.8, 0.8)
	panel.BackgroundColor3 = Color3.fromRGB(122, 138, 112)
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = panel

	canvas = Instance.new("Frame")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.Parent = panel
	dynamic = Instance.new("Frame")
	dynamic.Name = "Dynamic"
	dynamic.Size = UDim2.fromScale(1, 1)
	dynamic.BackgroundTransparency = 1
	dynamic.ZIndex = 7
	dynamic.Parent = canvas

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 8)
	title.Size = UDim2.new(0.9, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = "Map  -  grey houses are still unpainted  -  press M to close"
	title.ZIndex = 20
	title.Parent = panel

	ContextActionService:BindAction("ToggleMap", function(_, state)
		if state == Enum.UserInputState.Begin then
			setOpen(not open)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
	ContextActionService:SetTitle("ToggleMap", "Map")
	ContextActionService:SetPosition("ToggleMap", UDim2.new(1, -170, 1, -150))
end

return MapView
