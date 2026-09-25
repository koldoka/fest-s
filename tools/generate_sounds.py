"""A játék hangjainak előállítása kódból (szintézis), nincs szükség külső hangfájlra.

Futtatás:  pip install numpy soundfile  →  python tools/generate_sounds.py
Kimenet:   assets/sounds/*.ogg  (ezeket kell feltölteni a Robloxra, az azonosítókat a Config.SOUNDS-ba írni)
"""

from pathlib import Path

import numpy as np
import soundfile as sf

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
rng = np.random.default_rng(11)  # fix mag: minden futás ugyanazt a hangot adja


def t(duration):
    return np.arange(int(duration * RATE)) / RATE


def lowpass(signal, cutoff):
    """Egypólusú aluláteresztő szűrő (a cutoff lehet időben változó tömb is)."""
    cutoff = np.broadcast_to(cutoff, signal.shape)
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, x in enumerate(signal):
        acc += alpha[i] * (x - acc)
        out[i] = acc
    return out


def sweep(start_hz, end_hz, duration, curve=4.0):
    """Szinusz, amelynek frekvenciája exponenciálisan csúszik start_hz-ről end_hz-re."""
    time = t(duration)
    freq = end_hz + (start_hz - end_hz) * np.exp(-curve * time / duration)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def envelope(duration, attack, decay):
    time = t(duration)
    env = np.exp(-time / decay)
    attack_len = max(1, int(attack * RATE))
    env[:attack_len] *= np.linspace(0, 1, attack_len)
    return env


def fade_out(signal, length=0.01):
    n = min(len(signal), int(length * RATE))
    signal[-n:] *= np.linspace(1, 0, n)
    return signal


def save(name, signal, peak_db=-1.0):
    signal = signal - np.mean(signal)
    signal = fade_out(signal)
    signal = signal / np.max(np.abs(signal)) * 10 ** (peak_db / 20)
    path = OUT / f"{name}.ogg"
    sf.write(path, signal.astype(np.float32), RATE, format="OGG", subtype="VORBIS")
    print(f"{path.name}: {len(signal) / RATE:.2f} s")


def splat():
    # Nedves "placcs": lecsúszó szűrt zajlöket + rövid, mély "plop"
    d = 0.35
    n = len(t(d))
    noise = lowpass(rng.uniform(-1, 1, n), np.linspace(6000, 400, n)) * envelope(d, 0.002, 0.07)
    plop = sweep(420, 90, d, curve=7) * envelope(d, 0.001, 0.05)
    return 1.6 * noise + 0.8 * plop


def refill():
    # Bugyborékoló "glugy-glugy": három felfelé csúszó buborék
    d = 0.5
    out = np.zeros(len(t(d)))
    for start, f0, f1 in [(0.0, 300, 700), (0.13, 380, 850), (0.26, 460, 1000)]:
        bd = 0.14
        bubble = sweep(f0, f1, bd, curve=3) * envelope(bd, 0.004, 0.05)
        s = int(start * RATE)
        out[s : s + len(bubble)] += bubble
    return out


def jump():
    # Rugós "boing": felfelé csúszó hang enyhe vibratóval
    d = 0.3
    time = t(d)
    freq = 180 + 520 * (1 - np.exp(-time / 0.08)) + 25 * np.sin(2 * np.pi * 18 * time)
    tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * envelope(d, 0.003, 0.1)
    return tone


def land():
    # Tompa "cupp": rövid, mély, szűrt zaj és egy lefelé csúszó hang
    d = 0.18
    n = len(t(d))
    noise = lowpass(rng.uniform(-1, 1, n), 700) * envelope(d, 0.001, 0.03)
    thud = sweep(160, 60, d, curve=5) * envelope(d, 0.001, 0.05)
    return 2.0 * noise + 0.9 * thud


def city_done():
    # Vidám hangzat-futam: C-E-G-C, csilingelő felhangokkal
    d = 1.4
    out = np.zeros(len(t(d)))
    for i, freq in enumerate([523.25, 659.25, 783.99, 1046.5]):
        nd = d - i * 0.12
        time = t(nd)
        tone = np.sin(2 * np.pi * freq * time) + 0.35 * np.sin(2 * np.pi * freq * 2 * time)
        tone *= envelope(nd, 0.005, 0.35)
        s = int(i * 0.12 * RATE)
        end = min(len(out), s + len(tone))
        out[s:end] += tone[: end - s]
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save("splat", splat(), peak_db=-3)
    save("refill", refill(), peak_db=-5)
    save("jump", jump(), peak_db=-7)
    save("land", land(), peak_db=-6)
    save("city_done", city_done(), peak_db=-4)


if __name__ == "__main__":
    main()
