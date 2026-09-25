"""Pálya-előnézet a Roblox Studio nélkül.

A szerveroldali pályaépítő kódot (Kit + a pálya) egy Roblox-utánzattal (rbx_mock.luau) lefuttatja a
Luau parancssori értelmezővel, kiírja az alkatrészek számát, és képeket rajzol (felülnézet + a kért nézetek).
Így a Studio nélkül is kiderül, ha a pályakód hibára fut, ha valami egymásba lóg, vagy ha rosszul áll egy tető.

Kell hozzá: luau (https://github.com/luau-lang/luau/releases, a PATH-on vagy a LUAU környezeti változóban),
python: numpy, pillow.

Futtatás a repó gyökeréből:
  python tools/preview/preview.py SmallTown preview_out "square,0,8,-20,70,200,28,6.5"
Egy nézet: név,középX,középY,középZ,sugár,irányszög,dőlésszög,nagyítás
"""

import math
import os
import pathlib
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent.parent / "src"
MODULES = {
    "RS/Shared/Config": SRC / "shared/Config.luau",
    "S/Kit": SRC / "server/Kit/init.luau",
    "S/Kit/Common": SRC / "server/Kit/Common.luau",
    "S/Kit/Buildings": SRC / "server/Kit/Buildings.luau",
    "S/Kit/Props": SRC / "server/Kit/Props.luau",
}

LOADER = """
local MODULES, CACHE = {}, {}
local Pmt = {}
function P(path) return setmetatable({ __path = path }, Pmt) end
Pmt.__index = function(t, k)
	local path = rawget(t, "__path")
	if k == "Parent" then return P(string.match(path, "^(.*)/[^/]+$")) end
	return P(path .. "/" .. k)
end
function require(p)
	local path = rawget(p, "__path")
	if CACHE[path] == nil then
		assert(MODULES[path], "no module " .. path)
		CACHE[path] = MODULES[path](P(path))
	end
	return CACHE[path]
end
game = { GetService = function(_, n) if n == "ReplicatedStorage" then return P("RS") end return P(n) end }
"""


def run_level(level: str) -> list[str]:
    modules = dict(MODULES)
    modules[f"S/Levels/{level}"] = SRC / f"server/Levels/{level}.luau"
    chunks = [(HERE / "rbx_mock.luau").read_text(), LOADER]
    for path, file in modules.items():
        chunks.append(f'MODULES["{path}"] = function(script)\n{file.read_text()}\nend\n')
    chunks.append(f'LEVEL_NAME = "{level}"\n' + (HERE / "harness.luau").read_text())
    bundle = HERE / "_bundle.luau"
    bundle.write_text("\n".join(chunks))
    luau = os.environ.get("LUAU", "luau")
    result = subprocess.run([luau, str(bundle)], capture_output=True, text=True)
    if result.returncode != 0 or result.stderr:
        sys.exit("A pálya felépítése hibára futott:\n" + result.stderr)
    return result.stdout.strip().split("\n")


def parse(lines):
    parts = []
    for line in lines[1:]:
        r = line.split("|")
        v = list(map(float, r[4:22]))
        parts.append(dict(kind=r[0], owner=int(r[1]), name=r[2], shape=r[3], p=np.array(v[0:3]),
                          ax=[np.array(v[3:6]), np.array(v[6:9]), np.array(v[9:12])],
                          s=np.array(v[12:15]), c=np.array(v[15:18]), tr=float(r[22])))
    return parts


def faces_of(q):
    """Egy alkatrész lapjai (normális, csúcsok). Az ék (WedgePart) függőleges hátlapja a helyi +Z,
    a lejtője a felső-hátsó éltől az alsó-elülső élig tart."""
    hs = q["s"] / 2
    ax = q["ax"]
    P = lambda x, y, z: q["p"] + ax[0] * x * hs[0] + ax[1] * y * hs[1] + ax[2] * z * hs[2]  # noqa: E731
    if q.get("shape") == "Wedge":
        polys = [
            [P(-1, -1, -1), P(1, -1, -1), P(1, -1, 1), P(-1, -1, 1)],  # alj
            [P(-1, -1, 1), P(1, -1, 1), P(1, 1, 1), P(-1, 1, 1)],  # hátlap
            [P(-1, -1, -1), P(1, -1, -1), P(1, 1, 1), P(-1, 1, 1)],  # lejtő
            [P(-1, -1, -1), P(-1, -1, 1), P(-1, 1, 1)],  # bal háromszög
            [P(1, -1, -1), P(1, -1, 1), P(1, 1, 1)],  # jobb háromszög
        ]
        out = []
        for poly in polys:
            n = np.cross(poly[1] - poly[0], poly[2] - poly[0])
            n = n / (np.linalg.norm(n) + 1e-9)
            c = sum(poly) / len(poly)
            if n @ (c - q["p"]) < 0:
                n = -n
            out.append((n, poly))
        return out
    out = []
    for k in range(3):
        for sg in (-1, 1):
            n = ax[k] * sg
            o = [(k + 1) % 3, (k + 2) % 3]
            cs = [q["p"] + n * hs[k] + ax[o[0]] * s1 * hs[o[0]] + ax[o[1]] * s2 * hs[o[1]]
                  for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            out.append((n, cs))
    return out


def render(parts, out, center, radius, az, el, scale, W=1200, H=900, topdown=False):
    """Egyszerű z-pufferes rajzoló: minden alkatrész téglatest (a gömb és a henger is)."""
    a, e = math.radians(az), math.radians(el)
    fwd = np.array([math.cos(e) * math.sin(a), -math.sin(e), math.cos(e) * math.cos(a)])
    right = np.array([math.cos(a), 0, -math.sin(a)])
    up = np.cross(right, fwd)
    up = up if up[1] > 0 else -up
    if topdown:  # felülnézet: észak (-Z) felül, kelet (+X) jobbra
        fwd, right, up = np.array([0, -1.0, 0]), np.array([1.0, 0, 0]), np.array([0, 0, -1.0])
    center = np.array(center, float)
    light = np.array([0.4, 0.8, 0.3])
    light /= np.linalg.norm(light)
    img = np.zeros((H, W, 3))
    img[:] = np.array([170, 200, 230]) / 255
    zb = np.full((H, W), np.inf)
    ys, xs = np.mgrid[0:H, 0:W]
    for q in parts:
        if abs(q["p"][0] - center[0]) > radius or abs(q["p"][2] - center[2]) > radius:
            continue
        if q["tr"] >= 0.99 and q["name"] != "WindowPanel":
            continue
        for n, cs in faces_of(q):
            if n @ fwd >= 0:
                continue
            P = np.array([[W / 2 + scale * ((c - center) @ right), H / 2 - scale * ((c - center) @ up),
                           (c - center) @ fwd] for c in cs])
            col = np.array([0.55, 0.62, 0.75]) if q["name"] == "WindowPanel" else q["c"]
            col = np.clip(col * (0.55 + 0.45 * max(0, n @ light)), 0, 1)
            for tri in [(0, i, i + 1) for i in range(1, len(cs) - 1)]:
                T = P[list(tri)]
                x0, x1 = int(max(0, np.floor(T[:, 0].min()))), int(min(W - 1, np.ceil(T[:, 0].max())))
                y0, y1 = int(max(0, np.floor(T[:, 1].min()))), int(min(H - 1, np.ceil(T[:, 1].max())))
                if x1 < x0 or y1 < y0:
                    continue
                X = xs[y0:y1 + 1, x0:x1 + 1] + 0.5
                Y = ys[y0:y1 + 1, x0:x1 + 1] + 0.5
                (ax_, ay, az_), (bx, by, bz), (cx, cy, cz) = T
                den = (by - cy) * (ax_ - cx) + (cx - bx) * (ay - cy)
                if abs(den) < 1e-9:
                    continue
                l1 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / den
                l2 = ((cy - ay) * (X - cx) + (ax_ - cx) * (Y - cy)) / den
                l3 = 1 - l1 - l2
                inside = (l1 >= -1e-6) & (l2 >= -1e-6) & (l3 >= -1e-6)
                z = l1 * az_ + l2 * bz + l3 * cz
                sub = zb[y0:y1 + 1, x0:x1 + 1]
                upd = inside & (z < sub - 0.01)
                sub[upd] = z[upd]
                img[y0:y1 + 1, x0:x1 + 1][upd] = col
    Image.fromarray((img * 255).astype(np.uint8)).save(out)


def main():
    level, out_dir = sys.argv[1], pathlib.Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    lines = run_level(level)
    print(lines[0])
    parts = parse(lines)
    # Felülnézet az egész pályáról
    render(parts, out_dir / "top.png", (0, 0, 0), 320, 0, 90, 1.8, W=1200, H=1100, topdown=True)
    for spec in sys.argv[3:]:
        name, cx, cy, cz, rad, az, el, sc = spec.split(",")
        render(parts, out_dir / f"{name}.png", (float(cx), float(cy), float(cz)), float(rad), float(az), float(el), float(sc))


if __name__ == "__main__":
    main()
