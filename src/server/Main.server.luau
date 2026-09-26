-- A szerver belépési pontja: betölti a pályát, felállítja a csapatokat és a kerületeket, elindítja a festést,
-- a festéklopást és a meccsek körforgását.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ha a Rojo valamiért nem hozta volna létre a hálózati csatornákat, itt pótoljuk
-- (még a szolgáltatások betöltése előtt, mert azok már az elején hivatkoznak rájuk).
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end
for _, name in { "Painted", "NeedPaint", "Announce", "Stolen", "Knockback" } do
	if not Remotes:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
end

local Config = require(ReplicatedStorage.Shared.Config)
local LevelLoader = require(script.Parent.LevelLoader)
local PaintService = require(script.Parent.PaintService)
local TankService = require(script.Parent.TankService)
local TeamService = require(script.Parent.TeamService)
local DistrictService = require(script.Parent.DistrictService)
local StealService = require(script.Parent.StealService)
local MatchService = require(script.Parent.MatchService)
local StatueService = require(script.Parent.StatueService)

-- A "Baseplate" sablon alap elemei útban lennének.
for _, name in { "Baseplate", "SpawnLocation" } do
	local existing = workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

-- Ha a hely korábban más projekthez (pl. Toybox Tanks) volt csatlakoztatva, ott ez ki lehetett kapcsolva,
-- és akkor a játékosnak nem lenne karaktere.
Players.CharacterAutoLoads = true

TeamService.start()
-- Időmérés (a betöltési idő vizsgálatához; az Output ablakban látszik)
local buildStarted = os.clock()
local level = LevelLoader.load(Config.LEVEL)
local buildTime = os.clock() - buildStarted
local instanceCount = #workspace.Level:GetDescendants()
workspace:SetAttribute("LevelInstances", instanceCount)
print(string.format("[Paint Pop] Level built in %.2f s (%d instances)", buildTime, instanceCount))
PaintService.setLevel(level.buildings, level.props, level.tanks)
DistrictService.setup(level.buildings, level.districts)
StatueService.setup(level.props)
TankService.start(level.tanks, level.tankSpots, PaintService.refill)
PaintService.start(MatchService.isPlaying, MatchService.publishScores)
StealService.start(MatchService.isPlaying)
MatchService.start(PaintService.resetLevel)

-- Aki a pálya felépülése előtt belépett és karakter nélkül maradt, kap egyet.
-- Kis várakozás után nézzük, hogy ne akadjunk össze a Roblox saját karakterbetöltésével.
task.delay(1, function()
	for _, player in Players:GetPlayers() do
		if not player.Character then
			player:LoadCharacter()
		end
	end
end)
