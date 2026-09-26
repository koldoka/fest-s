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

Hud.start()
Effects.start()
BlobAnimator.start()
Sounds.start()
Trails.start()
MapView.start()
Pvp.start()
Districts.start()
Results.start()
Decor.start()
Music.start()
Ambient.start()
