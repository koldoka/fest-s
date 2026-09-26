-- A meccs pillanatai a kliensen:
--   Rajt: a szünet utolsó 3 mp-ében nagy visszaszámlálás, majd "GO!".
--   Vég: a meccs utolsó 10 mp-ében nagy visszaszámlálás pittyenéssel.
--   Eredmény: a győztes csapat színében eredménytábla (csapatpontok, a legjobb 3 játékos), konfetti,
--   győzelmi vagy vesztes dallam a saját csapat szerint.
-- Az állapot a workspace attribútumaiból jön (MatchState, PhaseEndsAt, Winner, Score_<csapat>).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)

local Results = {}

local WHITE = Color3.new(1, 1, 1)

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = WHITE
	l.TextStrokeTransparency = 0.3
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local gui: ScreenGui
local bigNumber: TextLabel
local panel: Frame

-- Nagy szám vagy szó a képernyő közepén: felpattan, majd elhalványul.
local function flash(text: string, color: Color3)
	bigNumber.Text = text
	bigNumber.TextColor3 = color
	bigNumber.TextTransparency = 0
	bigNumber.TextStrokeTransparency = 0.2
	local scale = bigNumber:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 1.6
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(
		bigNumber,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
end

-- Képernyő-konfetti: színes lapocskák hullanak a képernyő tetejéről.
local function screenConfetti(color: Color3)
	local palette = { color, color:Lerp(WHITE, 0.5), Color3.fromRGB(255, 220, 90), WHITE }
	for _ = 1, 70 do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = palette[math.random(1, #palette)]
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		local x = math.random()
		piece.Position = UDim2.new(x, 0, 0, -30 - math.random(0, 200))
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 20
		piece.Parent = gui
		local time = 2 + math.random() * 1.5
		TweenService:Create(piece, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(x + (math.random() - 0.5) * 0.2, 0, 1, 40),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(time, function()
			piece:Destroy()
		end)
	end
end

local function playerScore(player: Player): number
	local stats = player:FindFirstChild("leaderstats")
	local score = stats and stats:FindFirstChild("Score") :: IntValue?
	return if score then score.Value else 0
end

local function showResults()
	for _, child in panel:GetChildren() do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	local winner = workspace:GetAttribute("Winner") or ""
	local color = Config.PAINT_COLOR_BY_NAME[winner] or WHITE
	local myTeam = Players.LocalPlayer:GetAttribute("Team")
	local stroke = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = color

	label(panel, {
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.9, 0.18),
		Text = if winner ~= "" then `{string.upper(winner)} TEAM WINS!` else "IT'S A DRAW!",
		TextColor3 = color,
	})
	if winner ~= "" then
		label(panel, {
			Position = UDim2.fromScale(0.05, 0.22),
			Size = UDim2.fromScale(0.9, 0.08),
			Text = if myTeam == winner then "Your team won!" else "Better luck next time!",
		})
	end

	-- Csapatpontok, a legtöbbtől lefelé
	local teams = {}
	for _, team in Config.TEAMS do
		table.insert(teams, { name = team.name, score = workspace:GetAttribute("Score_" .. team.name) or 0 })
	end
	table.sort(teams, function(a, b)
		return a.score > b.score
	end)
	for i, team in teams do
		label(panel, {
			Position = UDim2.fromScale(0.1, 0.32 + (i - 1) * 0.09),
			Size = UDim2.fromScale(0.8, 0.08),
			Text = `{team.name}  {team.score}`,
			TextColor3 = Config.PAINT_COLOR_BY_NAME[team.name] or WHITE,
		})
	end

	-- A legjobb 3 játékos (saját pont)
	local top = 0.34 + #teams * 0.09
	label(panel, {
		Position = UDim2.fromScale(0.05, top),
		Size = UDim2.fromScale(0.9, 0.07),
		Text = "Top painters",
		TextColor3 = Color3.fromRGB(255, 220, 120),
	})
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return playerScore(a) > playerScore(b)
	end)
	for i = 1, math.min(3, #players) do
		local player = players[i]
		local medal = ({ "1st", "2nd", "3rd" })[i]
		label(panel, {
			Position = UDim2.fromScale(0.1, top + 0.08 + (i - 1) * 0.075),
			Size = UDim2.fromScale(0.8, 0.065),
			Text = `{medal}  {player.DisplayName}  {playerScore(player)}`,
			TextColor3 = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("Team") or ""] or WHITE,
		})
	end

	panel.Visible = true
	local scale = panel:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	screenConfetti(color)
	if winner ~= "" and myTeam == winner and Sounds.has("Win") then
		Sounds.play("Win")
	elseif winner ~= "" and myTeam ~= winner and Sounds.has("Lose") then
		Sounds.play("Lose")
	else
		Sounds.play("CityDone")
	end
end

function Results.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Results"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	bigNumber = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.5, 0.2),
		Text = "",
		TextTransparency = 1,
	})
	Instance.new("UIScale").Parent = bigNumber

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.42, 0.62)
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.9
	aspect.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = panel
	Instance.new("UIScale").Parent = panel

	local lastState = workspace:GetAttribute("MatchState")
	local lastShown: number? = nil
	RunService.Heartbeat:Connect(function()
		local state = workspace:GetAttribute("MatchState")
		local endsAt = workspace:GetAttribute("PhaseEndsAt") or 0
		local left = math.ceil(endsAt - workspace:GetServerTimeNow())

		if state ~= lastState then
			if state == "Playing" and lastState == "Intermission" then
				flash("GO!", Color3.fromRGB(120, 230, 120))
				Sounds.play("Go")
			elseif state == "Ended" then
				showResults()
			end
			if state ~= "Ended" then
				panel.Visible = false
			end
			lastState = state
			lastShown = nil
		end

		-- Visszaszámlálás: a szünet utolsó 3, a meccs utolsó 10 másodperce
		local limit = if state == "Intermission" then 3 elseif state == "Playing" then 10 else 0
		if left >= 1 and left <= limit and left ~= lastShown then
			lastShown = left
			local myColor = Config.PAINT_COLOR_BY_NAME[Players.LocalPlayer:GetAttribute("Team") or ""]
			flash(tostring(left), if state == "Playing" then Color3.fromRGB(255, 220, 120) else myColor or WHITE)
			Sounds.play("Tick")
		end
	end)
end

return Results
