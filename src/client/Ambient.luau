-- Élő környezet (csak látvány, a kliensen):
--   Fák és bokrok: finoman ringanak a szélben (a tövük körül, fánként más ütemben, időnként egy-egy
--   erősebb széllökéssel). Csak a kamera közelében lévők mozognak, hogy ne terhelje a gépet.
--   Víz: a folyó színe lassan hullámzik, a vízfelszínen csillogás, és apró fodrok gyűrűznek szét;
--   a szökőkút tetejéből víz spriccel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Ambient = {}

local SWAY_NAMES = { Tree = 3, FruitTree = 2.5, Bush = 3 } -- tárgynév -> kilengés (fok)
local SWAY_DISTANCE = 140 -- ennél közelebb lévő fák mozognak
local RIPPLE_DISTANCE = 160
local WIND = Vector3.new(1, 0, 0.35).Unit -- a szél iránya

local folder: Folder

---------------------------------------------------------------------------------------------------
-- Fák

type Swayer = {
	base: CFrame, -- a tő (a forgáspont)
	parts: { { part: BasePart, offset: CFrame } },
	amplitude: number,
	phase: number,
	speed: number,
	moving: boolean,
}
local swayers: { Swayer } = {}

local function addSwayer(model: Model, amplitude: number)
	local lowest = math.huge
	local list = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2)
			table.insert(list, { part = p, offset = CFrame.identity })
		end
	end
	if #list == 0 then
		return
	end
	local pivot = model:GetBoundingBox().Position
	local base = CFrame.new(pivot.X, lowest, pivot.Z)
	for _, entry in list do
		entry.offset = base:ToObjectSpace(entry.part.CFrame)
	end
	table.insert(swayers, {
		base = base,
		parts = list,
		amplitude = math.rad(amplitude),
		phase = (pivot.X * 0.13 + pivot.Z * 0.07) % (math.pi * 2),
		speed = 0.9 + ((pivot.X * 0.31 + pivot.Z * 0.17) % 1) * 0.5,
		moving = false,
	})
end

-- A szél tengelye: vízszintes, a szél irányára merőleges (e körül dőlnek a fák a szél felé)
local SWAY_AXIS = Vector3.yAxis:Cross(WIND).Unit

local function sway(t: number, camera: Vector3)
	-- Széllökés: lassan hullámzó erősség, néha felerősödik
	local gust = 1 + 0.6 * math.max(0, math.sin(t * 0.23) * math.sin(t * 0.71 + 1.3))
	for _, s in swayers do
		local near = (s.base.Position - camera).Magnitude < SWAY_DISTANCE
		if near then
			local angle = s.amplitude * gust * (0.6 + 0.4 * math.sin(t * s.speed + s.phase))
				+ s.amplitude * 0.25 * math.sin(t * s.speed * 2.3 + s.phase * 1.7)
			local frame = s.base * CFrame.fromAxisAngle(s.base:VectorToObjectSpace(SWAY_AXIS), -angle)
			for _, entry in s.parts do
				entry.part.CFrame = frame * entry.offset
			end
			s.moving = true
		elseif s.moving then
			-- Távol: vissza az eredeti helyére, és ott marad
			for _, entry in s.parts do
				entry.part.CFrame = s.base * entry.offset
			end
			s.moving = false
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Víz

local waters: { BasePart } = {}

local function glints(water: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Glints"
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Top
	local area = water.Size.X * water.Size.Z
	if water:IsA("Part") and water.Shape == Enum.PartType.Cylinder then
		area = water.Size.Y * water.Size.Z
	end
	emitter.Rate = math.clamp(area / 25, 4, 80)
	emitter.Parent = water
end

-- Egy fodor: vékony, táguló, elhalványuló gyűrű a vízfelszínen.
local function ripple(position: Vector3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(230, 245, 255)
	ring.Transparency = 0.45
	ring.Size = Vector3.new(0.04, 0.4, 0.4)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	local size = math.random() * 2 + 2.5
	TweenService:Create(ring, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.04, size, size),
		Transparency = 1,
	}):Play()
	task.delay(1.9, function()
		ring:Destroy()
	end)
end

-- Véletlen pont egy víz alkatrész felszínén, a kamerához közel.
local function pointOn(water: BasePart, camera: Vector3): Vector3?
	local cf, size = water.CFrame, water.Size
	if water:IsA("Part") and water.Shape == Enum.PartType.Cylinder then
		-- Álló henger: a tengely a helyi X, a sugár a Y/Z
		local r = math.sqrt(math.random()) * (size.Y / 2 - 0.8)
		local a = math.random() * math.pi * 2
		return cf:PointToWorldSpace(Vector3.new(size.X / 2 + 0.03, r * math.cos(a), r * math.sin(a)))
	end
	-- Lapos víz: a kamerához legközelebbi rész körül (a hosszú folyón így a közelben fodrozódik)
	local localCamera = cf:PointToObjectSpace(camera)
	local hx, hz = size.X / 2 - 0.8, size.Z / 2 - 0.8
	if hx <= 0 or hz <= 0 then
		return nil
	end
	local x = math.clamp(localCamera.X + (math.random() - 0.5) * 60, -hx, hx)
	local z = math.clamp(localCamera.Z + (math.random() - 0.5) * 60, -hz, hz)
	return cf:PointToWorldSpace(Vector3.new(x, size.Y / 2 + 0.03, z))
end

local function fountainSpray(model: Model)
	-- A legmagasabb gömb a szökőkút teteje: onnan spriccel a víz
	local top: BasePart? = nil
	for _, p in model:GetDescendants() do
		if p:IsA("Part") and p.Shape == Enum.PartType.Ball and (not top or p.Position.Y > top.Position.Y) then
			top = p
		end
	end
	if not top then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, top.Size.Y / 2, 0)
	attachment.Parent = top
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	spray.LightEmission = 0.3
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.8) })
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.45) })
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(22, 22)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Rate = 45
	spray.Parent = attachment
end

---------------------------------------------------------------------------------------------------

function Ambient.start()
	if not Config.AMBIENT then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Ambient"
	folder.Parent = workspace

	task.spawn(function()
		local level = workspace:WaitForChild("Level")
		local props = level:WaitForChild("Props")
		task.wait(1) -- a pálya teljes megérkezése
		local fountains, failures = 0, 0
		for _, model in props:GetChildren() do
			local amplitude = SWAY_NAMES[model.Name]
			local ok, err = pcall(function()
				if amplitude and model:IsA("Model") then
					addSwayer(model, amplitude)
				elseif model.Name == "Fountain" and model:IsA("Model") then
					fountainSpray(model)
					fountains += 1
				end
			end)
			if not ok then
				failures += 1
				if failures <= 3 then
					warn(`[Paint Pop] Ambient: {model.Name} failed: {err}`)
				end
			end
		end
		for _, part in level:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("Water") then
				table.insert(waters, part)
				local ok, err = pcall(glints, part)
				if not ok then
					warn(`[Paint Pop] Ambient: water glints failed: {err}`)
				end
				if part.Parent and part.Parent.Name == "World" then
					-- A folyó színe lassan hullámzik (a tavat és a szökőkutat festeni lehet, azokét nem)
					local base = part.Color
					TweenService:Create(
						part,
						TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ Color = base:Lerp(Color3.fromRGB(150, 205, 235), 0.35) }
					):Play()
				end
			end
		end
		print(
			`[Paint Pop] Ambient: {#swayers} trees, {#waters} water surfaces, {fountains} fountains ({failures} failed)`
		)
	end)

	local elapsed, rippleTimer = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local position = camera.CFrame.Position
		-- A fák 30-szor mp-enként mozdulnak (elég a finom ringáshoz)
		elapsed += dt
		if elapsed >= 1 / 30 then
			elapsed = 0
			sway(os.clock(), position)
		end
		rippleTimer += dt
		if rippleTimer >= 0.2 and #waters > 0 then
			rippleTimer = 0
			local water = waters[math.random(1, #waters)]
			local _, size = water.CFrame, water.Size
			local closest = water.CFrame:PointToWorldSpace(
				Vector3.new(
					math.clamp(water.CFrame:PointToObjectSpace(position).X, -size.X / 2, size.X / 2),
					0,
					math.clamp(water.CFrame:PointToObjectSpace(position).Z, -size.Z / 2, size.Z / 2)
				)
			)
			if (closest - position).Magnitude < RIPPLE_DISTANCE then
				local point = pointOn(water, position)
				if point then
					ripple(point)
				end
			end
		end
	end)
end

return Ambient
