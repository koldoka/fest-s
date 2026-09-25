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
		-- Ablakképek (assets/textures, a tools/generate_textures.py készíti).
		FACADE = {
			GREY = "rbxassetid://115620819300161", -- window_grey.png: festetlen ház
			LIT = "rbxassetid://75949786836220", -- window_lit.png: befestett ház, meleg fényű ablakok
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

	-- Festéktartályok: véletlen helyen és színnel; egy használat után eltűnik, és RESPAWN mp múlva máshol jelenik
	-- meg egy új. Egyszerre MIN darab van a pályán, minden további játékossal PER_PLAYER-rel több, legfeljebb MAX.
	TANKS = {
		MIN = 20,
		MAX = 40,
		PER_PLAYER = 4,
		RESPAWN = 6,
	},

	-- Festés
	PAINT_MAX = 10, -- ennyi épületre elég egy teli tartály
	PAINT_REACH = 1.5, -- a paca felszínétől ennyire lévő dolgokat festi be / tölti fel belőlük (stud)
	PAINT_CHECK_INTERVAL = 0.1, -- ilyen gyakran nézi a szerver, mihez ér hozzá a játékos (mp)
	POINTS_PAINT = 10, -- pont egy szürke épület befestéséért

	-- A paca figura (BlobCharacter). Az átmérő a festék mennyiségével nő MIN_SIZE és MAX_SIZE között.
	BLOB = {
		MIN_SIZE = 3, -- nagyon nagy paca belelógna a falakba, mert a mozgáshoz az avatar teste ütközik
		MAX_SIZE = 4.5,
		EMPTY_COLOR = Color3.fromRGB(236, 236, 240), -- festék nélkül fehéres
	},

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
		CityDone = { ids = { "rbxassetid://125442387668911" }, volume = 0.7 }, -- az egész város színes
		Roll = { ids = { "rbxassetid://75367702913623" }, volume = 0.5 }, -- roll_loop.ogg: ismétlődő gurulás, a sebességgel hangosodik
	},

	-- Kör
	RESET_DELAY = 10, -- ennyi mp után lesz újra szürke a város, ha minden be van festve
}

-- Színnév -> szín, a gyors kereséshez
Config.PAINT_COLOR_BY_NAME = {}
for _, paint in Config.PAINT_COLORS do
	Config.PAINT_COLOR_BY_NAME[paint.name] = paint.color
end

return Config
