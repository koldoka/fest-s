# Paint Pop (munkacím): teendőlista

A haladás nyilvántartása. A kész pontokat `[x]`-szel jelöljük.

## 1. mérföldkő: prototípus
- [x] Projektváz: Rojo, StyLua, Config
- [x] Generált szürke város (később kézzel tervezett pályák váltották fel)
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
- [x] Festékcsík: folytonos csík apró fröccsenésekkel, földet éréskor nagyobb fröccs; felszáradva elvékonyodik (`Trails`)
- [x] Simább festékcsík: a szélesség lassan hullámzik, rövidebb darabok, néha nagyobb csepp, sötétebb nedves szín
- [x] Épületrészletek: ablaksávok, ajtó, tetőperem; befestéskor az ablakok kivilágosodnak, a perem és az ajtó a festék sötétebb árnyalatát kapja
- [x] Élethűbb, rajzfilmes épületek: nyeregtető kéménnyel, kirakat csíkos napellenzővel, erkélyek, felső emelet kereszttetővel, óra; lábazat, párkány (`Kit.building`)
- [x] Rajzolt ablaktextúrák (szürke és kivilágított), `tools/generate_textures.py`
- [x] Az ablakképek feltöltése; ablakonként egy lap a képpel (`WINDOW_MODE = "decal"`), befestve kivilágított változat
- [x] Kézzel tervezett pályák a generált város helyett: építőkészlet (`Kit`), pályabetöltő (`LevelLoader`)
- [x] 1. pálya: Kisváros főtérrel (templom óratoronnyal, kávézók, piac utca városkapuval, kertes lakóutca, lépcsős terasz kilátótoronnyal, park tavacskával és pavilonnal)
- [x] Tárgyak (fák, padok, lámpák, szökőkút, standok, kerítések…): érintésre visszakapják a színüket
- [x] Új tetők: oromfal a ház színében, két tetősík cseréppel, ereszcsatorna, gerinccserép (a régi rombuszos tető helyett)
- [x] Részletesebb, változatosabb házak: fal anyaga (vakolat, tégla, deszka, kő), keretezett ablakok, zsalugáterek, díszsávok, sarokpillérek, előtető és lépcső az ajtónál, cégtábla, rózsaablak, lapos tetőn lépcsőház és klímadobozok
- [x] Ahol egy másik ház közvetlenül előtte áll, oda nem kerül ablak (kevesebb alkatrész)
- [x] Tárgyak a festék színében: lomb, ülőke, lámpaoszlop, kerítés, napernyő, ponyva, pavilontető; át is festhetők
- [x] Nagyobb pálya: folyó három híddal, szélmalmos domb tanyával és virágfölddel, folyóparti negyed rakparttal, városháza tér szoborral (83 ház)
- [x] Pálya-előnézet a Studio nélkül (`tools/preview`)
- [x] Városfal a pálya szélén (lőrések, festhető tornyok, bezárt kapuk, láthatatlan magas fal), kívül erdő
- [x] Organikus elrendezés: kanyargó utcák, sikátorok, a házak az utcák mentén (`Kit.path`, `Kit.streetRow`)
- [x] Nincs üres terület: telkenkénti témák (gyümölcsös, veteményeskert fészerrel, vadvirágos rét, liget, termőföld, udvar) (`Kit.fill`)
- [x] Kevesebb ablak (szélesebb falszakaszok, az oldalfalakon ritkábban)
- [x] Festéktartályok véletlen helyen és színnel, használat után máshol jelennek meg (`TankService`); 108 lehetséges hely, egyszerre 20–40 (a játékosszámtól függ)
- [x] Oromfal két ékből: a fal anyagának mintája (tégla, deszka) vízszintes marad (a ferde minta helyett)
- [x] Részletesebb ablakképek: klasszikus, függönyös virágládával, magas íves; a zsalugáter is kép a festék színében (ablakonként 1 alkatrész)
- [ ] Az új ablakképek feltöltése (7 kép), az azonosítók beírása (`BUILDINGS.WINDOWS`, `BUILDINGS.SHUTTERS`)
- [x] Festékár méret szerint: kis ház 3, közepes 6, nagy 10, tárgy 1; tartály 20 egység; figyelmeztetés, ha kevés
- [ ] 1. pálya finomítása a Studio-teszt alapján
- [ ] A szélmalom lapátjai forogjanak
- [ ] További pályák
- [ ] Díszek a befestett épületen (virágládák, cégérek)
- [x] Hangok: placcs, festékfelvétel, ugrás, földet érés, a város elkészülte (`Sounds`, `tools/generate_sounds.py`)
- [x] A hangok feltöltése a Robloxra, az azonosítók beírása a `Config.SOUNDS`-ba
- [x] Nedvesebb hangok: szaftos gurulás (sebességfüggő, ismétlődő), cuppanós ugrás és földet érés, 4 finomabb festéshang véletlenszerűen; a Roblox lépéshangjai kikapcsolva
- [x] Az új hangok feltöltése (roll_loop, paint_1..4, jump, land), az azonosítók beírása
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
