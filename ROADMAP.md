# Paint Pop (munkacím): teendőlista

A haladás nyilvántartása. A kész pontokat `[x]`-szel jelöljük.

## 1. mérföldkő: prototípus
- [x] Projektváz: Rojo, StyLua, Config
- [x] Generált szürke város (később kézzel tervezett pályák váltották fel)
- [x] Festéktartályok a kereszteződésekben (6 szín)
- [x] Festés érintéssel, fogyó festék; a szerver dönt
- [x] Pontok (ranglista), a város festettsége a képernyő tetején
- [x] Fröccsenő festék és felvillanás festéskor
- [x] Újrakezdés, ha minden épület színes (a PvP-ben a meccsek körforgása váltotta fel)
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
- [x] Az új ablakképek feltöltése (7 kép), az azonosítók beírása (`BUILDINGS.WINDOWS`, `BUILDINGS.SHUTTERS`)
- [x] Festékár a szintek szerint: földszintes 3, kétszintes 6, három- vagy többszintes 10, tárgy 1; tartály 20 egység; figyelmeztetés, ha kevés; felugró "-N" a festés helyén
- [x] Javítások a Studio-teszt után: toronyóra nem lóg a tetőbe, rózsaablak az oromzatban, kirakat osztókkal, cégtábla felirattal, szélmalomlapát nem ér a tetőhöz, rendes széklábak
- [x] Térkép az M gombra (mobilon Map gomb, kontrolleren Select): házak a színükkel, utcák, folyó, fal, tartályok, játékosok (`MapView`)
- [x] Festékár csökkentve: 1 szint 1, 2 szint 3, 3+ szint 4, tárgy 1
- [x] Térképen a játékosok az avatarjuk arcképével, valós idejű helyzettel; szélmalom tengellyel a falhoz rögzítve; a pad támlája hátradől
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
- [x] Csapatok (alapból piros és kék, a `Config.TEAMS`-ben 4 is lehet), a játékos a csapata színével fest (`TeamService`)
- [x] Festékesvödör ecsettel a színes tartály helyett; semleges, mindenki a csapata színét veszi fel belőle
- [x] Az ellenfél házai átfesthetők (festékbe kerül, saját pont jár érte)
- [x] Kerületek: amelyik csapatnak több háza van egy kerületben, azé; teljes elfoglaláskor 60 mp-es lezárás (`DistrictService`); a kisvárosban 11 kerület
- [x] Festéklopás: nekigurulás (30%) és ráugrás (50%), hátrapattanás, 3 mp védettség (`StealService`, kliensen `Pvp`)
- [x] Rövid meccsek: 15 mp szünet, 7 perc játék, eredmény; visszaszámlálás, csapatpontok sávja, bejelentések, győztes (`MatchService`)
- [x] Térkép: kerületek a vezető csapat színével, házszám csapatonként, lezárás jelölése; a játékosok a csapatuk színével
- [x] Valósághűbb vödör: színes címke „PAINT” felirattal (betűnként a palásthoz simulva), színes csorgások, lapos ecset foglalattal és rojtos, festékes heggyel; a térképen 🪣
- [x] Vízbe lépve elvész a festék (folyó, tó, szökőkút)
- [x] A tárgyak is adnak csapatpontot: a csapatpont a csapat színében álló házak és tárgyak festékértéke + 10 kerületenként
- [ ] Hangolás hosszabb játék alapján: lopás, hátrapattanás, meccshossz, kerületbónusz
- [x] PvP-teszt a Studióban: minden működik
- [x] PvP játékérzet: kerülettáblák a pálya fölött, lezárt kerület csillogó fala, elfoglalási konfetti; rajt (3-2-1-GO), utolsó 10 mp visszaszámlálása, "1 minute left", eredménytábla konfettivel és a legjobb 3 festővel; névcímke festéksávval; lopáskor "+N", piros villanás, kamerarázás (`Districts`, `Results`, `Pvp`)
- [x] Saját hangok (`tools/generate_sounds.py`): lopás, meglopva, elfoglalás, feloldás, visszaszámlálás, rajt, győzelem, vereség
- [x] Az új PvP-hangok feltöltése (8 fájl), az azonosítók beírása a `Config.SOUNDS`-ba
- [x] Friss festék: befestés után 5 mp-ig nem festhető át (`Config.PAINT_PROTECT`)
- [x] A friss festék látszik: "WET PAINT" tábla fogyó sávval, csöpögő falak, száradó fényes fal (`Effects`)
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
