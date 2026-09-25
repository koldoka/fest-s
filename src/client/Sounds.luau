-- Hangok lejátszása. Az azonosítók a Config.SOUNDS-ban vannak; amíg üresek, nem szól semmi.
--   Sounds.play("Jump")                -> mindenhol ugyanolyan hangos (a saját paca hangjai)
--   Sounds.play("Splat", position)     -> térhatású, a távolabbi hangok halkabbak

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

local rng = Random.new()

function Sounds.play(name: string, position: Vector3?)
	local info = Config.SOUNDS[name]
	if not info or info.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = info.id
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

-- A saját paca hangjai: ugrás, földet érés, festékfelvétel; és a város elkészülte.
function Sounds.start()
	local player = game:GetService("Players").LocalPlayer

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

	local wasDone = false
	workspace:GetAttributeChangedSignal("PaintedCount"):Connect(function()
		local painted = workspace:GetAttribute("PaintedCount") or 0
		local total = workspace:GetAttribute("BuildingCount") or 0
		local done = total > 0 and painted >= total
		if done and not wasDone then
			Sounds.play("CityDone")
		end
		wasDone = done
	end)
end

return Sounds
