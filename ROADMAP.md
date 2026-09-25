# Paint Pop (munkacím): teendőlista

A haladás nyilvántartása. A kész pontokat `[x]`-szel jelöljük.

## 1. mérföldkő: prototípus
- [x] Projektváz: Rojo, StyLua, Config
- [x] Generált szürke város: háztömbök, járdák, különböző magasságú épületek
- [x] Festéktartályok a kereszteződésekben (6 szín)
- [x] Festés érintéssel, fogyó festék; a szerver dönt
- [x] Pontok (ranglista), a város festettsége a képernyő tetején
- [x] Fröccsenő festék és felvillanás festéskor
- [x] Újrakezdés, ha minden épület színes
- [x] Első teszt a Studióban (a karakterbetöltés és a festékfelvétel javítva)
- [ ] Hangolás (sebesség, ugrás, festékmennyiség)

## 2. mérföldkő: a paca és a játékérzet
- [x] Saját figura: festékpaca szemekkel a Roblox-avatar helyett, a festék színében (`BlobCharacter`)
- [x] A paca mérete a nála lévő festék mennyiségével nő
- [x] Lapulás-nyúlás: ugráskor megnyúlik, földet éréskor ellapul, mozgás közben rezeg (`BlobAnimator`)
- [ ] Gurulásérzet: fényes csík vagy minta, ami forog a mozgás irányában
- [ ] Faltól visszapattanás, falra felgurulás
- [x] Festéknyomok az úton: a paca színes foltokat hagy, amelyek elhalványulnak (`Trails`)
- [x] Épületrészletek: ablaksávok, ajtó, tetőperem; befestéskor az ablakok kivilágosodnak, a perem és az ajtó a festék sötétebb árnyalatát kapja
- [ ] Díszek a befestett épületen (virágládák, napellenzők, cégérek)
- [x] Hangok: placcs, festékfelvétel, ugrás, földet érés, a város elkészülte (`Sounds`, `tools/generate_sounds.py`)
- [x] A hangok feltöltése a Robloxra, az azonosítók beírása a `Config.SOUNDS`-ba
- [ ] Zenei rétegek: minél színesebb a város, annál több hangszer szól
- [ ] Színkeverés: két szín egymás után keverve új színt ad (pl. piros + kék = lila)

## 3. mérföldkő: PvP
- [ ] Csapatok (pl. 2 vagy 4 szín), a játékos a csapata színével fest
- [ ] Kerületek: amelyik csapat egy kerület épületeinek nagyobb részét festi be, azé a kerület
- [ ] Ütközés: ha nekigurulsz egy ellenfélnek, elveszed a festéke egy részét
- [ ] Rövid meccsek (5–8 perc), visszaszámlálás, eredménytábla, győztes csapat
- [ ] Lobby és meccs közti szavazás a pályára
- [ ] Csalás elleni alapvédelem (sebesség, teleportálás)

## 4. mérföldkő: PvE mód
- [ ] "Szürke" ellenségek, amelyek visszaszürkítik az épületeket
- [ ] Küldetések a városban (fesd ki a parkot, adott színű épületek)
- [ ] Több város és téma

## 5. mérföldkő: fejlődés és monetizáció
- [ ] DataStore mentés: szint, XP, valuta, feloldott kinézetek
- [ ] Kozmetikumbolt: pacaskinek, szemek, kalapok, festéknyomok, különleges színek (neon, csillámos, szivárvány)
- [ ] VIP Game Pass (dupla jutalom, egyedi névszín), privát szerverek
- [ ] Szezonbérlet ingyenes és fizetős sávval
- [ ] Szabály: csak kinézetet és kényelmet árulunk, erőt nem (nincs pay-to-win)

## Nyitott kérdések
- [ ] Végleges név (a "Paint Pop" csak munkacím)
