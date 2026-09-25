-- Festés: a szerver nézi, mihez ér hozzá a játékos, és ő dönt a festékről, az épületek színéről és a pontokról.
--   Festéktartály -> felveszi a színt, teli lesz a tartálya
--   Épület, aminek más a színe -> befesti, egy adag festék elfogy; szürke épületért pont jár

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BlobCharacter = require(script.Parent.BlobCharacter)

local PaintedRemote = ReplicatedStorage.Remotes.Painted

local PaintService = {}

local buildingsFolder: Folder
local tanksFolder: Folder
local paintedCount = 0
local onCityComplete: (() -> ())? = nil

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function updateCityStats()
	workspace:SetAttribute("PaintedCount", paintedCount)
	workspace:SetAttribute("BuildingCount", #buildingsFolder:GetChildren())
end

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Befestéskor a részletek színe a festék színéből (ha a részletnek nincs fix PaintedColor-ja).
local ROLE_COLORS: { [string]: (Color3) -> Color3 } = {
	Tier = function(c)
		return c
	end,
	Plinth = function(c)
		return c:Lerp(BLACK, 0.35)
	end,
	Trim = function(c)
		return c:Lerp(WHITE, 0.6)
	end,
	Balcony = function(c)
		return c:Lerp(WHITE, 0.6)
	end,
	AwningA = function(c)
		return c:Lerp(BLACK, 0.1)
	end,
	AwningB = function()
		return Color3.fromRGB(250, 247, 238)
	end,
	Window = function()
		return Config.CITY.WINDOW_LIT_COLOR
	end,
	ShopWindow = function()
		return Config.CITY.WINDOW_LIT_COLOR
	end,
}

-- Az épület és a részletei színe. color = nil: vissza a festetlen szürkére.
local function colorBuilding(building: BasePart, color: Color3?)
	building.Color = color or building:GetAttribute("BaseColor")
	for _, detail in building:GetDescendants() do
		local role = detail:GetAttribute("Role")
		if detail:IsA("Texture") and role == "Facade" then
			detail.Texture = if color then Config.CITY.FACADE.LIT else Config.CITY.FACADE.GREY
		elseif detail:IsA("BasePart") and role then
			if not color then
				detail.Color = detail:GetAttribute("BaseColor")
			else
				local fixed = detail:GetAttribute("PaintedColor")
				local rule = ROLE_COLORS[role]
				detail.Color = fixed or (rule and rule(color)) or detail.Color
			end
		end
	end
end

-- A találat melyik épülethez tartozik (a részletek az épület testének gyerekei).
local function owningBuilding(part: Instance): BasePart?
	local current: Instance? = part
	while current and current.Parent ~= buildingsFolder do
		current = current.Parent
	end
	return current :: BasePart?
end

local function refill(player: Player, tank: BasePart)
	local colorName = tank:GetAttribute("ColorName")
	if player:GetAttribute("PaintColor") == colorName and player:GetAttribute("Paint") == Config.PAINT_MAX then
		return
	end
	player:SetAttribute("PaintColor", colorName)
	player:SetAttribute("Paint", Config.PAINT_MAX)
	BlobCharacter.update(player)
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

	colorBuilding(building, color)
	building:SetAttribute("ColorName", colorName)
	player:SetAttribute("Paint", paint - 1)
	BlobCharacter.update(player)

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
	-- A paca körül nézzük (ha még nincs paca, a karakter közepe körül).
	local blob = character:FindFirstChild("Blob") :: BasePart?
	local center = if blob then blob.Position else root.Position
	local diameter = if blob then blob:GetAttribute("Diameter") or Config.BLOB.MIN_SIZE else Config.BLOB.MIN_SIZE
	local radius = diameter / 2 + Config.PAINT_REACH
	for _, part in workspace:GetPartBoundsInRadius(center, radius, overlap) do
		if part.Parent == tanksFolder then
			refill(player, part)
		else
			local building = owningBuilding(part)
			if building then
				tryPaint(player, building)
			end
		end
	end
end

local function setupCharacter(player: Player, character: Model)
	-- Időkorláttal: ha a karaktert közben lecserélték, ne akadjon el itt örökre.
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or character.Parent == nil then
		return
	end
	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JUMP_POWER

	BlobCharacter.setup(character, humanoid)
	BlobCharacter.update(player)
end

local function setupPlayer(player: Player)
	if player:FindFirstChild("leaderstats") then
		return -- már be van állítva
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Parent = leaderstats
	leaderstats.Parent = player

	player:SetAttribute("PaintColor", "")
	player:SetAttribute("Paint", 0)

	-- Külön szálon, hogy a karakterre várás ne tartsa fel a többit.
	player.CharacterAdded:Connect(function(character)
		task.spawn(setupCharacter, player, character)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end

-- Új város esetén újra meg kell hívni.
function PaintService.setCity(buildings: Folder, tanks: Folder)
	buildingsFolder = buildings
	tanksFolder = tanks
	overlap.FilterDescendantsInstances = { buildings, tanks }
	-- Tartalék a körzetfigyelés mellé: a tartály érintése is feltölt.
	for _, tank in tanks:GetChildren() do
		(tank :: BasePart).Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				refill(player, tank :: BasePart)
			end
		end)
	end
	paintedCount = 0
	updateCityStats()
end

-- Minden épület újra szürke lesz (a pontok megmaradnak).
function PaintService.resetCity()
	for _, building in buildingsFolder:GetChildren() do
		colorBuilding(building, nil)
		building:SetAttribute("ColorName", "")
	end
	paintedCount = 0
	updateCityStats()
end

function PaintService.start(cityComplete: () -> ())
	onCityComplete = cityComplete

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

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return PaintService
