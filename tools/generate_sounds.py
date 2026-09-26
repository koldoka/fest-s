"""A játék hangjainak előállítása kódból (szintézis), nincs szükség külső hangfájlra.

Futtatás:  pip install numpy scipy soundfile  →  python tools/generate_sounds.py
Kimenet:   assets/sounds/*.ogg  (ezeket kell feltölteni a Robloxra, az azonosítókat a Config.SOUNDS-ba írni)

A "nedves" hangok alapja: sok apró buborék (felfelé csúszó, gyorsan lecsengő szinusz)
és sávszűrt zaj, amelynek a hangereje szabálytalanul rezeg (cuppogás).
"""

from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def t(duration):
    return np.arange(int(duration * RATE)) / RATE


def bandpass(signal, low, high):
    sos = butter(2, [low, high], btype="bandpass", fs=RATE, output="sos")
    return sosfilt(sos, signal)


def lowpass(signal, cutoff):
    sos = butter(2, cutoff, btype="lowpass", fs=RATE, output="sos")
    return sosfilt(sos, signal)


def sweeping_lowpass(signal, start_hz, end_hz):
    """Időben változó aluláteresztő (egypólusú), start_hz-ről end_hz-re csúszik."""
    cutoff = np.geomspace(start_hz, end_hz, len(signal))
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, x in enumerate(signal):
        acc += alpha[i] * (x - acc)
        out[i] = acc
    return out


def envelope(duration, attack, decay):
    time = t(duration)
    env = np.exp(-time / decay)
    attack_len = max(1, int(attack * RATE))
    env[:attack_len] *= np.linspace(0, 1, attack_len)
    return env


def bubble(f0, decay, rise=1.5):
    """Egy buborék pukkanása: gyorsan felfelé csúszó, lecsengő szinusz."""
    d = decay * 6
    time = t(d)
    freq = f0 * (1 + rise * time / d)
    tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE)
    return tone * envelope(d, 0.0015, decay)


def add(out, sound, start, wrap=False):
    """A hangot az out tömbbe keveri a start mp-től. wrap=True: a vége az elejére fordul (ismétlődő hanghoz)."""
    s = int(start * RATE)
    for i, x in enumerate(sound):
        j = s + i
        if j >= len(out):
            if not wrap:
                break
            j %= len(out)
        out[j] += x


def bubbles(rng, out, count, start, spread, f_range, decay_range, amp_range, wrap=False):
    for _ in range(count):
        b = bubble(rng.uniform(*f_range), rng.uniform(*decay_range), rng.uniform(0.8, 2.5))
        add(out, b * rng.uniform(*amp_range), start + rng.uniform(0, spread), wrap)


def flutter(rng, n, rate_hz, depth):
    """Szabálytalan hangerő-rezgés a cuppogáshoz."""
    points = int(n / RATE * rate_hz) + 2
    values = 1 - depth * rng.random(points)
    return np.interp(np.linspace(0, points - 1, n), np.arange(points), values)


def fade(signal, length=0.008):
    n = min(len(signal), int(length * RATE))
    signal[:n] *= np.linspace(0, 1, n)
    signal[-n:] *= np.linspace(1, 0, n)
    return signal


def save(name, signal, peak_db=-1.0, loop=False):
    signal = signal - np.mean(signal)
    if not loop:
        signal = fade(signal)
    signal = signal / np.max(np.abs(signal)) * 10 ** (peak_db / 20)
    path = OUT / f"{name}.ogg"
    sf.write(path, signal.astype(np.float32), RATE, format="OGG", subtype="VORBIS")
    print(f"{path.name}: {len(signal) / RATE:.2f} s")


def roll():
    # Szaftos gurulás, ismétlődő (loop) hang: halk, cuppogó zajalap + sok apró buborék.
    # A hossz egész számú "fordulatot" tartalmaz, és a buborékok a végén átfordulnak az elejére,
    # így a hang illesztés nélkül ismételhető.
    rng = np.random.default_rng(21)
    d = 2.0
    n = len(t(d))
    noise = rng.uniform(-1, 1, n * 3)
    bed = bandpass(noise, 150, 1400)[n : 2 * n]  # a középső harmad: nincs szűrő-bekapcsolódás a szélén
    turns = 12  # 6 fordulat / mp
    rolling = 0.45 + 0.55 * np.abs(np.sin(np.pi * turns * t(d) / d)) ** 2
    out = bed * rolling * flutter(rng, n, 30, 0.6) * 0.5
    bubbles(rng, out, 40, 0, d, (350, 1100), (0.006, 0.018), (0.15, 0.45), wrap=True)
    return out


def paint(seed):
    # Puha, nedves "placcs" épületfestéskor. Lassabb felfutás, kevesebb magas hang, mint korábban.
    rng = np.random.default_rng(seed)
    d = 0.45
    n = len(t(d))
    body = bandpass(rng.uniform(-1, 1, n), 250, rng.uniform(1800, 2600))
    body *= envelope(d, 0.008, rng.uniform(0.05, 0.08)) * flutter(rng, n, 45, 0.5)
    out = body * 1.2
    bubbles(rng, out, rng.integers(6, 11), 0.01, 0.14, (380, 1000), (0.008, 0.02), (0.2, 0.5))
    plop_d = 0.2
    freq = np.geomspace(rng.uniform(170, 230), 80, len(t(plop_d)))
    plop = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * envelope(plop_d, 0.004, 0.04)
    add(out, plop * 0.5, 0)
    return lowpass(out, 5000)


def jump():
    # Nedves "szlupp": felfelé nyíló szűrt zaj (mintha elszakadna a talajtól) + felfelé csúszó buborék.
    rng = np.random.default_rng(31)
    d = 0.35
    n = len(t(d))
    suction = sweeping_lowpass(rng.uniform(-1, 1, n), 300, 2800) * envelope(d, 0.01, 0.07)
    suction *= flutter(rng, n, 40, 0.5)
    out = suction * 2.0
    add(out, bubble(220, 0.05, rise=2.2) * 0.8, 0.015)
    bubbles(rng, out, 4, 0.03, 0.08, (500, 900), (0.006, 0.012), (0.15, 0.3))
    return out


def land():
    # Puha, nedves "placcs" földet éréskor: lecsukódó szűrt zaj, mély puffanás, utána pár buborék.
    rng = np.random.default_rng(41)
    d = 0.4
    n = len(t(d))
    splat = sweeping_lowpass(rng.uniform(-1, 1, n), 2600, 350) * envelope(d, 0.003, 0.06)
    splat *= flutter(rng, n, 50, 0.5)
    freq = np.geomspace(150, 55, n)
    thud = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * envelope(d, 0.002, 0.05)
    out = splat * 2.0 + thud * 0.7
    bubbles(rng, out, 7, 0.03, 0.15, (350, 900), (0.008, 0.018), (0.15, 0.35))
    return out


def city_done():
    # Vidám hangzat-futam: C-E-G-C, csilingelő felhangokkal
    d = 1.4
    out = np.zeros(len(t(d)))
    for i, freq in enumerate([523.25, 659.25, 783.99, 1046.5]):
        nd = d - i * 0.12
        time = t(nd)
        tone = np.sin(2 * np.pi * freq * time) + 0.35 * np.sin(2 * np.pi * freq * 2 * time)
        tone *= envelope(nd, 0.005, 0.35)
        add(out, tone, i * 0.12)
    return out


def sweep(start_hz, end_hz, duration, curve=4.0):
    """Szinusz, amelynek frekvenciája exponenciálisan csúszik start_hz-ről end_hz-re."""
    time = t(duration)
    freq = end_hz + (start_hz - end_hz) * np.exp(-curve * time / duration)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def refill():
    # Bugyborékoló "glugy-glugy": három felfelé csúszó buborék (változatlan, már fel van töltve)
    d = 0.5
    out = np.zeros(len(t(d)))
    for start, f0, f1 in [(0.0, 300, 700), (0.13, 380, 850), (0.26, 460, 1000)]:
        bd = 0.14
        add(out, sweep(f0, f1, bd, curve=3) * envelope(bd, 0.004, 0.05), start)
    return out


def tone(freq, duration, attack=0.005, decay=0.3, bright=0.35):
    """Egyszerű, csilingelő hang: alaphang + oktáv felhang, lecsengő burokkal."""
    time = t(duration)
    wave = np.sin(2 * np.pi * freq * time) + bright * np.sin(2 * np.pi * freq * 2 * time)
    return wave * envelope(duration, attack, decay)


def brass(freq, duration, attack=0.02, decay=0.5):
    """Rézfúvósszerű hang: sok felhang, lassabb felfutás, kis vibrato."""
    time = t(duration)
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * time)
    phase = 2 * np.pi * np.cumsum(freq * vibrato) / RATE
    wave = sum(np.sin(k * phase) / k**0.9 for k in range(1, 8))
    return lowpass(wave, 3200) * envelope(duration, attack, decay)


def steal():
    # Festéklopás (a lopónak): szívó "szlurp" felfelé nyíló szűrővel + felfelé csúszó buborékok
    rng = np.random.default_rng(51)
    d = 0.55
    n = len(t(d))
    suction = sweeping_lowpass(rng.uniform(-1, 1, n), 250, 3200) * envelope(d, 0.04, 0.18)
    suction *= flutter(rng, n, 35, 0.6)
    out = suction * 1.6
    for i, (f0, f1) in enumerate([(260, 620), (330, 780), (420, 980)]):
        bd = 0.13
        add(out, sweep(f0, f1, bd, curve=3) * envelope(bd, 0.004, 0.05) * 0.8, 0.05 + i * 0.11)
    return out


def stolen():
    # Meglopták (az áldozatnak): lefelé csúszó, leeresztő "blörp" és egy nedves placcs
    rng = np.random.default_rng(61)
    d = 0.6
    out = sweep(520, 140, d, curve=2.5) * envelope(d, 0.005, 0.2) * 0.8
    n = len(out)
    splat = sweeping_lowpass(rng.uniform(-1, 1, n), 2400, 300) * envelope(d, 0.002, 0.07)
    out += splat * 1.5
    bubbles(rng, out, 5, 0.05, 0.25, (250, 600), (0.01, 0.02), (0.1, 0.25))
    return out


def capture():
    # Kerület elfoglalva: rövid rézfúvós fanfár (G-C-E, majd hosszú G)
    d = 1.5
    out = np.zeros(len(t(d)))
    notes = [(0.0, 392.0, 0.14), (0.14, 523.25, 0.14), (0.28, 659.25, 0.14), (0.42, 783.99, 1.0)]
    for start, freq, length in notes:
        add(out, brass(freq, length + 0.1, decay=0.12 if length < 0.5 else 0.45), start)
        add(out, brass(freq / 2, length + 0.1, decay=0.12 if length < 0.5 else 0.45) * 0.4, start)
    return out


def unlock():
    # A kerület újra nyitott: két lefelé lépő, puha csengőhang
    d = 0.8
    out = np.zeros(len(t(d)))
    add(out, tone(880.0, 0.6, decay=0.18), 0)
    add(out, tone(659.25, 0.6, decay=0.22), 0.16)
    return out


def tick():
    # Visszaszámlálás: rövid, fa-kocogásszerű pittyenés
    return tone(1046.5, 0.12, attack=0.002, decay=0.03, bright=0.6)


def go():
    # Rajt: magasabb, hosszabb, fényes hang két oktávval
    d = 0.7
    out = tone(1567.98, d, attack=0.004, decay=0.25, bright=0.5)
    out += tone(783.99, d, attack=0.004, decay=0.3) * 0.6
    return out


def win():
    # Győzelem: dúr futam és egy kitartott dúr hármashangzat rézfúvóssal
    d = 2.4
    out = np.zeros(len(t(d)))
    for i, freq in enumerate([523.25, 659.25, 783.99]):
        add(out, brass(freq, 0.2, decay=0.1), i * 0.13)
    for freq in [523.25, 659.25, 783.99, 1046.5]:
        add(out, brass(freq, 1.9, attack=0.03, decay=0.8) * 0.6, 0.42)
    return out


def lose():
    # Vereség: lefelé lépő, tompa, kicsit szomorkás (de nem bántó) dallam
    d = 1.6
    out = np.zeros(len(t(d)))
    for i, freq in enumerate([392.0, 349.23, 311.13]):
        add(out, lowpass(brass(freq, 0.5, decay=0.25), 1500), i * 0.25)
    add(out, lowpass(brass(261.63, 0.9, decay=0.45), 1200), 0.75)
    return out


# ---------------------------------------------------------------------------------------------------
# Zene: négy egymásra rakható, egyforma hosszú, hézag nélkül ismételhető sáv (a kliens a város
# festettsége szerint hangosítja fel őket egymás után). 100 BPM, 8 ütem, C-dúr: C Am F G C Am F G.

BPM = 100
BEAT = 60 / BPM
BARS = 8
LOOP = BARS * 4 * BEAT
CHORDS = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]] * 2


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def loop_mix(events):
    """events: (kezdés mp, hanghullám) párok; a hurok végén túlnyúló rész az elejére fordul."""
    out = np.zeros(len(t(LOOP)))
    for start, wave in events:
        add(out, wave, start, wrap=True)
    return out


def music_pad():
    # Alap: puha, lassan nyíló akkordok (három enyhén elhangolt szinusz hangonként) és halk shaker
    rng = np.random.default_rng(71)
    events = []
    for bar, chord in enumerate(CHORDS):
        d = 4 * BEAT + 0.6
        time = t(d)
        env = np.minimum(1, time / 0.35) * np.exp(-np.maximum(0, time - 4 * BEAT) / 0.25)
        for note in chord:
            f = midi(note)
            wave = sum(np.sin(2 * np.pi * f * k * time) for k in (0.997, 1.0, 1.003)) / 3
            wave += 0.25 * np.sin(2 * np.pi * f * 2 * time)
            events.append((bar * 4 * BEAT, wave * env * 0.35))
    out = loop_mix(events)
    # Shaker nyolcadokon
    for i in range(BARS * 8):
        d = 0.08
        hit = bandpass(rng.uniform(-1, 1, len(t(d))), 4000, 9000) * envelope(d, 0.004, 0.02)
        add(out, hit * (0.12 if i % 2 else 0.2), i * BEAT / 2, wrap=True)
    return out


def music_bass():
    # Basszus: pengetős alaphangok az ütem 1. és 3. negyedén, közte egy nyolcad átvezetés
    events = []
    for bar, chord in enumerate(CHORDS):
        root = chord[0] - 24 if chord[0] >= 57 else chord[0] - 12
        for beat, note, length in [(0, root, 1.4), (2, root, 0.9), (3, root + 7, 0.45), (3.5, root + 12, 0.45)]:
            d = length * BEAT
            time = t(d + 0.1)
            f = midi(note)
            wave = np.sin(2 * np.pi * f * time) + 0.3 * np.sin(2 * np.pi * f * 2 * time)
            wave += 0.15 * np.sign(np.sin(2 * np.pi * f * time))
            env = envelope(d + 0.1, 0.005, d * 0.6)
            events.append((bar * 4 * BEAT + beat * BEAT, lowpass(wave, 900) * env * 0.8))
    return loop_mix(events)


def music_drums():
    # Dob: lábdob az 1. és 3., taps a 2. és 4. negyeden, lábcin nyolcadokon
    rng = np.random.default_rng(81)
    events = []
    for bar in range(BARS):
        base = bar * 4 * BEAT
        for beat in (0, 2):
            d = 0.35
            freq = np.geomspace(120, 45, len(t(d)))
            kick = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * envelope(d, 0.002, 0.09)
            events.append((base + beat * BEAT, kick * 1.0))
        for beat in (1, 3):
            d = 0.25
            clap = bandpass(rng.uniform(-1, 1, len(t(d))), 900, 4000) * envelope(d, 0.003, 0.06)
            events.append((base + beat * BEAT, clap * 0.6))
        for i in range(8):
            d = 0.06
            hat = bandpass(rng.uniform(-1, 1, len(t(d))), 6000, 12000) * envelope(d, 0.002, 0.015)
            events.append((base + i * BEAT / 2, hat * (0.25 if i % 2 else 0.35)))
    return loop_mix(events)


MELODY = [
    [(0, 76, 1), (1, 79, 0.5), (1.5, 76, 0.5), (2, 74, 1), (3, 72, 1)],
    [(0, 72, 0.5), (0.5, 74, 0.5), (1, 76, 1), (2, 81, 1), (3, 79, 1)],
    [(0, 81, 1), (1, 79, 0.5), (1.5, 77, 0.5), (2, 76, 1), (3, 72, 1)],
    [(0, 74, 1), (1, 76, 0.5), (1.5, 79, 1), (2.5, 74, 0.5), (3, 71, 1)],
    [(0, 76, 0.5), (0.5, 79, 0.5), (1, 84, 1), (2, 83, 0.5), (2.5, 79, 0.5), (3, 76, 1)],
    [(0, 81, 1), (1, 79, 0.5), (1.5, 76, 0.5), (2, 72, 1), (3, 76, 1)],
    [(0, 77, 1), (1, 81, 1), (2, 84, 1), (3, 81, 1)],
    [(0, 79, 1.5), (1.5, 77, 0.5), (2, 74, 1.5), (3.5, 71, 0.5)],
]


def music_melody():
    # Dallam: marimbaszerű, csilingelő hang (alaphang + 4-szeres felhang, gyors lecsengés)
    events = []
    for bar, notes in enumerate(MELODY):
        for beat, note, length in notes:
            d = max(0.35, length * BEAT) + 0.3
            time = t(d)
            f = midi(note)
            wave = np.sin(2 * np.pi * f * time) + 0.3 * np.sin(2 * np.pi * f * 4 * time) * np.exp(-time / 0.05)
            events.append((bar * 4 * BEAT + beat * BEAT, wave * envelope(d, 0.003, 0.28) * 0.7))
    return loop_mix(events)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in ["splat.ogg"]:  # a régi, túl erős festéshang helyett a paint_1..4 van
        (OUT / old).unlink(missing_ok=True)
    # A már feltöltött hangok csak akkor készülnek újra, ha hiányoznak (a kódolás minden futáskor picit más
    # fájlt ad, és az újrafeltöltés felesleges lenne). Egy hang újrakészítéséhez töröld a fájlját.
    if not (OUT / "roll_loop.ogg").exists():
        save("roll_loop", roll(), peak_db=-6, loop=True)
    for i in range(1, 5):
        if not (OUT / f"paint_{i}.ogg").exists():
            save(f"paint_{i}", paint(100 + i), peak_db=-7)
    if not (OUT / "jump.ogg").exists():
        save("jump", jump(), peak_db=-7)
    if not (OUT / "land.ogg").exists():
        save("land", land(), peak_db=-6)
    if not (OUT / "refill.ogg").exists():
        save("refill", refill(), peak_db=-5)
    if not (OUT / "city_done.ogg").exists():
        save("city_done", city_done(), peak_db=-4)
    # PvP hangok (ugyanígy: csak ha még nincsenek meg)
    for name, make, peak in [
        ("steal", steal, -5),
        ("stolen", stolen, -5),
        ("capture", capture, -4),
        ("unlock", unlock, -6),
        ("tick", tick, -8),
        ("go", go, -5),
        ("win", win, -4),
        ("lose", lose, -5),
    ]:
        if not (OUT / f"{name}.ogg").exists():
            save(name, make(), peak_db=peak)
    # Zenei rétegek (egyforma hosszúak, hurkolhatók)
    for name, make, peak in [
        ("music_pad", music_pad, -8),
        ("music_bass", music_bass, -8),
        ("music_drums", music_drums, -8),
        ("music_melody", music_melody, -9),
    ]:
        if not (OUT / f"{name}.ogg").exists():
            save(name, make(), peak_db=peak, loop=True)


if __name__ == "__main__":
    main()
