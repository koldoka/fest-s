-- Minden játékbeállítás egy helyen. Itt érdemes hangolni a játékérzetet.

local Config = {
	-- Város (a CityBuilder építi fel)
	CITY = {
		GRID = 6, -- ennyi háztömb van egy sorban és egy oszlopban
		BLOCK_SIZE = 40, -- egy háztömb oldalhossza (stud)
		STREET_WIDTH = 16,
		SIDEWALK = 3, -- a járda szélessége a tömb szélén
		LOTS = 2, -- egy tömbben ennyiszer ennyi épület áll
		LOT_GAP = 3, -- rés az épületek között (a játékos átfér rajta)
		MIN_HEIGHT = 10,
		MAX_HEIGHT = 36,
		MARGIN = 40, -- aszfalt a város körül
		GREY = Color3.fromRGB(128, 128, 132), -- a festetlen épületek színe
		GREY_VARIANCE = 12, -- ennyivel térhet el véletlenszerűen a szürke árnyalata
		ASPHALT = Color3.fromRGB(58, 58, 62),
		SIDEWALK_COLOR = Color3.fromRGB(170, 170, 170),
		-- Épületrészletek: ablaksávok emeletenként, ajtó, tetőperem. Festetlenül a szürke sötétebb árnyalatai,
		-- befestve az ablakok kivilágosodnak, a perem és az ajtó a festék sötétebb árnyalatát kapja.
		FLOOR_HEIGHT = 6, -- ennyi stud egy emelet
		WINDOW_BAND_HEIGHT = 2.5,
		WINDOW_LIT_COLOR = Color3.fromRGB(255, 244, 210),
		DOOR_SIZE = Vector2.new(3, 5), -- szélesség, magasság
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

	-- Festéknyomok az úton (csak látvány, a klienseken)
	TRAIL = {
		SPACING = 0.6, -- a paca átmérőjének ekkora része után tesz új foltot
		SIZE = 0.8, -- a folt átmérője a paca átmérőjéhez képest
		LIFETIME = 8, -- ennyi mp alatt tűnik el egy folt
		MAX_MARKS = 400, -- ennél több folt esetén a legrégebbi eltűnik
	},

	-- Hangok (assets/sounds/*.ogg, a tools/generate_sounds.py készíti). Feltöltés után ide kell beírni
	-- az azonosítót "rbxassetid://SZÁM" formában. Üres = nincs hang.
	SOUNDS = {
		Splat = { id = "", volume = 0.6, vary = true }, -- épület befestése
		Refill = { id = "", volume = 0.5 }, -- festék felvétele
		Jump = { id = "", volume = 0.35, vary = true },
		Land = { id = "", volume = 0.45, vary = true },
		CityDone = { id = "", volume = 0.7 }, -- az egész város színes
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
