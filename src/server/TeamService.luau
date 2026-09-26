-- Csapatok: a Config.TEAMS szerint (alapból Piros és Kék). A belépő játékos a legkisebb létszámú csapatba kerül;
-- meccs elején a MatchService újraoszthatja őket. A játékos csapata a Roblox Teams szolgáltatásban is látszik
-- (ranglista), és a "Team" attribútumban (a csapat festékszínének neve).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)
local BlobCharacter = require(script.Parent.BlobCharacter)

local TeamService = {}

local teamObjects: { [string]: Team } = {}

local function members(name: string): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Team") == name then
			count += 1
		end
	end
	return count
end

function TeamService.setTeam(player: Player, name: string)
	player:SetAttribute("Team", name)
	player.Team = teamObjects[name]
	-- A festék mindig a csapat színe: ha van festéke, az is átszíneződik
	if (player:GetAttribute("Paint") or 0) > 0 then
		player:SetAttribute("PaintColor", name)
	end
	BlobCharacter.update(player)
end

-- A legkisebb csapatba tesz (egyenlőségnél véletlenszerűen).
function TeamService.assign(player: Player)
	local best, bestCount = {}, math.huge
	for _, team in Config.TEAMS do
		local count = members(team.name)
		if player:GetAttribute("Team") == team.name then
			count -= 1 -- saját magát ne számolja
		end
		if count < bestCount then
			best, bestCount = { team.name }, count
		elseif count == bestCount then
			table.insert(best, team.name)
		end
	end
	TeamService.setTeam(player, best[math.random(1, #best)])
end

-- Mindenkit újraoszt kiegyensúlyozottan (meccs elején).
function TeamService.shuffle()
	local players = Players:GetPlayers()
	for i = #players, 2, -1 do
		local j = math.random(1, i)
		players[i], players[j] = players[j], players[i]
	end
	for i, player in players do
		local team = Config.TEAMS[(i - 1) % #Config.TEAMS + 1]
		TeamService.setTeam(player, team.name)
	end
end

function TeamService.colorOf(name: string?): Color3?
	return name and Config.PAINT_COLOR_BY_NAME[name]
end

function TeamService.start()
	for _, team in Config.TEAMS do
		local t = Instance.new("Team")
		t.Name = team.name
		t.TeamColor = BrickColor.new(Config.PAINT_COLOR_BY_NAME[team.name])
		t.AutoAssignable = false
		t.Parent = Teams
		teamObjects[team.name] = t
	end
	Players.PlayerAdded:Connect(TeamService.assign)
	for _, player in Players:GetPlayers() do
		TeamService.assign(player)
	end
end

return TeamService
