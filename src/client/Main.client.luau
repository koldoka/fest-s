-- A kliens belépési pontja.

-- Időmérés: mikor indulnak a kliens szkriptjei (a time() a kliens indulása óta eltelt másodperc).
-- Ha ez 10 mp körül van, a Studio kapcsolódása lassú, nem a játék (lásd README).
print(string.format("[Paint Pop] Client scripts started at %.2f s", time()))

local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local BlobAnimator = require(script.Parent.BlobAnimator)
local Sounds = require(script.Parent.Sounds)
local Trails = require(script.Parent.Trails)
local MapView = require(script.Parent.MapView)
local Pvp = require(script.Parent.Pvp)
local Districts = require(script.Parent.Districts)
local Results = require(script.Parent.Results)
local Decor = require(script.Parent.Decor)
local Music = require(script.Parent.Music)
local Ambient = require(script.Parent.Ambient)

-- Minden modul külön szálon, védetten indul: ha az egyik hibára fut, a többi ettől még működik,
-- a hiba pedig a modul nevével együtt megjelenik az Output ablakban.
local modules = {
	{ "Hud", Hud },
	{ "Effects", Effects },
	{ "BlobAnimator", BlobAnimator },
	{ "Sounds", Sounds },
	{ "Trails", Trails },
	{ "MapView", MapView },
	{ "Pvp", Pvp },
	{ "Districts", Districts },
	{ "Results", Results },
	{ "Decor", Decor },
	{ "Music", Music },
	{ "Ambient", Ambient },
}
for _, entry in modules do
	local name, module = entry[1], entry[2]
	task.spawn(function()
		local ok, err = xpcall(module.start, debug.traceback)
		if not ok then
			warn(`[Paint Pop] {name} failed to start: {err}`)
		end
	end)
end
