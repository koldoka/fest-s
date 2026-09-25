-- Minimális Roblox-utánzat a Kit futtatásához (csak geometria és adatok)
local V3mt = {}
local function V(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt) end
V3mt.__add = function(a, b) return V(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return V(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__unm = function(a) return V(-a.X, -a.Y, -a.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return V(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return V(a.X * b, a.Y * b, a.Z * b) end
	return V(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b) if type(b) == "number" then return V(a.X / b, a.Y / b, a.Z / b) end return V(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) return V(v.X / m, v.Y / m, v.Z / m) end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	if k == "Cross" then return function(a, b) return V(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	error("Vector3." .. tostring(k))
end
Vector3 = { new = V, zero = V(0, 0, 0), one = V(1, 1, 1), xAxis = V(1, 0, 0), yAxis = V(0, 1, 0), zAxis = V(0, 0, 1) }
local V2mt = {}
local function V2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2mt) end
V2mt.__add = function(a, b) return V2(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) return V2(a.X - b.X, a.Y - b.Y) end
V2mt.__mul = function(a, b) if type(a) == "number" then return V2(b.X * a, b.Y * a) end return V2(a.X * b, a.Y * b) end
V2mt.__index = function(v, k)
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y end end
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	error("Vector2." .. tostring(k))
end
Vector2 = { new = V2 }

local C3mt = {}
local function C3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end
C3mt.__index = { Lerp = function(a, b, t) return C3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end }
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = { new = C3, fromRGB = function(r, g, b) return C3(r / 255, g / 255, b / 255) end }

-- CFrame: p + oszlopvektorok (rx, ry, rz)
local CFmt = {}
local function CF(p, rx, ry, rz) return setmetatable({ p = p, rx = rx, ry = ry, rz = rz }, CFmt) end
local function rot(cf, v) return cf.rx * v.X + cf.ry * v.Y + cf.rz * v.Z end
CFmt.__mul = function(a, b)
	if getmetatable(b) == V3mt then return a.p + rot(a, b) end
	return CF(a.p + rot(a, b.p), rot(a, b.rx), rot(a, b.ry), rot(a, b.rz))
end
CFmt.__index = function(cf, k)
	if k == "Position" then return cf.p end
	if k == "Rotation" then return CF(V(0, 0, 0), cf.rx, cf.ry, cf.rz) end
	if k == "RightVector" then return cf.rx end
	if k == "LookVector" then return -cf.rz end
	if k == "UpVector" then return cf.ry end
	if k == "PointToObjectSpace" then return function(c, pt) local d = pt - c.p return V(d:Dot(c.rx), d:Dot(c.ry), d:Dot(c.rz)) end end
	error("CFrame." .. tostring(k))
end
local I = CF(V(0, 0, 0), V(1, 0, 0), V(0, 1, 0), V(0, 0, 1))
local function rX(a) local c, s = math.cos(a), math.sin(a) return CF(V(0,0,0), V(1, 0, 0), V(0, c, s), V(0, -s, c)) end
local function rY(a) local c, s = math.cos(a), math.sin(a) return CF(V(0,0,0), V(c, 0, -s), V(0, 1, 0), V(s, 0, c)) end
local function rZ(a) local c, s = math.cos(a), math.sin(a) return CF(V(0,0,0), V(c, s, 0), V(-s, c, 0), V(0, 0, 1)) end
CFrame = {
	identity = I,
	new = function(x, y, z)
		if type(x) == "table" then return CF(x, I.rx, I.ry, I.rz) end
		return CF(V(x or 0, y or 0, z or 0), I.rx, I.ry, I.rz)
	end,
	Angles = function(a, b, c) return rX(a) * rY(b) * rZ(c) end,
	fromMatrix = function(p, vx, vy, vz) vz = vz or vx:Cross(vy).Unit return CF(p, vx, vy, vz) end,
	lookAt = function(at, target, up)
		up = up or V(0, 1, 0)
		local look = (target - at).Unit
		local right = look:Cross(up).Unit
		local upv = right:Cross(look)
		return CF(at, right, upv, -look)
	end,
}

Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, n) return k .. "." .. n end }) end })

local rngmt = {}
rngmt.__index = {
	NextInteger = function(self, a, b) self.s = (self.s * 1103515245 + 12345) % 2147483648 return a + self.s % (b - a + 1) end,
	NextNumber = function(self, a, b) self.s = (self.s * 1103515245 + 12345) % 2147483648 local r = self.s / 2147483648 if a then return a + (b - a) * r end return r end,
}
Random = { new = function(seed) return setmetatable({ s = math.floor(seed or 1) % 2147483648 }, rngmt) end }

-- Instance
local all = {}
local Imt = {}
local methods = {}
function methods:SetAttribute(k, v) rawget(self, "_attr")[k] = v end
function methods:GetAttribute(k) return rawget(self, "_attr")[k] end
function methods:GetChildren() return table.clone(rawget(self, "_children")) end
function methods:GetDescendants()
	local out = {}
	local function walk(i) for _, c in rawget(i, "_children") do table.insert(out, c) walk(c) end end
	walk(self) return out
end
function methods:ClearAllChildren() rawset(self, "_children", {}) end
function methods:IsA(c)
	local cls = rawget(self, "ClassName")
	if c == "BasePart" then return cls == "Part" or cls == "SpawnLocation" or cls == "WedgePart" end
	if c == "Decal" then return cls == "Decal" or cls == "Texture" end
	return cls == c
end
function methods:FindFirstChild(n) for _, c in rawget(self, "_children") do if rawget(c, "Name") == n then return c end end end
function methods:Destroy() end
Imt.__index = function(t, k)
	if methods[k] then return methods[k] end
	if k == "Parent" then return rawget(t, "_parent") end
	if k == "Position" then return rawget(t, "_props").CFrame.p end
	return rawget(t, "_props")[k]
end
Imt.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then local ch = rawget(old, "_children") for i, c in ch do if c == t then table.remove(ch, i) break end end end
		rawset(t, "_parent", v)
		if v then table.insert(rawget(v, "_children"), t) end
		return
	end
	if k == "Position" then
		local cf = rawget(t, "_props").CFrame or I
		rawget(t, "_props").CFrame = CF(v, cf.rx, cf.ry, cf.rz) return
	end
	if k == "CFrame" and getmetatable(v) ~= CFmt then error("CFrame expected") end
	if k == "Size" and getmetatable(v) ~= V3mt then error("Size expected") end
	if k == "Color" and getmetatable(v) ~= C3mt then error("Color expected for " .. tostring(rawget(t, "_props").Name)) end
	rawget(t, "_props")[k] = v
end
Instance = {
	new = function(cls)
		local i = setmetatable({ ClassName = cls, _props = { Name = cls, CFrame = I, Size = V(4, 1, 2) }, _attr = {}, _children = {} }, Imt)
		table.insert(all, i)
		return i
	end,
}
ALL_INSTANCES = all
