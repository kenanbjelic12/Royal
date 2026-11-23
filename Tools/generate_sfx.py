#!/usr/bin/env python3
"""Synthesises all game sound effects and music loops as 16-bit mono WAVs.

Everything is generated procedurally (no third-party samples), so the audio is
original and license-free. Run: python3 Tools/generate_sfx.py
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Audio")
random.seed(42)


FORCE = "--force" in sys.argv


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    # never overwrite the ElevenLabs sounds / music that replaced these placeholders
    if os.path.exists(os.path.join(OUT, name + ".wav")) and not FORCE:
        return
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.89 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))


def env(t, a, d, total):
    if t < a:
        return t / a
    return max(0.0, 1.0 - (t - a) / max(1e-6, d)) if t < total else 0.0


def noise():
    return random.uniform(-1, 1)


class LP:
    def __init__(self, k):
        self.k = k
        self.y = 0.0

    def __call__(self, x, k=None):
        self.y += (k if k is not None else self.k) * (x - self.y)
        return self.y


def tone(freq_fn, dur, wave_fn=math.sin, amp_fn=None):
    out, ph = [], 0.0
    n = int(dur * SR)
    for i in range(n):
        t = i / SR
        ph += 2 * math.pi * freq_fn(t) / SR
        out.append(wave_fn(ph) * (amp_fn(t) if amp_fn else 1.0))
    return out


def square(ph):
    return 1.0 if math.sin(ph) >= 0 else -1.0


def tri(ph):
    return 2 / math.pi * math.asin(math.sin(ph))


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def swoosh(dur, lo, hi, amp=1.0):
    lp = LP(0.1)
    out = []
    n = int(dur * SR)
    for i in range(n):
        t = i / SR
        k = lo + (hi - lo) * math.sin(math.pi * t / dur)
        out.append(lp(noise(), k) * math.sin(math.pi * t / dur) * amp)
    return out


def thump(dur, f0, f1, amp=1.0):
    return tone(lambda t: f0 + (f1 - f0) * t / dur, dur, math.sin, lambda t: math.exp(-t * 9 / dur) * amp)


def silence(d):
    return [0.0] * int(d * SR)


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def sfx():
    # weapon attacks
    write("fire_slash", mix(swoosh(0.32, 0.05, 0.5), [s * 0.5 for s in swoosh(0.45, 0.02, 0.12)], thump(0.2, 180, 60, 0.5)))
    write("dagger", mix(swoosh(0.14, 0.2, 0.9, 0.8), seq(silence(0.07), swoosh(0.13, 0.25, 0.95, 0.7)),
                        tone(lambda t: 3200 - 4000 * t, 0.12, math.sin, lambda t: math.exp(-t * 30) * 0.25)))
    write("rock_slam", mix(thump(0.6, 90, 35, 1.0), [LP(0.05)(noise()) * math.exp(-i / SR * 6) for i in range(int(0.6 * SR))]))
    write("ice_shot", mix(tone(lambda t: 1400 + 1800 * t, 0.25, tri, lambda t: math.exp(-t * 9) * 0.6),
                          tone(lambda t: 2100 + 2400 * t, 0.25, math.sin, lambda t: math.exp(-t * 12) * 0.4),
                          swoosh(0.25, 0.3, 0.7, 0.3)))
    write("ice_hit", mix(*[seq(silence(k * 0.03), tone(lambda t, f=2400 + k * 700: f, 0.18, math.sin, lambda t: math.exp(-t * 25) * 0.5)) for k in range(5)],
                         [noise() * math.exp(-i / SR * 30) * 0.4 for i in range(int(0.2 * SR))]))
    write("poison_cast", mix(tone(lambda t: 300 + 500 * t + 60 * math.sin(t * 60), 0.4, tri, lambda t: env(t, 0.05, 0.35, 0.4) * 0.5),
                             swoosh(0.4, 0.05, 0.3, 0.4)))
    bub = []
    for k in range(6):
        f = random.uniform(400, 900)
        bub = mix(bub, seq(silence(k * 0.05), tone(lambda t, f=f: f + 1500 * t, 0.06, math.sin, lambda t: math.exp(-t * 40) * 0.6)))
    write("poison_hit", mix(bub, [LP(0.08)(noise()) * math.exp(-i / SR * 10) * 0.6 for i in range(int(0.3 * SR))]))
    write("arrow", mix(swoosh(0.12, 0.3, 0.8, 0.6), tone(lambda t: 900 - 600 * t, 0.08, tri, lambda t: math.exp(-t * 50) * 0.5)))
    write("cannon", mix(thump(0.45, 120, 40, 1.0), [LP(0.2)(noise()) * math.exp(-i / SR * 14) for i in range(int(0.4 * SR))]))
    write("cannon_hit", mix(thump(0.3, 160, 50, 0.8), [LP(0.3)(noise()) * math.exp(-i / SR * 18) * 0.7 for i in range(int(0.3 * SR))]))
    write("hit", mix(thump(0.12, 240, 90, 0.8), [noise() * math.exp(-i / SR * 50) * 0.4 for i in range(int(0.12 * SR))]))
    write("death", mix(tone(lambda t: 700 - 500 * t, 0.35, square, lambda t: math.exp(-t * 7) * 0.25),
                       [LP(0.15)(noise()) * math.exp(-i / SR * 8) * 0.5 for i in range(int(0.4 * SR))]))
    write("deploy", mix(thump(0.25, 200, 70, 0.9), tone(lambda t: 500 + 900 * t, 0.2, math.sin, lambda t: math.exp(-t * 14) * 0.4),
                        [LP(0.1)(noise()) * math.exp(-i / SR * 12) * 0.4 for i in range(int(0.3 * SR))]))
    write("card_select", tone(lambda t: 880 if t < 0.05 else 1320, 0.12, tri, lambda t: math.exp(-t * 20)))
    write("button", tone(lambda t: 660 + 400 * (t > 0.03), 0.09, tri, lambda t: math.exp(-t * 30)))
    write("error", tone(lambda t: 180, 0.22, square, lambda t: (0.6 if (t % 0.11) < 0.08 else 0) * math.exp(-t * 4)))
    write("king_wake", seq(*[tone(lambda t, f=f: f, 0.11, tri, lambda t: math.exp(-t * 10)) for f in (523, 659, 784)]))
    write("tower_destroyed", mix(thump(1.0, 80, 30, 1.0), [LP(0.04)(noise()) * math.exp(-i / SR * 3) for i in range(int(1.2 * SR))],
                                 seq(silence(0.15), [LP(0.3)(noise()) * math.exp(-i / SR * 5) * 0.6 for i in range(int(0.8 * SR))])))
    write("coin", mix(tone(lambda t: 1568 if t < 0.06 else 2093, 0.25, math.sin, lambda t: math.exp(-t * 12) * 0.7),
                      tone(lambda t: 3136, 0.25, math.sin, lambda t: math.exp(-t * 20) * 0.2)))
    write("chest_open", mix(thump(0.3, 140, 60, 0.7),
                            seq(silence(0.15), *[tone(lambda t, f=f: f, 0.09, math.sin, lambda t: math.exp(-t * 14) * 0.6) for f in (784, 988, 1175, 1568, 1976)])))
    # jingles
    def notes(seq_notes, bpm=150, wf=tri, decay=6.0):
        out = []
        beat = 60.0 / bpm
        for f, b in seq_notes:
            d = b * beat
            if f <= 0:
                out += silence(d)
            else:
                out += tone(lambda t, f=f: f, d, wf, lambda t, d=d: env(t, 0.01, d, d) * math.exp(-t * decay * 0.3))
        return out
    C5, D5, E5, F5, G5, A5, B5, C6 = 523, 587, 659, 698, 784, 880, 988, 1047
    vic = mix(notes([(G5, 0.5), (C6, 0.5), (E5 * 2, 0.5), (G5 * 2, 1.5), (E5 * 2, 0.5), (G5 * 2, 2.0)], 140),
              notes([(C5, 1.5), (E5, 1.5), (G5, 3.0)], 140, math.sin))
    write("victory", vic)
    write("defeat", mix(notes([(G5, 0.75), (F5, 0.75), (E5, 0.75), (C5 * 0.75, 2.5)], 110, tri, 3.0),
                        notes([(C5 * 0.5, 2.25), (C5 * 0.375, 2.5)], 110, math.sin)))


def music(name, bpm, chords, bars, lead_scale, seed):
    random.seed(seed)
    beat = 60.0 / bpm
    total = int(bars * 4 * beat * SR)
    out = [0.0] * total
    def add(start, samples, amp):
        s0 = int(start * SR)
        for i, v in enumerate(samples):
            if s0 + i < total:
                out[s0 + i] += v * amp
    for bar in range(bars):
        root = chords[bar % len(chords)]
        t0 = bar * 4 * beat
        # bass
        for b in range(4):
            f = root / 2
            add(t0 + b * beat, tone(lambda t, f=f: f, beat * 0.9, tri, lambda t: math.exp(-t * 3)), 0.35)
        # plucked arpeggio
        for k in range(8):
            f = root * [1, 1.25, 1.5, 2, 1.5, 1.25, 1, 1.5][k]
            add(t0 + k * beat / 2, tone(lambda t, f=f: f, beat * 0.5, math.sin, lambda t: math.exp(-t * 9)), 0.18)
        # kick + hat
        for b in range(4):
            add(t0 + b * beat, thump(0.18, 110, 45, 1.0), 0.32)
            add(t0 + b * beat + beat / 2, [noise() * math.exp(-i / SR * 60) for i in range(int(0.05 * SR))], 0.08)
        # simple lead melody every other bar
        if bar % 2 == 1:
            for k in range(4):
                f = root * 2 * random.choice(lead_scale)
                add(t0 + k * beat, tone(lambda t, f=f: f, beat * 0.8, tri, lambda t: env(t, 0.02, beat * 0.8, beat) * 0.8), 0.12)
    write("music_" + name, out)


if __name__ == "__main__":
    sfx()
    music("battle", 132, [262, 220, 175, 196], 16, [1, 1.125, 1.25, 1.5, 1.6875], 3)
    music("menu", 100, [262, 330, 220, 196], 8, [1, 1.25, 1.5, 2], 5)
    print("audio written to", os.path.abspath(OUT))
