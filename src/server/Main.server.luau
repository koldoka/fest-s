-- A szerver belépési pontja: felépíti a várost, elindítja a festést, és újrakezdi, ha minden színes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CityBuilder = require(script.Parent.CityBuilder)
local PaintService = require(script.Parent.PaintService)

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

-- Napos délután, hogy a színek jól látsszanak.
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)

local buildings, tanks = CityBuilder.build()
PaintService.setCity(buildings, tanks)

local resetting = false
PaintService.start(function()
	if resetting then
		return
	end
	resetting = true
	task.spawn(function()
		for remaining = Config.RESET_DELAY, 1, -1 do
			workspace:SetAttribute("Message", `City painted! It turns grey again in {remaining}...`)
			task.wait(1)
		end
		workspace:SetAttribute("Message", "")
		PaintService.resetCity()
		resetting = false
	end)
end)
