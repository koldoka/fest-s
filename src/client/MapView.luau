-- Térkép: az M gombra (telefonon a "Map" gombra, kontrolleren a Select gombra) felülnézeti térkép nyílik.
-- Látszanak rajta a házak a mostani színükkel (a festetlenek szürkék), az utcák, terek, a folyó, a városfal,
-- a festékesvödrök (kis vödör-ikonnal), a kerületek (a gazda csapat színével, a lezártak jelölve) és a játékosok (az avatarjuk
-- arcképével, a csapatuk színével szegélyezve). A játékosok helyzete képkockánként frissül, a többi félmásodpercenként.

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
type DistrictView = { folder: Instance, rects: { Frame }, label: TextLabel }
local districtViews: { DistrictView } = {}
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

-- Festékesvödör-ikon a térképre (Frame-ekből, nem kell hozzá feltöltött kép): fémvödör sárga címkével,
-- fölötte fül, fehér körvonallal, hogy a házak és az utak fölött is látsszon.
local function bucketIcon(): Frame
	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(18, 20)
	root.BackgroundTransparency = 1
	root.ZIndex = 8
	local function piece(props: { [string]: any }, radius: number?): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.ZIndex = 8
		for key, value in props do
			(f :: any)[key] = value
		end
		if radius then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, radius)
			c.Parent = f
		end
		f.Parent = root
		return f
	end
	-- Fül: egy kör felső fele (a kerete látszik, az alja a vödör mögé kerül)
	local handle = piece({
		Position = UDim2.fromOffset(3, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
	}, 6)
	local handleStroke = Instance.new("UIStroke")
	handleStroke.Color = Color3.fromRGB(60, 64, 72)
	handleStroke.Thickness = 2
	handleStroke.Parent = handle
	-- Test, perem, címke
	local body = piece({
		Position = UDim2.fromOffset(2, 6),
		Size = UDim2.fromOffset(14, 13),
		BackgroundColor3 = Color3.fromRGB(196, 202, 210),
		ZIndex = 9,
	}, 3)
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(1, 1, 1)
	outline.Thickness = 1.5
	outline.Parent = body
	piece({
		Position = UDim2.fromOffset(2, 10),
		Size = UDim2.fromOffset(14, 5),
		BackgroundColor3 = Color3.fromRGB(255, 212, 60),
		ZIndex = 10,
	})
	piece({
		Position = UDim2.fromOffset(2, 10),
		Size = UDim2.fromOffset(14, 1),
		BackgroundColor3 = Color3.fromRGB(226, 60, 60),
		ZIndex = 11,
	})
	piece({
		Position = UDim2.fromOffset(1, 5),
		Size = UDim2.fromOffset(16, 3),
		BackgroundColor3 = Color3.fromRGB(150, 156, 166),
		ZIndex = 11,
	}, 1)
	return root
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
	-- Kerületek: halvány téglalapok a gazda csapat színével, a nevük a legnagyobb téglalap közepén
	local districts = ReplicatedStorage:FindFirstChild("Districts")
	if districts then
		local size = mapMax - mapMin
		for _, folder in districts:GetChildren() do
			local view: DistrictView = { folder = folder, rects = {}, label = nil :: any }
			local biggest, biggestArea = nil, -1
			for _, rect in folder:GetChildren() do
				local lo: Vector2 = rect:GetAttribute("Min")
				local hi: Vector2 = rect:GetAttribute("Max")
				if not lo or not hi then
					continue
				end
				local frame = Instance.new("Frame")
				frame.Position = toMap(lo.X, lo.Y)
				frame.Size = UDim2.fromScale((hi.X - lo.X) / size.X, (hi.Y - lo.Y) / size.Y)
				frame.BackgroundTransparency = 1
				frame.BorderSizePixel = 0
				frame.ZIndex = 4
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.new(1, 1, 1)
				stroke.Transparency = 0.5
				stroke.Thickness = 1.5
				stroke.Parent = frame
				frame.Parent = canvas
				table.insert(view.rects, frame)
				local area = (hi.X - lo.X) * (hi.Y - lo.Y)
				if area > biggestArea then
					biggest, biggestArea = frame, area
				end
			end
			if biggest then
				local text = Instance.new("TextLabel")
				text.AnchorPoint = Vector2.new(0.5, 0.5)
				-- A vásznon, nem a téglalapban: így a házak fölött látszik
				text.Position = UDim2.fromScale(
					biggest.Position.X.Scale + biggest.Size.X.Scale / 2,
					biggest.Position.Y.Scale + biggest.Size.Y.Scale / 2
				)
				text.Size = UDim2.new(biggest.Size.X.Scale, -8, 0, 34)
				text.BackgroundTransparency = 1
				text.Font = Enum.Font.FredokaOne
				text.TextScaled = true
				text.TextColor3 = Color3.new(1, 1, 1)
				text.TextStrokeTransparency = 0.2
				text.ZIndex = 9
				text.Parent = canvas
				local limit = Instance.new("UITextSizeConstraint")
				limit.MaxTextSize = 16
				limit.Parent = text
				view.label = text
				table.insert(districtViews, view)
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
	local now = workspace:GetServerTimeNow()
	for _, view in districtViews do
		local d = view.folder
		local owner = d:GetAttribute("Owner") or ""
		local color = Config.PAINT_COLOR_BY_NAME[owner]
		local lockedFor = math.ceil((d:GetAttribute("LockedUntil") or 0) - now)
		for _, frame in view.rects do
			frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
			frame.BackgroundTransparency = if not color then 1 elseif lockedFor > 0 then 0.45 else 0.7
		end
		local counts = {}
		for _, team in Config.TEAMS do
			table.insert(counts, tostring(d:GetAttribute("Count_" .. team.name) or 0))
		end
		local line = `{table.concat(counts, " : ")} / {d:GetAttribute("Total") or 0}`
		view.label.Text = if lockedFor > 0 then `{d.Name}\nLOCKED {lockedFor}s` else `{d.Name}\n{line}`
	end
	dynamic:ClearAllChildren()
	local level = workspace:FindFirstChild("Level")
	local tanks = level and level:FindFirstChild("PaintTanks")
	if tanks then
		for _, tank in tanks:GetChildren() do
			if tank:IsA("BasePart") and not tank:GetAttribute("Used") then
				local icon = bucketIcon()
				icon.Position = toMap(tank.Position.X, tank.Position.Z)
				icon.Parent = dynamic
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
			icon.stroke.Color = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("Team") or ""] or Color3.new(1, 1, 1)
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
	title.Text = "Map  -  districts show houses per team  -  press M to close"
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
