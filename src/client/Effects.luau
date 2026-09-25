-- Festés-effektek: fröccsenő festékcseppek és egy rövid felvillanás a befestett épületen.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local PaintedRemote = ReplicatedStorage.Remotes.Painted

local Effects = {}

local function splash(building: BasePart, color: Color3, painter: Player?)
	-- A cseppek onnan fröccsennek, ahol a festő a házhoz ért (ha tudjuk), különben a ház aljáról.
	local root = painter and painter.Character and painter.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local localPoint = if root
		then building.CFrame:PointToObjectSpace(root.Position)
		else Vector3.new(0, -building.Size.Y / 2 + 3, 0)
	local half = building.Size / 2
	localPoint = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)

	local attachment = Instance.new("Attachment")
	attachment.Position = localPoint
	attachment.Parent = building

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.2) })
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(12, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.LightEmission = 0.2
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(30)
	Debris:AddItem(attachment, 1.5)

	local flash = Instance.new("Highlight")
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.2
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = building
	TweenService:Create(flash, TweenInfo.new(0.35), { FillTransparency = 1 }):Play()
	Debris:AddItem(flash, 0.4)
end

function Effects.start()
	PaintedRemote.OnClientEvent:Connect(function(building: BasePart, colorName: string, painter: Player?)
		local color = Config.PAINT_COLOR_BY_NAME[colorName]
		if building and building.Parent and color then
			splash(building, color, painter)
		end
	end)
end

return Effects
