#!/usr/bin/env python3
"""Sound design for the first-boot cinematic of 404: Alive. Writes cine_*.wav (16-bit mono 22.05 kHz)
into assets/sounds/. Requires numpy. Loops are built from whole-cycle partials / circular-FFT noise so
they repeat seamlessly. Run: python3 tools/generate_cinematic_audio.py"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds"))
rng = np.random.default_rng(404)

def T(d): return np.arange(int(SR * d)) / SR
def sine(f, d): return np.sin(2 * np.pi * f * T(d))
def sweep(f0, f1, d):
    t = T(d); f = f0 * (f1 / f0) ** (t / d); return np.sin(2 * np.pi * np.cumsum(f) / SR)
def saw_sweep(f0, f1, d):
    t = T(d); f = f0 * (f1 / f0) ** (t / d); return 2 * ((np.cumsum(f) / SR) % 1) - 1
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def env(d, a=0.004, k=8.0):
    t = T(d); return np.minimum(t / a, 1) * np.exp(-k * t)
def bpg(x, fc, bw=0.5):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR) + 1e-3
    return np.fft.irfft(X * np.exp(-0.5 * ((np.log(f) - np.log(fc)) / bw) ** 2), len(x))
def lp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / fc) ** 4), len(x))
def hp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * (1 - 1 / (1 + (f / fc) ** 4)), len(x))
def add(*xs):
    out = np.zeros(max(len(x) for x in xs))
    for x in xs: out[:len(x)] += x
    return out
def norm(x, peak=0.85): return x / max(np.abs(x).max(), 1e-9) * peak
def mix(parts, d):
    out = np.zeros(int(SR * d))
    for off, x in parts:
        i = int(SR * off); n = min(len(x), len(out) - i)
        if n > 0: out[i:i + n] += x[:n]
    return out
def bell(f, d, k=3.0):
    return (sine(f, d) + 0.5 * sine(f * 2.76, d) * np.exp(-2 * T(d)) + 0.25 * sine(f * 5.4, d) * np.exp(-4 * T(d))) * env(d, 0.003, k)
def echoes(x, delays=(0.37, 0.71, 1.13, 1.7), gains=(0.5, 0.35, 0.22, 0.12)):
    out = np.zeros(len(x) + int(SR * max(delays)))
    out[:len(x)] += x
    for dl, g in zip(delays, gains):
        i = int(SR * dl); out[i:i + len(x)] += x * g
    return out

def save(name, x, loop=False, peak=0.85):
    x = norm(x, peak)
    if not loop:
        n = min(int(SR * 0.01), len(x) // 2); x[-n:] *= np.linspace(1, 0, n)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print(name, round(len(x) / SR, 2), "s")

def cyc(f, d, ph=0.0):   # sine with a whole number of cycles in d seconds (loops cleanly)
    f = round(f * d) / d
    return np.sin(2 * np.pi * f * T(d) + ph)

# ---- cine_ambience: night wind + a low, slowly beating drone + far-off groans (12 s loop)
d = 12.0; t = T(d)
wind = bpg(noise(d), 260, 0.9) * (0.65 + 0.35 * np.sin(2 * np.pi * 2 * t / d + 1.0)) + bpg(noise(d), 900, 0.7) * 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * t / d))
drone = cyc(55, d) * 0.55 + cyc(55.5, d) * 0.45 + cyc(110.4, d) * 0.18 + cyc(82.5, d) * 0.12
air = bpg(noise(d), 6500, 0.5) * 0.06 * (0.5 + 0.5 * np.sin(2 * np.pi * 5 * t / d))
groan = np.zeros(len(t))
for c0 in (2.6, 8.1):
    dd = 2.4; g = sweep(95, 62, dd) * np.sin(np.pi * T(dd) / dd) ** 2 * 0.35
    i = int(SR * c0); groan[i:i + len(g)] += g
save("cine_ambience", wind * 0.9 + drone * 0.55 + air + groan, loop=True, peak=0.8)

# ---- cine_hum: 50 Hz mains hum of the room's electronics (2 s loop)
d = 2.0; t = T(d)
hum = cyc(50, d) + 0.6 * cyc(100, d) + 0.35 * cyc(150, d) + 0.2 * cyc(250, d) + bpg(noise(d), 120, 0.3) * 0.2
save("cine_hum", hum * (0.85 + 0.15 * np.sin(2 * np.pi * 6 * t / d)), loop=True, peak=0.7)

# ---- cine_pc: a PC that should not be running - fan, coil whine, a faint sub (4 s loop)
d = 4.0; t = T(d)
fan = bpg(noise(d), 220, 0.5) * 0.9 + bpg(noise(d), 1800, 0.8) * 0.14
whine = cyc(3000, d) * 0.05 * (0.6 + 0.4 * np.sin(2 * np.pi * 2 * t / d)) + cyc(1500, d) * 0.03
save("cine_pc", fan + whine + cyc(60, d) * 0.25, loop=True, peak=0.7)

# ---- cine_music: slow, dissonant, evolving pad - minor seconds, a tritone, ghostly bells (36 s)
d = 36.0; t = T(d)
def swell(a, b): return np.clip((t - a) / (b - a), 0, 1)
pad = np.zeros(len(t))
for f, amp, a0, ph in [(55.0, 0.60, 0, 0), (58.3, 0.34, 2, 1), (110.0, 0.30, 4, 2), (116.5, 0.26, 7, 3), (164.8, 0.18, 10, 4), (233.1, 0.16, 14, 5), (329.6, 0.10, 20, 6), (311.1, 0.09, 22, 7)]:
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * (0.07 + 0.01 * ph) * t + ph)
    pad += amp * trem * swell(a0, a0 + 6) * (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * (f * 1.006) * t + 0.8))
sub = np.sin(2 * np.pi * 41.2 * t) * swell(20, 33) * 0.7
tension = (np.sin(2 * np.pi * 440 * t) * 0.05 + np.sin(2 * np.pi * 622.3 * t) * 0.045) * swell(26, 34) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.4 * t))   # a-tritone-eb
bells = np.zeros(len(t))
for at, f, g in [(4.0, 880, 0.10), (9.5, 932.3, 0.09), (13.0, 1318.5, 0.08), (17.5, 740, 0.10), (21.0, 1244.5, 0.09), (25.0, 466.2, 0.12), (29.0, 987.8, 0.10)]:
    b = echoes(bell(f, 3.2, 1.6)) * g; i = int(SR * at); n = min(len(b), len(bells) - i); bells[i:i + n] += b[:n]
music = (pad + sub + tension) * (0.30 + 0.70 * (t / d) ** 1.5) + bells
music *= np.minimum(t / 2.5, 1) * np.minimum((d - t) / 1.5, 1)
save("cine_music", lp(music, 5200), peak=0.8)

# ---- cine_riser: the build-up after the lights die (14 s) - rising, beating saws and a tightening tremolo
d = 14.0; t = T(d); r = (t / d)
tone = saw_sweep(60, 330, d) * 0.5 + saw_sweep(63.5, 349, d) * 0.45 + sweep(120, 700, d) * 0.4 + sweep(170, 990, d) * 0.25
nz = np.zeros(len(t))
for fc in (300, 700, 1500, 3000, 6000):
    nz += bpg(noise(d), fc, 0.5) * np.exp(-0.5 * ((t - d * np.log(fc / 200) / np.log(6000 / 200)) / 2.2) ** 2)
trem = 0.6 + 0.4 * np.sin(2 * np.pi * (1.5 + 9 * r ** 2) * t)
save("cine_riser", lp(tone * 0.55 + nz * 0.9, 7000) * trem * r ** 2.2, peak=0.8)

# ---- cine_power_off: thunk + zap + everything spinning down (2.4 s)
d = 2.4
thunk = sine(52, d) * env(d, 0.002, 7) + lp(noise(d), 600) * env(d, 0.001, 30) * 0.9
zap = saw_sweep(4200, 70, 0.4) * env(0.4, 0.001, 9) * 0.6
spin = sweep(50, 18, d) * env(d, 0.01, 2.2) * 0.8 + sweep(3000, 200, d) * env(d, 0.01, 6) * 0.1
save("cine_power_off", np.tanh(1.8 * add(thunk, mix([(0.0, zap)], d), spin)), peak=0.9)

# ---- cine_zap: short electrical crackle (0.55 s)
d = 0.55; z = np.zeros(int(SR * d))
for _ in range(9):
    at = rng.uniform(0, 0.45); ln = rng.uniform(0.012, 0.05); i = int(SR * at)
    z[i:i + int(SR * ln)] += hp(noise(ln), 1800) * rng.uniform(0.4, 1.0)
save("cine_zap", add(z, sweep(5200, 400, 0.12) * env(0.12, 0.001, 22) * 0.5), peak=0.8)

# ---- cine_type: one keyboard click
d = 0.07
save("cine_type", add(bpg(noise(d), 2800, 0.5) * env(d, 0.001, 70), sine(190, d) * env(d, 0.001, 45) * 0.5), peak=0.7)

# ---- cine_wake: the PC "answering" - dark cluster + three falling digital chirps (1.8 s)
d = 1.8
clu = (sine(55, d) + sine(58.3, d) + 0.6 * sine(110, d) + 0.4 * sine(155.6, d)) * env(d, 0.5, 1.6)
chirps = mix([(0.55 + i * 0.13, sweep(1500 - i * 260, 900 - i * 160, 0.09) * env(0.09, 0.002, 22) * 0.5) for i in range(3)], d)
save("cine_wake", clu * 0.8 + chirps, peak=0.8)

# ---- cine_glitch: stuttering bit-crushed digital burst (0.7 s)
d = 0.7; g = np.zeros(int(SR * d)); t0 = 0.0
while t0 < d - 0.06:
    ln = rng.uniform(0.03, 0.11); n = int(SR * ln); f = rng.uniform(180, 2600)
    seg = np.sign(np.sin(2 * np.pi * f * T(ln))) * 0.5 + noise(ln) * 0.5
    seg = np.round(seg * 3) / 3 * rng.choice([0.0, 1.0, 1.0]); i = int(SR * t0)
    g[i:i + n] += seg[: len(g) - i]; t0 += ln
save("cine_glitch", g + hp(noise(d), 4000) * 0.12 * (np.random.default_rng(1).random(len(g)) > 0.7), peak=0.75)

# ---- cine_pull: the suction - noise swept upward, a rising sine, a sub swell, a dead thump at the end (4.2 s)
d = 4.2; t = T(d); nz = np.zeros(len(t))
for k, fc in enumerate((200, 420, 850, 1700, 3400, 6000)):
    nz += bpg(noise(d), fc, 0.45) * np.exp(-0.5 * ((t - 0.5 - k * 0.55) / 0.5) ** 2)
rise = sweep(55, 820, d) * (t / d) ** 2 * 0.7
subw = sine(38, d) * (t / d) ** 1.5 * 0.9
thump = mix([(d - 0.5, sweep(110, 32, 0.5) * env(0.5, 0.002, 9))], d)
save("cine_pull", np.tanh(1.4 * (nz * 0.9 + rise + subw + thump * 1.3)), peak=0.9)

# ---- cine_impact: crossing into the game world - deep boom + dissonant metallic shimmer (2.4 s)
d = 2.4
boom = sweep(95, 28, d) * env(d, 0.002, 2.2) + lp(noise(d), 450) * env(d, 0.001, 3.2) * 0.9
shim = (sine(1480, d) + sine(1568, d) + 0.5 * sine(2211, d)) * env(d, 0.002, 2.6) * 0.18
save("cine_impact", np.tanh(2.4 * boom) * 0.9 + shim, peak=0.9)
