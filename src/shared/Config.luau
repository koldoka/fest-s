-- Minden játékbeállítás egy helyen. Itt érdemes hangolni a játékérzetet.

local Config = {
	-- Melyik pálya töltődjön be (src/server/Levels/<név>.luau)
	LEVEL = "SmallTown",

	-- Épületek (a Kit építi fel őket a pályaleírás alapján). A magasság mindig egész számú emelet.
	BUILDINGS = {
		FLOOR_HEIGHT = 6, -- ennyi stud egy emelet
		BAY_WIDTH = 6, -- nagyjából ilyen széles egy ablakos falszakasz (elöl és hátul)
		SIDE_BAY_FACTOR = 1.7, -- az oldalfalakon ennyiszer szélesebb (ritkábbak az ablakok)
		GREY = Color3.fromRGB(128, 128, 132), -- a festetlen épületek színe
		GREY_VARIANCE = 12, -- ennyivel térhet el véletlenszerűen a szürke árnyalata
		-- Ablakok: "decal" = ablakonként egy lap a rajzolt ablakképpel (alap);
		-- "3d" = keret, üveg, párkány külön alkatrészekből (háromszor annyi alkatrész);
		-- "texture" = az egész falra feszített kép (a legkevesebb alkatrész, de az ajtók mögött is van ablak).
		WINDOW_MODE = "decal",
		-- Ablakképek (assets/textures, a tools/generate_textures.py készíti). Mindegyik szürke (festetlen) és
		-- kivilágított (befestett) változatban. Ami még üres, ott a FACADE régi képe látszik.
		WINDOWS = {
			-- window_classic_grey.png, window_classic_lit.png
			classic = { grey = "rbxassetid://126750374345516", lit = "rbxassetid://75102740074434" },
			-- window_curtain_*.png: függönnyel, virágládával
			curtain = { grey = "rbxassetid://104866367880237", lit = "rbxassetid://125613555917244" },
			-- window_tall_*.png: magas, íves (templom, városháza)
			tall = { grey = "rbxassetid://91938070754489", lit = "rbxassetid://98292753643780" },
		},
		SHUTTERS = "rbxassetid://99631545557841", -- shutters.png: zsalugáterek (a játék színezi); amíg üres, alkatrészekből
		FACADE = {
			GREY = "rbxassetid://115620819300161", -- window_grey.png: a régi ablakkép (tartalék)
			LIT = "rbxassetid://75949786836220", -- window_lit.png
		},
		DOOR_SIZE = Vector2.new(3, 5), -- szélesség, magasság
		-- Befestve fix színű részletek (a többi a festék színéből számolódik, lásd PaintService)
		WINDOW_LIT_COLOR = Color3.fromRGB(255, 226, 140),
		ROOF_COLORS = {
			Color3.fromRGB(184, 78, 60), -- cserép
			Color3.fromRGB(88, 100, 124), -- pala
			Color3.fromRGB(72, 124, 92), -- zöld
			Color3.fromRGB(126, 76, 58), -- barna
		},
		DOOR_COLORS = {
			Color3.fromRGB(124, 82, 50), -- fa
			Color3.fromRGB(42, 88, 64),
			Color3.fromRGB(44, 60, 104),
			Color3.fromRGB(156, 44, 44),
		},
		CHIMNEY_COLOR = Color3.fromRGB(168, 84, 64),
		RAILING_COLOR = Color3.fromRGB(58, 58, 68),
		METAL_COLOR = Color3.fromRGB(150, 154, 160),
	},

	-- Festékek. A festéktartályok ezekből a színekből kapnak, sorban.
	PAINT_COLORS = {
		{ name = "Red", color = Color3.fromRGB(235, 64, 64) },
		{ name = "Yellow", color = Color3.fromRGB(252, 206, 46) },
		{ name = "Blue", color = Color3.fromRGB(56, 128, 240) },
		{ name = "Green", color = Color3.fromRGB(70, 200, 96) },
		{ name = "Purple", color = Color3.fromRGB(164, 92, 224) },
		{ name = "Orange", color = Color3.fromRGB(250, 140, 40) },
	},

	-- Csapatok (PvP): a nevek a PAINT_COLORS-ból valók, a csapat ezzel a színnel fest. 4 csapathoz elég ide
	-- felvenni még kettőt, pl. { name = "Yellow" }, { name = "Green" }.
	TEAMS = {
		{ name = "Red" },
		{ name = "Blue" },
	},

	-- Festékesvödrök: véletlen helyen; egy használat után eltűnik, és RESPAWN mp múlva máshol jelenik
	-- meg egy új. Egyszerre MIN darab van a pályán, minden további játékossal PER_PLAYER-rel több, legfeljebb MAX.
	TANKS = {
		MIN = 20,
		MAX = 40,
		PER_PLAYER = 4,
		RESPAWN = 6,
	},

	-- Festés
	PAINT_MAX = 20, -- egy teli tartály ennyi egység festék
	PAINT_REACH = 1.5, -- a paca felszínétől ennyire lévő dolgokat festi be / tölti fel belőlük (stud)
	PAINT_PROTECT = 5, -- befestés után ennyi mp-ig más csapat nem festheti át a házat (friss festék)
	PAINT_CHECK_INTERVAL = 0.1, -- ilyen gyakran nézi a szerver, mihez ér hozzá a játékos (mp)
	-- Festékár: földszintes ház SMALL, kétszintes MEDIUM, három- vagy többszintes LARGE, tárgy PROP.
	PAINT_COST = {
		SMALL = 1,
		MEDIUM = 3,
		LARGE = 4,
		PROP = 1,
	},
	POINTS_PER_PAINT = 5, -- saját pont (ranglista) minden elfestett egységért, átfestésért is

	-- A paca figura (BlobCharacter). Az átmérő a festék mennyiségével nő MIN_SIZE és MAX_SIZE között.
	BLOB = {
		MIN_SIZE = 3, -- nagyon nagy paca belelógna a falakba, mert a mozgáshoz az avatar teste ütközik
		MAX_SIZE = 4.5,
		EMPTY_COLOR = Color3.fromRGB(236, 236, 240), -- festék nélkül fehéres
	},

	AMBIENT = true, -- élő környezet: ringó fák, csillogó, fodrozódó víz, spriccelő szökőkút (csak látvány, kliens)
	DECOR_FLOWER_BOXES = true, -- a befestett házak néhány ablaka alá virágláda kerül (csak látvány, kliens)

	-- Mozgás: a paca gyors és pattogós
	WALK_SPEED = 24,
	JUMP_POWER = 60,

	-- Festékcsík a paca után (csak látvány, a klienseken)
	TRAIL = {
		WIDTH = 0.5, -- a csík szélessége a paca átmérőjéhez képest
		SEGMENT_LENGTH = 0.8, -- ennyi stud után tesz le új csíkdarabot (kisebb = simább kanyarok)
		SPLATTER_CHANCE = 0.25, -- ekkora eséllyel fröccsen pár apró csepp egy csíkdarab mellé
		BLOB_CHANCE = 0.08, -- ekkora eséllyel kerül egy nagyobb csepp a csíkba
		LIFETIME = 8, -- ennyi mp alatt szárad fel (vékonyodik el és tűnik el) a csík
		MAX_MARKS = 900, -- ennél több darab esetén a legrégebbi eltűnik
	},

	-- Hangok (assets/sounds/*.ogg, a tools/generate_sounds.py készíti). Feltöltés után ide kell beírni
	-- az azonosítókat "rbxassetid://SZÁM" formában. Több azonosító esetén lejátszáskor véletlenszerűen választ.
	-- Üres lista = nincs hang.
	SOUNDS = {
		-- Épület befestése: paint_1..4.ogg, véletlenszerűen
		Paint = {
			ids = {
				"rbxassetid://90741859902412",
				"rbxassetid://84857459118539",
				"rbxassetid://96482009124283",
				"rbxassetid://131710288937929",
			},
			volume = 0.45,
			vary = true,
		},
		Refill = { ids = { "rbxassetid://124300779326945" }, volume = 0.5 }, -- festék felvétele
		Jump = { ids = { "rbxassetid://108980992543334" }, volume = 0.35, vary = true },
		Land = { ids = { "rbxassetid://129774262633784" }, volume = 0.45, vary = true },
		CityDone = { ids = { "rbxassetid://125442387668911" }, volume = 0.7 }, -- a meccs vége (győztes)
		Roll = { ids = { "rbxassetid://75367702913623" }, volume = 0.5 }, -- roll_loop.ogg: ismétlődő gurulás, a sebességgel hangosodik
		-- PvP
		Steal = { ids = { "rbxassetid://116148583301394" }, volume = 0.6 }, -- steal.ogg: te loptál festéket
		Stolen = { ids = { "rbxassetid://73959400048175" }, volume = 0.6 }, -- stolen.ogg: tőled loptak
		Capture = { ids = { "rbxassetid://135356805004270" }, volume = 0.6 }, -- capture.ogg: egy kerület lezárult (teljes elfoglalás)
		Unlock = { ids = { "rbxassetid://77869124313182" }, volume = 0.45 }, -- unlock.ogg: a kerület újra nyitott
		Tick = { ids = { "rbxassetid://131059209706725" }, volume = 0.5 }, -- tick.ogg: visszaszámlálás
		Go = { ids = { "rbxassetid://132287258180915" }, volume = 0.6 }, -- go.ogg: a meccs indul
		Win = { ids = { "rbxassetid://99102616948967" }, volume = 0.7 }, -- win.ogg: a csapatod nyert
		Lose = { ids = { "rbxassetid://74527392621971" }, volume = 0.6 }, -- lose.ogg: a csapatod vesztett
	},

	-- Zene (Music, kliens): négy egymásra rakott, egyforma hosszú sáv (tools/generate_sounds.py). Az alap mindig
	-- szól; a többi akkor erősödik fel, amikor a város ekkora része (0..1) már színes. A meccs végén mind szól.
	MUSIC = {
		VOLUME = 0.45, -- a zene hangereje összesen
		FADE = 2.5, -- ennyi mp alatt erősödik fel vagy halkul el egy réteg
		LAYERS = {
			{ name = "Pad", id = "", from = 0, volume = 0.8 }, -- music_pad.ogg: akkordok, shaker
			{ name = "Bass", id = "", from = 0.1, volume = 0.8 }, -- music_bass.ogg
			{ name = "Drums", id = "", from = 0.3, volume = 0.9 }, -- music_drums.ogg
			{ name = "Melody", id = "", from = 0.55, volume = 0.7 }, -- music_melody.ogg
		},
	},

	-- Kerületek (PvP, a pálya Level.districts listája alapján)
	DISTRICTS = {
		LOCK_TIME = 60, -- ha egy csapat a kerület minden házát befestette, ennyi mp-ig senki nem festhet benne
		-- Csapatpont: a csapat színében álló házak és tárgyak festékértéke (PAINT_COST), és ennyi minden
		-- kerületért, ahol a csapatnak van a legtöbb háza
		BONUS = 10,
	},

	-- Festéklopás (PvP): ha két ellenfél paca összeér
	STEAL = {
		RAM = 0.3, -- nekigurulás: a gyorsabb elveszi a másik festékének ekkora részét
		STOMP = 0.5, -- ráugrás felülről: ekkora részét
		MIN = 2, -- legalább ennyi egységet (ha van annyi)
		IMMUNITY = 3, -- akitől loptak, ennyi mp-ig nem lehet újra meglopni
		KNOCKBACK = 45, -- a meglopott paca ekkora sebességgel pattan hátra
		REACH = 0.5, -- a két paca felszíne között ennyi hézag még ütközésnek számít (stud)
		MIN_SPEED = 8, -- nekiguruláshoz legalább ekkora sebességgel kell a másik felé menni
		STOMP_FALL_SPEED = 5, -- ráugráshoz legalább ekkora sebességgel kell esni
	},

	-- Csalás elleni alapvédelem (AntiCheatService): a lehetetlen mozgást visszahúzza
	ANTICHEAT = {
		ENABLED = true,
		INTERVAL = 0.25, -- ilyen gyakran nézi a mozgást (mp)
		SPEED_FACTOR = 1.6, -- a megengedett vízszintes sebesség: WALK_SPEED ennyiszerese
		MAX_RISE_SPEED = 80, -- felfelé legfeljebb ennyi stud/mp (az ugrás kb. 60)
		TOLERANCE = 6, -- ennyi stud ráhagyás a hálózati késés miatt
		MAX_AIR_TIME = 2.5, -- ennyi mp-nél tovább nem lehet magasan lebegni esés nélkül
		STRIKE_WINDOW = 30, -- ennyi mp-en belüli szabálysértéseket számolja
		KICK_STRIKES = 15, -- ennyi szabálysértés után kirúgja (0 = soha)
		LOG = true, -- szabálysértéskor figyelmeztetés az Output ablakba
	},

	-- Meccs (PvP)
	MATCH = {
		INTERMISSION = 15, -- szünet a meccsek között (mp); ilyenkor nem lehet festeni
		LENGTH = 420, -- egy meccs hossza (mp)
		RESULTS = 10, -- ennyi ideig látszik az eredmény
	},
}

-- Színnév -> szín, a gyors kereséshez
Config.PAINT_COLOR_BY_NAME = {}
for _, paint in Config.PAINT_COLORS do
	Config.PAINT_COLOR_BY_NAME[paint.name] = paint.color
end

return Config
