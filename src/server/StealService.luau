-- Festéklopás (PvP): ha két különböző csapatbeli paca összeér, az egyik elveszi a másik festékének egy részét.
--   Ráugrás: aki felülről, esés közben ér a másikra, a festéke Config.STEAL.STOMP részét viszi el.
--   Nekigurulás: különben az nyer, aki gyorsabban mozgott a másik felé (legalább MIN_SPEED-del),
--   és a festék Config.STEAL.RAM részét viszi el (legalább MIN egységet).
-- Akitől loptak, IMMUNITY másodpercig nem lehet újra meglopni, és kicsit hátrapattan. A lopott festék a lopó
-- csapatának színére vált, és nem mehet a maximum fölé. Erről is a szerver dönt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BlobCharacter = require(script.Parent.BlobCharacter)

local StolenRemote = ReplicatedStorage.Remotes.Stolen
local KnockbackRemote = ReplicatedStorage.Remotes.Knockback

local StealService = {}

local immuneUntil: { [Player]: number } = {}
local enabled: () -> boolean = function()
	return true
end

type Blob = { player: Player, root: BasePart, center: Vector3, radius: number, velocity: Vector3 }

local function blobOf(player: Player): Blob?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local blob = character and character:FindFirstChild("Blob") :: BasePart?
	if not root or not humanoid or humanoid.Health <= 0 or not blob then
		return nil
	end
	return {
		player = player,
		root = root,
		center = blob.Position,
		radius = (blob:GetAttribute("Diameter") or Config.BLOB.MIN_SIZE) / 2,
		velocity = root.AssemblyLinearVelocity,
	}
end

local function steal(thief: Blob, victim: Blob, share: number, stomp: boolean)
	local s = Config.STEAL
	local victimPaint = victim.player:GetAttribute("Paint") or 0
	local thiefPaint = thief.player:GetAttribute("Paint") or 0
	local amount = math.max(s.MIN, math.floor(victimPaint * share))
	amount = math.min(amount, victimPaint, Config.PAINT_MAX - thiefPaint)
	if amount <= 0 then
		return
	end
	victim.player:SetAttribute("Paint", victimPaint - amount)
	thief.player:SetAttribute("Paint", thiefPaint + amount)
	thief.player:SetAttribute("PaintColor", thief.player:GetAttribute("Team"))
	BlobCharacter.update(victim.player)
	BlobCharacter.update(thief.player)
	immuneUntil[victim.player] = os.clock() + s.IMMUNITY

	-- A vesztes hátrapattan (a karaktert a saját gépe mozgatja, ezért neki szólunk)
	local away = victim.center - thief.center
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
	KnockbackRemote:FireClient(victim.player, away * s.KNOCKBACK + Vector3.new(0, s.KNOCKBACK * 0.6, 0))
	StolenRemote:FireAllClients(thief.player, victim.player, amount, stomp)
end

local function check()
	if not enabled() then
		return
	end
	local blobs = {}
	for _, player in Players:GetPlayers() do
		local b = blobOf(player)
		if b and player:GetAttribute("Team") then
			table.insert(blobs, b)
		end
	end
	local now = os.clock()
	local s = Config.STEAL
	for i = 1, #blobs do
		for j = i + 1, #blobs do
			local a, b = blobs[i], blobs[j]
			if a.player:GetAttribute("Team") == b.player:GetAttribute("Team") then
				continue
			end
			local offset = b.center - a.center
			if offset.Magnitude > a.radius + b.radius + s.REACH then
				continue
			end
			-- Ki a lopó? Ráugrás: aki fent van és esik; különben aki gyorsabban ment a másik felé.
			local thief, victim, share, stomp = nil, nil, s.RAM, false
			if a.center.Y > b.center.Y + b.radius * 0.6 and a.velocity.Y < -s.STOMP_FALL_SPEED then
				thief, victim, share, stomp = a, b, s.STOMP, true
			elseif b.center.Y > a.center.Y + a.radius * 0.6 and b.velocity.Y < -s.STOMP_FALL_SPEED then
				thief, victim, share, stomp = b, a, s.STOMP, true
			else
				local dir = Vector3.new(offset.X, 0, offset.Z)
				if dir.Magnitude < 0.01 then
					continue
				end
				dir = dir.Unit
				local aToward = a.velocity:Dot(dir)
				local bToward = -b.velocity:Dot(dir)
				if aToward >= bToward and aToward > s.MIN_SPEED then
					thief, victim = a, b
				elseif bToward > aToward and bToward > s.MIN_SPEED then
					thief, victim = b, a
				end
			end
			if thief and victim and (immuneUntil[victim.player] or 0) < now then
				steal(thief, victim, share, stomp)
			end
		end
	end
end

-- isEnabled: csak meccs közben lehet lopni (a MatchService adja).
function StealService.start(isEnabled: () -> boolean)
	enabled = isEnabled
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.05 then
			elapsed = 0
			check()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		immuneUntil[player] = nil
	end)
end

return StealService
