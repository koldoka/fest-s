-- Festékesvödrök: a pálya lehetséges helyei (Kit.tankSpot) közül egyszerre néhányon van egy vödör (hány: a
-- játékosok számától függ, lásd Config.TANKS). A vödörben semleges, fehér festék van, mindenki a saját csapata
-- színét veszi fel belőle. Használat után eltűnik, és kis idő múlva egy másik szabad helyen jelenik meg.
-- Egy vödör: egy láthatatlan érintőlap (ezt figyeli a PaintService), benne a látható részek.

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

local HITBOX = Vector3.new(4.5, 5, 4.5)
local METAL = Color3.fromRGB(186, 192, 200)
local PAINT_WHITE = Color3.fromRGB(246, 246, 242)

local function visual(parent: BasePart, props: { [string]: any })
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part:SetAttribute("Transparency0", part.Transparency)
	part.Transparency = 1 -- a felbukkanáskor válik láthatóvá
	part.Parent = parent
	return part
end

-- Álló henger CFrame-je (a Roblox hengerének tengelye az X)
local function upright(p: Vector3): CFrame
	return CFrame.new(p) * CFrame.Angles(0, 0, math.rad(90))
end

-- Festékesvödör fedő nélkül, tetején keresztbe fektetett ecsettel.
local function buildBucket(at: Vector3, rot: number): BasePart
	local hitbox = Instance.new("Part")
	hitbox.Name = "Bucket"
	hitbox.Anchored = true
	hitbox.CanCollide = false -- bele lehet ugrani
	hitbox.Transparency = 1
	hitbox.Color = PAINT_WHITE -- a térkép ezzel a színnel jelöli
	hitbox.Size = HITBOX
	hitbox.CFrame = CFrame.new(at + Vector3.new(0, HITBOX.Y / 2, 0))

	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rot), 0)
	local h, d = 3, 3.4
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, d, d),
		CFrame = upright((base * CFrame.new(0, h / 2, 0)).Position),
		Color = METAL,
		Material = Enum.Material.Metal,
	})
	-- Perem és alsó abroncs
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, d + 0.3, d + 0.3),
		CFrame = upright((base * CFrame.new(0, h, 0)).Position),
		Color = METAL:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = Enum.Material.Metal,
	})
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, d + 0.15, d + 0.15),
		CFrame = upright((base * CFrame.new(0, 0.6, 0)).Position),
		Color = METAL:Lerp(Color3.new(0, 0, 0), 0.15),
		Material = Enum.Material.Metal,
	})
	-- Festék a vödörben és egy lecsorgó csík az oldalán
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, d - 0.3, d - 0.3),
		CFrame = upright((base * CFrame.new(0, h - 0.2, 0)).Position),
		Color = PAINT_WHITE,
	})
	visual(hitbox, {
		Size = Vector3.new(0.5, 1.4, 0.2),
		CFrame = base * CFrame.new(0.6, h - 0.6, -d / 2 - 0.02),
		Color = PAINT_WHITE,
	})
	visual(hitbox, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.55,
		CFrame = base * CFrame.new(0.6, h - 1.35, -d / 2 - 0.02),
		Color = PAINT_WHITE,
	})
	-- Fül: két kis tartó és a felhajtott fogantyú
	for _, x in { -1, 1 } do
		visual(hitbox, {
			Size = Vector3.new(0.15, 1.3, 0.15),
			CFrame = base * CFrame.new(x * (d / 2 + 0.05), h + 0.5, 0),
			Color = METAL,
		})
	end
	visual(
		hitbox,
		{ Size = Vector3.new(d + 0.3, 0.15, 0.15), CFrame = base * CFrame.new(0, h + 1.15, 0), Color = METAL }
	)
	-- Ecset keresztben a vödör tetején: nyél, fémfoglalat, festékes sörte
	local brush = base * CFrame.new(0, h + 0.35, 0.3) * CFrame.Angles(0, math.rad(25), math.rad(4))
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 0.35, 0.35),
		CFrame = brush * CFrame.new(-0.9, 0, 0),
		Color = Color3.fromRGB(176, 118, 70),
		Material = Enum.Material.Wood,
	})
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 0.55, 0.55),
		CFrame = brush * CFrame.new(0.65, 0, 0),
		Color = METAL,
		Material = Enum.Material.Metal,
	})
	visual(hitbox, { Size = Vector3.new(0.9, 0.35, 1.0), CFrame = brush * CFrame.new(1.35, 0, 0), Color = PAINT_WHITE })

	-- Fény és csillogás, hogy messziről is látszódjon
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 246, 220)
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = hitbox
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.new(1, 1, 1))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Rate = 4
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(30, 30)
	sparkle.Parent = hitbox
	return hitbox
end

-- A látható részek megjelenítése vagy elrejtése (felbukkanás, eltűnés).
local function fade(hitbox: BasePart, visible: boolean, time: number)
	for _, part in hitbox:GetChildren() do
		if part:IsA("BasePart") then
			local target = if visible then part:GetAttribute("Transparency0") or 0 else 1
			TweenService:Create(part, TweenInfo.new(time), { Transparency = target }):Play()
		end
	end
end

local function spawnTank()
	-- Szabad hely keresése (ahol most nincs vödör)
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
	used[index] = true

	local bucket = buildBucket(spots[index], rng:NextNumber(0, 360))
	bucket:SetAttribute("Spot", index)
	bucket.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and onRefill then
			onRefill(player, bucket)
		end
	end)
	bucket.Parent = folder
	fade(bucket, true, 0.4)
end

-- A vödörből festéket vettek: eltűnik, és egy idő múlva máshol jelenik meg egy új.
function TankService.consume(tank: BasePart)
	if tank.Parent ~= folder or tank:GetAttribute("Used") then
		return
	end
	tank:SetAttribute("Used", true)
	local index = tank:GetAttribute("Spot")
	fade(tank, false, 0.3)
	local sparkle = tank:FindFirstChildOfClass("ParticleEmitter")
	if sparkle then
		sparkle.Enabled = false
	end
	task.delay(0.35, function()
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
