-- Festés-effektek: fröccsenő festékcseppek, egy rövid felvillanás a befestett épületen, placcs hang.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)

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

-- Felugró "-N" felirat: mennyi festék fogyott (csak a festőnek).
local function costPopup(position: Vector3, cost: number, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.2
	text.Text = `-{cost}`
	text.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(anchor, TweenInfo.new(1.1), { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(text, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 1.2)
end

function Effects.start()
	local localPlayer = game:GetService("Players").LocalPlayer
	PaintedRemote.OnClientEvent:Connect(function(building: BasePart, colorName: string, painter: Player?, cost: number?)
		local color = Config.PAINT_COLOR_BY_NAME[colorName]
		if building and building.Parent and color then
			splash(building, color, painter)
			if painter == localPlayer and cost then
				local root = localPlayer.Character
					and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				costPopup((if root then root.Position else building.Position) + Vector3.new(0, 4, 0), cost, color)
			end
			local root = painter
				and painter.Character
				and painter.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			Sounds.play("Paint", if root then root.Position else building.Position)
		end
	end)
end

return Effects
