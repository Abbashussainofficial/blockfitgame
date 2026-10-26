#!/usr/bin/env python3
"""Generates Block Fit's placeholder sound effects (royalty-free: they are
synthesised here, not sampled).

    python3 tools/generate_sounds.py

Writes 16-bit mono WAVs to assets/sounds/. To use your own sounds instead,
replace those files keeping the same names (place, clear, combo, game_over,
tap). WAV, OGG or MP3 all work if you also update the file names in
lib/services/audio_service.dart.
"""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')


def tone(freq, dur, vol=0.5, freq_end=None, attack=0.004, decay=6.0,
         harmonics=(1.0, 0.3, 0.1)):
    """A short tone with optional pitch glide and an exponential decay."""
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if freq_end is None else freq + (freq_end - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t / dur)
        s = sum(a * math.sin(phase * (k + 1)) for k, a in enumerate(harmonics))
        out.append(vol * env * s / sum(harmonics))
    return out


def silence(dur):
    return [0.0] * int(RATE * dur)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts):
    return [s for p in parts for s in p]


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f'{name}.wav')
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.95 / peak)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(s * scale * 32767)) for s in samples))
    print('wrote', os.path.relpath(path))


# Soft wooden "tock" when a piece lands.
write('place', tone(520, 0.07, 0.6, freq_end=300, decay=5,
                    harmonics=(1.0, 0.5, 0.2)))

# Bright upward sweep with a sparkle for a line clear.
write('clear', mix(
    tone(660, 0.28, 0.45, freq_end=1320, decay=4),
    seq(silence(0.06), tone(1760, 0.2, 0.2, decay=5)),
))

# Rising three-note chime for a combo.
write('combo', seq(
    tone(784, 0.09, 0.5, decay=3),   # G5
    tone(988, 0.09, 0.5, decay=3),   # B5
    tone(1319, 0.28, 0.55, decay=4),  # E6
))

# Gentle descending phrase for game over.
write('game_over', seq(
    tone(523, 0.18, 0.5, decay=3),   # C5
    tone(440, 0.18, 0.5, decay=3),   # A4
    tone(349, 0.45, 0.55, decay=3.5),  # F4
))

# Tiny click for buttons.
write('tap', tone(1200, 0.03, 0.35, freq_end=900, decay=6,
                  harmonics=(1.0, 0.2)))
