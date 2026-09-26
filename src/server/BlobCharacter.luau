-- A játékos figurája: az avatar láthatatlan, helyette egy festékpaca szemekkel.
-- A paca színe a nála lévő festék színe, és minél több festéke van, annál nagyobb.
-- A mozgást továbbra is a Roblox karaktere végzi; a paca csak hozzá van hegesztve.
-- A lapulás-nyúlás (squash & stretch) a klienseken fut (BlobAnimator).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BlobCharacter = {}

-- Az avatar minden részét elrejtjük, kivéve a paca saját részeit.
local function hide(instance: Instance)
	if instance:GetAttribute("BlobPart") then
		return
	end
	if instance:IsA("BasePart") then
		instance.Transparency = 1
		instance.CastShadow = false
	elseif instance:IsA("Decal") then
		instance.Transparency = 1
	end
end

local function makeBlobPart(name: string, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Name = name
	part:SetAttribute("BlobPart", true) -- még a Parent előtt, hogy a hide() ne rejtse el
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function weld(part0: BasePart, part1: BasePart): Weld
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
	return w
end

function BlobCharacter.setup(character: Model, humanoid: Humanoid)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root or character.Parent == nil then
		return
	end

	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- saját névcímke van (kliens: Pvp)
	for _, descendant in character:GetDescendants() do
		hide(descendant)
	end
	character.DescendantAdded:Connect(hide) -- a később betöltődő kiegészítők is

	-- A test gömb alakú mesh, mert annak a méretarányát a kliens szabadon nyújthatja.
	local blob = makeBlobPart("Blob", { Material = Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = blob
	-- Ennyivel van a gyökérrész közepe a talaj fölött; ehhez igazítjuk a paca alját.
	blob:SetAttribute("RootHeight", humanoid.HipHeight + root.Size.Y / 2)
	weld(root, blob).Name = "BlobWeld"

	for _, side in { -1, 1 } do
		local eye = makeBlobPart("Eye", {
			Shape = Enum.PartType.Ball,
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
		})
		eye:SetAttribute("Side", side)
		weld(blob, eye).Name = "EyeWeld"
		eye.Parent = blob

		local pupil = makeBlobPart("Pupil", {
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(25, 25, 30),
			Material = Enum.Material.SmoothPlastic,
		})
		pupil:SetAttribute("Side", side)
		weld(blob, pupil).Name = "PupilWeld"
		pupil.Parent = blob
	end

	blob.Parent = character
end

-- A paca színének és méretének frissítése a játékos festéke alapján.
function BlobCharacter.update(player: Player)
	local character = player.Character
	local blob = character and character:FindFirstChild("Blob") :: BasePart?
	if not blob then
		return
	end
	local b = Config.BLOB
	local paint = player:GetAttribute("Paint") or 0
	local color = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("PaintColor")]
	-- Festék nélkül a csapat színének halvány változata (hogy látszódjon, ki melyik csapatban van)
	local teamColor = Config.PAINT_COLOR_BY_NAME[player:GetAttribute("Team")]
	local empty = if teamColor then teamColor:Lerp(b.EMPTY_COLOR, 0.65) else b.EMPTY_COLOR
	blob.Color = if color and paint > 0 then color else empty

	local d = b.MIN_SIZE + (b.MAX_SIZE - b.MIN_SIZE) * paint / Config.PAINT_MAX
	blob.Size = Vector3.one * d
	blob:SetAttribute("Diameter", d)
	local rootHeight = blob:GetAttribute("RootHeight") or 3
	local blobWeld = blob:FindFirstChild("BlobWeld") :: Weld?
	if blobWeld then
		blobWeld.C0 = CFrame.new(0, -rootHeight + d / 2, 0) -- a paca alja a talajon
	end

	-- Szemek elöl (a karakter előre néző iránya a -Z), a méret a pacával együtt nő.
	for _, part in blob:GetChildren() do
		local side = part:GetAttribute("Side")
		if not side then
			continue
		end
		local isPupil = part.Name == "Pupil"
		local size = d * (if isPupil then 0.13 else 0.26)
		local forward = d * (if isPupil then 0.5 else 0.4);
		(part :: BasePart).Size = Vector3.one * size
		local partWeld = part:FindFirstChildOfClass("Weld")
		if partWeld then
			partWeld.C0 = CFrame.new(side * d * 0.17, d * 0.14, -forward)
		end
	end
end

return BlobCharacter
