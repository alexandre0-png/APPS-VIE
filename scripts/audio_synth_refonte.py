"""Chipe-Oeufs : pack de ~38 sons synthetises (numpy + ffmpeg). Sortie : OGG mono 44,1 kHz, pic 0,8."""
import numpy as np, subprocess, os, wave, sys
SR = 44100
rng = np.random.default_rng(11)
OUT = os.environ.get("AUDIO_OUT", "/tmp/claude-0/-home-user-APPS-VIE/c9e841d1-d554-571c-a61d-bf92920d8724/scratchpad/audio4")
os.makedirs(OUT, exist_ok=True)
PI2 = 2 * np.pi

# ---------- outils ----------
def mf(m): return 440.0 * 2 ** ((m - 69) / 12)
def T(d): return np.arange(int(SR * d)) / SR
def noise(d): return rng.standard_normal(int(SR * d))
def buf(total): return np.zeros(int(SR * total))
def put(b, x, t0, g=1.0):
    i = int(round(SR * t0))
    if i >= len(b): return b
    n = min(len(x), len(b) - i); b[i:i + n] += g * x[:n]; return b
def ex(n, a=0.003, tau=0.2):
    t = np.arange(n) / SR
    return np.exp(-t / tau) * np.clip(t / max(a, 1e-4), 0, 1)
def sine(f, d): return np.sin(PI2 * f * T(d))
def sweep(f0, f1, d, expo=True):
    n = int(SR * d); u = np.linspace(0, 1, n)
    f = f0 * (f1 / f0) ** u if expo else f0 + (f1 - f0) * u
    return np.sin(PI2 * np.cumsum(f) / SR)
def band(x, lo=0, hi=SR / 2, soft=0.15):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); m = np.ones_like(f)
    if lo > 0: m *= 1 / (1 + np.exp(-(f - lo) / (lo * soft + 1)))
    if hi < SR / 2: m *= 1 / (1 + np.exp((f - hi) / (hi * soft + 1)))
    return np.fft.irfft(X * m, len(x))
def lp(x, hi): return band(x, 0, hi)
def hp(x, lo): return band(x, lo, SR / 2)
def sweep_noise(f0, f1, d, q=0.35, base=None):
    """bruit passe-bande dont la frequence centrale glisse (STFT recouvrante)."""
    n = int(SR * d); x = (base if base is not None else noise(d)); N = 1024; H = 512
    out = np.zeros(n + N); w = np.hanning(N); fr = np.fft.rfftfreq(N, 1 / SR)
    for s in range(0, n, H):
        u = s / max(n, 1); fc = f0 * (f1 / f0) ** u; seg = np.zeros(N); c = x[s:s + N]; seg[:len(c)] = c * w[:len(c)]
        m = np.exp(-0.5 * ((fr - fc) / (fc * q)) ** 2)
        out[s:s + N] += np.fft.irfft(np.fft.rfft(seg) * m, N)
    return out[:n]
def bell(f, d, bright=1.0):
    t = T(d); n = len(t); y = np.zeros(n)
    for i, (r, a) in enumerate(zip([1, 2.76, 5.4, 8.93], [1, .45, .22, .08])):
        if f * r < 16000: y += a * (bright if i else 1) * np.sin(PI2 * f * r * t) * ex(n, 0.002, d / 4 / (1 + 0.9 * i))
    return y
def warm(f, d, tau=None):
    t = T(d); n = len(t); tau = tau or d / 3
    return (np.sin(PI2 * f * t) + .3 * np.sin(PI2 * 2 * f * t) + .1 * np.sin(PI2 * 3 * f * t)) * ex(n, 0.004, tau)
def brass(f, d, a=0.04, r=0.12, vib=0.003):
    t = T(d); n = len(t); ph = PI2 * f * t + vib * np.sin(PI2 * 5.5 * t) * f / 20
    y = sum(np.sin(h * ph) / h ** 1.15 for h in range(1, 10) if h * f < 9000)
    e = np.ones(n); na = int(SR * a); nr = int(SR * r)
    e[:na] = np.linspace(0, 1, na) ** 1.3; e[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    return y * e
def pad(f, d, a=0.3, r=0.5, harm=3):
    t = T(d); n = len(t); y = sum(np.sin(PI2 * f * h * t + h) / h ** 1.5 for h in range(1, harm + 1))
    e = np.ones(n); na = int(SR * a); nr = int(SR * r)
    e[:na] = np.sin(np.linspace(0, np.pi / 2, na)) ** 2; e[-nr:] *= np.cos(np.linspace(0, np.pi / 2, nr)) ** 2
    return y * e
def pop(d=0.09, f0=250, f1=700):
    n = int(SR * d)
    return sweep(f0, f1, d) * ex(n, 0.001, d / 3) + 0.35 * lp(noise(d), 3500) * ex(n, 0.0005, d / 5)
def timp(d=0.6, f=90, amp=1.0):
    n = int(SR * d)
    return amp * (sweep(f * 1.8, f, d) * ex(n, 0.001, d / 4) + 0.4 * lp(noise(d), 600) * ex(n, 0.0005, 0.03))
def echo(x, delay, fb, taps, total):
    y = buf(total)
    for k in range(taps + 1): put(y, lp(x, 5000 - 700 * k) if k else x, delay * k, fb ** k)
    return y
def chord_notes(ms, d, a=0.2, r=0.6, harm=3): return sum(pad(mf(m), d, a, r, harm) for m in ms)

def finish(name, x, maxd=3.0, loop=False):
    x = np.asarray(x, float)
    x = x[:int(SR * maxd)]
    if not loop:
        nfi = int(SR * 0.004); nfo = int(SR * 0.04)
        x[:nfi] *= np.linspace(0, 1, nfi); x[-nfo:] *= np.linspace(1, 0, nfo)
    x = x - np.mean(x) if loop else x
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(1.6 * x) / np.tanh(1.6)          # compression douce -> volume homogene
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    def enc(y):
        w = os.path.join(OUT, name + ".wav")
        with wave.open(w, "wb") as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes((y * 32767).astype(np.int16).tobytes())
        o = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-ac", "1", "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "4", o], check=True)
        os.remove(w)
        r = subprocess.run(["ffmpeg", "-v", "error", "-i", o, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True).stdout
        return np.abs(np.frombuffer(r, np.int16) / 32768).max()
    sc = 1.0
    for _ in range(5):                     # le codage OGG peut depasser : on recale le pic decode a 0,8
        pk = enc(x * sc)
        if 0.785 <= pk <= 0.805: break
        sc *= 0.795 / pk

C5, E5, G5, C6, E6, G6 = 72, 76, 79, 84, 88, 91

# ---------- eclosions ----------
def hatch_r1():
    b = buf(0.8); put(b, pop(), 0); put(b, bell(mf(88), 0.6), 0.07, .6); put(b, bell(mf(95), 0.5), 0.14, .35); return b
def hatch_r2():
    b = buf(1.0); put(b, pop(), 0)
    g = sweep(500, 1800, 0.3) * ex(int(SR * .3), 0.01, 0.2); put(b, g, 0.06, .45)
    put(b, bell(mf(91), 0.7), 0.3, .6); put(b, bell(mf(98), 0.6), 0.38, .3); return b
def hatch_r3():
    b = buf(1.3)
    for i, m in enumerate([79, 83, 86]): put(b, bell(mf(m), 0.9), 0.0 + i * 0.14, .75); put(b, warm(mf(m - 12), 0.5), i * .14, .25)
    put(b, bell(mf(91), 0.8), 0.45, .35); return b
def hatch_r4():
    b = buf(2.0); put(b, chord_notes([57, 60, 64, 69, 72], 1.8, .12, .9), 0, .5)
    put(b, sweep(110, 45, 1.2) * ex(int(SR * 1.2), 0.02, 0.5), 0, .8)
    put(b, bell(mf(81), 1.2, .7), 0.05, .3); return b
def hatch_r5():
    b = buf(2.2)
    for m, t0, d in [(C5, 0, .18), (E5, .16, .18), (G5, .32, .18)]: put(b, brass(mf(m), d + .05, .02, .06), t0, .7)
    for m in [C5, E5, G5, C6]: put(b, brass(mf(m), 1.2, .03, .5), .5, .35)
    put(b, timp(.5, 110), .5, .5)
    for i, m in enumerate([96, 100, 103, 108, 103, 100]): put(b, bell(mf(m), 0.8, 1.3), .55 + i * .11, .3)
    return b
def hatch_r6():
    b = buf(2.4); put(b, timp(1.0, 55, 1.2), 0)
    for i, t0 in enumerate([.25, .36, .43, .6, .67]):
        c = buf(.18); put(c, bell(mf(96 + i % 3 * 2), 0.18), 0, .5); put(c, hp(noise(.05), 5000) * ex(int(SR * .05), 0.0005, 0.01), 0, .3)
        put(b, c, t0, .5)
    cr = lp(noise(1.6), 900) ** 3 * ex(int(SR * 1.6), 0.05, 0.8); put(b, cr / (np.max(np.abs(cr)) + 1e-9), .4, .3)
    put(b, sweep(300, 800, 1.2) * ex(int(SR * 1.2), 0.3, 0.5), .5, .12); return b
def hatch_r7():
    b = buf(2.2)
    for t0, m in zip([0, .1, .19, .33, .42, .6, .85, 1.1], [96, 103, 108, 100, 106, 110, 101, 108]): put(b, bell(mf(m), 1.0, 1.4), t0, .5)
    put(b, hp(noise(.5), 6500) * ex(int(SR * .5), 0.05, 0.2), 0, .06); return b
def hatch_r8():
    seq = [57, 60, 64, 69, 72, 76, 81]; d = buf(1.1)
    for i, m in enumerate(seq): put(d, warm(mf(m), .5, .22) + .3 * bell(mf(m + 12), .5), i * .1, .6)
    b = echo(d, .22, .55, 4, 2.6); put(b, pad(mf(45), 2.0, .5, .9, 2), 0, .25); return b
def hatch_r9():
    b = buf(2.6); put(b, bell(mf(45), 2.4), 0, 1.0); put(b, bell(mf(57), 2.0, .5), 0, .4)
    br = band(noise(2.4), 300, 1400) * np.sin(np.linspace(0, np.pi, int(SR * 2.4))) ** 2; put(b, br / (np.max(np.abs(br)) + 1e-9), .3, .35); return b
def choir(ms, d, a=.6, r=.8):
    t = T(d); n = len(t); y = np.zeros(n)
    for m in ms:
        f = mf(m)
        for det in (-.004, 0, .004):
            ph = PI2 * f * (1 + det) * t + 0.004 * np.sin(PI2 * 5 * t + m)
            y += sum(np.sin(h * ph) / h for h in range(1, 14) if f * h < 8000)
    fr = np.fft.rfftfreq(n, 1 / SR)
    m_ = .15 + np.exp(-.5 * ((fr - 700) / 140) ** 2) + .7 * np.exp(-.5 * ((fr - 1150) / 200) ** 2) + .3 * np.exp(-.5 * ((fr - 2600) / 300) ** 2)
    y = np.fft.irfft(np.fft.rfft(y) * m_, n)
    e = np.ones(n); na = int(SR * a); nr = int(SR * r)
    e[:na] = np.sin(np.linspace(0, np.pi / 2, na)) ** 2; e[-nr:] *= np.cos(np.linspace(0, np.pi / 2, nr)) ** 2
    return y * e
def hatch_r10():
    b = buf(3.0); put(b, choir([48, 55, 60, 64, 67, 72], 2.9), 0, 1.0)
    for i in range(14): put(b, bell(mf(84 + [0, 4, 7, 12, 16, 19, 24][i % 7] + (i // 7) * 0), .9, 1.2), .5 + i * .14, .12 + i * .008)
    return b
def jackpot_rare():
    b = buf(3.0)
    for m, t0 in [(C5, 0), (E5, .16), (G5, .32), (C6, .48)]: put(b, brass(mf(m), .22, .02, .06), t0, .7)
    for m in [C5, G5, C6, E6]: put(b, brass(mf(m), 2.0, .04, .8), .75, .35)
    put(b, timp(.8, 80, 1.1), .75); put(b, timp(.5, 110), .0, .6)
    for i in range(16): put(b, bell(mf(96 + [0, 4, 7, 12, 4, 7][i % 6]), .8, 1.3), .85 + i * .12, .22)
    put(b, choir([60, 67, 72, 76], 2.0, .4, .8), .75, .35); return b

# ---------- attaques ----------
def atk_feu():
    n = int(SR * .7); b = buf(.7)
    put(b, sweep_noise(400, 2500, .7, .6) * ex(n, .02, .35), 0, 1.0)
    cr = lp(noise(.7), 3000); cr = np.where(np.abs(cr) > 2.0 * np.std(cr), cr, 0) * ex(n, .01, .4); put(b, cr / (np.max(np.abs(cr)) + 1e-9), 0, .5)
    put(b, sweep(120, 70, .7) * ex(n, .02, .3), 0, .6); return b
def atk_eau():
    b = buf(.75)
    for t0, f0, f1 in [(0, 300, 900), (.14, 400, 1200), (.27, 350, 1000), (.4, 500, 1400)]:
        put(b, sweep(f0, f1, .12) * ex(int(SR * .12), .004, .08), t0, .7)
    put(b, sweep_noise(800, 3000, .75, .5) * ex(int(SR * .75), .08, .3), 0, .35); return b
def atk_plante():
    b = buf(.7); n = int(SR * .5)
    put(b, sweep_noise(2500, 5000, .5, .35) * (0.6 + .4 * np.sin(PI2 * 18 * T(.5))) * ex(n, .02, .25), 0, .6)
    for t0, m in [(.05, 64), (.2, 69), (.35, 76)]: put(b, (np.sin(PI2 * mf(m) * T(.3)) + .5 * np.sin(PI2 * mf(m) * 4 * T(.3))) * ex(int(SR * .3), .001, .08), t0, .7)
    return b
def atk_terre():
    b = buf(.8); put(b, timp(.7, 70, 1.0), 0)
    gr = lp(noise(.6), 1800); gr = gr * (np.random.default_rng(5).random(len(gr)) > .985) * 6; gr = lp(gr, 900) * ex(len(gr), .005, .3)
    put(b, gr / (np.max(np.abs(gr)) + 1e-9), .05, .5); return b
def atk_ciel():
    n = int(SR * .8); b = buf(.8)
    put(b, sweep_noise(600, 3500, .8, .4) * np.sin(np.linspace(0, np.pi, n)) ** 1.5, 0, .8)
    put(b, sweep(600, 1500, .6, False) * np.sin(np.linspace(0, np.pi, int(SR * .6))) ** 2, 0.05, .35); return b
def atk_ombre():
    n = int(SR * .8); b = buf(.8); t = T(.8)
    put(b, sweep(330, 70, .8) * (.6 + .4 * np.sin(PI2 * 14 * t)) * ex(n, .05, .5), 0, .8)
    put(b, sweep(349, 74, .8) * ex(n, .05, .5), 0, .5)
    put(b, sweep_noise(500, 150, .8, .5) * ex(n, .05, .4), 0, .3); return b
def atk_lumiere():
    b = buf(.8)
    put(b, sweep(500, 2000, .4) * ex(int(SR * .4), .01, .25), 0, .4)
    for i, m in enumerate([84, 88, 91, 96]): put(b, bell(mf(m), .6, 1.2), .08 + i * .07, .6)
    return b
def atk_glace():
    b = buf(.75)
    for t0, m in [(0, 100), (.06, 105), (.12, 108), (.2, 103)]: put(b, bell(mf(m), .5, 1.6), t0, .6)
    put(b, hp(noise(.08), 4500) * ex(int(SR * .08), .0005, .02), 0, .5)
    put(b, sweep_noise(6000, 3000, .5, .3) * ex(int(SR * .5), .01, .2), 0, .25); return b
def atk_foudre():
    n = int(SR * .5); b = buf(.5); t = T(.5)
    z = sweep(2500, 180, .5) * (np.sign(np.sin(PI2 * 90 * t)) * .5 + .5) * ex(n, .001, .15)
    put(b, lp(z, 6000), 0, .8)
    cr = hp(noise(.5), 1500); cr = cr * (rng.random(n) > .9) * ex(n, .001, .2); put(b, lp(cr, 7000) / (np.max(np.abs(cr)) + 1e-9), 0, .4)
    put(b, timp(.4, 100), .02, .4); return b
def special_ready():
    b = buf(.9); put(b, bell(mf(79), .5), 0, .7); put(b, bell(mf(86), .7), .12, .8); put(b, sweep(800, 2400, .25) * ex(int(SR * .25), .01, .15), 0, .2); return b
def special_hit():
    b = buf(.8); n = int(SR * .6)
    put(b, sweep(260, 40, .6) * ex(n, .001, .22), 0, 1.0); put(b, lp(noise(.3), 2500) * ex(int(SR * .3), .0005, .06), 0, .8)
    put(b, bell(mf(67), .5, .6), 0, .3); return b

# ---------- combat ----------
def battle_start():
    b = buf(2.8); t0 = 0.0; k = 0
    while t0 < 1.95:
        iv = max(.045, .17 - .125 * (t0 / 1.95) ** 1.2); amp = .25 + .55 * (t0 / 1.95)
        put(b, timp(.18, 140 + (k % 2) * 15, 1.0), t0, amp); t0 += iv; k += 1
    put(b, timp(.9, 60, 1.4), 2.0, 1.0)
    for m in [48, 55, 60]: put(b, brass(mf(m), .6, .01, .3), 2.0, .35)
    put(b, bell(mf(72), .6, .5), 2.0, .2); return b
def battle_win():
    b = buf(2.2)
    for m, t0, d in [(C5, 0, .2), (E5, .2, .2), (G5, .4, .2), (C6, .6, .9)]: put(b, brass(mf(m), d + .05, .02, .08), t0, .7)
    for m in [C5, E5, G5, C6]: put(b, brass(mf(m), 1.2, .05, .6), 1.0, .35)
    put(b, timp(.5, 90), 0, .6); put(b, timp(.7, 90), 1.0, .8)
    for i, m in enumerate([96, 100, 103, 108]): put(b, bell(mf(m), .7, 1.2), 1.05 + i * .1, .25); return b
def battle_lose():
    b = buf(1.7)
    for i, m in enumerate([67, 64, 60, 55]): put(b, warm(mf(m), .8, .3), i * .3, .6); put(b, warm(mf(m - 12), .8, .3), i * .3, .3)
    return b

# ---------- calendrier ----------
def page(d=.22): return sweep_noise(2000, 800, d, .5) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 1.5
def calendar_open():
    b = buf(1.1)
    for t0 in [0, .14, .26]: put(b, page(), t0, .5)
    put(b, bell(mf(91), .8), .4, .7); put(b, bell(mf(96), .6), .5, .4); return b
def calendar_claim():
    b = buf(1.3); put(b, bell(mf(79), .5), 0, .6); put(b, bell(mf(86), .6), .08, .7); put(b, bell(mf(91), .8), .17, .8)
    put(b, sweep_noise(2000, 8000, .4, .4) * ex(int(SR * .4), .01, .2), .17, .25)
    for i in range(8): put(b, bell(mf(96 + [0, 4, 7, 12][i % 4]), .4, 1.3), .3 + i * .07, .25)
    return b
def calendar_milestone():
    b = buf(2.7)
    for m, t0, d in [(C5, 0, .2), (G5, .22, .2), (C6, .44, .2), (E6, .66, .9)]: put(b, brass(mf(m), d + .05, .02, .08), t0, .6)
    for m in [C5, E5, G5, C6, E6]: put(b, pad(mf(m), 1.8, .1, .9, 4), .66, .22)
    put(b, timp(.6, 100), 0, .5); put(b, timp(.9, 80), .66, .9)
    for i in range(10): put(b, bell(mf(91 + [0, 5, 9, 12][i % 4]), .7, 1.2), .9 + i * .12, .2)
    return b

# ---------- boucles ----------
def belt_loop():
    d = 5.0; n = int(SR * d); t = T(d)
    rum = lp(noise(d), 160); rum /= np.std(rum)
    hum = np.sin(PI2 * 60 * t) + .5 * np.sin(PI2 * 120 * t + 1) + .2 * np.sin(PI2 * 180 * t)
    ticks = band(noise(d), 800, 2500) * np.sin(np.pi * 6 * t) ** 10
    ticks /= (np.std(ticks) + 1e-9)
    wob = 1 + .15 * np.sin(PI2 * .4 * t)
    return (0.5 * rum + 0.35 * hum + 0.22 * ticks) * wob
def kiosk_ambience():
    d = 6.0; t = T(d)
    base = band(noise(d), 180, 1500); base /= np.std(base)
    y = base * (1 + .3 * np.sin(PI2 * 3 / d * t) + .2 * np.sin(PI2 * 7 / d * t + 1))
    for lo, hi, k, ph in [(450, 900, 17, 0), (900, 1700, 23, 2), (300, 650, 13, 4)]:
        v = band(noise(d), lo, hi); v /= np.std(v); y += .6 * v * (.5 + .5 * np.sin(PI2 * k / d * t + ph)) ** 2
    cl = buf(d); put(cl, bell(mf(96), .3, .5), 1.5, .08); put(cl, bell(mf(91), .3, .5), 4.2, .07)
    return y + cl * np.std(y) * 3

# ---------- divers ----------
def house_levelup():
    b = buf(2.6)
    for i, m in enumerate([60, 64, 67, 72, 76, 79]): put(b, brass(mf(m), .25, .02, .08), i * .14, .55)
    for m in [C5, E5, G5, C6]: put(b, brass(mf(m), 1.5, .05, .7), .9, .35)
    put(b, timp(.7, 80), .9, .8); put(b, pad(mf(48), 1.6, .1, .8, 2), .9, .3)
    for i in range(12): put(b, bell(mf(88 + [0, 4, 7, 12][i % 4] + 12 * (i // 8)), .7, 1.2), 1.0 + i * .12, .2)
    return b
def npc_ping():
    b = buf(.7); put(b, warm(mf(84), .25, .1) + .3 * bell(mf(96), .25), 0, .7); put(b, warm(mf(88), .4, .15) + .3 * bell(mf(100), .4), .14, .8); return b
def coin_pickup():
    b = buf(.45); t = T(.35)
    def sq(f, d): n = int(SR * d); return (np.sin(PI2 * f * T(d)) + .25 * np.sin(PI2 * 3 * f * T(d))) * ex(n, .001, d / 2.5)
    put(b, sq(mf(83), .08), 0, .7); put(b, sq(mf(88), .35), .07, .8); put(b, bell(mf(100), .3, 1.0), .07, .2); return b
def egg_shake():
    b = buf(1.0); ts = [.05, .15, .27, .36, .5, .6, .72, .82]
    for i, t0 in enumerate(ts):
        g = np.sin(np.pi * (t0 + .05)) ** 1.2
        c = band(noise(.06), 1500 + (i % 2) * 800, 4000) * ex(int(SR * .06), .0005, .015) + .7 * np.sin(PI2 * (330 + (i % 2) * 60) * T(.06)) * ex(int(SR * .06), .0005, .02)
        put(b, c / (np.max(np.abs(c)) + 1e-9), t0, .5 + .5 * g)
    return b
def belt_buy():
    b = buf(.6); put(b, (np.sin(PI2 * 1100 * T(.04)) * ex(int(SR * .04), .0005, .01) + .5 * lp(noise(.04), 3000) * ex(int(SR * .04), .0005, .01)), 0, .6)
    put(b, bell(mf(88), .4, .9), .07, .6); put(b, bell(mf(95), .45, .9), .13, .7); return b
def ui_click():
    b = buf(.12); put(b, np.sin(PI2 * 900 * T(.1)) * ex(int(SR * .1), .001, .02), 0, .7); put(b, np.sin(PI2 * 450 * T(.1)) * ex(int(SR * .1), .001, .03), 0, .4); return b
def ui_error():
    b = buf(.4); n = int(SR * .15)
    for t0 in [0, .17]:
        x = lp(sum(np.sin(PI2 * 150 * h * T(.15)) / h for h in range(1, 8)), 900) * ex(n, .005, .08)
        put(b, x, t0, .8)
    return b

JOBS = [
 ("hatch_r1", hatch_r1), ("hatch_r2", hatch_r2), ("hatch_r3", hatch_r3), ("hatch_r4", hatch_r4), ("hatch_r5", hatch_r5),
 ("hatch_r6", hatch_r6), ("hatch_r7", hatch_r7), ("hatch_r8", hatch_r8), ("hatch_r9", hatch_r9), ("hatch_r10", hatch_r10),
 ("jackpot_rare", jackpot_rare),
 ("atk_feu", atk_feu), ("atk_eau", atk_eau), ("atk_plante", atk_plante), ("atk_terre", atk_terre), ("atk_ciel", atk_ciel),
 ("atk_ombre", atk_ombre), ("atk_lumiere", atk_lumiere), ("atk_glace", atk_glace), ("atk_foudre", atk_foudre),
 ("special_ready", special_ready), ("special_hit", special_hit),
 ("battle_start", battle_start), ("battle_win", battle_win), ("battle_lose", battle_lose),
 ("calendar_open", calendar_open), ("calendar_claim", calendar_claim), ("calendar_milestone", calendar_milestone),
 ("belt_loop", belt_loop), ("belt_buy", belt_buy), ("kiosk_ambience", kiosk_ambience),
 ("house_levelup", house_levelup), ("npc_ping", npc_ping), ("coin_pickup", coin_pickup), ("egg_shake", egg_shake),
 ("ui_click", ui_click), ("ui_error", ui_error),
]
LOOPS = {"belt_loop": 6.0, "kiosk_ambience": 6.0}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in JOBS:
        if only and name not in only: continue
        finish(name, fn(), LOOPS.get(name, 3.0), name in LOOPS)
    print(len([f for f in os.listdir(OUT) if f.endswith(".ogg")]), "ogg dans", OUT)
