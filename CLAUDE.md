# Paint Pop (munkacím): projektjegyzet

Színes festős platformjáték Robloxra (a de Blob ihletésére, de saját figurával, névvel és stílussal).
Egy guruló, pattogó festékpaca szürke várost fest ki (kézzel, kódból tervezett pályák); később csapatos PvP (kerületfoglalás) és PvE mód.

- **A teendőlista és a haladás: [ROADMAP.md](ROADMAP.md).** Új munka előtt ezt nézd meg,
  és a kész pontokat pipáld ki ugyanabban a commitban.
- A felhasználóval **magyarul** kommunikálunk. A játékon belüli szövegek angolok (globális közönség),
  a kódkommentek magyarok.
- Munkamenet: a kódot itt írjuk, a felhasználó a Roblox Studióban tesztel.
  Rojo 7.7.0 (`rojo.exe serve`) → Studio Rojo plugin → Connect. Részletek: [README.md](README.md).
  A Studiót nem tudjuk futtatni, a futás közbeni hibákat a felhasználó küldi (Output ablak).
- Formázás: StyLua (`stylua.toml`). Ellenőrzés: `npx -y @johnnymorganz/stylua-bin --check src`.
- Felépítés: `src/shared` (Config), `src/server` (Kit = építőkészlet, Levels = kézzel tervezett pályák), `src/client`.
  Minden hangolható érték a `src/shared/Config.luau`-ban van.
- Elvek: a festékről, az épületek színéről és a pontokról mindig a szerver dönt; a saját karaktert a kliens mozgatja.
- Szerzői jog: semmit nem veszünk át a de Blobból vagy a Splatoonból (nevek, figurák, modellek, zenék).
  A "Blob", "Splat", "Chroma" szavakat kerüljük a nevekben.
