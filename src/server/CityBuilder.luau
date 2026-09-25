-- A szürke város felépítése: aszfalt, háztömbök járdával, épületek (ablakokkal, ajtóval, tetőperemmel),
-- festéktartályok a kereszteződésekben.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CityBuilder = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function greyShade(rng: Random): Color3
	local c = Config.CITY
	local offset = rng:NextInteger(-c.GREY_VARIANCE, c.GREY_VARIANCE) / 255
	return Color3.new(
		math.clamp(c.GREY.R + offset, 0, 1),
		math.clamp(c.GREY.G + offset, 0, 1),
		math.clamp(c.GREY.B + offset, 0, 1)
	)
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Egy épületrészlet: nem ütközik, nem festhető közvetlenül, a festéskor a PaintService színezi át.
local function makeDetail(building: BasePart, role: string, size: Vector3, offset: Vector3, color: Color3)
	local detail = makePart({
		Name = role,
		Size = size,
		CFrame = building.CFrame * CFrame.new(offset),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = role == "Trim", -- a tetőperemre rá lehet állni
		CanQuery = false,
		CanTouch = false,
	})
	detail:SetAttribute("Role", role)
	detail:SetAttribute("BaseColor", color)
	detail.Parent = building
end

-- Ablaksávok emeletenként mind a négy oldalon, egy ajtó a földszinten, perem a tetőn.
local function addDetails(building: BasePart, rng: Random)
	local c = Config.CITY
	local size = building.Size
	local half = size / 2
	local grey = building.Color

	-- A földszint az ajtóé, onnan felfelé emeletenként egy ablaksáv, a tető alatt kis hellyel.
	local bandY = -half.Y + c.FLOOR_HEIGHT + c.WINDOW_BAND_HEIGHT / 2 + 1
	while bandY + c.WINDOW_BAND_HEIGHT / 2 < half.Y - 1.5 do
		for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			local bandSize = if dir.X ~= 0
				then Vector3.new(0.2, c.WINDOW_BAND_HEIGHT, size.Z - 2)
				else Vector3.new(size.X - 2, c.WINDOW_BAND_HEIGHT, 0.2)
			local offset = Vector3.new(dir.X * (half.X + 0.1), bandY, dir.Z * (half.Z + 0.1))
			makeDetail(building, "Window", bandSize, offset, darker(grey, 0.3))
		end
		bandY += c.FLOOR_HEIGHT
	end

	local doorDir = ({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis })[rng:NextInteger(1, 4)]
	local doorSize = if doorDir.X ~= 0
		then Vector3.new(0.3, c.DOOR_SIZE.Y, c.DOOR_SIZE.X)
		else Vector3.new(c.DOOR_SIZE.X, c.DOOR_SIZE.Y, 0.3)
	local doorOffset =
		Vector3.new(doorDir.X * (half.X + 0.15), -half.Y + c.DOOR_SIZE.Y / 2, doorDir.Z * (half.Z + 0.15))
	makeDetail(building, "Door", doorSize, doorOffset, darker(grey, 0.45))

	makeDetail(
		building,
		"Trim",
		Vector3.new(size.X + 0.6, 0.8, size.Z + 0.6),
		Vector3.new(0, half.Y + 0.4, 0),
		darker(grey, 0.15)
	)
end

local function makePaintTank(position: Vector3, paint: { name: string, color: Color3 }, parent: Instance)
	-- Álló henger: a Roblox hengerének tengelye az X, ezért 90 fokkal elforgatjuk.
	local tank = makePart({
		Name = paint.name .. "Tank",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 6, 6),
		CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = paint.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false, -- bele lehet ugrani
	})
	tank:SetAttribute("ColorName", paint.name)

	local light = Instance.new("PointLight")
	light.Color = paint.color
	light.Range = 14
	light.Brightness = 2
	light.Parent = tank

	tank.Parent = parent
end

-- Felépíti a várost. Visszaadja az épületek és a festéktartályok mappáját, meg a kezdőpontot.
function CityBuilder.build(seed: number?): (Folder, Folder, Vector3)
	local old = workspace:FindFirstChild("City")
	if old then
		old:Destroy()
	end

	local c = Config.CITY
	local rng = Random.new(seed or math.floor(os.clock() * 1000))

	local city = Instance.new("Folder")
	city.Name = "City"
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = city
	local tanks = Instance.new("Folder")
	tanks.Name = "PaintTanks"
	tanks.Parent = city

	local pitch = c.BLOCK_SIZE + c.STREET_WIDTH
	local size = c.GRID * pitch + c.STREET_WIDTH
	local origin = -size / 2 -- a város bal felső sarka (X és Z)

	makePart({
		Name = "Ground",
		Size = Vector3.new(size + 2 * c.MARGIN, 1, size + 2 * c.MARGIN),
		Position = Vector3.new(0, -0.5, 0),
		Color = c.ASPHALT,
		Material = Enum.Material.Asphalt,
	}).Parent =
		city

	-- Háztömbök
	local lotSize = (c.BLOCK_SIZE - 2 * c.SIDEWALK) / c.LOTS
	for bx = 0, c.GRID - 1 do
		for bz = 0, c.GRID - 1 do
			local minX = origin + c.STREET_WIDTH + bx * pitch
			local minZ = origin + c.STREET_WIDTH + bz * pitch

			makePart({
				Name = "Sidewalk",
				Size = Vector3.new(c.BLOCK_SIZE, 0.6, c.BLOCK_SIZE),
				Position = Vector3.new(minX + c.BLOCK_SIZE / 2, 0.3, minZ + c.BLOCK_SIZE / 2),
				Color = c.SIDEWALK_COLOR,
				Material = Enum.Material.Concrete,
			}).Parent =
				city

			for lx = 0, c.LOTS - 1 do
				for lz = 0, c.LOTS - 1 do
					local width = lotSize - c.LOT_GAP
					local height = rng:NextInteger(c.MIN_HEIGHT, c.MAX_HEIGHT)
					local centerX = minX + c.SIDEWALK + (lx + 0.5) * lotSize
					local centerZ = minZ + c.SIDEWALK + (lz + 0.5) * lotSize
					local grey = greyShade(rng)

					local building = makePart({
						Name = "Building",
						Size = Vector3.new(width, height, width),
						Position = Vector3.new(centerX, 0.6 + height / 2, centerZ),
						Color = grey,
						Material = Enum.Material.SmoothPlastic,
					})
					building:SetAttribute("BaseColor", grey) -- ide áll vissza a város újrakezdésekor
					building:SetAttribute("ColorName", "") -- "" = még festetlen
					addDetails(building, rng)
					building.Parent = buildings
				end
			end
		end
	end

	-- Kereszteződések: minden másodikban festéktartály, középen a kezdőpont.
	local middle = c.GRID // 2
	local spawnPosition = Vector3.zero
	local colorIndex = 0
	for ix = 0, c.GRID do
		for iz = 0, c.GRID do
			local position =
				Vector3.new(origin + c.STREET_WIDTH / 2 + ix * pitch, 0, origin + c.STREET_WIDTH / 2 + iz * pitch)
			if ix == middle and iz == middle then
				spawnPosition = position
			elseif (ix + iz) % 2 == 0 then
				colorIndex = colorIndex % #Config.PAINT_COLORS + 1
				makePaintTank(position, Config.PAINT_COLORS[colorIndex], tanks)
			end
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = spawnPosition + Vector3.new(0, 0.2, 0)
	spawn.Color = Color3.fromRGB(240, 240, 240)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0 -- nincs védőpajzs a születéskor
	spawn.Parent = city

	city.Parent = workspace
	return buildings, tanks, spawnPosition
end

return CityBuilder
