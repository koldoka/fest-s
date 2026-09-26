-- Festés-effektek: fröccsenő festékcseppek, egy rövid felvillanás a befestett épületen, placcs hang.
-- Friss festék (a ház Config.PAINT_PROTECT mp-ig nem festhető át): "WET PAINT" tábla fogyó sávval az ajtón,
-- a falakon lassan lefolyó festékcseppek, és a fal fényes, majd fokozatosan "megszárad".

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

-- Friss festék jelzése egy házon, amíg védett (Config.PAINT_PROTECT mp).
local wetFolder: Folder? = nil
local wetRuns: { [BasePart]: number } = {} -- házanként a legutóbbi jelzés azonosítója

local function wetPart(props: { [string]: any }): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = wetFolder
	return part
end

-- A ház egy oldala: kifelé mutató normális (világ), a fal síkjának középpontja, szélessége.
type Face = { normal: Vector3, along: Vector3, center: Vector3, width: number }
local function facesOf(building: BasePart): { Face }
	local cf, half = building.CFrame, building.Size / 2
	local list = {}
	for _, axis in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local depth = math.abs(axis:Dot(half))
		local alongLocal = Vector3.yAxis:Cross(axis)
		table.insert(list, {
			normal = cf:VectorToWorldSpace(axis),
			along = cf:VectorToWorldSpace(alongLocal),
			center = cf:PointToWorldSpace(axis * depth),
			width = math.abs(alongLocal:Dot(building.Size)),
		})
	end
	return list
end

-- "WET PAINT" jelzőtábla: az ajtóra ragasztva (ha nincs ajtó, a leghosszabb fal aljára).
local function wetSign(building: BasePart, color: Color3, duration: number): BasePart
	local door: BasePart? = nil
	for _, child in building:GetDescendants() do
		if child:IsA("BasePart") and child.Name == "Door" and (not door or child.Position.Y < door.Position.Y) then
			door = child
		end
	end
	local cf: CFrame
	if door then
		-- A tábla az ajtó elé: a normális a ház közepétől az ajtó felé eső tengely
		local localPos = building.CFrame:PointToObjectSpace(door.Position)
		local half = building.Size / 2
		local axis = if math.abs(localPos.X) / half.X > math.abs(localPos.Z) / half.Z
			then Vector3.xAxis * math.sign(localPos.X)
			else Vector3.zAxis * math.sign(localPos.Z)
		local normal = building.CFrame:VectorToWorldSpace(axis)
		local thickness = math.min(door.Size.X, door.Size.Z)
		local pos = door.Position + normal * (thickness / 2 + 0.04) + Vector3.new(0, 0.7, 0)
		cf = CFrame.lookAt(pos, pos + normal)
	else
		local best: Face? = nil
		for _, face in facesOf(building) do
			if not best or face.width > best.width then
				best = face
			end
		end
		local face = best :: Face
		local pos = face.center + face.normal * 0.2 - Vector3.new(0, building.Size.Y / 2 - 3, 0)
		cf = CFrame.lookAt(pos, pos + face.normal)
	end

	local sign = wetPart({
		Name = "WetPaintSign",
		Size = Vector3.new(2.4, 1.3, 0.06),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(Random.new():NextNumber(-5, 5))), -- kicsit ferdén felragasztva
		Color = Color3.fromRGB(250, 247, 238),
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.6
	gui.Parent = sign
	local stroke = Instance.new("Frame")
	stroke.Size = UDim2.fromScale(1, 1)
	stroke.BackgroundTransparency = 1
	stroke.Parent = gui
	local border = Instance.new("UIStroke")
	border.Color = color
	border.Thickness = 5
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = stroke
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromScale(0.07, 0.08)
	text.Size = UDim2.fromScale(0.86, 0.58)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.3)
	text.Text = "WET PAINT"
	text.Parent = gui
	local fill = Instance.new("Frame")
	fill.Position = UDim2.fromScale(0.1, 0.74)
	fill.Size = UDim2.fromScale(0.8, 0.14)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color
	fill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = fill
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 0.14) })
		:Play()
	return sign
end

-- Lefolyó festékcseppek a falon: vékony csík, ami lassan lefelé nő, a végén egy kerek csepp.
local function wetDrips(building: BasePart, color: Color3, duration: number): { BasePart }
	local rng = Random.new()
	local parts = {}
	local faces = facesOf(building)
	local floors = math.max(1, math.floor(building.Size.Y / Config.BUILDINGS.FLOOR_HEIGHT + 0.5))
	local perimeter = 2 * (building.Size.X + building.Size.Z)
	local count = math.clamp(math.floor(perimeter / 5), 6, 16)
	local dripColor = color:Lerp(Color3.new(0, 0, 0), 0.12)
	local bottom = building.Position.Y - building.Size.Y / 2 + 1.3 -- a lábazat fölött
	for _ = 1, count do
		-- Oldal a szélesség arányában
		local pick = rng:NextNumber() * perimeter / 2
		local face = faces[#faces]
		for _, f in faces do
			pick -= f.width
			if pick <= 0 then
				face = f
				break
			end
		end
		if face.width < 3 then
			continue
		end
		local lateral = rng:NextNumber(-face.width / 2 + 1.2, face.width / 2 - 1.2)
		-- Egy emelet tetejéről (a díszsáv, ill. az eresz alól) indul
		local floor = rng:NextInteger(1, floors)
		local topY = building.Position.Y - building.Size.Y / 2 + floor * Config.BUILDINGS.FLOOR_HEIGHT - 0.4
		local length = math.min(rng:NextNumber(1.2, 3.2), topY - bottom)
		if length < 0.6 then
			continue
		end
		local width = rng:NextNumber(0.16, 0.26)
		local origin = face.center + face.along * lateral + face.normal * 0.05
		origin = Vector3.new(origin.X, topY, origin.Z)
		local frame = CFrame.lookAt(origin, origin + face.normal)
		local streak = wetPart({
			Name = "WetDrip",
			Size = Vector3.new(width, 0.05, 0.04),
			CFrame = frame * CFrame.new(0, -0.025, 0),
			Color = dripColor,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.25,
		})
		local bead = wetPart({
			Name = "WetDrop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (width + 0.12),
			CFrame = frame,
			Color = dripColor,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.25,
		})
		table.insert(parts, streak)
		table.insert(parts, bead)
		-- Lassan lefolyik (a vége felé lassul), eltolt kezdéssel
		local info = TweenInfo.new(
			rng:NextNumber(1.4, 2.8),
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			rng:NextNumber(0, 1.5)
		)
		TweenService:Create(streak, info, {
			Size = Vector3.new(width, length, 0.04),
			CFrame = frame * CFrame.new(0, -length / 2, 0),
		}):Play()
		TweenService:Create(bead, info, { CFrame = frame * CFrame.new(0, -length, 0) }):Play()
	end
	return parts
end

-- Fényes, nedves fal: a ház teste (és a felső emelete, oromfala) sima, csillogó felületet kap, ami
-- fokozatosan megszárad; a végén visszakapja az eredeti anyagát (vakolat, tégla…).
local GLOSSY_ROLES = { Tier = true, Gable = true }
local function wetGloss(building: BasePart, duration: number): () -> ()
	local saved = {}
	local targets = { building }
	for _, child in building:GetDescendants() do
		if child:IsA("BasePart") and GLOSSY_ROLES[child:GetAttribute("Role")] then
			table.insert(targets, child)
		end
	end
	for _, part in targets do
		table.insert(saved, { part = part, material = part.Material, reflectance = part.Reflectance })
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0.4
		TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Reflectance = 0.05,
		}):Play()
	end
	return function()
		for _, entry in saved do
			entry.part.Material = entry.material
			entry.part.Reflectance = entry.reflectance
		end
	end
end

local wetRestore: { [BasePart]: () -> () } = {}

local function wetPaint(building: BasePart, color: Color3)
	local duration = Config.PAINT_PROTECT
	if duration <= 0 then
		return
	end
	if not wetFolder then
		local folder = Instance.new("Folder")
		folder.Name = "WetPaint"
		folder.Parent = workspace
		wetFolder = folder
	end
	-- Ha már nedves volt (ritka), az előzőt visszaállítjuk
	local previousRestore = wetRestore[building]
	if previousRestore then
		previousRestore()
	end
	local run = (wetRuns[building] or 0) + 1
	wetRuns[building] = run

	local sign = wetSign(building, color, duration)
	local drips = wetDrips(building, color, duration)
	local restore = wetGloss(building, duration)
	wetRestore[building] = restore

	task.delay(duration, function()
		if wetRuns[building] == run then
			restore()
			wetRestore[building] = nil
			wetRuns[building] = nil
		end
		-- Megszáradt: a tábla és a cseppek elhalványulnak
		local fadeInfo = TweenInfo.new(0.6)
		for _, part in drips do
			TweenService:Create(part, fadeInfo, { Transparency = 1 }):Play()
			Debris:AddItem(part, 0.7)
		end
		TweenService:Create(sign, fadeInfo, { Transparency = 1 }):Play()
		local gui = sign:FindFirstChildOfClass("SurfaceGui")
		if gui then
			gui.Enabled = false
		end
		Debris:AddItem(sign, 0.7)
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
