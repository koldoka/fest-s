-- A Kit közös segédei és állapota (a pálya mappái, a véletlengenerátor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Common = {}

Common.WHITE = Color3.new(1, 1, 1)
Common.BLACK = Color3.new(0, 0, 0)

-- A Kit.begin tölti ki
Common.folders = (nil :: any) :: { world: Folder, buildings: Folder, props: Folder, tanks: Folder }
Common.rng = Random.new(1)

-- Oldalak helyi irányai és a hozzájuk tartozó NormalId.
Common.FACES = {
	front = { dir = -Vector3.zAxis, normal = Enum.NormalId.Front },
	back = { dir = Vector3.zAxis, normal = Enum.NormalId.Back },
	left = { dir = -Vector3.xAxis, normal = Enum.NormalId.Left },
	right = { dir = Vector3.xAxis, normal = Enum.NormalId.Right },
}

function Common.darker(color: Color3, amount: number): Color3
	return color:Lerp(Common.BLACK, amount)
end

function Common.lighter(color: Color3, amount: number): Color3
	return color:Lerp(Common.WHITE, amount)
end

-- Egy szín szürke változata (a festetlen világhoz): a világossága marad, a színe eltűnik.
function Common.toGrey(color: Color3): Color3
	local l = 0.3 * color.R + 0.59 * color.G + 0.11 * color.B
	return Color3.new(l, l, l):Lerp(Config.BUILDINGS.GREY, 0.35)
end

function Common.greyShade(): Color3
	local b = Config.BUILDINGS
	local offset = Common.rng:NextInteger(-b.GREY_VARIANCE, b.GREY_VARIANCE) / 255
	return Color3.new(
		math.clamp(b.GREY.R + offset, 0, 1),
		math.clamp(b.GREY.G + offset, 0, 1),
		math.clamp(b.GREY.B + offset, 0, 1)
	)
end

function Common.pick<T>(list: { T }): T
	return list[Common.rng:NextInteger(1, #list)]
end

function Common.newPart(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	-- A CanCollide menjen előre: a CanQuery csak nem ütköző alkatrésznél kapcsolható ki.
	if props.CanCollide ~= nil then
		part.CanCollide = props.CanCollide
	end
	for key, value in props do
		if key ~= "ClassName" and key ~= "CanCollide" then
			(part :: any)[key] = value
		end
	end
	return part
end

function Common.faceWidth(size: Vector3, dir: Vector3): number
	return if dir.X ~= 0 then size.Z else size.X
end

-- Vízszintes irány a fal mentén, kívülről nézve balról jobbra.
function Common.alongFace(dir: Vector3): Vector3
	return Vector3.yAxis:Cross(dir).Unit
end

-- Egy oldal elé helyezett pont: kifelé "out" studdal, a fal mentén "shift"-tel, "y" magasan (a tömb aljától).
-- A visszaadott CFrame iránya a tömbé.
function Common.onFace(part: BasePart, dir: Vector3, out: number, shift: number, y: number): CFrame
	local half = part.Size / 2
	local offset = dir * (math.abs(dir:Dot(half)) + out)
		+ Common.alongFace(dir) * shift
		+ Vector3.new(0, -half.Y + y, 0)
	return part.CFrame * CFrame.new(offset)
end

-- Lapos darab egy oldalon: "w" széles (a fal mentén), "h" magas, "t" vastag.
function Common.faceSize(dir: Vector3, w: number, h: number, t: number): Vector3
	return if dir.X ~= 0 then Vector3.new(t, h, w) else Vector3.new(w, h, t)
end

---------------------------------------------------------------------------------------------------
-- Foglaltsági térkép: minden elhelyezett dolog (ház, utca, tárgy, fal) alaprajza egy elforgatott téglalap.
-- Ez alapján rakja a Kit a házakat az utcák mentén és tölti ki az üres helyeket úgy, hogy semmi ne kerüljön
-- egymásra. A felszínek (dombok, teraszok) megadják, milyen magasan van a talaj egy adott helyen.

export type Rect = { cx: number, cz: number, ux: Vector2, uz: Vector2, hx: number, hz: number }

Common.footprints = {} :: { Rect }
Common.surfaces = {} :: { { rect: Rect, top: number } }

-- Téglalap a vízszintes síkon: középpont, fél méretek, elforgatás (fokban, mint a Kit.building rot-ja).
function Common.rect(cx: number, cz: number, hx: number, hz: number, rotDeg: number?): Rect
	local a = math.rad(rotDeg or 0)
	-- CFrame.Angles(0, a, 0): a helyi X a világban (cos a, -sin a), a helyi Z (sin a, cos a)
	return {
		cx = cx,
		cz = cz,
		ux = Vector2.new(math.cos(a), -math.sin(a)),
		uz = Vector2.new(math.sin(a), math.cos(a)),
		hx = hx,
		hz = hz,
	}
end

-- Két elforgatott téglalap átfedése (elválasztó tengelyek tétele).
function Common.overlaps(a: Rect, b: Rect): boolean
	local d = Vector2.new(b.cx - a.cx, b.cz - a.cz)
	for _, axis in { a.ux, a.uz, b.ux, b.uz } do
		local ra = a.hx * math.abs(a.ux:Dot(axis)) + a.hz * math.abs(a.uz:Dot(axis))
		local rb = b.hx * math.abs(b.ux:Dot(axis)) + b.hz * math.abs(b.uz:Dot(axis))
		if math.abs(d:Dot(axis)) > ra + rb then
			return false
		end
	end
	return true
end

function Common.isFree(r: Rect): boolean
	for _, f in Common.footprints do
		if Common.overlaps(r, f) then
			return false
		end
	end
	return true
end

function Common.occupy(r: Rect)
	table.insert(Common.footprints, r)
end

-- Egy pont benne van-e a téglalapban (margóval).
function Common.contains(r: Rect, x: number, z: number, margin: number?): boolean
	local d = Vector2.new(x - r.cx, z - r.cz)
	local m = margin or 0
	return math.abs(d:Dot(r.ux)) <= r.hx - m and math.abs(d:Dot(r.uz)) <= r.hz - m
end

-- A talaj magassága egy pontban: a legmagasabb felszín, amely teljesen lefedi a pont körüli "radius" sugarú
-- területet; ha csak részben fedi (a domb széle), nil (oda nem teszünk semmit).
function Common.groundAt(x: number, z: number, radius: number): number?
	local best = 0
	for _, s in Common.surfaces do
		local r = s.rect
		if Common.contains(r, x, z, radius) then
			best = math.max(best, s.top)
		elseif Common.contains(r, x, z, -radius) then
			return nil
		end
	end
	return best
end

return Common
