-- Festés-effektek: fröccsenő festékcseppek, egy rövid felvillanás a befestett épületen, placcs hang.
-- Friss festék (a ház Config.PAINT_PROTECT mp-ig nem festhető át): "WET PAINT" tábla fogyó sávval a ház fölött,
-- a falakról csöpögő festék, és a fal fényes, majd fokozatosan "megszárad".

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

-- Felugró felirat a világban (pl. "-3": mennyi festék fogyott; "+6": mennyit loptál).
local function popup(position: Vector3, message: string, color: Color3)
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
	text.Text = message
	text.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(anchor, TweenInfo.new(1.1), { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(text, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 1.2)
end

Effects.popup = popup

-- Friss festék jelzése egy házon, amíg védett.
local wetSigns: { [BasePart]: Instance } = {}
local function wetPaint(building: BasePart, color: Color3)
	local duration = Config.PAINT_PROTECT
	if duration <= 0 then
		return
	end
	local old = wetSigns[building]
	if old then
		old:Destroy()
	end

	-- Tábla a ház fölött: felirat és a csapat színében fogyó sáv
	local gui = Instance.new("BillboardGui")
	gui.Name = "WetPaint"
	gui.Size = UDim2.fromOffset(110, 40)
	gui.StudsOffset = Vector3.new(0, building.Size.Y / 2 + 4, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Adornee = building
	local sign = Instance.new("Frame")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundColor3 = Color3.fromRGB(250, 247, 238)
	sign.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = sign
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = sign
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromScale(0.06, 0.05)
	text.Size = UDim2.fromScale(0.88, 0.6)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.25)
	text.Text = "WET PAINT"
	text.Parent = sign
	local fill = Instance.new("Frame")
	fill.Position = UDim2.fromScale(0.08, 0.7)
	fill.Size = UDim2.fromScale(0.84, 0.16)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color
	fill.Parent = sign
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 0.16) })
		:Play()
	wetSigns[building] = gui

	-- Csöpögés a falakról (a ház testének felszínéről, lefelé)
	local drips = Instance.new("ParticleEmitter")
	drips.Name = "WetDrips"
	drips.Shape = Enum.ParticleEmitterShape.Box
	drips.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	drips.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.1))
	drips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	drips.Squash = NumberSequence.new(-0.6) -- megnyúlt cseppek
	drips.Lifetime = NumberRange.new(0.5, 0.9)
	drips.Speed = NumberRange.new(0)
	drips.Acceleration = Vector3.new(0, -25, 0)
	local area = building.Size.X * building.Size.Y + building.Size.Z * building.Size.Y
	drips.Rate = math.clamp(area / 12, 10, 45)
	drips.Parent = building

	-- Fényes, nedves fal, ami fokozatosan megszárad
	local reflectance = building.Reflectance
	building.Reflectance = 0.25
	TweenService:Create(building, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Reflectance = reflectance,
	}):Play()

	task.delay(duration, function()
		drips.Enabled = false
		Debris:AddItem(drips, 1)
		if wetSigns[building] == gui then
			wetSigns[building] = nil
		end
		TweenService:Create(sign, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(gui, 0.35)
	end)
end

function Effects.start()
	local localPlayer = game:GetService("Players").LocalPlayer
	PaintedRemote.OnClientEvent:Connect(function(building: BasePart, colorName: string, painter: Player?, cost: number?)
		local color = Config.PAINT_COLOR_BY_NAME[colorName]
		if building and building.Parent and color then
			splash(building, color, painter)
			-- Csak a házakon (a tárgyak nem védettek)
			if building.Parent and building.Parent.Name == "Buildings" then
				wetPaint(building, color)
			end
			if painter == localPlayer and cost then
				local root = localPlayer.Character
					and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				popup((if root then root.Position else building.Position) + Vector3.new(0, 4, 0), `-{cost}`, color)
			end
			local root = painter
				and painter.Character
				and painter.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			Sounds.play("Paint", if root then root.Position else building.Position)
		end
	end)
end

return Effects
