# Paint Pop (munkacím)

Színes festős platformjáték **Robloxra**: egy festékpacával ugrálsz végig egy szürke városon,
és minden épületet kifestesz, amihez hozzáérsz.

**Első pálya:** kézzel tervezett kisváros városfallal körülvéve: kanyargó utcák és sikátorok, főtér
templommal és városházával, folyó három híddal, terasz kilátótoronnyal, szélmalmos domb, keleti park,
kertek, gyümölcsösök, rétek, termőföldek. Minden szürke, a festékes paca adja vissza a színeket.

## Indítás (Windows)

### Egyszer kell

1. **Roblox Studio** és a **Rojo plugin** a Studióban (Toolbox → Plugins → "Rojo" → Install), 7.7.0-s verzió.
2. **Rojo parancssori program**, ugyanabban a verzióban:
   - https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0 → `rojo-7.7.0-windows-x86_64.zip`
   - A `rojo.exe`-t másold be **ebbe a mappába** (a `default.project.json` mellé). A git nem tölti fel.

### Minden alkalommal

1. VS Code: **Terminal → New Terminal** → `.\rojo.exe serve` (a terminált hagyd nyitva).
2. Roblox Studio: új **Baseplate** hely → **Plugins** → **Rojo** → **Connect**.
3. Egyszer, a Studióban: Explorer → **Workspace** → Properties → **StreamingEnabled** kikapcsolása.
4. Tesztelés: **Play** (F5), vagy többjátékos: **Test** → *Clients and Servers* → 2 játékos → **Start**.
5. A hibák a **View → Output** ablakban jelennek meg pirossal. Ezeket kell továbbküldeni.

## Ha valami furcsa (nincs karakter, régi elemek a pályán)

- Mindig **új Baseplate helyen** teszteld, ne abban, amelyikben a Toybox Tanks fut. A két projekt beállításai
  (pl. a `Players.CharacterAutoLoads`) és szkriptjei összekeveredhetnek.
- Egyszerre csak **egy** `rojo serve` fusson.

## Hangok és képek

A hangokat a `tools/generate_sounds.py`, az ablakképeket a `tools/generate_textures.py` állítja elő
(`assets/sounds/`, `assets/textures/`). Feltöltés: Studio → **Asset Manager** → **Import** → jobb klikk →
**Copy ID**, majd az azonosító a `src/shared/Config.luau`-ba (`SOUNDS`, illetve `BUILDINGS.FACADE`).
Mind fel van töltve és be van írva. Ha egy hangot vagy képet újragenerálunk, újra fel kell tölteni.

| Fájl | Config-név | Mikor szól |
|---|---|---|
| `paint_1.ogg` … `paint_4.ogg` | `Paint` | épület befestése, véletlenszerűen |
| `roll_loop.ogg` | `Roll` | gurulás (ismétlődik, a sebességgel hangosodik) |
| `jump.ogg`, `land.ogg` | `Jump`, `Land` | ugrás, földet érés |
| `refill.ogg` | `Refill` | festék felvétele tartályból |
| `city_done.ogg` | `CityDone` | minden ház színes |

A Roblox alap lépéshangjait a `src/overrides/RbxCharacterSounds.client.luau` üres szkript kapcsolja ki.

| Kép | Config-név |
|---|---|
| `window_classic_grey.png`, `window_classic_lit.png` | `BUILDINGS.WINDOWS.classic` (`grey`, `lit`) |
| `window_curtain_grey.png`, `window_curtain_lit.png` | `BUILDINGS.WINDOWS.curtain` |
| `window_tall_grey.png`, `window_tall_lit.png` | `BUILDINGS.WINDOWS.tall` |
| `shutters.png` | `BUILDINGS.SHUTTERS` (a zsalugáter; a játék a festék színére színezi) |

## Játékmenet

- Ugorj bele egy **festéktartályba** (színes, világító henger): felveszed a színét, és teli lesz a festéked.
  A tartály ezután eltűnik, és kis idő múlva máshol, más színnel jelenik meg (egyszerre 20 van a pályán, minden további játékossal 4-gyel több, legfeljebb 40).
- **Érj hozzá egy épülethez** (neki is ugorhatsz, vagy ráugorhatsz a tetejére): befested. Egy teli tartály 20 egység;
  egy földszintes ház 1, egy kétszintes 3, egy három- vagy többszintes 4 egységbe kerül, egy tárgy (fa, pad,
  veteményes…) 1-be. Festéskor egy felugró "-N" mutatja, mennyi fogyott.
  Ha nincs elég festéked, a játék kiírja, mennyi kellene.
- Pont az első befestésért jár (egységenként 5). Már befestett dolgot más színre át lehet festeni, de azért nincs pont.
- A fák, padok, lámpák, kerítések és más tárgyak érintésre színesek lesznek.
- Ha az összes ház színes, 10 másodperc múlva minden újra szürke lesz.

Irányítás: a Roblox alap irányítása (WASD + Space, mobilon joystick + ugrás gomb).
**M**: térkép (mobilon a „Map” gomb, kontrolleren a Select): a szürke házak még festetlenek, a pöttyök a tartályok,
a játékosokat az avatarjuk arcképe mutatja (valós időben).

## Felépítés

```
default.project.json   Rojo: melyik mappa hová kerül a Studióban
src/shared/
  Config.luau          minden beállítás: pálya, épületek, színek, festék, mozgás, hangok
src/server/
  Main.server.luau     indítás, a pálya újrakezdése
  LevelLoader.luau     a pálya betöltése (Config.LEVEL)
  Kit/                 építőkészlet a pályákhoz
    init.luau          talaj, utcák, házsorok, kitöltés, városfal, lépcső, víz, híd, tartályhelyek
    Buildings.luau     épületek: tetők, ablakok, ajtók, kirakatok, erkélyek, óra…
    Props.luau         tárgyak: fa, pad, lámpa, kerítés, szökőkút, szobor, szélmalom…
    Common.luau        közös segédek
  Levels/
    SmallTown.luau     1. pálya: kisváros főtérrel (kézzel tervezve)
  PaintService.luau    festés: mihez ér a játékos, festék, pontok (erről mindig a szerver dönt)
  TankService.luau     festéktartályok: véletlen helyen és színnel, használat után máshol jelennek meg
  BlobCharacter.luau   a paca figura: elrejti az avatart, szín és méret a festék szerint
src/client/
  Main.client.luau     indítás
  Hud.luau             a pálya festettsége, saját festék, üzenetek
  Effects.luau         fröccsenő festék és felvillanás festéskor
  BlobAnimator.luau    a pacák lapulása és nyúlása (csak látvány)
  Trails.luau          festékcsík a paca után (csak látvány)
  Sounds.luau          hangok, gurulás
  MapView.luau         térkép az M gombra
src/overrides/         a Roblox alapszkriptjeinek felülírása (lépéshangok ki)
tools/generate_sounds.py    a hangok előállítása kódból (assets/sounds/*.ogg)
tools/generate_textures.py  az ablakképek előállítása (assets/textures/*.png)
tools/preview/              pálya-előnézet a Studio nélkül (lásd lent)
```

## Új pálya készítése

A pályák kézzel, kódból vannak megtervezve a `src/server/Levels/` mappában. Az utcák, terek és a különleges
helyek (templom, terasz, domb…) kézzel vannak elhelyezve; a házak az utcák mentén sorakoznak (`Kit.streetRow`),
és ami üres hely marad, azt a `Kit.fill` tölti ki telkenként egy-egy témával (gyümölcsös, veteményeskert, rét,
liget, termőföld, udvar). Egy foglaltsági térkép gondoskodik róla, hogy semmi ne kerüljön egymásra. Egy pálya a `Kit` függvényeit
hívja (épület, fa, pad, lámpa, szökőkút, lépcső, festéktartály…), a leírásuk a `Kit.luau` elején és
a `Kit.building` fölött van. A betöltendő pályát a `Config.LEVEL` adja meg.

- **Épületek**: a játékos befesti őket a saját színével, ezekért jár pont. Ha mind színes, a pálya újraindul.
- **Tárgyak** (fák, padok, lámpák, kerítések, szökőkút, standok…): érintésre színesek lesznek; a festhető
  részeik (lomb, ülőke, lámpaoszlop, napernyő…) a festék színét kapják, a többi a természetes színét.
  Át is festhetők. Egységnyi festékbe kerülnek.

### Pálya-előnézet a Studio nélkül

A `tools/preview/preview.py` a pályakódot egy Roblox-utánzattal lefuttatja, kiírja az alkatrészek számát,
és képeket rajzol (felülnézet és tetszőleges nézetek). Így a Studio nélkül is kiderül, ha a pálya hibára fut,
vagy valami rosszul áll. Kell hozzá a `luau` parancssori program és a Pythonhoz a `numpy` és a `pillow`.

```
python tools/preview/preview.py SmallTown preview_out "square,0,8,-20,70,200,28,6.5"
```

## Ismert korlátok (prototípus)

- A paca csak látvány: a mozgást és az ütközést a láthatatlan Roblox-avatar végzi, ezért a paca picit belelóghat a falakba.
- A grafika egyszerű dobozokból áll, zene még nincs.
- Nincs PvP, mentés és bolt. Ezek a [ROADMAP.md](ROADMAP.md) szerint jönnek.
