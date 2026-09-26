-- Kerületek (PvP): a pálya kerületekre oszlik (Level.districts), minden ház egy kerülethez tartozik.
--   Gazda: az a csapat, amelyiknek a kerületben a legtöbb háza van a saját színében.
--   Teljes elfoglalás: ha egy csapat a kerület MINDEN házát befestette, a kerület Config.DISTRICTS.LOCK_TIME
--   másodpercre lezárul: addig senki nem festhet át benne semmit.
-- Az állapot a ReplicatedStorage.Districts mappában van (a kliens a térképhez és a kijelzőhöz olvassa):
--   minden kerület egy Folder, attribútumai: Total, Owner ("" = senki), LockedUntil (szerveridő), Count_<csapat>;
--   a gyerekei (Rect) a kerület téglalapjai (Min, Max: Vector2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DistrictService = {}

type District = {
	name: string,
	rects: { { number } },
	folder: Folder,
	total: number,
	counts: { [string]: number },
	owner: string,
	lockedUntil: number,
}

local districts: { [string]: District } = {}
-- Csapatonként a színükben álló házak és tárgyak festékértéke (ebből jön a csapatpont)
local values: { [string]: number } = {}
local order: { District } = {}
local onAnnounce: ((string, string?) -> ())? = nil

local function contains(rect: { number }, x: number, z: number): boolean
	return x >= math.min(rect[1], rect[3])
		and x <= math.max(rect[1], rect[3])
		and z >= math.min(rect[2], rect[4])
		and z <= math.max(rect[2], rect[4])
end

local function districtAt(x: number, z: number): District?
	for _, d in order do
		for _, rect in d.rects do
			if contains(rect, x, z) then
				return d
			end
		end
	end
	-- Ha egyik téglalapba sem esik, a legközelebbi kerület
	local best, bestDistance = nil, math.huge
	for _, d in order do
		for _, rect in d.rects do
			local cx, cz = (rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2
			local distance = (cx - x) ^ 2 + (cz - z) ^ 2
			if distance < bestDistance then
				best, bestDistance = d, distance
			end
		end
	end
	return best
end

local function publish(d: District)
	d.folder:SetAttribute("Total", d.total)
	d.folder:SetAttribute("Owner", d.owner)
	d.folder:SetAttribute("LockedUntil", d.lockedUntil)
	for _, team in Config.TEAMS do
		d.folder:SetAttribute("Count_" .. team.name, d.counts[team.name] or 0)
	end
end

-- A pálya kerületeinek beállítása és a házak besorolása.
function DistrictService.setup(buildings: Folder, list: { { name: string, rects: { { number } } } })
	local root = ReplicatedStorage:FindFirstChild("Districts")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "Districts"
	districts, order = {}, {}
	for _, info in list do
		local folder = Instance.new("Folder")
		folder.Name = info.name
		for _, rect in info.rects do
			local r = Instance.new("Folder")
			r.Name = "Rect"
			r:SetAttribute("Min", Vector2.new(math.min(rect[1], rect[3]), math.min(rect[2], rect[4])))
			r:SetAttribute("Max", Vector2.new(math.max(rect[1], rect[3]), math.max(rect[2], rect[4])))
			r.Parent = folder
		end
		folder.Parent = root
		local d: District = {
			name = info.name,
			rects = info.rects,
			folder = folder,
			total = 0,
			counts = {},
			owner = "",
			lockedUntil = 0,
		}
		districts[info.name] = d
		table.insert(order, d)
	end
	for _, building in buildings:GetChildren() do
		local d = districtAt(building.Position.X, building.Position.Z)
		if d then
			building:SetAttribute("District", d.name)
			d.total += 1
		end
	end
	for _, d in order do
		publish(d)
	end
	root.Parent = ReplicatedStorage
end

function DistrictService.setAnnouncer(fn: (string, string?) -> ())
	onAnnounce = fn
end

function DistrictService.isLocked(building: BasePart): boolean
	local d = districts[building:GetAttribute("District") or ""]
	return d ~= nil and d.lockedUntil > workspace:GetServerTimeNow()
end

-- Egy ház színe megváltozott (oldName -> newName; "" = festetlen).
function DistrictService.onPainted(building: BasePart, oldName: string, newName: string)
	local d = districts[building:GetAttribute("District") or ""]
	local value = building:GetAttribute("PaintCost") or Config.PAINT_COST.SMALL
	if oldName ~= "" then
		values[oldName] = (values[oldName] or 0) - value
	end
	if newName ~= "" then
		values[newName] = (values[newName] or 0) + value
	end
	if not d then
		return
	end
	if oldName ~= "" then
		d.counts[oldName] = math.max(0, (d.counts[oldName] or 0) - 1)
	end
	if newName ~= "" then
		d.counts[newName] = (d.counts[newName] or 0) + 1
	end
	-- Gazda: a legtöbb ház; döntetlennél marad az eddigi
	local best, bestCount = d.owner, if d.owner ~= "" then d.counts[d.owner] or 0 else 0
	for team, count in d.counts do
		if count > bestCount then
			best, bestCount = team, count
		end
	end
	if bestCount == 0 then
		best = ""
	end
	if best ~= d.owner and best ~= "" and onAnnounce then
		onAnnounce(`{best} took the lead in {d.name}!`, best)
	end
	d.owner = best
	-- Teljes elfoglalás: lezárás egy időre
	if newName ~= "" and d.total > 0 and (d.counts[newName] or 0) >= d.total then
		local lockTime = Config.DISTRICTS.LOCK_TIME
		d.lockedUntil = workspace:GetServerTimeNow() + lockTime
		if onAnnounce then
			onAnnounce(`{newName} captured {d.name}! Locked for {lockTime} seconds.`, newName)
		end
		local until_ = d.lockedUntil
		task.delay(lockTime, function()
			if d.lockedUntil == until_ then
				d.lockedUntil = 0
				publish(d)
				if onAnnounce then
					onAnnounce(`{d.name} is open again!`, nil)
				end
			end
		end)
	end
	publish(d)
end

-- Egy tárgy színe megváltozott: a csapatpontba a festékértéke számít.
function DistrictService.onPropPainted(oldName: string, newName: string)
	local value = Config.PAINT_COST.PROP
	if oldName ~= "" then
		values[oldName] = (values[oldName] or 0) - value
	end
	if newName ~= "" then
		values[newName] = (values[newName] or 0) + value
	end
end

-- Csapatpontok: a csapat színében álló házak és tárgyak festékértéke (ház 1/3/4, tárgy 1)
-- + kerületenként (ahol a csapat a gazda) Config.DISTRICTS.BONUS.
function DistrictService.scores(): { [string]: number }
	local scores = {}
	for _, team in Config.TEAMS do
		scores[team.name] = math.max(0, values[team.name] or 0)
	end
	for _, d in order do
		if d.owner ~= "" and scores[d.owner] then
			scores[d.owner] += Config.DISTRICTS.BONUS
		end
	end
	return scores
end

function DistrictService.reset()
	values = {}
	for _, d in order do
		d.counts = {}
		d.owner = ""
		d.lockedUntil = 0
		publish(d)
	end
end

return DistrictService
