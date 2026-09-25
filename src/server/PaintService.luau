-- Festés: a szerver nézi, mihez ér hozzá a játékos, és ő dönt a festékről, az épületek színéről és a pontokról.
--   Festéktartály -> felveszi a színt, teli lesz a tartálya
--   Épület, aminek más a színe -> befesti, egy adag festék elfogy; szürke épületért pont jár

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local PaintedRemote = ReplicatedStorage.Remotes.Painted

local PaintService = {}

local buildingsFolder: Folder
local tanksFolder: Folder
local paintedCount = 0
local onCityComplete: (() -> ())? = nil

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

-- A játékos körüli színes fény mutatja, milyen festék van nála.
local function updateGlow(player: Player)
	local character = player.Character
	local glow = character and character:FindFirstChild("PaintGlow") :: Highlight?
	if not glow then
		return
	end
	local color = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("PaintColor")]
	local paint = player:GetAttribute("Paint") or 0
	glow.Enabled = color ~= nil and paint > 0
	if color then
		glow.FillColor = color
	end
end

local function updateCityStats()
	workspace:SetAttribute("PaintedCount", paintedCount)
	workspace:SetAttribute("BuildingCount", #buildingsFolder:GetChildren())
end

local function refill(player: Player, tank: BasePart)
	local colorName = tank:GetAttribute("ColorName")
	if player:GetAttribute("PaintColor") == colorName and player:GetAttribute("Paint") == Config.PAINT_MAX then
		return
	end
	player:SetAttribute("PaintColor", colorName)
	player:SetAttribute("Paint", Config.PAINT_MAX)
	updateGlow(player)
end

local function tryPaint(player: Player, building: BasePart)
	local colorName = player:GetAttribute("PaintColor")
	local paint = player:GetAttribute("Paint") or 0
	local color = Config.PAINT_COLOR_BY_NAME[colorName]
	if not color or paint <= 0 then
		return
	end
	local previous = building:GetAttribute("ColorName")
	if previous == colorName then
		return
	end

	building.Color = color
	building:SetAttribute("ColorName", colorName)
	player:SetAttribute("Paint", paint - 1)
	updateGlow(player)

	if previous == "" then
		paintedCount += 1
		local score = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Score")
		if score then
			score.Value += Config.POINTS_PAINT
		end
		updateCityStats()
	end
	PaintedRemote:FireAllClients(building, colorName, player)

	if paintedCount >= #buildingsFolder:GetChildren() and onCityComplete then
		onCityComplete()
	end
end

local function checkPlayer(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	for _, part in workspace:GetPartBoundsInRadius(root.Position, Config.PAINT_RADIUS, overlap) do
		if part.Parent == tanksFolder then
			refill(player, part)
		elseif part.Parent == buildingsFolder then
			tryPaint(player, part)
		end
	end
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JUMP_POWER

	local glow = Instance.new("Highlight")
	glow.Name = "PaintGlow"
	glow.FillTransparency = 0.35
	glow.OutlineColor = Color3.new(1, 1, 1)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Enabled = false
	glow.Parent = character
	updateGlow(player)
end

local function setupPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Parent = leaderstats
	leaderstats.Parent = player

	player:SetAttribute("PaintColor", "")
	player:SetAttribute("Paint", 0)

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		setupCharacter(player, player.Character)
	end
end

-- Új város esetén újra meg kell hívni.
function PaintService.setCity(buildings: Folder, tanks: Folder)
	buildingsFolder = buildings
	tanksFolder = tanks
	overlap.FilterDescendantsInstances = { buildings, tanks }
	paintedCount = 0
	updateCityStats()
end

-- Minden épület újra szürke lesz (a pontok megmaradnak).
function PaintService.resetCity()
	for _, building in buildingsFolder:GetChildren() do
		building.Color = building:GetAttribute("BaseColor")
		building:SetAttribute("ColorName", "")
	end
	paintedCount = 0
	updateCityStats()
end

function PaintService.start(cityComplete: () -> ())
	onCityComplete = cityComplete

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.PAINT_CHECK_INTERVAL then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			checkPlayer(player)
		end
	end)
end

return PaintService
