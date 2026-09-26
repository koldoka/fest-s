-- Csalás elleni alapvédelem. A saját karaktert a kliens mozgatja, ezért a szerver csak utólag látja,
-- hová ment; ha a mozgás lehetetlen, visszahúzza az utolsó rendben lévő helyére:
--   Túl gyors (sebességcsalás) vagy teleportálás: az elmozdulás több, mint amennyit a paca a megengedett
--   sebességgel (Config.WALK_SPEED * SPEED_FACTOR) megtehet, egy kis tűréssel (késés miatt).
--   Repülés: a paca sokáig magasan van a talaj fölött, és nem esik.
-- Kivétel: a hátrapattanás (festéklopás) és az újraéledés; ezeket a többi szolgáltatás jelzi (allow).
-- Sok szabálysértés rövid időn belül: kirúgás (Config.ANTICHEAT.KICK_STRIKES; 0 = soha).
-- A festékről és a pontokról amúgy is a szerver dönt, és a kliens semmit nem küld a szervernek, így a
-- mozgás az egyetlen, amivel csalni lehet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local AntiCheatService = {}

type Track = {
	root: BasePart,
	last: Vector3, -- az utolsó ellenőrzött hely
	good: CFrame, -- az utolsó rendben lévő hely (ide húzzuk vissza)
	grounded: CFrame, -- az utolsó hely, ahol a talajon volt (repülésnél ide)
	airTime: number, -- mióta van magasan, esés nélkül
	allowUntil: number, -- eddig nagyobb sebesség is megengedett (hátrapattanás)
	strikes: { number }, -- a szabálysértések időpontjai
}

local tracks: { [Player]: Track } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Egy ideig nagyobb elmozdulás is rendben van (pl. hátrapattanás után).
function AntiCheatService.allow(player: Player, seconds: number)
	local track = tracks[player]
	if track then
		track.allowUntil = math.max(track.allowUntil, os.clock() + seconds)
	end
end

local function strike(player: Player, track: Track, reason: string, backTo: CFrame)
	local c = Config.ANTICHEAT
	local now = os.clock()
	table.insert(track.strikes, now)
	while track.strikes[1] and now - track.strikes[1] > c.STRIKE_WINDOW do
		table.remove(track.strikes, 1)
	end
	track.root.AssemblyLinearVelocity = Vector3.zero
	track.root.CFrame = backTo
	track.last = backTo.Position
	track.good = backTo
	track.airTime = 0
	if c.LOG then
		warn(`[Paint Pop] Anti-cheat: {player.Name} {reason} ({#track.strikes} in {c.STRIKE_WINDOW}s)`)
	end
	if c.KICK_STRIKES > 0 and #track.strikes >= c.KICK_STRIKES then
		player:Kick("Unusual movement detected. Please rejoin.")
	end
end

local function startTracking(player: Player, character: Model)
	local previous = tracks[player]
	tracks[player] = nil -- amíg az új karakter nincs meg, nem ellenőrzünk
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root or character.Parent == nil then
		return
	end
	tracks[player] = {
		root = root,
		last = root.Position,
		good = root.CFrame,
		grounded = root.CFrame,
		airTime = 0,
		allowUntil = os.clock() + 3, -- az éledés utáni első pillanatokban még helyére kerülhet
		strikes = if previous then previous.strikes else {},
	}
end

local function check(player: Player, track: Track, dt: number)
	local c = Config.ANTICHEAT
	local root = track.root
	if root.Parent == nil then
		return
	end
	local position = root.Position
	local delta = position - track.last
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local allowed = Config.WALK_SPEED * c.SPEED_FACTOR
	if os.clock() < track.allowUntil then
		allowed = math.max(allowed, Config.STEAL.KNOCKBACK * 1.5)
	end
	-- Vízszintesen túl messzire jutott (sebesség vagy teleport); felfelé túl gyorsan (ugrás-csalás)
	if horizontal > allowed * dt + c.TOLERANCE then
		strike(player, track, string.format("moved %.1f studs in %.2fs", horizontal, dt), track.good)
		return
	end
	if delta.Y > c.MAX_RISE_SPEED * dt + c.TOLERANCE then
		strike(player, track, string.format("rose %.1f studs in %.2fs", delta.Y, dt), track.good)
		return
	end

	-- Repülés: mennyire van a talaj fölött, és esik-e
	rayParams.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = workspace:Raycast(position, Vector3.new(0, -500, 0), rayParams)
	local height = if hit then position.Y - hit.Position.Y else math.huge
	if height < 6 then
		track.grounded = root.CFrame
		track.airTime = 0
	elseif delta.Y > -0.5 then
		track.airTime += dt
		if track.airTime > c.MAX_AIR_TIME then
			strike(player, track, string.format("floated %.0f studs high", height), track.grounded)
			return
		end
	else
		track.airTime = 0
	end

	track.last = position
	track.good = root.CFrame
end

function AntiCheatService.start()
	if not Config.ANTICHEAT.ENABLED then
		return
	end
	local function setup(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(startTracking, player, character)
		end)
		if player.Character then
			task.spawn(startTracking, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.ANTICHEAT.INTERVAL then
			return
		end
		local step = elapsed
		elapsed = 0
		for player, track in tracks do
			check(player, track, step)
		end
	end)
end

return AntiCheatService
