-- Festéknyomok: a festékes paca színes foltokat hagy maga után a talajon, amelyek lassan elhalványulnak.
-- Csak látvány, minden kliens a saját gépén rajzolja minden játékosra; a játékmenetre nincs hatása.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Trails = {}

local folder: Folder
local marks: { BasePart } = {}
local lastMark: { [Player]: Vector3 } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function addMark(position: Vector3, normal: Vector3, diameter: number, color: Color3)
	local size = diameter * Config.TRAIL.SIZE
	local mark = Instance.new("Part")
	mark.Name = "PaintMark"
	-- Lapos henger: a tengelye (X) a talaj normálisa felé néz.
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.05, size, size)
	local up = if math.abs(normal.Y) < 0.99 then Vector3.yAxis else Vector3.zAxis
	-- Pici véletlen emelés, hogy az egymásra eső foltok ne villogjanak.
	local lift = 0.03 + math.random() * 0.02
	mark.CFrame = CFrame.fromMatrix(position + normal * lift, normal, normal:Cross(up).Unit)
	mark.Color = color
	mark.Material = Enum.Material.SmoothPlastic
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Parent = folder

	local lifetime = Config.TRAIL.LIFETIME
	TweenService:Create(
		mark,
		TweenInfo.new(lifetime * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, lifetime * 0.6),
		{
			Transparency = 1,
		}
	):Play()
	Debris:AddItem(mark, lifetime + 0.1)

	table.insert(marks, mark)
	if #marks > Config.TRAIL.MAX_MARKS then
		local oldest = table.remove(marks, 1)
		if oldest then
			oldest:Destroy()
		end
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

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local blob = character and character:FindFirstChild("Blob") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local paint = player:GetAttribute("Paint") or 0
		if not blob or not humanoid or paint <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
			lastMark[player] = nil
			continue
		end
		local diameter = blob.Size.Y
		local last = lastMark[player]
		if last and (blob.Position - last).Magnitude < diameter * Config.TRAIL.SPACING then
			continue
		end
		local hit = workspace:Raycast(blob.Position, Vector3.new(0, -diameter, 0), rayParams)
		if hit then
			addMark(hit.Position, hit.Normal, diameter, blob.Color)
			lastMark[player] = blob.Position
		end
	end
end

function Trails.start()
	folder = Instance.new("Folder")
	folder.Name = "PaintTrails"
	folder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		lastMark[player] = nil
	end)
	RunService.Heartbeat:Connect(function()
		-- A Debris által már törölt foltokat kivesszük a listából.
		while marks[1] and marks[1].Parent == nil do
			table.remove(marks, 1)
		end
		update()
	end)
end

return Trails
