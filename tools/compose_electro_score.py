"""Original pulse/electro score: 64-bar forms, Reese bass, supersaws and sidechain.
No source audio, project-reference code, commercial melodies or samples are used.
Requires NumPy and SciPy; generated PCM is imported/compressed by Godot.
"""
from pathlib import Path
import json
import math
import wave
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets'/'audio'
SR = 32000
TAU = math.tau
analysis = []

def save(name, data, bpm=0):
    data = data.astype(np.float32)
    data -= np.mean(data, axis=0)
    data = sosfilt(butter(2, 27, 'highpass', fs=SR, output='sos'), data, axis=0)
    peak = float(np.max(np.abs(data)))
    if peak: data *= .94/peak
    pcm = (np.clip(data, -.96, .96)*32767).astype('<i2')
    with wave.open(str(OUT/(name+'.wav')), 'wb') as f:
        f.setnchannels(2 if data.ndim == 2 else 1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    analysis.append(dict(name=name, bpm=bpm, seconds=len(data)/SR,
                         peak=float(np.max(np.abs(data))), rms=float(np.sqrt(np.mean(data**2)))))
    print(f'ELECTRO {name}: {len(data)/SR:.1f}s, {bpm} BPM', flush=True)

def compose(name, bpm, root, theme, intense=False):
    beat = 60/bpm
    n = round(64*4*beat*SR)
    drums = np.zeros((n, 2), np.float32)
    low = np.zeros_like(drums)
    music = np.zeros_like(drums)
    rng = np.random.default_rng(2094+theme)
    cache = {}
    scale = [0, 2, 3, 5, 7, 8, 10] if theme != 7 else [0, 2, 4, 5, 7, 9, 11]
    progression = [[0, 5, 2, 6], [0, 3, 5, 4], [0, 6, 3, 5], [0, 2, 5, 3]][theme % 4]
    # Independently authored phrase contours, developed across eight sections.
    contour = [[0, 4, 7, 4, 2, 5, 9, 7], [4, 6, 7, 11, 9, 7, 5, 2],
               [0, 2, 6, 7, 4, 9, 7, 2], [7, 4, 2, 0, 2, 5, 7, 9]][theme % 4]

    def add(bus, at, signal, gain, pan=0):
        start = round(at*SR) % n
        count = min(len(signal), n-start)
        stereo = np.stack((signal*math.sqrt((1-pan)/2), signal*math.sqrt((1+pan)/2)), 1)*gain
        bus[start:start+count] += stereo[:count]
        if count < len(signal): bus[:len(signal)-count] += stereo[count:]

    def tone(bus, at, midi, duration, gain, voice='lead', pan=0):
        count = round(duration*SR)
        key = (midi, count, voice)
        if key not in cache:
            t = np.arange(count, dtype=np.float32)/SR
            freq = 440*2**((midi-69)/12)
            attack = .006 if voice == 'bass' else .009
            env = np.minimum(1, t/attack)*np.minimum(1, (duration-t)/.035)
            if voice == 'sub':
                s = np.sin(TAU*freq*t)*env
            else:
                s = np.zeros(count, np.float32)
                for detune in ([.993, 1, 1.007] if voice == 'lead' else [.997, 1.003]):
                    for h in range(1, 8 if voice == 'bass' else 6):
                        if freq*h*detune < SR*.42:
                            s += np.sin(TAU*freq*h*detune*t)/(h*(3 if voice == 'lead' else 2))
                s *= env
                if voice == 'arp': s *= np.exp(-t*12)
                if voice == 'bass': s = np.tanh(s*2.5)*.65
            cache[key] = s.astype(np.float32)
        add(bus, at, cache[key], gain, pan)

    drum_cache = {}
    def drum(at, kind, gain):
        if kind not in drum_cache:
            duration = {'kick': .25, 'snare': .17, 'clap': .13, 'hat': .06, 'open': .18, 'crash': .8}[kind]
            t = np.arange(round(duration*SR), dtype=np.float32)/SR
            noise = rng.uniform(-1, 1, len(t))
            bright = noise - np.roll(noise, 1)
            if kind == 'kick':
                phase = 48*t + 6*(1-np.exp(-t*32))
                s = np.tanh(np.sin(TAU*phase)*1.9)*np.exp(-t*16)
                s += bright*np.exp(-t*500)*.17
            elif kind in ['snare', 'clap']:
                s = (bright*.52 + np.sin(TAU*185*t)*.35)*np.exp(-t*30)
                if kind == 'clap': s *= .6+.4*np.sin(TAU*130*t)**2
            else:
                s = bright*np.exp(-t*({'hat': 75, 'open': 22, 'crash': 6}[kind]))*.5
            drum_cache[kind] = s.astype(np.float32)
        add(drums, at, drum_cache[kind], gain, -.18 if kind in ['hat', 'open'] else 0)

    for bar in range(64):
        phrase = bar//8
        drop = phrase in [1, 2, 5, 6]
        build = phrase in [0, 4, 7]
        breakdown = phrase == 3
        drive = (1 if drop else (.72 if build else .45)) * (1 if intense else .8)
        degree = progression[(bar//2) % 4]
        chord = root + scale[degree]
        if not breakdown:
            for b in range(4):
                kick_on = not (theme == 3 and b == 1)
                if kick_on: drum((bar*4+b)*beat, 'kick', .65*drive)
                if b % 2: drum((bar*4+b)*beat, 'snare', .32*drive)
                drum((bar*4+b+.5)*beat, 'open', .18*drive)
                for off in ([.25, .75] if drop or intense else [.75]):
                    drum((bar*4+b+off)*beat, 'hat', .13*drive)
            if theme == 3: drum((bar*4+2.75)*beat, 'kick', .36)
        if bar % 8 == 0: drum(bar*4*beat, 'crash', .28)
        if bar % 8 == 7:
            for j in range(8): drum((bar*4+2+j*.25)*beat, 'snare', .07+j*.018)
        for b in range(4):
            if breakdown and b % 2: continue
            tone(low, (bar*4+b+.0)*beat, chord-24, beat*.8, .38*drive, 'sub')
            for off in ([.0, .5] if drop or intense else [.5]):
                midi = chord-12+(7 if b == 3 and bar % 2 else 0)
                tone(low, (bar*4+b+off)*beat, midi, beat*.42, .29*drive, 'bass')
        for step in range(8):
            if breakdown and step % 2: continue
            value = contour[(step+bar % 4) % 8]
            value += 2 if phrase in [2, 6] and step >= 4 else 0
            midi = root+12+scale[value % 7]+12*(value//7)
            if bar % 4 == 3 and step > 5: midi -= 12
            voice = 'lead' if drop else 'arp'
            tone(music, (bar*4+step*.5)*beat, midi, beat*(.43 if drop else .3),
                 .16 if intense and drop else .115, voice, .18*math.sin(step+bar))
            if intense or theme == 3:
                tone(music, (bar*4+step*.5+.25)*beat, midi+12, beat*.18, .045, 'arp', -.4)
        for third in [0, 3, 7]:
            tone(music, bar*4*beat, chord+third, beat*3.9, .035 if breakdown else .017, 'lead', -.35 if third == 0 else .35)
        if bar in [6, 14, 30, 38, 46, 62]:
            duration = beat*8
            t = np.arange(round(duration*SR), dtype=np.float32)/SR
            noise = rng.uniform(-1, 1, len(t))
            rise = (t/duration)**2
            signal = (noise*.12+np.sin(TAU*(180*t+1100*t*t/duration))*.06)*rise
            add(music, bar*4*beat, signal, .9)
    # Pump pads, leads and bass around every kick; leave the transients intact.
    phase = (np.arange(n, dtype=np.float32)/SR) % beat
    duck = .22+.78*(1-np.exp(-phase*22))
    low *= duck[:, None]
    music *= (.55+.45*duck)[:, None]
    music += np.roll(music[:, ::-1], round(beat*.75*SR), 0)*.20
    data = np.tanh((drums+low+music)*1.25)
    # A narrow final high-frequency rolloff avoids harsh synthetic aliases.
    data = sosfilt(butter(2, 12500, fs=SR, output='sos'), data, axis=0)
    save(name, data, bpm)

for level, bpm, root in [(1, 156, 57), (2, 160, 60), (3, 168, 54), (4, 164, 59)]:
    compose(f'campus_{level}', bpm, root, level)
    compose(f'campus_{level}_intense', bpm, root, level, True)
for name, bpm, root, theme in [('modern_menu', 152, 57, 5), ('urgent_chase', 176, 54, 6),
                               ('epic_boss', 172, 52, 4), ('epic_final', 180, 52, 6), ('ceremony', 148, 60, 7)]:
    compose(name, bpm, root, theme, True)

def effect(name, duration, category, index):
    rng = np.random.default_rng(801+index)
    t = np.arange(round(duration*SR), dtype=np.float32)/SR
    env = np.minimum(1, t/.004)*np.maximum(0, 1-t/duration)**2
    noise = rng.uniform(-1, 1, len(t))
    if category == 'sweep':
        signal = (np.sin(TAU*(240*t+1600*t*t))*.5 + noise*.12)*env
    elif category == 'impact':
        signal = (np.sin(TAU*(75*t+2.5*(1-np.exp(-t*40))))*.6+noise*np.exp(-t*35)*.4)*env
    elif category == 'reward':
        signal = np.zeros(len(t))
        for j, midi in enumerate([76, 83, 88]):
            f = 440*2**((midi-69)/12)
            signal += np.sin(TAU*f*t)*(t >= j*duration*.16)*np.exp(-np.maximum(0, t-j*duration*.16)*10)*.25
        signal *= env
    else:
        signal = (np.sin(TAU*(480*t+90*t*t))*.5+np.sin(TAU*720*t)*.2)*env
    save(name, signal)

for i, (name, category, duration) in enumerate([
    ('jump', 'sweep', .19), ('attack', 'sweep', .16), ('hit', 'impact', .21),
    ('hurt', 'impact', .32), ('coin', 'reward', .17), ('power', 'reward', .46),
    ('victory', 'reward', .85), ('alert', 'tone', .25), ('windup', 'sweep', .32),
    ('enemy_attack', 'impact', .22), ('checkpoint', 'reward', .56), ('ui_hover', 'tone', .07),
    ('land', 'impact', .10), ('step', 'impact', .045)]):
    effect(name, duration, category, i)

(ROOT/'docs'/'music-analysis.json').write_text(json.dumps({
    'method': 'Original electro synthesis. 64 bars, 8 phrases; drops/builds/break, sidechain Reese/sub bass, supersaws, arpeggios, percussion fills and stereo delay. No third-party source recordings.',
    'sample_rate': SR, 'tracks': analysis}, indent=2), encoding='utf-8')
