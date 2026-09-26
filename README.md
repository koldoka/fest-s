# Paint Pop (munkacím)

Színes festős csapatjáték **Robloxra**: festékpacaként gurulsz végig egy szürke városon, és a csapatod
színére fested az épületeket. Két csapat (alapból piros és kék) versenyez a város kerületeiért.

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
A már feltöltött hangokat a szkript nem írja felül (egy hang újrakészítéséhez töröld a fájlját, és töltsd fel újra).

| Fájl | Config-név | Mikor szól |
|---|---|---|
| `paint_1.ogg` … `paint_4.ogg` | `Paint` | épület befestése, véletlenszerűen |
| `roll_loop.ogg` | `Roll` | gurulás (ismétlődik, a sebességgel hangosodik) |
| `jump.ogg`, `land.ogg` | `Jump`, `Land` | ugrás, földet érés |
| `refill.ogg` | `Refill` | festék felvétele tartályból |
| `city_done.ogg` | `CityDone` | döntetlen |
| `steal.ogg` | `Steal` | te loptál festéket |
| `stolen.ogg` | `Stolen` | tőled loptak |
| `capture.ogg` | `Capture` | egy kerület teljesen elfoglalva, lezárul |
| `unlock.ogg` | `Unlock` | a kerület újra nyitott |
| `tick.ogg` | `Tick` | visszaszámlálás |
| `go.ogg` | `Go` | a meccs indul |
| `win.ogg`, `lose.ogg` | `Win`, `Lose` | a csapatod nyert / vesztett |

A Roblox alap lépéshangjait a `src/overrides/RbxCharacterSounds.client.luau` üres szkript kapcsolja ki.

| Kép | Config-név |
|---|---|
| `window_classic_grey.png`, `window_classic_lit.png` | `BUILDINGS.WINDOWS.classic` (`grey`, `lit`) |
| `window_curtain_grey.png`, `window_curtain_lit.png` | `BUILDINGS.WINDOWS.curtain` |
| `window_tall_grey.png`, `window_tall_lit.png` | `BUILDINGS.WINDOWS.tall` |
| `shutters.png` | `BUILDINGS.SHUTTERS` (a zsalugáter; a játék a festék színére színezi) |

## Játékmenet

- **Meccsek**: 15 mp szünet (lehet szaladgálni és festéket felvenni, festeni nem), 7 perc játék, majd az eredmény.
  Utána minden visszaszürkül, és a csapatok újra összekeverednek. Belépéskor a kisebb csapatba kerülsz.
- **Festékesvödör** (fémvödör színes „PAINT” címkével, rajta lapos ecset): ha beleugrasz, teli lesz a festéked a **csapatod színével**.
  A vödör ezután eltűnik, és kis idő múlva máshol jelenik meg (egyszerre 20 van a pályán, minden további
  játékossal 4-gyel több, legfeljebb 40).
- **Érj hozzá egy épülethez**: a csapatod színére fested, az ellenfél házát is át lehet festeni. Egy teli vödör
  20 egység; egy földszintes ház 1, egy kétszintes 3, egy három- vagy többszintes 4 egységbe kerül, egy tárgy
  (fa, pad, veteményes…) 1-be. Festéskor egy felugró "-N" mutatja, mennyi fogyott; ha kevés a festéked, a játék kiírja,
  mennyi kellene. Minden elfestett egységért 5 saját pont jár (ranglista).
- **Friss festék**: egy befestett házat 5 mp-ig más csapat nem festhet át. Addig "WET PAINT" tábla van az ajtaján
  fogyó sávval, a falán lassan lefolynak a festékcseppek, és a fal fényes, majd fokozatosan megszárad.
- **Kerületek** (a kisvárosban 11): amelyik csapatnak több háza van egy kerületben, azé a kerület. Ha egy csapat
  a kerület **minden** házát befestette, a kerület 60 mp-re **lezárul**: addig senki nem festhet benne.
- **Csapatpont**: a csapat színében álló házak és tárgyak festékértéke (ház 1/3/4, tárgy 1), és minden kerület,
  ahol a csapat vezet, +10. A több pont nyer.
- **Víz**: aki a folyóba, a tóba vagy a szökőkútba megy, elveszíti az összes festékét.
- **Festéklopás**: ha nekigurulsz egy ellenfélnek, a gyorsabb elveszi a másik festékének 30%-át (legalább 2-t);
  ha felülről ráugrasz, 50%-át. A lopott festék a lopó csapatának színére vált. Akitől loptak, hátrapattan,
  és 3 mp-ig nem lehet újra meglopni.
- Felül a meccs ideje és a csapatok pontjai, bal alul a csapatod és a festéked, középen a bejelentések.
  Rajt előtt 3-2-1-GO, a meccs utolsó 10 mp-ében nagy visszaszámlálás, a végén eredménytábla (csapatpontok,
  a legjobb 3 festő) konfettivel, győzelmi vagy vesztes dallammal; 1 perccel a vége előtt figyelmeztetés.
- A pályán minden kerület fölött tábla lebeg (név, a csapatok házai, a gazda színe, lezárva a hátralévő idő).
  Lezárt kerület határán csapatszínű, csillogó erőtér-fal áll; elfoglaláskor a házakból konfetti pattan ki.
- A többi paca fölött a neve a csapata színében, alatta a festéke (kit érdemes meglopni). Lopáskor a lopónak
  "+N", a meglopottnak piros villanás és rázkódó kamera.

Irányítás: a Roblox alap irányítása (WASD + Space, mobilon joystick + ugrás gomb).
**M**: térkép (mobilon a „Map” gomb, kontrolleren a Select): a házak a színükkel, a kerületek a vezető csapat
színével és a csapatonkénti házszámmal (a lezártak erősebb színnel, "LOCKED"), 🪣 a vödrök, a játékosokat az
avatarjuk arcképe mutatja a csapatuk színével szegélyezve (valós időben).

## Felépítés

```
default.project.json   Rojo: melyik mappa hová kerül a Studióban
src/shared/
  Config.luau          minden beállítás: pálya, épületek, színek, festék, mozgás, hangok
src/server/
  Main.server.luau     indítás: a szolgáltatások összekötése
  LevelLoader.luau     a pálya betöltése (Config.LEVEL)
  Kit/                 építőkészlet a pályákhoz
    init.luau          talaj, utcák, házsorok, kitöltés, városfal, lépcső, víz, híd, tartályhelyek
    Buildings.luau     épületek: tetők, ablakok, ajtók, kirakatok, erkélyek, óra…
    Props.luau         tárgyak: fa, pad, lámpa, kerítés, szökőkút, szobor, szélmalom…
    Common.luau        közös segédek
  Levels/
    SmallTown.luau     1. pálya: kisváros főtérrel (kézzel tervezve)
  PaintService.luau    festés: mihez ér a játékos, festék, pontok (erről mindig a szerver dönt)
  TankService.luau     festékesvödrök: véletlen helyen, használat után máshol jelennek meg
  TeamService.luau     csapatok (Config.TEAMS), a játékosok elosztása
  DistrictService.luau kerületek: gazda csapat, teljes elfoglalás és lezárás, csapatpontok
  StealService.luau    festéklopás ütközéskor (nekigurulás, ráugrás), hátrapattanás
  MatchService.luau    a meccsek menete: szünet, játék, eredmény, újrakezdés
  BlobCharacter.luau   a paca figura: elrejti az avatart, szín és méret a festék szerint
src/client/
  Main.client.luau     indítás
  Hud.luau             meccsidő, csapatpontok, saját csapat és festék, bejelentések
  Pvp.luau             hátrapattanás, a festéklopás látványa és hangja, névcímkék
  Districts.luau       kerülettáblák a pályán, lezárt kerület fala, elfoglalási konfetti
  Results.luau         visszaszámlálás, rajt, eredménytábla
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

- **Épületek**: a játékos a csapata színére festi őket, ezekért jár pont.
- **Kerületek** (`Level.districts`): név és téglalapok; minden ház abba a kerületbe tartozik, amelyik téglalapjába
  esik. Érdemes nagyjából egyforma (6–25 házas) kerületeket csinálni.
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
- Nincs lobby, pályaszavazás, mentés és bolt. Ezek a [ROADMAP.md](ROADMAP.md) szerint jönnek.
- A festéklopás a karakterek közepe és sebessége alapján dönt; a hátrapattanást a meglopott játékos gépe végzi.
