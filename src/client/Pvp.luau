-- PvP a kliensen:
--   Hátrapattanás, ha meglopták a pacánkat (a lopásról a szerver dönt, StealService; a saját karaktert
--   viszont a kliens mozgatja, ezért a hátrapattanást itt kell rátenni).
--   A lopás látványa: festékcseppek a lopó felé, a lopónak "+N" és szívó hang, a meglopottnak piros
--   villanás, rázkódó kamera és leeresztő hang.
--   Névcímke a többi paca fölött: név a csapat színében, alatta a festéke (így látszik, kit érdemes meglopni).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local Effects = require(script.Parent.Effects)

local Pvp = {}

local function blobOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Blob") :: BasePart?
end

-- Festékcseppek a meglopott pacától a lopó felé.
local function stealBurst(from: BasePart, to: BasePart?, color: Color3, amount: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = from.Position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.2) })
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Speed = NumberRange.new(18, 30)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -50, 0)
	emitter.Enabled = false
	if to then
		local direction = to.Position - from.Position
		if direction.Magnitude > 0.01 then
			attachment.WorldCFrame = CFrame.lookAt(from.Position, to.Position) * CFrame.Angles(math.rad(-90), 0, 0)
		end
	else
		emitter.SpreadAngle = Vector2.new(180, 180)
	end
	emitter.Parent = attachment
	emitter:Emit(math.clamp(amount * 4, 10, 40))
	Debris:AddItem(attachment, 1.2)
end

-- A meglopott játékos képernyője: piros villanás és rövid kamerarázás.
local hurtFrame: Frame? = nil
local function hurt()
	if hurtFrame then
		hurtFrame.BackgroundTransparency = 0.55
		TweenService:Create(hurtFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > 0.35 or humanoid.Parent == nil then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local strength = 0.6 * (1 - t / 0.35)
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * strength
	end)
end

-- Névcímkék a többi játékos pacája fölött.
type Tag = { gui: BillboardGui, name: TextLabel, fill: Frame }
local tags: { [Player]: Tag } = {}

local function makeTag(player: Player): Tag
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag_" .. player.Name
	gui.Size = UDim2.fromOffset(120, 34)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 22)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextStrokeTransparency = 0.3
	name.Text = player.DisplayName
	name.Parent = gui
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 24)
	bar.Size = UDim2.fromOffset(60, 7)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	bar.BackgroundTransparency = 0.2
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return { gui = gui, name = name, fill = fill }
end

local function updateTags()
	for player, tag in tags do
		if player.Parent == nil then
			tag.gui:Destroy()
			tags[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		if player == Players.LocalPlayer then
			continue
		end
		local tag = tags[player]
		if not tag then
			tag = makeTag(player)
			tags[player] = tag
		end
		local blob = blobOf(player)
		tag.gui.Adornee = blob
		tag.gui.Enabled = blob ~= nil
		if blob then
			local diameter = blob:GetAttribute("Diameter") or Config.BLOB.MIN_SIZE
			tag.gui.StudsOffset = Vector3.new(0, diameter / 2 + 1.6, 0)
			tag.name.TextColor3 = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("Team") or ""] or Color3.new(1, 1, 1)
			local paint = player:GetAttribute("Paint") or 0
			tag.fill.Size = UDim2.fromScale(paint / Config.PAINT_MAX, 1)
			tag.fill.BackgroundColor3 = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("PaintColor") or ""]
				or Config.BUILDINGS.GREY
		end
	end
end

local function onStolen(thief: Player, victim: Player, amount: number, stomp: boolean)
	local localPlayer = Players.LocalPlayer
	local color = Config.PAINT_COLOR_BY_NAME[thief:GetAttribute("Team") or ""] or Color3.new(1, 1, 1)
	local victimBlob = blobOf(victim)
	local thiefBlob = blobOf(thief)
	if victimBlob then
		stealBurst(victimBlob, thiefBlob, color, amount)
	end
	local how = if stomp then "Stomp!" else "Bump!"
	if thief == localPlayer then
		Hud.announce(`{how} You stole {amount} paint from {victim.DisplayName}!`, color)
		if thiefBlob then
			Effects.popup(thiefBlob.Position + Vector3.new(0, 4, 0), `+{amount}`, color)
		end
		if Sounds.has("Steal") then
			Sounds.play("Steal")
		end
	elseif victim == localPlayer then
		Hud.announce(`{how} {thief.DisplayName} stole {amount} of your paint!`, color)
		hurt()
		Sounds.play(if Sounds.has("Stolen") then "Stolen" else "Land")
	elseif victimBlob then
		Sounds.play("Land", victimBlob.Position)
	end
end

function Pvp.start()
	local localPlayer = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Piros villanás a meglopottnak
	local screen = Instance.new("ScreenGui")
	screen.Name = "PvpFlash"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = screen
	hurtFrame = frame

	remotes:WaitForChild("Knockback").OnClientEvent:Connect(function(velocity: Vector3)
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping) -- a talajról így el tud pattanni
			root.AssemblyLinearVelocity = velocity
		end
	end)
	remotes:WaitForChild("Stolen").OnClientEvent:Connect(onStolen)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			updateTags()
		end
	end)
end

return Pvp
