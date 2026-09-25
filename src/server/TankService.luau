-- Festéktartályok: a pálya lehetséges tartályhelyei (Kit.tankSpot) közül egyszerre néhányon van tartály,
-- véletlen színnel (hány: a játékosok számától függ, lásd Config.TANKS). Ha valaki festéket vesz belőle, a tartály eltűnik, és kis idő múlva egy másik
-- szabad helyen, más színnel jelenik meg.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local TankService = {}

local folder: Folder
local spots: { Vector3 } = {}
local used: { [number]: boolean } = {} -- melyik helyen áll most tartály
local rng = Random.new()
local onRefill: ((Player, BasePart) -> ())? = nil
local planned = 0 -- a pályán lévő tartályok + a már ütemezett újak

-- Hány tartály legyen egyszerre a pályán.
local function target(): number
	local t = Config.TANKS
	return math.clamp(t.MIN + t.PER_PLAYER * (#Players:GetPlayers() - 1), t.MIN, t.MAX)
end

local SIZE = Vector3.new(3, 6, 6) -- álló henger: a tengely (X) függőleges

local function spawnTank()
	-- Szabad hely keresése (ahol most nincs tartály)
	local free = {}
	for i in spots do
		if not used[i] then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		planned -= 1
		return
	end
	local index = free[rng:NextInteger(1, #free)]
	local paint = Config.PAINT_COLORS[rng:NextInteger(1, #Config.PAINT_COLORS)]
	used[index] = true

	local at = spots[index]
	local tank = Instance.new("Part")
	tank.Name = paint.name .. "Tank"
	tank.Shape = Enum.PartType.Cylinder
	tank.Anchored = true
	tank.CanCollide = false -- bele lehet ugrani
	tank.Material = Enum.Material.SmoothPlastic
	tank.Color = paint.color
	tank.Size = SIZE * 0.2
	tank.CFrame = CFrame.new(at + Vector3.new(0, SIZE.X / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tank:SetAttribute("ColorName", paint.name)
	tank:SetAttribute("Spot", index)
	local light = Instance.new("PointLight")
	light.Color = paint.color
	light.Range = 14
	light.Brightness = 2
	light.Parent = tank
	tank.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and onRefill then
			onRefill(player, tank)
		end
	end)
	tank.Parent = folder
	-- Felbukkanás: kicsiből nő meg
	TweenService:Create(tank, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = SIZE })
		:Play()
end

-- A tartályból festéket vettek: eltűnik, és egy idő múlva máshol jelenik meg egy új.
function TankService.consume(tank: BasePart)
	if tank.Parent ~= folder or tank:GetAttribute("Used") then
		return
	end
	tank:SetAttribute("Used", true)
	local index = tank:GetAttribute("Spot")
	TweenService:Create(tank, TweenInfo.new(0.25), { Size = SIZE * 0.1, Transparency = 1 }):Play()
	task.delay(0.3, function()
		tank:Destroy()
		used[index] = nil
	end)
	-- Csak akkor jön helyette új, ha nincs több a kelleténél (pl. kilépett egy játékos)
	if planned > target() then
		planned -= 1
	else
		task.delay(Config.TANKS.RESPAWN, spawnTank)
	end
end

-- Feltöltés a kívánt darabszámig (induláskor és új játékosnál).
local function topUp()
	while planned < math.min(target(), #spots) do
		planned += 1
		spawnTank()
	end
end

-- refill(player, tank): a PaintService adja; akkor hívódik, ha egy játékos hozzáér egy tartályhoz.
function TankService.start(tankFolder: Folder, tankSpots: { Vector3 }, refill: (Player, BasePart) -> ())
	folder = tankFolder
	spots = tankSpots
	used = {}
	onRefill = refill
	planned = 0
	folder:ClearAllChildren()
	topUp()
	Players.PlayerAdded:Connect(topUp)
end

return TankService
