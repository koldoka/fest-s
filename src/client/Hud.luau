-- Képernyőelemek: a város festettsége felül, a saját festék bal alul, üzenet középen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Hud = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.TextScaled = true
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

-- Egy sáv háttérrel és kitöltéssel. Visszaadja a keretet és a kitöltést.
local function bar(parent: Instance, props: { [string]: any }): (Frame, Frame)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	frame.BackgroundTransparency = 0.3
	for key, value in props do
		(frame :: any)[key] = value
	end
	corner(frame, 8)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = frame
	corner(fill, 8)
	frame.Parent = parent
	return frame, fill
end

function Hud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- A város festettsége
	local cityBar, cityFill = bar(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0.4, 0, 0, 26),
	})
	cityFill.BackgroundColor3 = Color3.fromRGB(120, 220, 140)
	local cityText = label({ Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = cityBar })

	local function updateCity()
		local painted = workspace:GetAttribute("PaintedCount") or 0
		local total = workspace:GetAttribute("BuildingCount") or 0
		local ratio = if total > 0 then painted / total else 0
		cityFill.Size = UDim2.fromScale(ratio, 1)
		cityText.Text = `City painted: {math.floor(ratio * 100)}%`
	end
	workspace:GetAttributeChangedSignal("PaintedCount"):Connect(updateCity)
	workspace:GetAttributeChangedSignal("BuildingCount"):Connect(updateCity)
	updateCity()

	-- Saját festék
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0, 1)
	swatch.Position = UDim2.new(0, 16, 1, -16)
	swatch.Size = UDim2.fromOffset(56, 56)
	swatch.Parent = gui
	corner(swatch, 28)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = swatch

	local _, paintFill = bar(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 82, 1, -16),
		Size = UDim2.fromOffset(180, 22),
	})
	local paintText = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 82, 1, -42),
		Size = UDim2.fromOffset(180, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = gui,
	})

	local function updatePaint()
		local colorName = player:GetAttribute("PaintColor") or ""
		local paint = player:GetAttribute("Paint") or 0
		local color = Config.PAINT_COLOR_BY_NAME[colorName]
		if color and paint > 0 then
			swatch.BackgroundColor3 = color
			paintFill.BackgroundColor3 = color
			paintText.Text = `{colorName} paint`
		else
			swatch.BackgroundColor3 = Config.CITY.GREY
			paintFill.BackgroundColor3 = Config.CITY.GREY
			paintText.Text = "Find a paint tank!"
		end
		paintFill.Size = UDim2.fromScale(paint / Config.PAINT_MAX, 1)
	end
	player:GetAttributeChangedSignal("PaintColor"):Connect(updatePaint)
	player:GetAttributeChangedSignal("Paint"):Connect(updatePaint)
	updatePaint()

	-- Üzenet középen
	local message = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.7, 0, 0, 48),
		Parent = gui,
	})
	local function updateMessage()
		message.Text = workspace:GetAttribute("Message") or ""
	end
	workspace:GetAttributeChangedSignal("Message"):Connect(updateMessage)
	updateMessage()
end

return Hud
