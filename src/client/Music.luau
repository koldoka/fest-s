-- Zenei rétegek: minél színesebb a város, annál több hangszer szól.
-- A négy sáv (Config.MUSIC.LAYERS) egyforma hosszú és együtt indul; mindegyik mindig megy, csak a hangerejük
-- változik: az alap mindig hallható, a többi akkor erősödik fel, amikor a festett házak aránya eléri a
-- réteg "from" értékét. A meccs végén (eredmény) minden réteg szól. A sávokat időnként összeigazítja,
-- hogy ne csússzanak el egymástól.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Music = {}

type Layer = { sound: Sound, from: number, volume: number }

local function paintedShare(): number
	local total = workspace:GetAttribute("BuildingCount") or 0
	local painted = workspace:GetAttribute("PaintedCount") or 0
	return if total > 0 then painted / total else 0
end

function Music.start()
	local m = Config.MUSIC
	local layers: { Layer } = {}
	for _, info in m.LAYERS do
		if info.id == "" then
			return -- amíg nincs mind feltöltve, nincs zene (a sávok csak együtt szólnak jól)
		end
		local sound = Instance.new("Sound")
		sound.Name = "Music" .. info.name
		sound.SoundId = info.id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		table.insert(layers, { sound = sound, from = info.from, volume = info.volume })
	end
	if #layers == 0 then
		return
	end

	task.spawn(function()
		local sounds = {}
		for _, layer in layers do
			table.insert(sounds, layer.sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		for _, layer in layers do
			layer.sound:Play()
		end

		local master = layers[1].sound
		local syncTimer = 0
		RunService.Heartbeat:Connect(function(dt)
			local share = paintedShare()
			local ended = workspace:GetAttribute("MatchState") == "Ended"
			local step = dt / math.max(0.1, m.FADE)
			for _, layer in layers do
				local on = ended or share >= layer.from
				local target = if on then m.VOLUME * layer.volume else 0
				local volume = layer.sound.Volume
				if volume < target then
					layer.sound.Volume = math.min(target, volume + step * m.VOLUME)
				elseif volume > target then
					layer.sound.Volume = math.max(target, volume - step * m.VOLUME)
				end
			end
			-- Összeigazítás a hurok belsejében (a hurok határán a pozíció átugrik, ott nem)
			syncTimer += dt
			if syncTimer >= 2 then
				syncTimer = 0
				local position = master.TimePosition
				local length = master.TimeLength
				if length > 0 and position > 0.5 and position < length - 0.5 then
					for i = 2, #layers do
						local sound = layers[i].sound
						if math.abs(sound.TimePosition - position) > 0.06 then
							sound.TimePosition = position
						end
					end
				end
			end
		end)
	end)
end

return Music
