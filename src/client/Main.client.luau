-- A kliens belépési pontja.

-- Időmérés (a betöltési idő vizsgálatához; az Output ablakban látszik): mikor indult a kliens, mikor ért ide
-- a pálya, és mikor lett karakter. A time() a kliens indulása óta eltelt másodperc.
local Players = game:GetService("Players")
print(string.format("[Paint Pop] Client scripts started at %.2f s", time()))
task.spawn(function()
	local level = workspace:WaitForChild("Level", 120)
	if not level then
		return
	end
	print(string.format("[Paint Pop] Level folder arrived at %.2f s", time()))
	local expected = workspace:GetAttribute("LevelInstances") or 0
	while #level:GetDescendants() < expected * 0.99 do
		task.wait(0.25)
	end
	print(string.format("[Paint Pop] Level fully received at %.2f s (%d instances)", time(), expected))
end)
task.spawn(function()
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 60)
	print(string.format("[Paint Pop] Character ready at %.2f s", time()))
end)

local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local BlobAnimator = require(script.Parent.BlobAnimator)
local Sounds = require(script.Parent.Sounds)
local Trails = require(script.Parent.Trails)
local MapView = require(script.Parent.MapView)
local Pvp = require(script.Parent.Pvp)
local Districts = require(script.Parent.Districts)
local Results = require(script.Parent.Results)

Hud.start()
Effects.start()
BlobAnimator.start()
Sounds.start()
Trails.start()
MapView.start()
Pvp.start()
Districts.start()
Results.start()
