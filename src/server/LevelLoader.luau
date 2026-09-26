-- Pálya betöltése: létrehozza a mappákat, és lefuttatja a pályaleírást (src/server/Levels/<név>.luau).
-- Egy pályaleírás egy táblát ad vissza:
--   { seed = szám, lighting = { ClockTime = 15, ... }, build = function(Kit) ... end }

local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Kit)

local LevelLoader = {}

export type LevelFolders = { world: Folder, buildings: Folder, props: Folder, tanks: Folder, tankSpots: { Vector3 } }

function LevelLoader.load(name: string): LevelFolders
	local old = workspace:FindFirstChild("Level")
	if old then
		old:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "Level"
	local folders = {}
	for key, folderName in { world = "World", buildings = "Buildings", props = "Props", tanks = "PaintTanks" } do
		local folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = root
		folders[key] = folder
	end

	local module = script.Parent.Levels:FindFirstChild(name)
	assert(module, `Level not found: {name}`)
	local level = require(module) :: any
	Kit.begin(folders :: any, level.seed or 1)
	level.build(Kit)
	Kit.finish()

	for property, value in level.lighting or {} do
		(Lighting :: any)[property] = value
	end
	-- A térképnek (kliens): melyik területet mutassa
	local b = level.bounds or { -250, -250, 250, 250 }
	workspace:SetAttribute("MapMin", Vector2.new(b[1], b[2]))
	workspace:SetAttribute("MapMax", Vector2.new(b[3], b[4]))

	root.Parent = workspace
	folders.tankSpots = Kit.tankSpots
	return folders :: any
end

return LevelLoader
