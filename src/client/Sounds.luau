-- Hangok lejátszása. Az azonosítók a Config.SOUNDS-ban vannak; amíg üresek, nem szól semmi.
--   Sounds.play("Jump")                -> mindenhol ugyanolyan hangos (a saját paca hangjai)
--   Sounds.play("Paint", position)     -> térhatású, a távolabbi hangok halkabbak
-- A gurulás ismétlődő hangja minden pacán szól, a sebességgel hangosodik és magasodik.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

local rng = Random.new()

local function pickId(name: string): (string?, any)
	local info = Config.SOUNDS[name]
	if not info or #info.ids == 0 then
		return nil, nil
	end
	return info.ids[rng:NextInteger(1, #info.ids)], info
end

-- Van-e feltöltött hang ezen a néven.
function Sounds.has(name: string): boolean
	local info = Config.SOUNDS[name]
	return info ~= nil and #info.ids > 0
end

function Sounds.play(name: string, position: Vector3?)
	local id, info = pickId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = info.volume
	if info.vary then
		sound.PlaybackSpeed = rng:NextNumber(0.9, 1.1)
	end

	if position then
		-- Térhatású hang: egy láthatatlan pontra tesszük a világban.
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 200
		sound.Parent = attachment
		sound:Play()
		Debris:AddItem(attachment, 3)
	else
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 3)
	end
end

-- Gurulás: minden pacán egy ismétlődő hang, a hangerő és a hangmagasság a sebességtől függ.
local function updateRolling()
	local info = Config.SOUNDS.Roll
	if #info.ids == 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local blob = character and character:FindFirstChild("Blob") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not blob or not humanoid or not root then
			continue
		end
		local sound = blob:FindFirstChild("RollSound") :: Sound?
		if not sound then
			local newSound = Instance.new("Sound")
			newSound.Name = "RollSound"
			newSound.SoundId = info.ids[1]
			newSound.Looped = true
			newSound.Volume = 0
			newSound.RollOffMinDistance = 10
			newSound.RollOffMaxDistance = 80
			newSound.Parent = blob
			newSound:Play()
			sound = newSound
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local ratio = math.clamp(speed / Config.WALK_SPEED, 0, 1)
		local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
		local target = if onGround then info.volume * ratio else 0
		(sound :: Sound).Volume += (target - sound.Volume) * 0.2 -- lágy átmenet
		(sound :: Sound).PlaybackSpeed = 0.8 + 0.4 * ratio
	end
end

-- A saját paca hangjai: ugrás, földet érés, festékfelvétel.
function Sounds.start()
	local player = Players.LocalPlayer

	-- Feltöltés: nőtt a festék, vagy színt váltott. A kettő egyszerre is jöhet, ezért csak egyszer szól.
	local lastPaint = player:GetAttribute("Paint") or 0
	local lastRefill = 0
	local function refilled()
		if os.clock() - lastRefill > 0.3 then
			lastRefill = os.clock()
			Sounds.play("Refill")
		end
	end
	player:GetAttributeChangedSignal("Paint"):Connect(function()
		local paint = player:GetAttribute("Paint") or 0
		if paint > lastPaint then
			refilled()
		end
		lastPaint = paint
	end)
	player:GetAttributeChangedSignal("PaintColor"):Connect(function()
		if (player:GetAttribute("PaintColor") or "") ~= "" then
			refilled()
		end
	end)

	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				Sounds.play("Jump")
			elseif new == Enum.HumanoidStateType.Landed then
				Sounds.play("Land")
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService.Heartbeat:Connect(updateRolling)
end

return Sounds
