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

-- Festékesvödör fedő nélkül: színes címke "PAINT" felirattal, színes csorgások, tetején keresztbe fektetett ecset.
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
	-- Színes címke körben (sárga, fölötte piros, alatta kék csík), elöl és hátul "PAINT" felirattal
	local label = Color3.fromRGB(255, 212, 60)
	for _, band in
		{
			{ y = 1.65, height = 1.1, color = label },
			{ y = 2.28, height = 0.16, color = Color3.fromRGB(226, 60, 60) },
			{ y = 1.02, height = 0.16, color = Color3.fromRGB(60, 120, 230) },
		}
	do
		visual(hitbox, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(band.height, d + 0.06, d + 0.06),
			CFrame = upright((base * CFrame.new(0, band.y, 0)).Position),
			Color = band.color,
		})
	end
	for _, side in { -1, 1 } do
		local plate = visual(hitbox, {
			Size = Vector3.new(1.6, 0.9, 0.05),
			CFrame = base * CFrame.Angles(0, if side > 0 then math.pi else 0, 0) * CFrame.new(0, 1.65, -(d / 2 + 0.06)),
			Transparency = 1,
			CastShadow = false,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 1
		gui.Enabled = false -- a felbukkanáskor kapcsol be
		gui.Parent = plate
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = "PAINT"
		text.TextColor3 = Color3.fromRGB(214, 48, 48)
		text.TextStrokeColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.2
		text.Parent = gui
	end

	-- Festék a vödörben (fehér: mindenki a csapata színét kapja belőle), a peremről színes csorgások
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, d - 0.3, d - 0.3),
		CFrame = upright((base * CFrame.new(0, h - 0.2, 0)).Position),
		Color = PAINT_WHITE,
	})
	for _, drip in
		{
			{ angle = 20, length = 1.2, color = Color3.fromRGB(235, 64, 64) },
			{ angle = 130, length = 0.8, color = Color3.fromRGB(56, 128, 240) },
			{ angle = 235, length = 1.5, color = Color3.fromRGB(70, 200, 96) },
			{ angle = 300, length = 0.7, color = PAINT_WHITE },
		}
	do
		local around = base * CFrame.Angles(0, math.rad(drip.angle), 0)
		visual(hitbox, {
			Size = Vector3.new(0.45, drip.length, 0.12),
			CFrame = around * CFrame.new(0, h + 0.1 - drip.length / 2, -(d / 2 + 0.1)),
			Color = drip.color,
		})
		visual(hitbox, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.5,
			CFrame = around * CFrame.new(0, h + 0.1 - drip.length, -(d / 2 + 0.1)),
			Color = drip.color,
		})
	end
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

	-- Lapos ecset a vödör tetején: lakkozott fanyél, bádog foglalat, sörte, festékbe mártott, rojtos vége.
	-- Az ecset hossza a helyi X, a szélessége a helyi Z.
	local brush = base * CFrame.new(-0.2, h + 0.3, 0.35) * CFrame.Angles(0, math.rad(25), math.rad(5))
	local wood = Color3.fromRGB(196, 72, 52)
	visual(hitbox, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 0.34, 0.34),
		CFrame = brush * CFrame.new(-1.2, 0, 0),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	visual(hitbox, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.46,
		CFrame = brush * CFrame.new(-2.3, 0, 0),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	visual(hitbox, {
		Size = Vector3.new(0.3, 0.3, 0.6),
		CFrame = brush * CFrame.new(-0.05, 0, 0),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	visual(hitbox, {
		Size = Vector3.new(0.6, 0.36, 1.1),
		CFrame = brush * CFrame.new(0.4, 0, 0),
		Color = METAL,
		Material = Enum.Material.Metal,
	})
	visual(hitbox, {
		Size = Vector3.new(0.06, 0.4, 1.14),
		CFrame = brush * CFrame.new(0.25, 0, 0),
		Color = METAL:Lerp(Color3.new(0, 0, 0), 0.25),
		Material = Enum.Material.Metal,
	})
	visual(hitbox, {
		Size = Vector3.new(0.7, 0.3, 1.04),
		CFrame = brush * CFrame.new(1.05, 0, 0),
		Color = Color3.fromRGB(222, 192, 140),
	})
	visual(hitbox, {
		Size = Vector3.new(0.35, 0.26, 1.0),
		CFrame = brush * CFrame.new(1.55, 0, 0),
		Color = PAINT_WHITE,
	})
	for i, tuft in { { -0.4, 0.3 }, { -0.14, 0.45 }, { 0.12, 0.25 }, { 0.38, 0.4 } } do
		visual(hitbox, {
			Size = Vector3.new(tuft[2], 0.14 + (i % 2) * 0.04, 0.2),
			CFrame = brush * CFrame.new(1.72 + tuft[2] / 2, (i % 2 - 0.5) * 0.06, tuft[1]),
			Color = PAINT_WHITE,
		})
	end

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
		local label = part:FindFirstChildOfClass("SurfaceGui")
		if label then
			label.Enabled = visible
		end
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
