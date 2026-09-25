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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in ["splat.ogg"]:  # a régi, túl erős festéshang helyett a paint_1..4 van
        (OUT / old).unlink(missing_ok=True)
    save("roll_loop", roll(), peak_db=-6, loop=True)
    for i in range(1, 5):
        save(f"paint_{i}", paint(100 + i), peak_db=-7)
    save("jump", jump(), peak_db=-7)
    save("land", land(), peak_db=-6)
    # Ezek már fel vannak töltve; csak akkor készülnek újra, ha hiányoznak (a kódolás minden futáskor
    # picit más fájlt ad, és az újrafeltöltés felesleges lenne).
    if not (OUT / "refill.ogg").exists():
        save("refill", refill(), peak_db=-5)
    if not (OUT / "city_done.ogg").exists():
        save("city_done", city_done(), peak_db=-4)


if __name__ == "__main__":
    main()
