-- Megvárja, amíg a pálya teljesen megérkezik a kliensre. A szerver a "LevelInstances" attribútumban adja meg,
-- hány elemből áll a pálya; a 11 000 elem több képkocka alatt érkezik meg, és ha egy modul túl korán néz
-- körül, csak egy részét látja (így maradt ki korábban a legtöbb fa és a tó).

local LevelReady = {}

local ready: Instance? = nil

function LevelReady.wait(timeout: number?): Instance
	if ready then
		return ready
	end
	local level = workspace:WaitForChild("Level")
	local deadline = os.clock() + (timeout or 30)
	while os.clock() < deadline do
		local expected = workspace:GetAttribute("LevelInstances") or 0
		if expected > 0 and #level:GetDescendants() >= expected * 0.98 then
			break
		end
		task.wait(0.25)
	end
	ready = level
	return level
end

return LevelReady
