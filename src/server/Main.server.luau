-- A szerver belépési pontja: betölti a pályát, elindítja a festést, és újrakezdi, ha minden ház színes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LevelLoader = require(script.Parent.LevelLoader)
local PaintService = require(script.Parent.PaintService)
local TankService = require(script.Parent.TankService)

-- Ha a Rojo valamiért nem hozta volna létre a hálózati csatornákat, itt pótoljuk.
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end
for _, name in { "Painted" } do
	if not Remotes:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
end

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

local level = LevelLoader.load(Config.LEVEL)
PaintService.setLevel(level.buildings, level.props, level.tanks)
TankService.start(level.tanks, level.tankSpots, PaintService.refill)

local resetting = false
PaintService.start(function()
	if resetting then
		return
	end
	resetting = true
	task.spawn(function()
		for remaining = Config.RESET_DELAY, 1, -1 do
			workspace:SetAttribute("Message", `Town painted! It turns grey again in {remaining}...`)
			task.wait(1)
		end
		workspace:SetAttribute("Message", "")
		PaintService.resetLevel()
		resetting = false
	end)
end)

-- Aki a pálya felépülése előtt belépett és karakter nélkül maradt, kap egyet.
-- Kis várakozás után nézzük, hogy ne akadjunk össze a Roblox saját karakterbetöltésével.
task.delay(1, function()
	for _, player in Players:GetPlayers() do
		if not player.Character then
			player:LoadCharacter()
		end
	end
end)
