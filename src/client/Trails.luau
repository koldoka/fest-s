-- Festékcsík: a festékes paca folytonos, kicsit hullámzó szélességű csíkot húz maga után, apró fröccsenésekkel.
-- Földet éréskor nagyobb fröccs. A csík lassan "felszárad": elvékonyodik és eltűnik.
-- Csak látvány, minden kliens a saját gépén rajzolja minden játékosra; a játékmenetre nincs hatása.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Trails = {}

local THICKNESS = 0.05

local folder: Folder
local marks: { BasePart } = {}
-- Játékosonként: az utolsó csíkpont a talajon, és a levegőben volt-e az előző lépésben.
local states: { [Player]: { last: Vector3?, wasAir: boolean, travel: number, phase: number } } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local rng = Random.new()

local function markPart(color: Color3): Part
	local part = Instance.new("Part")
	part.Name = "PaintMark"
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.06 -- kicsit fényes, mint a nedves festék
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Felszáradás: egy idő után elvékonyodik, aztán eltűnik.
local function dry(part: BasePart, endSize: Vector3)
	local t = Config.TRAIL
	local lifetime = t.LIFETIME * rng:NextNumber(0.85, 1.15)
	local info =
		TweenInfo.new(lifetime * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, lifetime * 0.55)
	TweenService:Create(part, info, { Size = endSize }):Play()
	Debris:AddItem(part, lifetime + 0.1)

	table.insert(marks, part)
	if #marks > t.MAX_MARKS then
		local oldest = table.remove(marks, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

-- Kerek folt (lapos henger), a tengelye a talaj normálisa.
local function blot(position: Vector3, normal: Vector3, diameter: number, color: Color3)
	local part = markPart(color)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(THICKNESS, diameter, diameter)
	local side = if math.abs(normal.Y) < 0.99 then normal:Cross(Vector3.yAxis).Unit else Vector3.xAxis
	-- Pici véletlen emelés, hogy az egymásra eső foltok ne villogjanak.
	local lift = 0.03 + rng:NextNumber() * 0.02
	part.CFrame = CFrame.fromMatrix(position + normal * lift, normal, side)
	part.Parent = folder
	dry(part, Vector3.new(THICKNESS, 0.05, 0.05))
end

-- Egyenes csíkdarab két pont között (a két végén kerek folt zárja).
local function stroke(from: Vector3, to: Vector3, normal: Vector3, width: number, color: Color3)
	local along = to - from
	local length = along.Magnitude
	if length < 0.05 then
		return
	end
	along = along.Unit
	local part = markPart(color)
	part.Size = Vector3.new(length, THICKNESS, width)
	local lift = 0.03 + rng:NextNumber() * 0.02
	part.CFrame = CFrame.fromMatrix((from + to) / 2 + normal * lift, along, normal)
	part.Parent = folder
	dry(part, Vector3.new(length, THICKNESS, 0.05))
end

-- Apró cseppek a csík mellett.
local function splatter(
	center: Vector3,
	normal: Vector3,
	along: Vector3,
	width: number,
	color: Color3,
	count: number,
	reach: number
)
	local side = along:Cross(normal)
	for _ = 1, count do
		local offset = side * (rng:NextNumber(-1, 1) * reach) + along * (rng:NextNumber(-0.5, 0.5) * reach)
		blot(center + offset, normal, width * rng:NextNumber(0.12, 0.32), color)
	end
end

local function update()
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = { folder, table.unpack(characters) }

	local t = Config.TRAIL
	for _, player in Players:GetPlayers() do
		local state = states[player]
		if not state then
			state = { last = nil, wasAir = false, travel = 0, phase = rng:NextNumber(0, 10) }
			states[player] = state
		end
		local character = player.Character
		local blob = character and character:FindFirstChild("Blob") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local paint = player:GetAttribute("Paint") or 0
		if not blob or not humanoid or paint <= 0 then
			state.last = nil
			state.wasAir = false
			continue
		end
		local airborne = humanoid.FloorMaterial == Enum.Material.Air
		local diameter = blob.Size.Y
		-- A nedves festék a földön kicsit sötétebb, mint a paca.
		local color = blob.Color:Lerp(Color3.new(0, 0, 0), 0.08)
		if airborne then
			state.last = nil -- a levegőben megszakad a csík
			state.wasAir = true
			continue
		end
		local hit = workspace:Raycast(blob.Position, Vector3.new(0, -diameter, 0), rayParams)
		if not hit then
			state.last = nil
			continue
		end
		local point, normal = hit.Position, hit.Normal
		-- A szélesség lassan hullámzik a megtett úttal (nem ugrál darabonként).
		local wave = math.sin(state.travel * 0.35 + state.phase) * 0.6
			+ math.sin(state.travel * 0.9 + state.phase * 2) * 0.4
		local width = diameter * t.WIDTH * (1 + 0.14 * wave)

		if state.wasAir then
			-- Földet érés: nagyobb folt és körben fröccsenés.
			state.wasAir = false
			blot(point, normal, diameter * 0.9, color)
			splatter(point, normal, Vector3.zAxis, diameter, color, rng:NextInteger(6, 10), diameter * 1.1)
			state.last = point
			continue
		end

		local last = state.last
		if not last then
			blot(point, normal, width, color)
			state.last = point
			continue
		end
		local distance = (point - last).Magnitude
		if distance < t.SEGMENT_LENGTH then
			continue
		end
		-- Nagy ugrás (járdaszél, teleport): nem húzunk át rajta csíkot, új csík kezdődik.
		state.travel += distance
		if math.abs(point.Y - last.Y) < 0.6 and distance < t.SEGMENT_LENGTH * 4 then
			stroke(last, point, normal, width, color)
			-- Néha egy nagyobb csepp a csíkban
			if rng:NextNumber() < t.BLOB_CHANCE then
				blot(
					point + (point - last).Unit:Cross(normal) * rng:NextNumber(-0.3, 0.3) * width,
					normal,
					width * rng:NextNumber(1.2, 1.45),
					color
				)
			end
			if rng:NextNumber() < t.SPLATTER_CHANCE then
				splatter(
					(last + point) / 2,
					normal,
					(point - last).Unit,
					width,
					color,
					rng:NextInteger(1, 3),
					width * 0.9
				)
			end
		end
		blot(point, normal, width, color)
		state.last = point
	end
end

function Trails.start()
	folder = Instance.new("Folder")
	folder.Name = "PaintTrails"
	folder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(function()
		-- A Debris által már törölt darabokat kivesszük a listából.
		while marks[1] and marks[1].Parent == nil do
			table.remove(marks, 1)
		end
		update()
	end)
end

return Trails
