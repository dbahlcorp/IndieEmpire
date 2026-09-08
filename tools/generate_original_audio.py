"""Generate Indie Empire's original, sample-free looping audio assets.

Requires only Python, NumPy, and the standard library. Every tone, transient,
and noise layer is synthesized here; no third-party recordings are used.
"""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
MUSIC_PATH = ROOT / "assets" / "audio" / "music" / "studio_day_loop.wav"
AMBIENCE_PATH = ROOT / "assets" / "audio" / "ambience" / "office_room_loop.wav"


def midi(note: int) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def envelope(length: int, sample_rate: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(length, dtype=np.float64)
    attack_n = min(length, max(1, int(attack * sample_rate)))
    release_n = min(length, max(1, int(release * sample_rate)))
    env[:attack_n] *= np.linspace(0.0, 1.0, attack_n, endpoint=False)
    env[-release_n:] *= np.linspace(1.0, 0.0, release_n)
    return env


def add_periodic(buffer: np.ndarray, start: int, signal: np.ndarray, pan: float = 0.0) -> None:
    """Add a signal with wraparound so tails remain mathematically loopable."""
    left, right = pan_gains(pan)
    count = len(buffer)
    indices = (np.arange(len(signal)) + start) % count
    np.add.at(buffer[:, 0], indices, signal * left)
    np.add.at(buffer[:, 1], indices, signal * right)


def oscillator(freq: float, duration: float, sample_rate: int, kind: str = "sine") -> np.ndarray:
    t = np.arange(max(1, int(duration * sample_rate)), dtype=np.float64) / sample_rate
    phase = 2.0 * math.pi * freq * t
    if kind == "triangle":
        return 2.0 / math.pi * np.arcsin(np.sin(phase))
    if kind == "soft_square":
        return np.tanh(np.sin(phase) * 2.2) * 0.72
    if kind == "bell":
        return np.sin(phase) + 0.28 * np.sin(phase * 2.01) + 0.12 * np.sin(phase * 3.99)
    return np.sin(phase)


def add_note(buffer: np.ndarray, start_seconds: float, duration: float, sample_rate: int,
             note: int, amplitude: float, kind: str, pan: float = 0.0,
             attack: float = 0.012, release: float = 0.12) -> None:
    signal = oscillator(midi(note), duration, sample_rate, kind)
    signal *= envelope(len(signal), sample_rate, attack, release) * amplitude
    add_periodic(buffer, int(start_seconds * sample_rate), signal, pan)


def add_noise_hit(buffer: np.ndarray, rng: np.random.Generator, start_seconds: float,
                  duration: float, sample_rate: int, amplitude: float, pan: float,
                  tone: float = 0.0) -> None:
    length = max(1, int(duration * sample_rate))
    noise = rng.normal(0.0, 1.0, length)
    if tone > 0.0:
        # A tiny one-pole low pass turns white noise into a soft physical tap.
        filtered = np.empty_like(noise)
        filtered[0] = noise[0]
        coefficient = math.exp(-2.0 * math.pi * tone / sample_rate)
        for index in range(1, length):
            filtered[index] = coefficient * filtered[index - 1] + (1.0 - coefficient) * noise[index]
        noise = filtered * 5.0
    noise *= envelope(length, sample_rate, 0.002, duration * 0.92) * amplitude
    add_periodic(buffer, int(start_seconds * sample_rate), noise, pan)


def normalize_and_write(path: Path, audio: np.ndarray, sample_rate: int, peak: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    audio = np.tanh(audio * 1.08)
    maximum = float(np.max(np.abs(audio)))
    if maximum > 0.0:
        audio *= peak / maximum
    pcm = np.asarray(np.clip(audio, -1.0, 1.0) * 32767.0, dtype="<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm.tobytes())


def generate_music() -> None:
    sample_rate = 32_000
    bpm = 96.0
    beat = 60.0 / bpm
    bars = 16
    duration = bars * 4 * beat  # Exactly 40 seconds.
    audio = np.zeros((int(duration * sample_rate), 2), dtype=np.float64)
    rng = np.random.default_rng(19_850_904)

    # Dmaj7, Bm7, Gmaj7, Aadd9 — optimistic without quoting an existing tune.
    progression = [
        [50, 54, 57, 61], [47, 50, 54, 57], [43, 47, 50, 54], [45, 49, 52, 59],
        [50, 54, 57, 61], [47, 50, 54, 57], [43, 47, 50, 54], [45, 49, 52, 59],
        [52, 55, 59, 62], [43, 47, 50, 54], [45, 49, 52, 59], [50, 54, 57, 61],
        [47, 50, 54, 57], [43, 47, 50, 54], [45, 49, 52, 59], [50, 54, 57, 61],
    ]
    roots = [38, 35, 31, 33, 38, 35, 31, 33, 40, 31, 33, 38, 35, 31, 33, 38]
    melody = [
        [66, 69, 73, 69, 71, 69, 66, 64], [66, 62, 64, 66, 69, 66, 64, 62],
        [67, 71, 74, 71, 69, 67, 66, 62], [64, 66, 69, 71, 69, 66, 64, 61],
    ]

    for bar in range(bars):
        start = bar * 4 * beat
        for voice, note in enumerate(progression[bar]):
            add_note(audio, start, 4 * beat - 0.035, sample_rate, note, 0.050,
                     "sine", -0.34 + voice * 0.23, 0.12, 0.28)
            add_note(audio, start, 4 * beat - 0.05, sample_rate, note + 12, 0.018,
                     "triangle", 0.30 - voice * 0.16, 0.18, 0.34)
        for pulse in range(4):
            add_note(audio, start + pulse * beat, beat * 0.72, sample_rate,
                     roots[bar] + (12 if pulse == 2 else 0), 0.095,
                     "soft_square", -0.08, 0.012, 0.18)

        phrase = melody[(bar // 4) % len(melody)]
        for step, note in enumerate(phrase):
            # Rest every fourth bar before the turnaround, giving the loop air.
            if bar % 4 == 3 and step in (5, 7):
                continue
            variation = 12 if bar >= 8 and step in (2, 6) else 0
            add_note(audio, start + step * beat * 0.5, beat * 0.38, sample_rate,
                     note + variation, 0.060, "bell", 0.28, 0.006, 0.14)

        # A soft electronic rhythm: rounded kick, brushed snare, quiet hats.
        for pulse in range(4):
            kick_start = start + pulse * beat
            length = int(0.18 * sample_rate)
            t = np.arange(length) / sample_rate
            kick = np.sin(2 * math.pi * (72.0 - 28.0 * t / 0.18) * t)
            kick *= np.exp(-t * 25.0) * 0.090
            add_periodic(audio, int(kick_start * sample_rate), kick, 0.0)
            if pulse in (1, 3):
                add_noise_hit(audio, rng, kick_start, 0.11, sample_rate, 0.030, 0.10, 2400.0)
        for eighth in range(8):
            add_noise_hit(audio, rng, start + eighth * beat * 0.5, 0.035,
                          sample_rate, 0.010 if eighth % 2 == 0 else 0.007,
                          0.42 if eighth % 2 == 0 else -0.42, 6500.0)

    normalize_and_write(MUSIC_PATH, audio, sample_rate, 0.74)


def generate_ambience() -> None:
    sample_rate = 22_050
    duration = 30.0
    count = int(duration * sample_rate)
    t = np.arange(count, dtype=np.float64) / sample_rate
    audio = np.zeros((count, 2), dtype=np.float64)
    rng = np.random.default_rng(20_260_904)

    # Periodic low room and computer tones. Integer cycle counts guarantee a
    # seamless boundary rather than relying on a destructive fade-to-silence.
    for cycles, amplitude, pan in [(1500, 0.020, -0.2), (1800, 0.013, 0.25),
                                   (3600, 0.006, -0.45), (7200, 0.003, 0.4)]:
        phase = rng.uniform(0.0, math.tau)
        signal = np.sin(math.tau * cycles * t / duration + phase) * amplitude
        left, right = pan_gains(pan)
        audio[:, 0] += signal * left
        audio[:, 1] += signal * right

    # Broad, gently moving ventilation made from periodic partials.
    for _ in range(90):
        cycles = int(rng.integers(18, 900))
        phase = rng.uniform(0.0, math.tau)
        amplitude = rng.uniform(0.00035, 0.0015) / (1.0 + cycles / 500.0)
        signal = np.sin(math.tau * cycles * t / duration + phase) * amplitude
        left, right = pan_gains(rng.uniform(-0.8, 0.8))
        audio[:, 0] += signal * left
        audio[:, 1] += signal * right

    # Deterministic desk sounds: restrained enough to sit beneath the music.
    cluster_starts = [2.2, 6.8, 11.4, 16.2, 21.7, 26.1]
    for cluster, start in enumerate(cluster_starts):
        keys = int(rng.integers(7, 15))
        for key in range(keys):
            at = start + key * rng.uniform(0.075, 0.17)
            add_noise_hit(audio, rng, at, 0.025, sample_rate,
                          rng.uniform(0.010, 0.020), -0.55 if cluster % 2 == 0 else 0.48, 3100.0)
        # A mouse click after some typing clusters.
        if cluster % 2 == 0:
            click_at = start + keys * 0.13 + 0.18
            add_noise_hit(audio, rng, click_at, 0.018, sample_rate, 0.024, 0.52, 4800.0)

    # Two soft chair/cloth movements give the room life without voices.
    for at, pan in [(9.1, -0.28), (23.8, 0.36)]:
        add_noise_hit(audio, rng, at, 0.42, sample_rate, 0.009, pan, 700.0)

    normalize_and_write(AMBIENCE_PATH, audio, sample_rate, 0.36)


if __name__ == "__main__":
    generate_music()
    generate_ambience()
    print(f"Wrote {MUSIC_PATH.relative_to(ROOT)}")
    print(f"Wrote {AMBIENCE_PATH.relative_to(ROOT)}")
