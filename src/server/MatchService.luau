-- A meccs menete (PvP), körbe-körbe:
--   Intermission (Config.MATCH.INTERMISSION mp): a pálya szürke, lehet szaladgálni, festeni nem.
--   Playing (Config.MATCH.LENGTH mp): a csapatok festenek; a pont házanként 1 + kerületenként BONUS.
--   Ended (Config.MATCH.RESULTS mp): kihirdeti a győztest, utána minden visszaszürkül.
-- Az állapot a workspace attribútumaiban van (a kliens a kijelzőhöz olvassa):
--   MatchState, PhaseEndsAt (szerveridő), Winner, Score_<csapat>.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DistrictService = require(script.Parent.DistrictService)
local TeamService = require(script.Parent.TeamService)
local BlobCharacter = require(script.Parent.BlobCharacter)

local AnnounceRemote = ReplicatedStorage.Remotes.Announce

local MatchService = {}

local state = "Intermission"
local resetLevel: () -> () = function() end

function MatchService.isPlaying(): boolean
	return state == "Playing"
end

-- Üzenet mindenkinek (a kliens a képernyő tetején mutatja). colorName: a csapat színe, vagy nil.
function MatchService.announce(text: string, colorName: string?)
	AnnounceRemote:FireAllClients(text, colorName)
end

local function publishScores()
	for team, score in DistrictService.scores() do
		workspace:SetAttribute("Score_" .. team, score)
	end
end
MatchService.publishScores = publishScores

local function setPhase(name: string, seconds: number)
	state = name
	workspace:SetAttribute("MatchState", name)
	workspace:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + seconds)
end

-- Új meccs előtt: senkinél nincs festék, a saját pontok (ranglista) nulláról indulnak.
local function clearPlayers()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Paint", 0)
		player:SetAttribute("PaintColor", "")
		BlobCharacter.update(player)
		local score = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Score")
		if score then
			score.Value = 0
		end
	end
end

local function loop()
	local m = Config.MATCH
	while true do
		-- Várakozás: legalább egy játékos kell
		while #Players:GetPlayers() == 0 do
			task.wait(1)
		end
		resetLevel()
		DistrictService.reset()
		clearPlayers()
		workspace:SetAttribute("Winner", "")
		publishScores()
		setPhase("Intermission", m.INTERMISSION)
		task.wait(m.INTERMISSION)

		-- Új csapatok; akinek már van festéke (a szünetben felvette), annak az új csapata színére vált
		TeamService.shuffle()
		setPhase("Playing", m.LENGTH)
		MatchService.announce("Paint the town! Capture districts for your team!", nil)
		if m.LENGTH > 60 then
			task.wait(m.LENGTH - 60)
			MatchService.announce("1 minute left!", nil)
			task.wait(60)
		else
			task.wait(m.LENGTH)
		end

		publishScores()
		local winner, best, tie = "", -1, false
		for team, score in DistrictService.scores() do
			if score > best then
				winner, best, tie = team, score, false
			elseif score == best then
				tie = true
			end
		end
		if tie then
			winner = ""
		end
		workspace:SetAttribute("Winner", winner)
		setPhase("Ended", m.RESULTS)
		-- A győztest a kliens eredménytáblája mutatja (Results)
		task.wait(m.RESULTS)
	end
end

-- reset: a pálya visszaszürkítése (a PaintService adja).
function MatchService.start(reset: () -> ())
	resetLevel = reset
	DistrictService.setAnnouncer(MatchService.announce)
	task.spawn(loop)
end

return MatchService
