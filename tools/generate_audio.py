#!/usr/bin/env python3
"""
Generates the placeholder sound set for Hossein Rides.

Everything here is synthesised from scratch with numpy - no samples are
downloaded or bundled. The goal is a complete, coherent sound bed so the game
is never silent, and so every hook in sfx.gd has something to play.

These are placeholders in the honest sense: the engine, horns, rain and UI
sounds are perfectly usable, but the voice clips are formant synthesis, not
speech. They carry the right rhythm, pitch contour and vowel colour for a
shout out of a car window, which is all you perceive at 90 km/h - but they are
not real Persian. Replace assets/sfx/voice/*.wav with real recordings using the
same filenames and the game picks them up with no code change.

Usage:
    python tools/generate_audio.py
    python tools/generate_audio.py --only voice
"""

from __future__ import annotations

import argparse
import math
import os
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
SFX = ROOT / "assets" / "sfx"

rng = np.random.default_rng(20260828)


# ----------------------------------------------------------------------
#  Output
# ----------------------------------------------------------------------

def write(path: Path, samples: np.ndarray, *, normalize: float = 0.89) -> None:
    """Writes 16-bit mono PCM, with a short DC-safe fade at both ends."""
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.asarray(samples, dtype=np.float64)

    peak = float(np.max(np.abs(x))) if x.size else 0.0
    if peak > 1e-9:
        x = x / peak * normalize

    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")

    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())

    print(f"  {path.relative_to(ROOT)}  ({len(x) / SR:.2f}s)")


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds), dtype=np.float64) / SR


def fade(x: np.ndarray, attack: float = 0.004, release: float = 0.02) -> np.ndarray:
    """Applies a short attack and release so nothing clicks."""
    n = len(x)
    a = min(int(SR * attack), n // 2)
    r = min(int(SR * release), n // 2)
    env = np.ones(n)
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r > 0:
        env[-r:] = np.linspace(1.0, 0.0, r)
    return x * env


def loopable(x: np.ndarray, crossfade: float = 0.05) -> np.ndarray:
    """
    Makes a buffer seamlessly loopable by crossfading its tail over its head.
    Returns a buffer shortened by the crossfade length.
    """
    n = len(x)
    c = int(SR * crossfade)
    if c <= 0 or c * 2 >= n:
        return x
    head = x[:c]
    tail = x[-c:]
    ramp = np.linspace(0.0, 1.0, c)
    blended = tail * (1.0 - ramp) + head * ramp
    out = x[c:-c].copy()
    return np.concatenate([blended, out])


def lowpass_fast(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    """Butterworth-shaped lowpass applied in the frequency domain."""
    n = len(x)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    mask = 1.0 / (1.0 + (freqs / max(cutoff, 1.0)) ** (2 * order)) ** 0.5
    return np.fft.irfft(spec * mask, n=n)


def highpass_fast(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    n = len(x)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    with np.errstate(divide="ignore"):
        mask = 1.0 / (1.0 + (max(cutoff, 1.0) / np.maximum(freqs, 1e-6)) ** (2 * order)) ** 0.5
    return np.fft.irfft(spec * mask, n=n)


def bandpass(x: np.ndarray, low: float, high: float, order: int = 2) -> np.ndarray:
    return highpass_fast(lowpass_fast(x, high, order), low, order)


def resonator(x: np.ndarray, freq: float, q: float) -> np.ndarray:
    """
    Two-pole resonant filter. Used for vocal formants, where the resonance is
    the entire point - a vowel is just a set of these.
    """
    w = 2.0 * math.pi * freq / SR
    r = math.exp(-w / (2.0 * q))
    a1 = -2.0 * r * math.cos(w)
    a2 = r * r
    gain = (1.0 - r) * math.sqrt(1.0 - 2.0 * r * math.cos(2 * w) + r * r)

    y = np.zeros(len(x))
    z1 = z2 = 0.0
    for i in range(len(x)):
        v = gain * x[i] - a1 * z1 - a2 * z2
        y[i] = v
        z2 = z1
        z1 = v
    return y


# ----------------------------------------------------------------------
#  Engine
# ----------------------------------------------------------------------

def engine_loop(fundamental: float, cylinders: float, brightness: float,
                seconds: float = 1.0) -> np.ndarray:
    """
    A four-stroke engine note.

    Built the way the real thing works: a periodic combustion pulse train at
    the firing frequency, shaped by a resonant exhaust, plus mechanical noise.
    Modelling the pulse train rather than stacking sine harmonics is what gives
    it the characteristic uneven "thump" of a single-cylinder thumper.
    """
    # Choose a length holding a whole number of cycles, so the loop is exact.
    cycles = max(1, round(fundamental * seconds))
    seconds = cycles / fundamental
    t = t_axis(seconds)
    n = len(t)

    phase = (t * fundamental) % 1.0

    # Combustion pulse: sharp rise, exponential decay.
    pulse = np.exp(-phase * 14.0) * (1.0 - np.exp(-phase * 260.0))

    # Uneven firing - a twin fires unevenly, which is most of its character.
    if cylinders >= 2:
        second = (phase + 0.42) % 1.0
        pulse = pulse + 0.82 * np.exp(-second * 14.0) * (1.0 - np.exp(-second * 260.0))

    # Intake and mechanical noise, gated by the cycle.
    noise = rng.normal(0.0, 1.0, n)
    noise = bandpass(noise, 220.0, 5200.0, order=2)
    mech = noise * (0.16 + 0.42 * pulse)

    body = pulse * 1.0 + mech

    # Exhaust resonances give it a throat.
    body = (
        1.00 * bandpass(body, 60.0, 340.0, 2)
        + 0.72 * bandpass(body, 340.0, 1100.0, 2)
        + brightness * bandpass(body, 1100.0, 4800.0, 2)
    )

    # A little saturation for grit.
    body = np.tanh(body * 2.1)
    return loopable(body, crossfade=0.02)


def build_engine() -> None:
    print("engine:")
    # Low voice: the thumper you hear at any speed.
    write(SFX / "bike" / "engine_loop.wav", engine_loop(58.0, 1, 0.30, 1.0))
    # High voice: fades in under load, keeps the top end from thinning out.
    write(SFX / "bike" / "engine_high.wav", engine_loop(116.0, 2, 0.62, 1.0))


# ----------------------------------------------------------------------
#  Traffic
# ----------------------------------------------------------------------

def horn(freqs: list[float], seconds: float, reedy: float = 0.5) -> np.ndarray:
    """
    A car horn: two slightly detuned reeds with strong odd harmonics. Iranian
    traffic runs on these, so there are four variants with different intervals.
    """
    t = t_axis(seconds)
    sig = np.zeros(len(t))

    for f in freqs:
        for h in range(1, 13):
            amp = (1.0 / h) * (1.0 if h % 2 else reedy * 0.6)
            # Slight drift so the two reeds beat against each other.
            drift = 1.0 + 0.0016 * math.sin(2 * math.pi * 5.5 * h)
            sig += amp * np.sin(2 * math.pi * f * h * drift * t)

    sig = np.tanh(sig * 0.55)
    sig = bandpass(sig, 260.0, 6500.0, 2)

    # Envelope: fast on, slight sag, fast off.
    env = np.ones(len(t))
    a = int(SR * 0.012)
    r = int(SR * 0.05)
    env[:a] = np.linspace(0, 1, a)
    env[-r:] = np.linspace(1, 0, r)
    env *= 1.0 - 0.10 * np.linspace(0, 1, len(t))
    return sig * env


def build_traffic() -> None:
    print("traffic:")
    write(SFX / "traffic" / "horn_01.wav", horn([392.0, 466.0], 0.62, 0.5))
    write(SFX / "traffic" / "horn_02.wav", horn([330.0, 415.0], 0.48, 0.65))
    write(SFX / "traffic" / "horn_03.wav", horn([440.0, 523.0], 0.34, 0.4))
    write(SFX / "traffic" / "horn_04.wav", horn([294.0, 370.0], 0.85, 0.55))

    # --- whoosh: the air displaced by a car passing close ---------------
    seconds = 0.55
    t = t_axis(seconds)
    noise = rng.normal(0.0, 1.0, len(t))
    # Sweep the filter down as the car goes by - that fall IS the Doppler cue.
    sweep = np.zeros(len(t))
    chunk = 512
    for i in range(0, len(t), chunk):
        f = 2600.0 - 1700.0 * (i / len(t))
        seg = noise[i:i + chunk]
        sweep[i:i + chunk] = bandpass(seg, f * 0.35, f, 1)
    env = np.exp(-((np.linspace(-1.6, 1.9, len(t))) ** 2) * 2.4)
    write(SFX / "traffic" / "whoosh.wav", fade(sweep * env, 0.01, 0.08))

    # --- crash -----------------------------------------------------------
    seconds = 1.9
    t = t_axis(seconds)
    n = len(t)
    # Impact: broadband burst plus a low thud.
    burst = rng.normal(0.0, 1.0, n) * np.exp(-t * 26.0)
    thud = np.sin(2 * math.pi * 62.0 * t) * np.exp(-t * 9.0)
    thud += np.sin(2 * math.pi * 41.0 * t) * np.exp(-t * 6.0) * 0.8
    # Metal: a few inharmonic resonances ringing out.
    metal = np.zeros(n)
    for f, decay in [(1870.0, 5.5), (2410.0, 6.8), (3320.0, 8.2), (4790.0, 11.0)]:
        metal += np.sin(2 * math.pi * f * t + rng.random() * 6.28) * np.exp(-t * decay)
    metal *= 0.30
    # Glass and debris scatter afterwards.
    scatter = rng.normal(0.0, 1.0, n)
    scatter = highpass_fast(scatter, 3200.0, 2)
    gate = (rng.random(n) < 0.0016).astype(float)
    gate = np.convolve(gate, np.exp(-np.linspace(0, 8, 900)), mode="same")
    scatter *= gate * np.exp(-t * 1.6) * 0.55

    crash = np.tanh((burst * 1.4 + thud * 1.7 + metal + scatter) * 1.1)
    write(SFX / "traffic" / "crash.wav", fade(crash, 0.001, 0.25))

    # --- rain bed ---------------------------------------------------------
    seconds = 4.0
    n = int(SR * seconds)
    base = rng.normal(0.0, 1.0, n)
    hiss = bandpass(base, 900.0, 11000.0, 2) * 0.55
    # Individual drops hitting the helmet and tank.
    drops = (rng.random(n) < 0.004).astype(float) * rng.normal(1.0, 0.4, n)
    drops = np.convolve(drops, np.exp(-np.linspace(0, 12, 260)), mode="same")
    drops = bandpass(drops, 1800.0, 9000.0, 1) * 0.6
    # Low rumble of water on the road.
    rumble = lowpass_fast(rng.normal(0.0, 1.0, n), 260.0, 2) * 0.35
    write(SFX / "traffic" / "rain_loop.wav", loopable(hiss + drops + rumble, 0.25))


# ----------------------------------------------------------------------
#  Bike incidentals
# ----------------------------------------------------------------------

def build_bike_extras() -> None:
    print("bike:")
    # --- lighter: flint scrape, then flame ------------------------------
    seconds = 0.85
    t = t_axis(seconds)
    n = len(t)
    scrape_len = int(SR * 0.09)
    scrape = np.zeros(n)
    s = rng.normal(0.0, 1.0, scrape_len)
    s = bandpass(s, 2400.0, 9500.0, 2)
    s *= np.linspace(1.0, 0.2, scrape_len) * (1.0 + 0.6 * np.sin(np.linspace(0, 30, scrape_len)))
    scrape[:scrape_len] = s * 0.9

    flame_start = int(SR * 0.10)
    flame = np.zeros(n)
    fl = rng.normal(0.0, 1.0, n - flame_start)
    fl = bandpass(fl, 180.0, 2200.0, 2)
    fl *= np.exp(-np.linspace(0, 3.0, len(fl))) * 0.5
    flame[flame_start:] = fl

    write(SFX / "bike" / "lighter.wav", fade(scrape + flame, 0.002, 0.12))

    # --- bike horn -------------------------------------------------------
    # Thinner and higher than a car's: a small single reed, and it sounds it.
    write(SFX / "bike" / "horn.wav", horn([515.0, 622.0], 0.55, reedy=0.78))

    # --- boost pad -------------------------------------------------------
    # Rising sweep plus a filtered noise whoosh, so it reads as acceleration
    # rather than as a pickup chime.
    seconds = 1.15
    t = t_axis(seconds)
    n = len(t)
    # Exponential pitch rise is what the ear hears as "speeding up".
    f_sweep = 180.0 * np.exp(np.linspace(0.0, 1.75, n))
    phase = np.cumsum(f_sweep) / SR
    tone = np.sin(2 * math.pi * phase) + 0.45 * np.sin(4 * math.pi * phase)
    tone *= np.exp(-t * 2.2)

    air = rng.normal(0.0, 1.0, n)
    swept = np.zeros(n)
    chunk = 512
    for i in range(0, n, chunk):
        f = 700.0 + 5200.0 * (i / n)
        swept[i:i + chunk] = bandpass(air[i:i + chunk], f * 0.5, f, 1)
    swept *= np.exp(-t * 1.8) * 0.7

    boost = np.tanh((tone * 0.8 + swept) * 1.3)
    write(SFX / "bike" / "boost.wav", fade(boost, 0.004, 0.22))

    # --- inhale: breath drawn through a cigarette -------------------------
    seconds = 1.05
    t = t_axis(seconds)
    n = len(t)
    breath = rng.normal(0.0, 1.0, n)
    breath = bandpass(breath, 420.0, 3400.0, 2)
    # Slow swell then release, like a real drag.
    env = np.exp(-((np.linspace(-2.0, 2.4, n)) ** 2) * 1.1)
    write(SFX / "bike" / "inhale.wav", fade(breath * env * 0.7, 0.05, 0.2))


# ----------------------------------------------------------------------
#  UI
# ----------------------------------------------------------------------

def build_ui() -> None:
    print("ui:")

    def blip(freqs, seconds, decay, noise_mix=0.0):
        t = t_axis(seconds)
        sig = np.zeros(len(t))
        for i, f in enumerate(freqs):
            start = int(len(t) * i / max(len(freqs), 1))
            seg_t = t[: len(t) - start]
            tone = np.sin(2 * math.pi * f * seg_t) * np.exp(-seg_t * decay)
            sig[start:] += tone
        if noise_mix > 0:
            nz = bandpass(rng.normal(0, 1, len(t)), 1200, 7000, 1)
            sig += nz * np.exp(-t * decay * 1.5) * noise_mix
        return fade(sig, 0.002, 0.04)

    write(SFX / "ui" / "click.wav", blip([880.0], 0.09, 55.0, 0.25))
    write(SFX / "ui" / "purchase.wav", blip([660.0, 880.0, 1320.0], 0.42, 12.0, 0.1))
    write(SFX / "ui" / "deny.wav", blip([220.0, 175.0], 0.26, 18.0, 0.15))


# ----------------------------------------------------------------------
#  Voice
# ----------------------------------------------------------------------

# Formant targets (F1, F2, F3) for Persian vowels, in Hz, male register.
# These are what give a synthesised vowel its identity.
PERSIAN_VOWELS = {
    "a":  (700.0, 1250.0, 2550.0),   # as in "âb" - back open
    "ae": (620.0, 1720.0, 2600.0),   # as in "bæd" - front open
    "e":  (450.0, 1900.0, 2600.0),
    "i":  (300.0, 2200.0, 2900.0),
    "o":  (450.0, 900.0, 2450.0),
    "u":  (330.0, 780.0, 2400.0),
}

# Syllable shapes with plausible Persian phonotactics and stress patterns.
# Each entry is (vowel, duration, is_stressed, leading_consonant_burst).
SHOUT_PATTERNS = [
    [("ae", 0.13, True, "plosive"), ("e", 0.11, False, "fricative")],
    [("a", 0.16, True, "plosive"), ("o", 0.10, False, None), ("i", 0.13, False, "nasal")],
    [("e", 0.11, False, "fricative"), ("a", 0.19, True, None)],
    [("o", 0.12, True, "plosive"), ("a", 0.15, False, "liquid")],
    [("i", 0.10, False, None), ("ae", 0.17, True, "plosive"), ("e", 0.09, False, None)],
    [("a", 0.20, True, "nasal"), ("u", 0.12, False, None)],
]


def glottal_source(f0_curve: np.ndarray, breathiness: float = 0.12) -> np.ndarray:
    """
    A glottal pulse train following a pitch contour.

    Uses a Rosenberg-style asymmetric pulse rather than an impulse, because a
    real glottis closes faster than it opens, and that asymmetry is what stops
    synthesised voice sounding like a buzzer.
    """
    n = len(f0_curve)
    phase = np.cumsum(f0_curve) / SR
    frac = phase % 1.0

    open_q = 0.62
    pulse = np.zeros(n)
    rising = frac < open_q
    pulse[rising] = 0.5 * (1.0 - np.cos(math.pi * frac[rising] / open_q))
    falling = (~rising) & (frac < open_q + 0.16)
    fp = (frac[falling] - open_q) / 0.16
    pulse[falling] = np.cos(math.pi * 0.5 * fp)

    # Differentiate: the acoustic excitation is the derivative of glottal flow.
    src = np.diff(pulse, prepend=pulse[0])
    src += rng.normal(0.0, breathiness, n) * 0.4
    return src


def synth_shout(pattern, base_f0: float, intensity: float) -> np.ndarray:
    """
    Builds one exclamation from a syllable pattern.

    This is formant synthesis, not speech: it has the vowel colour, syllable
    rhythm, and shouted pitch contour of a Persian exclamation shouted from a
    car, but it carries no words. At the distance and speed these play at,
    that reads as a voice - which is the job. Swap in real recordings for the
    real thing.
    """
    segments = []

    for vowel, dur, stressed, onset in pattern:
        n = int(SR * dur)
        t = np.linspace(0.0, 1.0, n)

        # Shouted speech rises sharply then falls away.
        f0 = base_f0 * (1.0 + (0.34 if stressed else 0.12) * intensity)
        contour = f0 * (1.0 + 0.22 * np.sin(math.pi * t) - 0.16 * t)
        contour *= 1.0 + rng.normal(0.0, 0.006, n).cumsum() * 0.02  # natural jitter

        src = glottal_source(contour, breathiness=0.10 + 0.10 * intensity)

        f1, f2, f3 = PERSIAN_VOWELS[vowel]
        # Shouting raises F1 - the jaw opens.
        f1 *= 1.0 + 0.16 * intensity

        voiced = (
            1.00 * resonator(src, f1, 9.0)
            + 0.60 * resonator(src, f2, 11.0)
            + 0.28 * resonator(src, f3, 13.0)
            + 0.10 * resonator(src, 3900.0, 14.0)
        )

        # Amplitude envelope per syllable.
        env = np.sin(np.pi * np.clip(t, 0, 1)) ** 0.55
        voiced *= env * (1.0 if stressed else 0.72)

        # Consonant onset.
        if onset:
            seg = _consonant(onset, intensity)
            segments.append(seg)

        segments.append(voiced)

        # Short gap between syllables.
        segments.append(np.zeros(int(SR * 0.012)))

    out = np.concatenate(segments)

    # Vocal tract radiation: a gentle high-shelf.
    out = out + 0.5 * highpass_fast(out, 1800.0, 1)
    # Shouting compresses hard.
    out = np.tanh(out * (1.6 + intensity))
    return fade(out, 0.006, 0.06)


def _consonant(kind: str, intensity: float) -> np.ndarray:
    """Short consonantal onsets - these carry most of the sense of speech."""
    if kind == "plosive":
        n = int(SR * 0.026)
        burst = rng.normal(0.0, 1.0, n)
        burst = bandpass(burst, 900.0, 5200.0, 1)
        burst *= np.exp(-np.linspace(0.0, 9.0, n)) * (0.7 + intensity * 0.4)
        return np.concatenate([np.zeros(int(SR * 0.014)), burst])
    if kind == "fricative":
        n = int(SR * 0.055)
        f = rng.normal(0.0, 1.0, n)
        f = bandpass(f, 3200.0, 9000.0, 2)
        f *= np.linspace(0.35, 1.0, n) * 0.5
        return f
    if kind == "nasal":
        n = int(SR * 0.045)
        t = np.linspace(0, 1, n)
        contour = np.full(n, 130.0)
        src = glottal_source(contour, 0.05)
        nas = resonator(src, 280.0, 12.0) + 0.4 * resonator(src, 1100.0, 9.0)
        return nas * np.linspace(0.2, 0.8, n) * 0.5
    if kind == "liquid":
        n = int(SR * 0.040)
        contour = np.full(n, 128.0)
        src = glottal_source(contour, 0.05)
        liq = resonator(src, 480.0, 8.0) + 0.5 * resonator(src, 1350.0, 9.0)
        return liq * np.linspace(0.3, 0.9, n) * 0.5
    return np.zeros(0)


def build_voice() -> None:
    print("voice (formant placeholders - replace with real recordings):")
    # A spread of voices: different speakers, different levels of annoyance.
    voices = [
        (118.0, 0.95),
        (102.0, 0.80),
        (135.0, 1.00),
        (95.0, 0.65),
        (126.0, 0.88),
        (110.0, 0.72),
    ]
    for i, (f0, intensity) in enumerate(voices, start=1):
        pattern = SHOUT_PATTERNS[(i - 1) % len(SHOUT_PATTERNS)]
        clip = synth_shout(pattern, f0, intensity)
        write(SFX / "voice" / f"shout_{i:02d}.wav", clip, normalize=0.80)


# ----------------------------------------------------------------------

def build_weather() -> None:
    """Thunder: a crack followed by a long, tumbling rumble."""
    print("weather:")

    for idx, (crack_amt, length, distance) in enumerate(
        [(1.0, 4.2, 0.25), (0.45, 5.6, 0.75), (0.75, 4.8, 0.5)], start=1
    ):
        t = t_axis(length)
        n = len(t)

        # The initial crack: broadband, very short. A distant strike loses it
        # almost entirely, which is what `distance` controls.
        crack = rng.normal(0.0, 1.0, n) * np.exp(-t * 42.0)
        crack = bandpass(crack, 180.0, 7000.0 * (1.0 - distance * 0.8) + 400.0, 1)
        crack *= crack_amt * (1.0 - distance * 0.7)

        # The rumble: low noise, amplitude-modulated by slow random swells so
        # it tumbles rather than fading smoothly. That irregularity is what
        # makes thunder sound like thunder and not like a fade-out.
        rumble = rng.normal(0.0, 1.0, n)
        rumble = lowpass_fast(rumble, 260.0 - distance * 120.0, 2)

        swell = rng.normal(0.0, 1.0, n)
        swell = lowpass_fast(swell, 3.5, 2)
        swell = 0.55 + 0.75 * np.abs(swell / (np.max(np.abs(swell)) + 1e-9))

        # Slow attack so the rumble arrives behind the crack, then a long tail.
        env = (1.0 - np.exp(-t * 6.0)) * np.exp(-t * (0.75 + distance * 0.3))
        rumble *= swell * env * 1.5

        # A little sub weight underneath.
        sub = np.sin(2 * math.pi * 38.0 * t) * np.exp(-t * 1.1) * 0.35

        thunder = np.tanh((crack + rumble + sub) * 1.15)
        write(SFX / "weather" / f"thunder_{idx:02d}.wav", thunder)


GROUPS = {
    "engine": build_engine,
    "weather": build_weather,
    "traffic": build_traffic,
    "bike": build_bike_extras,
    "ui": build_ui,
    "voice": build_voice,
}


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate the Hossein Rides sound set.")
    ap.add_argument("--only", choices=sorted(GROUPS), help="generate one group only")
    args = ap.parse_args()

    targets = [args.only] if args.only else list(GROUPS)
    print(f"Writing to {SFX}\n")
    for name in targets:
        GROUPS[name]()
    print("\nDone.")


if __name__ == "__main__":
    main()
