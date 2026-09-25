-- A pálya felépítése az utánzattal, majd minden alkatrész kiírása (a preview.py olvassa).
-- LEVEL_NAME-et a preview.py adja meg.
local Kit = require(P("S/Kit"))
local function folder(n) local f = Instance.new("Folder") f.Name = n return f end
local folders = { world = folder("World"), buildings = folder("Buildings"), props = folder("Props"), tanks = folder("PaintTanks") }
local Level = require(P("S/Levels/" .. LEVEL_NAME))
Kit.begin(folders, Level.seed or 1)
Level.build(Kit)
Kit.finish()

local function num(x) return string.format("%.3f", x) end
local lines = {}
local function dump(inst, owner, kind)
	local cf, s, c = inst.CFrame, inst.Size, inst.Color or Color3.new(0.5, 0.5, 0.5)
	table.insert(lines, table.concat({ kind, owner, inst.Name, tostring(inst.Shape or ""),
		num(cf.p.X), num(cf.p.Y), num(cf.p.Z), num(cf.rx.X), num(cf.rx.Y), num(cf.rx.Z), num(cf.ry.X), num(cf.ry.Y), num(cf.ry.Z),
		num(cf.rz.X), num(cf.rz.Y), num(cf.rz.Z), num(s.X), num(s.Y), num(s.Z), num(c.R), num(c.G), num(c.B),
		tostring(inst.Transparency or 0) }, "|"))
end
local parts = 0
for bi, b in folders.buildings:GetChildren() do
	dump(b, bi, "B")
	parts += 1
	for _, d in b:GetDescendants() do
		if d.ClassName == "Part" then dump(d, bi, "B") parts += 1 end
	end
end
for pi, p in folders.props:GetChildren() do
	for _, d in p:GetDescendants() do
		if d.ClassName == "Part" then dump(d, pi, "P") parts += 1 end
	end
end
for _, w in folders.world:GetChildren() do
	if w.ClassName == "Part" then dump(w, 0, "W") parts += 1 end
end
for _, t in folders.tanks:GetChildren() do dump(t, 0, "T") parts += 1 end
print("PARTS " .. parts .. " buildings " .. #folders.buildings:GetChildren() .. " props " .. #folders.props:GetChildren())
print(table.concat(lines, "\n"))
