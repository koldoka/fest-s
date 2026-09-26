-- Képernyőelemek: felül a meccs ideje és a csapatok pontjai, bal alul a saját csapat és festék,
-- középen a bejelentések (kerületfoglalás, festéklopás, győztes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Hud = {}

-- Bejelentés a képernyő közepén (a Hud.start() után használható).
function Hud.announce(_text: string, _color: Color3?) end

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

	-- A meccs állapota és ideje
	local timer = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(320, 30),
		Parent = gui,
	})
	local PHASE_TEXT = { Intermission = "Next match in", Playing = "", Ended = "New match in" }
	local lastTimerText = ""
	RunService.Heartbeat:Connect(function()
		local state = workspace:GetAttribute("MatchState")
		local endsAt = workspace:GetAttribute("PhaseEndsAt")
		local text = ""
		if state and endsAt then
			local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			local clock = string.format("%d:%02d", left // 60, left % 60)
			local prefix = PHASE_TEXT[state] or ""
			text = if prefix ~= "" then `{prefix} {clock}` else clock
		end
		if text ~= lastTimerText then
			lastTimerText = text
			timer.Text = text
		end
	end)

	-- A csapatok pontjai: egy sáv, amit a csapatok a pontjaik arányában töltenek ki
	local scoreBar = Instance.new("Frame")
	scoreBar.AnchorPoint = Vector2.new(0.5, 0)
	scoreBar.Position = UDim2.new(0.5, 0, 0, 40)
	scoreBar.Size = UDim2.new(0.4, 0, 0, 26)
	scoreBar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	scoreBar.BackgroundTransparency = 0.3
	scoreBar.ClipsDescendants = true
	scoreBar.Parent = gui
	corner(scoreBar, 8)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scoreBar
	local segments = {}
	for index, team in Config.TEAMS do
		local segment = Instance.new("Frame")
		segment.LayoutOrder = index
		segment.BorderSizePixel = 0
		segment.BackgroundColor3 = Config.PAINT_COLOR_BY_NAME[team.name]
		segment.Size = UDim2.fromScale(1 / #Config.TEAMS, 1)
		segment.Parent = scoreBar
		local text = label({ Size = UDim2.fromScale(1, 1), Parent = segment })
		segments[team.name] = { frame = segment, text = text }
	end
	local function updateScores()
		local total = 0
		for _, team in Config.TEAMS do
			total += workspace:GetAttribute("Score_" .. team.name) or 0
		end
		for _, team in Config.TEAMS do
			local score = workspace:GetAttribute("Score_" .. team.name) or 0
			local share = if total > 0 then score / total else 1 / #Config.TEAMS
			local seg = segments[team.name]
			TweenService:Create(seg.frame, TweenInfo.new(0.3), { Size = UDim2.fromScale(share, 1) }):Play()
			seg.text.Text = if share > 0.12 then `{team.name} {score}` else tostring(score)
		end
	end
	for _, team in Config.TEAMS do
		workspace:GetAttributeChangedSignal("Score_" .. team.name):Connect(updateScores)
	end
	updateScores()

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

	-- Saját csapat a festéksáv fölött
	local teamText = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -76),
		Size = UDim2.fromOffset(246, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = gui,
	})
	local function updateTeam()
		local team = player:GetAttribute("Team")
		teamText.Text = if team then `Team {team}` else ""
		teamText.TextColor3 = Config.PAINT_COLOR_BY_NAME[team or ""] or Color3.new(1, 1, 1)
		stroke.Color = teamText.TextColor3
	end
	player:GetAttributeChangedSignal("Team"):Connect(updateTeam)
	updateTeam()

	local function updatePaint()
		local colorName = player:GetAttribute("PaintColor") or ""
		local paint = player:GetAttribute("Paint") or 0
		local color = Config.PAINT_COLOR_BY_NAME[colorName]
		if color and paint > 0 then
			swatch.BackgroundColor3 = color
			paintFill.BackgroundColor3 = color
			paintText.Text = `{colorName} paint  {paint}/{Config.PAINT_MAX}`
		else
			swatch.BackgroundColor3 = Config.BUILDINGS.GREY
			paintFill.BackgroundColor3 = Config.BUILDINGS.GREY
			paintText.Text = "Find a paint bucket!"
		end
		paintFill.Size = UDim2.fromScale(paint / Config.PAINT_MAX, 1)
	end
	player:GetAttributeChangedSignal("PaintColor"):Connect(updatePaint)
	player:GetAttributeChangedSignal("Paint"):Connect(updatePaint)
	updatePaint()

	-- Ha kevés a festék egy házhoz vagy tárgyhoz: rövid figyelmeztetés a festéksáv fölött
	local warning = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -104),
		Size = UDim2.fromOffset(260, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = "",
		Parent = gui,
	})
	local warningToken = 0
	ReplicatedStorage.Remotes:WaitForChild("NeedPaint").OnClientEvent:Connect(function(cost: number)
		warningToken += 1
		local token = warningToken
		warning.Text = `Not enough paint! This needs {cost}.`
		task.delay(2, function()
			if token == warningToken then
				warning.Text = ""
			end
		end)
	end)

	-- Bejelentések középen (a szerver küldi; a PvP modul is ezt használja). Pár mp után elhalványul.
	local message = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.new(0.7, 0, 0, 44),
		Text = "",
		Parent = gui,
	})
	local messageToken = 0
	Hud.announce = function(text: string, color: Color3?)
		messageToken += 1
		local token = messageToken
		message.Text = text
		message.TextColor3 = color or Color3.new(1, 1, 1)
		message.TextTransparency = 0
		message.TextStrokeTransparency = 0.3
		task.delay(3.5, function()
			if token == messageToken then
				TweenService:Create(message, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
					:Play()
			end
		end)
	end
	ReplicatedStorage.Remotes:WaitForChild("Announce").OnClientEvent:Connect(function(text: string, colorName: string?)
		Hud.announce(text, colorName and Config.PAINT_COLOR_BY_NAME[colorName])
	end)
end

return Hud
