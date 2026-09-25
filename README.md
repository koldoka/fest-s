# Paint Pop (munkacím)

Színes festős platformjáték **Robloxra**: egy festékpacával ugrálsz végig egy szürke városon,
és minden épületet kifestesz, amihez hozzáérsz.

**1. mérföldkő (prototípus):** generált szürke város, festéktartályok, festés érintéssel,
pontok, a város festettségének kijelzése, újrakezdés, ha minden színes.

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

## Játékmenet

- Ugorj bele egy **festéktartályba** (a kereszteződésekben álló színes hengerek): felveszed a színét, és teli lesz a festéked.
- **Érj hozzá egy épülethez** (neki is ugorhatsz, vagy ráugorhatsz a tetejére): befested, és elfogy egy adag festék.
- Szürke épületért pont jár. Már befestett épületet más színre át lehet festeni, de azért nincs pont.
- Ha az egész város színes, 10 másodperc múlva újra szürke lesz.

Irányítás: a Roblox alap irányítása (WASD + Space, mobilon joystick + ugrás gomb).

## Felépítés

```
default.project.json   Rojo: melyik mappa hová kerül a Studióban
src/shared/
  Config.luau          minden beállítás: város, színek, festék, mozgás
src/server/
  Main.server.luau     indítás, a város újrakezdése
  CityBuilder.luau     a szürke város felépítése, festéktartályok
  PaintService.luau    festés: mihez ér a játékos, festék, pontok (erről mindig a szerver dönt)
src/client/
  Main.client.luau     indítás
  Hud.luau             a város festettsége, saját festék, üzenetek
  Effects.luau         fröccsenő festék és felvillanás festéskor
```

## Ismert korlátok (prototípus)

- A figura még a sima Roblox-avatar színes derengéssel, nem igazi paca.
- A grafika egyszerű dobozokból áll, nincs hang és zene.
- Nincs PvP, mentés és bolt. Ezek a [ROADMAP.md](ROADMAP.md) szerint jönnek.
